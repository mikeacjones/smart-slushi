import Foundation

// MARK: - Slushability Status

/// Indicates whether a recipe will freeze properly in a slush machine
public enum SlushabilityStatus: Equatable, Sendable {
    case optimal
    case tooSweet
    case notSweetEnough
    case tooAlcoholic
    case willNotFreeze
    case warning(String)

    public var isOptimal: Bool {
        if case .optimal = self { return true }
        return false
    }

    public var message: String {
        switch self {
        case .optimal:
            return "Perfect for slush!"
        case .tooSweet:
            return "Too sweet - may stay runny. Add water to dilute."
        case .notSweetEnough:
            return "Not sweet enough - may freeze too hard. Add sweetener."
        case .tooAlcoholic:
            return "Too much alcohol - won't freeze properly. Add water."
        case .willNotFreeze:
            return "This mix won't form a proper slush."
        case .warning(let message):
            return message
        }
    }

    /// Evaluate slushability based on ABV and Brix values
    /// - Parameters:
    ///   - abv: Final alcohol by volume percentage
    ///   - brix: Final sugar content
    ///   - optimalBrixRange: ABV-adjusted optimal Brix window (defaults to 13–15)
    public static func evaluate(
        abv: Double,
        brix: Double,
        optimalBrixRange: ClosedRange<Double> = 13...15
    ) -> SlushabilityStatus {
        // Check ABV first - too high prevents freezing entirely
        if abv > 12 {
            return .willNotFreeze
        }

        if abv > 10 {
            return .tooAlcoholic
        }

        // Hard failure bands outside the workable Brix window
        let hardLow = max(11.0, optimalBrixRange.lowerBound - 2.0)
        let hardHigh = min(18.0, optimalBrixRange.upperBound + 2.0)

        if brix < hardLow {
            return .willNotFreeze
        }

        if brix < optimalBrixRange.lowerBound {
            return .notSweetEnough
        }

        if brix > hardHigh {
            return .willNotFreeze
        }

        if brix > optimalBrixRange.upperBound {
            return .tooSweet
        }

        // Both ABV and Brix are in optimal range
        return .optimal
    }
}

// MARK: - Recipe Ingredient

/// Represents an ingredient as used in a recipe with its amount
public struct RecipeIngredient: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let ingredientId: UUID
    public var amount: Double
    public var unit: MeasurementUnit

    /// Whether the user has locked this ingredient's ratio during auto-balance
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        ingredientId: UUID,
        amount: Double,
        unit: MeasurementUnit = .oz,
        isLocked: Bool = false
    ) {
        self.id = id
        self.ingredientId = ingredientId
        self.amount = amount
        self.unit = unit
        self.isLocked = isLocked
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ingredientId
        case amount
        case unit
        case isLocked
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        ingredientId = try container.decode(UUID.self, forKey: .ingredientId)
        amount = try container.decode(Double.self, forKey: .amount)

        let unitRaw = try container.decodeIfPresent(String.self, forKey: .unit) ?? MeasurementUnit.oz.rawValue
        unit = MeasurementUnit(rawValue: unitRaw) ?? .oz

        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ingredientId, forKey: .ingredientId)
        try container.encode(amount, forKey: .amount)
        try container.encode(unit.rawValue, forKey: .unit)
        try container.encode(isLocked, forKey: .isLocked)
    }

    /// Get the volume in milliliters
    public var volumeInMl: Double {
        unit.convert(amount, to: .ml)
    }

    /// Get the volume in ounces
    public var volumeInOz: Double {
        unit.convert(amount, to: .oz)
    }
}

// MARK: - Recipe Stats

/// Calculated statistics for a recipe
public struct RecipeStats: Sendable {
    public let totalVolumeOz: Double
    public let totalVolumeMl: Double
    public let finalABV: Double
    public let finalBrix: Double
    public let freezingPointCelsius: Double
    public let freezingPointFahrenheit: Double
    public let slushabilityStatus: SlushabilityStatus
    public let servings: Int
    public let warnings: [String]

    public init(
        totalVolumeOz: Double,
        totalVolumeMl: Double,
        finalABV: Double,
        finalBrix: Double,
        freezingPointCelsius: Double,
        freezingPointFahrenheit: Double,
        slushabilityStatus: SlushabilityStatus,
        servings: Int,
        warnings: [String]
    ) {
        self.totalVolumeOz = totalVolumeOz
        self.totalVolumeMl = totalVolumeMl
        self.finalABV = finalABV
        self.finalBrix = finalBrix
        self.freezingPointCelsius = freezingPointCelsius
        self.freezingPointFahrenheit = freezingPointFahrenheit
        self.slushabilityStatus = slushabilityStatus
        self.servings = servings
        self.warnings = warnings
    }

    /// Default empty stats
    public static let empty = RecipeStats(
        totalVolumeOz: 0,
        totalVolumeMl: 0,
        finalABV: 0,
        finalBrix: 0,
        freezingPointCelsius: 0,
        freezingPointFahrenheit: 32,
        slushabilityStatus: .optimal,
        servings: 0,
        warnings: []
    )
}

// MARK: - Recipe

/// A complete slush recipe with ingredients and metadata
public struct Recipe: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?

    /// If this recipe was created from a template
    public var baseRecipeId: UUID?

    /// The ingredients in this recipe
    public var ingredients: [RecipeIngredient]

    /// Target batch size in ounces
    public var targetBatchSize: Double

    /// Preferred display unit
    public var targetUnit: MeasurementUnit

    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        baseRecipeId: UUID? = nil,
        ingredients: [RecipeIngredient] = [],
        targetBatchSize: Double = 64,
        targetUnit: MeasurementUnit = .oz,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.baseRecipeId = baseRecipeId
        self.ingredients = ingredients
        self.targetBatchSize = targetBatchSize
        self.targetUnit = targetUnit
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Recipe Template

/// A pre-defined recipe template that can be customized
public struct RecipeTemplate: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let category: String
    public let flavorProfile: String?

    /// Base ingredients with ratios (amounts that can be scaled)
    public let baseIngredients: [RecipeIngredient]

    /// Pre-calculated values for the base recipe
    public let baseABV: Double
    public let baseBrix: Double

    /// Machine-ready adjustments (dilution ratios, etc.)
    public let dilutionRatio: Double?

    /// Tips for making this recipe
    public let notes: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        category: String,
        flavorProfile: String? = nil,
        baseIngredients: [RecipeIngredient],
        baseABV: Double,
        baseBrix: Double,
        dilutionRatio: Double? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.flavorProfile = flavorProfile
        self.baseIngredients = baseIngredients
        self.baseABV = baseABV
        self.baseBrix = baseBrix
        self.dilutionRatio = dilutionRatio
        self.notes = notes
    }

    /// Create a new Recipe instance from this template
    public func createRecipe(targetBatchSize: Double = 64) -> Recipe {
        let baseVolumeOz = baseIngredients.reduce(0.0) { partialResult, ingredient in
            partialResult + ingredient.volumeInOz
        }

        let scaledIngredients: [RecipeIngredient]
        if baseVolumeOz > 0, targetBatchSize > 0 {
            let scaleFactor = targetBatchSize / baseVolumeOz
            scaledIngredients = baseIngredients.map { ingredient in
                var scaled = ingredient
                scaled.amount = ingredient.amount * scaleFactor
                return scaled
            }
        } else {
            scaledIngredients = baseIngredients
        }

        return Recipe(
            name: name,
            description: description,
            baseRecipeId: id,
            ingredients: scaledIngredients,
            targetBatchSize: targetBatchSize
        )
    }
}
