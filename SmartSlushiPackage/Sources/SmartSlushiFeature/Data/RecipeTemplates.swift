import Foundation
import Observation

// MARK: - JSON Structures for Decoding

private struct RecipeTemplatesJSON: Codable {
    let metadata: TemplateMetadataJSON
    let templates: [TemplateJSON]
    let categories: [CategoryJSON]
}

private struct TemplateMetadataJSON: Codable {
    let version: String
    let lastUpdated: String
    let sources: [String]
    let notes: String
}

private struct CategoryJSON: Codable {
    let id: String
    let name: String
    let icon: String
}

private struct TemplateJSON: Codable {
    let id: String
    let name: String
    let description: String
    let category: String
    let baseIngredients: [TemplateIngredientJSON]
    let expectedStats: ExpectedStatsJSON?
    let batchNotes: String?
    let machineReady: MachineReadyJSON?
    let tags: [String]
    let servingSize: Double?
    let isBatchRecipe: Bool?
    let yield: YieldJSON?
    let source: String?
}

private struct TemplateIngredientJSON: Codable {
    let ingredient: String
    let amount: Double
    let unit: String
    let scalable: Bool
    let notes: String?
}

private struct ExpectedStatsJSON: Codable {
    let abvSingleServing: Double?
    let brixSingleServing: Double?
    let abv: Double?
    let brix: Double?
}

private struct MachineReadyJSON: Codable {
    let waterRatio: Double?
    let additionalSweetenerRatio: Double?
    let expectedABV: Double
    let expectedBrix: Double
}

private struct YieldJSON: Codable {
    let totalOz: Double
    let servings: Int
    let servingSizeOz: Double
}

// MARK: - Template Category

/// Categories for organizing recipe templates
public struct TemplateCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let icon: String

    public init(id: String, name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

// MARK: - Recipe Template Store

/// Manages pre-defined recipe templates
@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class RecipeTemplateStore: @unchecked Sendable {
    /// All available recipe templates
    public private(set) var templates: [RecipeTemplate] = []

    /// Template categories
    public private(set) var categories: [TemplateCategory] = []

    /// Singleton instance
    @ObservationIgnored
    public static let shared = RecipeTemplateStore()

    /// Reference to ingredient database for lookups
    @ObservationIgnored
    private weak var ingredientDatabase: IngredientDatabase?

    private init() {
        self.ingredientDatabase = IngredientDatabase.shared
        loadTemplates()
    }

    /// Initialize with a specific ingredient database (for testing)
    public init(ingredientDatabase: IngredientDatabase) {
        self.ingredientDatabase = ingredientDatabase
        loadTemplates()
    }

    // MARK: - Loading

    /// Load templates from the bundled JSON file
    private func loadTemplates() {
        guard let url = Bundle.module.url(forResource: "recipe-templates", withExtension: "json") else {
            print("Error: Could not find recipe-templates.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let database = try JSONDecoder().decode(RecipeTemplatesJSON.self, from: data)
            categories = parseCategories(from: database.categories)
            templates = parseTemplates(from: database.templates)
        } catch {
            print("Error loading recipe templates: \(error)")
        }
    }

    /// Parse categories from JSON
    private func parseCategories(from jsonCategories: [CategoryJSON]) -> [TemplateCategory] {
        jsonCategories.map { category in
            TemplateCategory(
                id: category.id,
                name: category.name,
                icon: category.icon
            )
        }
    }

    /// Parse templates from JSON
    private func parseTemplates(from jsonTemplates: [TemplateJSON]) -> [RecipeTemplate] {
        jsonTemplates.compactMap { parseTemplate($0) }
    }

    /// Parse a single template
    private func parseTemplate(_ json: TemplateJSON) -> RecipeTemplate? {
        guard let db = ingredientDatabase else { return nil }

        // Convert ingredients to RecipeIngredients
        let recipeIngredients: [RecipeIngredient] = json.baseIngredients.compactMap { ingredient in
            // Look up ingredient by name
            guard let foundIngredient = db.ingredients.first(where: {
                $0.name.lowercased() == ingredient.ingredient.lowercased()
            }) else {
                print("Warning: Could not find ingredient '\(ingredient.ingredient)' for template '\(json.name)'")
                return nil
            }

            let unit = parseUnit(ingredient.unit)
            return RecipeIngredient(
                ingredientId: foundIngredient.id,
                amount: ingredient.amount,
                unit: unit,
                isLocked: false
            )
        }

        // Skip templates where we couldn't find all ingredients
        guard recipeIngredients.count == json.baseIngredients.count else {
            print("Warning: Skipping template '\(json.name)' - could not resolve all ingredients")
            return nil
        }

        // Determine ABV and Brix from either single serving or batch stats
        let baseABV: Double
        let baseBrix: Double
        if let stats = json.expectedStats {
            baseABV = stats.abv ?? stats.abvSingleServing ?? 0
            baseBrix = stats.brix ?? stats.brixSingleServing ?? 0
        } else {
            baseABV = 0
            baseBrix = 0
        }

        // Build flavor profile from tags
        let flavorProfile = json.tags.joined(separator: ", ")

        // Build notes from batch notes and machine ready info
        var notes = json.batchNotes ?? ""
        if let machineReady = json.machineReady {
            if !notes.isEmpty { notes += "\n\n" }
            notes += "Machine-ready: ABV \(String(format: "%.1f", machineReady.expectedABV))%, Brix \(String(format: "%.1f", machineReady.expectedBrix))"
            if let waterRatio = machineReady.waterRatio {
                notes += ". Add \(Int(waterRatio * 100))% water."
            }
        }
        if let source = json.source {
            if !notes.isEmpty { notes += "\n\n" }
            notes += "Source: \(source)"
        }

        return RecipeTemplate(
            id: UUID(uuidString: json.id) ?? UUID(),
            name: json.name,
            description: json.description,
            category: json.category,
            flavorProfile: flavorProfile,
            baseIngredients: recipeIngredients,
            baseABV: baseABV,
            baseBrix: baseBrix,
            dilutionRatio: json.machineReady?.waterRatio,
            notes: notes.isEmpty ? nil : notes
        )
    }

    /// Parse unit string to MeasurementUnit
    private func parseUnit(_ unit: String) -> MeasurementUnit {
        switch unit.lowercased() {
        case "oz": return .oz
        case "ml": return .ml
        case "cup", "cups": return .cup
        case "tbsp", "tablespoon": return .tablespoon
        case "tsp", "teaspoon": return .teaspoon
        case "l", "liter": return .liter
        default: return .oz
        }
    }

    // MARK: - Access

    /// Get a template by ID
    public func template(for id: UUID) -> RecipeTemplate? {
        templates.first { $0.id == id }
    }

    /// Get templates filtered by category
    public func templates(in category: String) -> [RecipeTemplate] {
        templates.filter { $0.category == category }
    }

    /// Get templates grouped by category
    public var templatesByCategory: [String: [RecipeTemplate]] {
        Dictionary(grouping: templates) { $0.category }
    }

    /// Search templates by name or description
    public func search(_ query: String) -> [RecipeTemplate] {
        guard !query.isEmpty else { return templates }
        let lowercasedQuery = query.lowercased()
        return templates.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            ($0.description?.lowercased().contains(lowercasedQuery) ?? false) ||
            ($0.flavorProfile?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    /// Get category by ID
    public func category(for id: String) -> TemplateCategory? {
        categories.first { $0.id == id }
    }

    /// Get display name for a category
    public func categoryDisplayName(for categoryId: String) -> String {
        category(for: categoryId)?.name ?? categoryId.capitalized
    }

    /// Get icon for a category
    public func categoryIcon(for categoryId: String) -> String {
        category(for: categoryId)?.icon ?? "🍹"
    }
}
