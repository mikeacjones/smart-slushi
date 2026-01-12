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

    /// Evaluate slushability based on ABV and Brix values using default machine constraints
    public static func evaluate(abv: Double, brix: Double) -> SlushabilityStatus {
        // Use default Ninja Slushi 72oz constraints
        evaluate(abv: abv, brix: brix, machine: .ninjaSlushi72oz)
    }

    /// Evaluate slushability based on ABV and Brix values for a specific machine
    /// - Parameters:
    ///   - abv: The alcohol by volume percentage
    ///   - brix: The sugar content (Brix)
    ///   - machine: The target slush machine with its constraints
    /// - Returns: The slushability status for this recipe on the given machine
    public static func evaluate(abv: Double, brix: Double, machine: SlushiMachine) -> SlushabilityStatus {
        // Check ABV first - too high prevents freezing entirely
        if abv > machine.maxABV {
            return .willNotFreeze
        }

        // Warning zone: within 80-100% of max ABV
        let abvWarningThreshold = machine.maxABV * 0.8
        let isABVNearLimit = abv > abvWarningThreshold

        if isABVNearLimit {
            // At upper limit, give a warning but check Brix too
            if brix < machine.minBrix + 1 {
                return .warning("ABV at \(String(format: "%.1f", abv))% is high, and Brix at \(String(format: "%.1f", brix)) is low - may be icy.")
            }
            if brix > machine.maxBrix - 1 {
                return .warning("ABV at \(String(format: "%.1f", abv))% is high, and Brix at \(String(format: "%.1f", brix)) is high - may be soft.")
            }
            return .warning("ABV at \(String(format: "%.1f", abv))% is near the machine limit (\(String(format: "%.0f", machine.maxABV))%) - may be softer than ideal.")
        }

        // ABV is acceptable, now check Brix
        if brix < machine.minBrix {
            return .willNotFreeze
        }

        // Calculate optimal Brix range (middle of acceptable range)
        let optimalRange = machine.optimalBrixRange
        let warningLowThreshold = machine.minBrix + 1
        let warningHighThreshold = machine.maxBrix - 1

        if brix < warningLowThreshold {
            return .notSweetEnough
        }

        if brix > machine.maxBrix {
            return .willNotFreeze
        }

        if brix > warningHighThreshold {
            return .tooSweet
        }

        // Check if in optimal range
        if optimalRange.contains(brix) {
            return .optimal
        }

        // In acceptable range but not optimal
        if brix < optimalRange.lowerBound {
            return .notSweetEnough
        }

        if brix > optimalRange.upperBound {
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
    /// The machine used for constraint evaluation
    public let machine: SlushiMachine

    public init(
        totalVolumeOz: Double,
        totalVolumeMl: Double,
        finalABV: Double,
        finalBrix: Double,
        freezingPointCelsius: Double,
        freezingPointFahrenheit: Double,
        slushabilityStatus: SlushabilityStatus,
        servings: Int,
        warnings: [String],
        machine: SlushiMachine = .default
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
        self.machine = machine
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
        warnings: [],
        machine: .default
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
        targetBatchSize: Double = 72,
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
    public func createRecipe(targetBatchSize: Double = 72) -> Recipe {
        Recipe(
            name: name,
            description: description,
            baseRecipeId: id,
            ingredients: baseIngredients,
            targetBatchSize: targetBatchSize
        )
    }
}
