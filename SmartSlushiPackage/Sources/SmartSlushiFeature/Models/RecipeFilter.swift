import Foundation

// MARK: - Recipe Filter

/// Filter options for community recipes
public struct RecipeFilter: Equatable, Sendable {
    /// Filter by alcohol categories present in the recipe
    public var alcoholCategories: Set<IngredientCategory> = []

    /// ABV range filter
    public var abvRange: ClosedRange<Double>?

    /// Whether any filters are active
    public var hasActiveFilters: Bool {
        !alcoholCategories.isEmpty || abvRange != nil
    }

    /// Reset all filters to defaults
    public mutating func reset() {
        alcoholCategories = []
        abvRange = nil
    }

    public init(
        alcoholCategories: Set<IngredientCategory> = [],
        abvRange: ClosedRange<Double>? = nil
    ) {
        self.alcoholCategories = alcoholCategories
        self.abvRange = abvRange
    }
}

// MARK: - ABV Presets

extension RecipeFilter {
    /// Predefined ABV ranges for quick selection
    public enum ABVPreset: String, CaseIterable, Sendable {
        case light = "Light (0-5%)"
        case moderate = "Moderate (5-8%)"
        case standard = "Standard (8-12%)"
        case strong = "Strong (12%+)"

        public var range: ClosedRange<Double> {
            switch self {
            case .light: return 0...5
            case .moderate: return 5...8
            case .standard: return 8...12
            case .strong: return 12...100
            }
        }

        public var icon: String {
            switch self {
            case .light: return "drop"
            case .moderate: return "drop.halffull"
            case .standard: return "drop.fill"
            case .strong: return "flame.fill"
            }
        }
    }

    /// Alcohol categories that can be filtered (those with ABV > 0)
    public static let filterableCategories: [IngredientCategory] = [
        .spirit,
        .liqueur,
        .wine,
        .beer
    ]
}
