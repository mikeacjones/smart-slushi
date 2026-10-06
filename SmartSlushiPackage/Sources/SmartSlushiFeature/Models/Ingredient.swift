import Foundation

// MARK: - Ingredient Category

/// Categories for organizing ingredients in the database
public enum IngredientCategory: String, Codable, CaseIterable, Sendable {
    case spirit
    case liqueur
    case sweetener
    case citrus
    case juice
    case puree
    case dairy
    case mixer
    case wine
    case beer
    case bitters
    case misc

    public var displayName: String {
        switch self {
        case .spirit: return "Spirits"
        case .liqueur: return "Liqueurs"
        case .sweetener: return "Sweeteners"
        case .citrus: return "Citrus"
        case .juice: return "Juices"
        case .puree: return "Purees"
        case .dairy: return "Dairy & Cream"
        case .mixer: return "Mixers"
        case .wine: return "Wine"
        case .beer: return "Beer & Seltzers"
        case .bitters: return "Bitters"
        case .misc: return "Miscellaneous"
        }
    }
}

// MARK: - Measurement Unit

/// Supported measurement units with conversion factors
public enum MeasurementUnit: String, Codable, CaseIterable, Sendable {
    case oz
    case ml
    case cup
    case tablespoon
    case teaspoon
    case liter

    /// Conversion factor to milliliters
    public var toMl: Double {
        switch self {
        case .oz: return 29.5735
        case .ml: return 1.0
        case .cup: return 236.588
        case .tablespoon: return 14.787
        case .teaspoon: return 4.929
        case .liter: return 1000.0
        }
    }

    /// Conversion factor from milliliters
    public var fromMl: Double {
        return 1.0 / toMl
    }

    /// Convert an amount from this unit to another unit
    public func convert(_ amount: Double, to unit: MeasurementUnit) -> Double {
        let ml = amount * self.toMl
        return ml / unit.toMl
    }

    public var abbreviation: String {
        switch self {
        case .oz: return "oz"
        case .ml: return "ml"
        case .cup: return "cup"
        case .tablespoon: return "tbsp"
        case .teaspoon: return "tsp"
        case .liter: return "L"
        }
    }

    public var displayName: String {
        switch self {
        case .oz: return "Ounces"
        case .ml: return "Milliliters"
        case .cup: return "Cups"
        case .tablespoon: return "Tablespoons"
        case .teaspoon: return "Teaspoons"
        case .liter: return "Liters"
        }
    }
}

// MARK: - Ingredient

/// Represents an ingredient with its ABV and Brix values
public struct Ingredient: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let category: IngredientCategory

    /// Alcohol by volume percentage (0-100)
    public let abv: Double

    /// Sugar content in Brix (0-100)
    public let brix: Double

    /// Default measurement unit for this ingredient
    public let defaultUnit: MeasurementUnit

    /// Whether this is a user-created custom ingredient
    public let isCustom: Bool

    /// Optional notes about the ingredient
    public let notes: String?

    public init(
        id: UUID = UUID(),
        name: String,
        category: IngredientCategory,
        abv: Double,
        brix: Double,
        defaultUnit: MeasurementUnit = .oz,
        isCustom: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.abv = abv
        self.brix = brix
        self.defaultUnit = defaultUnit
        self.isCustom = isCustom
        self.notes = notes
    }
}

// MARK: - Ingredient Convenience Properties

extension Ingredient {
    /// Whether this ingredient contains alcohol
    public var isAlcoholic: Bool {
        abv > 0
    }

    /// Whether this ingredient is primarily a sweetener (high brix, no alcohol)
    public var isSweetener: Bool {
        brix >= 40 && abv == 0
    }

    /// Whether this ingredient is water (0 ABV, 0 Brix)
    public var isWater: Bool {
        abv == 0 && brix == 0 && (category == .mixer || name.lowercased().contains("water"))
    }
}

// MARK: - Deterministic UUID Generation

extension Ingredient {
    /// Generate a deterministic UUID from ingredient name
    /// This ensures the same ingredient always has the same UUID across app launches
    public static func deterministicId(for name: String) -> UUID {
        // Use a namespace UUID (DNS namespace from RFC 4122)
        let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!

        // Create a deterministic UUID by hashing the namespace + name
        var data = withUnsafeBytes(of: namespace.uuid) { Data($0) }
        data.append(Data(name.utf8))

        // Deterministic hash (DJB2 + LCG) — not cryptographic; stable IDs for built-in ingredients
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            // Simple hash using DJB2 algorithm, expanded to 16 bytes
            var hashValue: UInt64 = 5381
            for byte in buffer {
                hashValue = ((hashValue << 5) &+ hashValue) &+ UInt64(byte)
            }

            // Use the hash to seed generation of 16 bytes
            var seed = hashValue
            for i in 0..<16 {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                hash[i] = UInt8(truncatingIfNeeded: seed >> 56)
            }
        }

        // Set version (4) and variant (RFC 4122) bits
        hash[6] = (hash[6] & 0x0F) | 0x40  // Version 4
        hash[8] = (hash[8] & 0x3F) | 0x80  // Variant RFC 4122

        return UUID(uuid: (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        ))
    }
}

// MARK: - JSON Decoding Support

/// Structure for decoding ingredients from the research JSON file
struct IngredientJSON: Codable {
    let name: String
    let abv: Double
    let brix: Double
    let category: String
    let notes: String?
}
