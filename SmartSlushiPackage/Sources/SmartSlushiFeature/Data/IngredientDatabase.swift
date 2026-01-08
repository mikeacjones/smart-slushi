import Foundation
import Observation

// MARK: - JSON Structures for Decoding

private struct IngredientDatabaseJSON: Codable {
    let metadata: MetadataJSON
    let ingredients: IngredientsContainerJSON
}

private struct MetadataJSON: Codable {
    let version: String
    let lastUpdated: String
    let sources: [String]
    let notes: String
}

private struct IngredientsContainerJSON: Codable {
    let spirits: [IngredientItemJSON]
    let liqueurs: [IngredientItemJSON]
    let sweeteners: [IngredientItemJSON]
    let citrus: [IngredientItemJSON]
    let juices: [IngredientItemJSON]
    let purees: [IngredientItemJSON]
    let dairy_and_cream: [IngredientItemJSON]
    let mixers: [IngredientItemJSON]
    let wine_and_beer: [IngredientItemJSON]
    let bitters_and_misc: [IngredientItemJSON]

    enum CodingKeys: String, CodingKey {
        case spirits, liqueurs, sweeteners, citrus, juices, purees
        case dairy_and_cream, mixers, wine_and_beer, bitters_and_misc
    }
}

private struct IngredientItemJSON: Codable {
    let name: String
    let abv: Double
    let brix: Double
    let category: String
    let notes: String?
}

// MARK: - Ingredient Database

/// Manages the ingredient database including built-in and custom ingredients
@available(iOS 17.0, macOS 14.0, *)
@Observable
public final class IngredientDatabase: @unchecked Sendable {
    /// All available ingredients (built-in + custom)
    public private(set) var ingredients: [Ingredient] = []

    /// Recently used ingredient IDs (for quick access)
    public private(set) var recentIngredientIds: [UUID] = []

    /// Maximum number of recent ingredients to track
    @ObservationIgnored
    private let maxRecentIngredients = 10

    /// Singleton instance
    @ObservationIgnored
    public static let shared = IngredientDatabase()

    private init() {
        loadBuiltInIngredients()
    }

    // MARK: - Loading

    /// Load built-in ingredients from the bundled JSON file
    private func loadBuiltInIngredients() {
        guard let url = Bundle.module.url(forResource: "ingredient-database", withExtension: "json") else {
            print("Error: Could not find ingredient-database.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let database = try JSONDecoder().decode(IngredientDatabaseJSON.self, from: data)
            ingredients = parseIngredients(from: database.ingredients)
        } catch {
            print("Error loading ingredient database: \(error)")
        }
    }

    /// Parse all ingredient categories from JSON
    private func parseIngredients(from container: IngredientsContainerJSON) -> [Ingredient] {
        var allIngredients: [Ingredient] = []

        allIngredients.append(contentsOf: parseCategory(container.spirits, category: .spirit))
        allIngredients.append(contentsOf: parseCategory(container.liqueurs, category: .liqueur))
        allIngredients.append(contentsOf: parseCategory(container.sweeteners, category: .sweetener))
        allIngredients.append(contentsOf: parseCategory(container.citrus, category: .citrus))
        allIngredients.append(contentsOf: parseCategory(container.juices, category: .juice))
        allIngredients.append(contentsOf: parseCategory(container.purees, category: .puree))
        allIngredients.append(contentsOf: parseCategory(container.dairy_and_cream, category: .dairy))
        allIngredients.append(contentsOf: parseCategory(container.mixers, category: .mixer))
        allIngredients.append(contentsOf: parseMixedCategory(container.wine_and_beer))
        allIngredients.append(contentsOf: parseMixedCategory(container.bitters_and_misc))

        return allIngredients
    }

    /// Parse a single category of ingredients
    private func parseCategory(_ items: [IngredientItemJSON], category: IngredientCategory) -> [Ingredient] {
        return items.map { item in
            Ingredient(
                id: Ingredient.deterministicId(for: item.name),
                name: item.name,
                category: category,
                abv: item.abv,
                brix: item.brix,
                defaultUnit: defaultUnit(for: category),
                isCustom: false,
                notes: item.notes
            )
        }
    }

    /// Parse categories where items specify their own category
    private func parseMixedCategory(_ items: [IngredientItemJSON]) -> [Ingredient] {
        return items.map { item in
            let category = mapCategory(item.category)
            return Ingredient(
                id: Ingredient.deterministicId(for: item.name),
                name: item.name,
                category: category,
                abv: item.abv,
                brix: item.brix,
                defaultUnit: defaultUnit(for: category),
                isCustom: false,
                notes: item.notes
            )
        }
    }

    /// Map JSON category string to IngredientCategory enum
    private func mapCategory(_ jsonCategory: String) -> IngredientCategory {
        switch jsonCategory.lowercased() {
        case "spirit": return .spirit
        case "liqueur": return .liqueur
        case "sweetener": return .sweetener
        case "citrus": return .citrus
        case "juice": return .juice
        case "puree": return .puree
        case "dairy": return .dairy
        case "mixer": return .mixer
        case "wine": return .wine
        case "beer": return .beer
        case "bitters": return .bitters
        default: return .misc
        }
    }

    /// Get default measurement unit for a category
    private func defaultUnit(for category: IngredientCategory) -> MeasurementUnit {
        switch category {
        case .bitters:
            return .teaspoon
        case .sweetener:
            return .oz
        default:
            return .oz
        }
    }

    // MARK: - Access

    /// Get an ingredient by its ID
    public func ingredient(for id: UUID) -> Ingredient? {
        ingredients.first { $0.id == id }
    }

    /// Get ingredients filtered by category
    public func ingredients(in category: IngredientCategory) -> [Ingredient] {
        ingredients.filter { $0.category == category }
    }

    /// Get ingredients grouped by category
    public var ingredientsByCategory: [IngredientCategory: [Ingredient]] {
        Dictionary(grouping: ingredients) { $0.category }
    }

    /// Search ingredients by name
    public func search(_ query: String) -> [Ingredient] {
        guard !query.isEmpty else { return ingredients }
        let lowercasedQuery = query.lowercased()
        return ingredients.filter { $0.name.lowercased().contains(lowercasedQuery) }
    }

    /// Get recently used ingredients
    public var recentIngredients: [Ingredient] {
        recentIngredientIds.compactMap { ingredient(for: $0) }
    }

    // MARK: - Common Ingredients (Quick Access)

    /// Water ingredient (for auto-balance)
    public var water: Ingredient? {
        ingredients.first { $0.name == "Water" && $0.category == .mixer }
    }

    /// Simple syrup ingredient (for auto-balance)
    public var simpleSyrup: Ingredient? {
        ingredients.first { $0.name.contains("Simple Syrup") && $0.name.contains("1:1") }
    }

    // MARK: - Custom Ingredients

    /// Add a custom ingredient to the database
    public func addCustomIngredient(_ ingredient: Ingredient) {
        // Create new with isCustom = true
        let customIngredient = Ingredient(
            id: ingredient.id,
            name: ingredient.name,
            category: ingredient.category,
            abv: ingredient.abv,
            brix: ingredient.brix,
            defaultUnit: ingredient.defaultUnit,
            isCustom: true,
            notes: ingredient.notes
        )
        ingredients.append(customIngredient)
    }

    /// Remove a custom ingredient
    public func removeCustomIngredient(_ id: UUID) {
        ingredients.removeAll { $0.id == id && $0.isCustom }
    }

    /// Get all custom ingredients
    public var customIngredients: [Ingredient] {
        ingredients.filter { $0.isCustom }
    }

    // MARK: - Recent Ingredients Tracking

    /// Mark an ingredient as recently used
    public func markAsRecentlyUsed(_ id: UUID) {
        // Remove if already in list
        recentIngredientIds.removeAll { $0 == id }

        // Add to front
        recentIngredientIds.insert(id, at: 0)

        // Trim to max size
        if recentIngredientIds.count > maxRecentIngredients {
            recentIngredientIds = Array(recentIngredientIds.prefix(maxRecentIngredients))
        }
    }

    /// Clear recent ingredients list
    public func clearRecentIngredients() {
        recentIngredientIds.removeAll()
    }
}

// MARK: - Convenience Extensions

@available(iOS 17.0, macOS 14.0, *)
extension IngredientDatabase {
    /// Create a lookup function for use with SlushCalculator
    public func lookupFunction() -> (UUID) -> Ingredient? {
        return { [weak self] id in
            self?.ingredient(for: id)
        }
    }
}
