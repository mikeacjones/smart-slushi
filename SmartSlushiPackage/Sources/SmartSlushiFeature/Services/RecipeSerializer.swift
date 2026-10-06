import Foundation

// MARK: - Export Format

/// Supported formats for recipe export
public enum RecipeExportFormat: String, CaseIterable, Sendable {
    case json
    case text
    case shoppingList

    public var displayName: String {
        switch self {
        case .json: return "JSON"
        case .text: return "Text"
        case .shoppingList: return "Shopping List"
        }
    }

    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .text, .shoppingList: return "txt"
        }
    }

    public var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .text, .shoppingList: return "text/plain"
        }
    }
}

// MARK: - Exportable Recipe

/// Codable representation of a recipe for import/export
public struct ExportableRecipe: Codable, Sendable {
    public let version: String
    public let exportedAt: Date
    public let recipe: RecipeData

    public struct RecipeData: Codable, Sendable {
        public let id: String
        public let name: String
        public let description: String?
        public let targetBatchSize: Double
        public let targetUnit: String
        public let ingredients: [IngredientData]
        public let createdAt: Date
        public let modifiedAt: Date
    }

    public struct IngredientData: Codable, Sendable {
        public let name: String
        public let amount: Double
        public let unit: String
        public let abv: Double
        public let brix: Double
        public let category: String
        public let isLocked: Bool?

        public init(
            name: String,
            amount: Double,
            unit: String,
            abv: Double,
            brix: Double,
            category: String,
            isLocked: Bool? = false
        ) {
            self.name = name
            self.amount = amount
            self.unit = unit
            self.abv = abv
            self.brix = brix
            self.category = category
            self.isLocked = isLocked
        }
    }

    public static let currentVersion = "1.1"
}

// MARK: - Recipe Serializer

/// Handles serialization and deserialization of recipes for export/import
public final class RecipeSerializer: Sendable {
    private let calculator: SlushCalculator

    public init(calculator: SlushCalculator = SlushCalculator()) {
        self.calculator = calculator
    }

    // MARK: - Export

    /// Export a recipe to JSON format
    /// - Parameters:
    ///   - recipe: The recipe to export
    ///   - ingredientLookup: Function to resolve ingredient details
    /// - Returns: JSON string representation
    public func exportToJSON(
        _ recipe: Recipe,
        ingredientLookup: @escaping (UUID) -> Ingredient?
    ) throws -> String {
        let exportable = createExportable(recipe, ingredientLookup: ingredientLookup)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportable)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw RecipeSerializerError.encodingFailed
        }
        return jsonString
    }

    /// Export a recipe to shareable text format
    /// - Parameters:
    ///   - recipe: The recipe to export
    ///   - ingredientLookup: Function to resolve ingredient details
    ///   - includeStats: Whether to include calculated stats
    /// - Returns: Human-readable text representation
    public func exportToText(
        _ recipe: Recipe,
        ingredientLookup: @escaping (UUID) -> Ingredient?,
        includeStats: Bool = true
    ) -> String {
        var lines: [String] = []

        // Header
        lines.append("===================================")
        lines.append(recipe.name.uppercased())
        lines.append("===================================")

        if let description = recipe.description, !description.isEmpty {
            lines.append("")
            lines.append(description)
        }

        lines.append("")
        lines.append("Batch Size: \(formatBatchSize(recipe))")
        lines.append("")

        // Ingredients
        lines.append("INGREDIENTS")
        lines.append("-----------------------------------")

        for recipeIngredient in recipe.ingredients {
            if let ingredient = ingredientLookup(recipeIngredient.ingredientId) {
                let amount = formatAmount(recipeIngredient.amount, unit: recipeIngredient.unit)
                lines.append("\(amount) \(ingredient.name)")
            }
        }

        // Stats
        if includeStats {
            let stats = calculator.calculateStats(
                for: recipe.ingredients,
                ingredientLookup: ingredientLookup
            )

            lines.append("")
            lines.append("STATS")
            lines.append("-----------------------------------")
            lines.append("ABV: \(String(format: "%.1f", stats.finalABV))%")
            lines.append("Brix: \(String(format: "%.1f", stats.finalBrix))")
            lines.append("Freezing Point: \(String(format: "%.0f", stats.freezingPointFahrenheit))F")
            lines.append("Servings: ~\(stats.servings)")
            lines.append("")
            lines.append("Status: \(stats.slushabilityStatus.message)")
        }

        lines.append("")
        lines.append("-----------------------------------")
        lines.append("Created with Smart Slushi")

        return lines.joined(separator: "\n")
    }

    /// Export a recipe as a shopping list
    /// - Parameters:
    ///   - recipe: The recipe to export
    ///   - ingredientLookup: Function to resolve ingredient details
    /// - Returns: Shopping list text
    public func exportToShoppingList(
        _ recipe: Recipe,
        ingredientLookup: @escaping (UUID) -> Ingredient?
    ) -> String {
        var lines: [String] = []

        lines.append("SHOPPING LIST: \(recipe.name)")
        lines.append("===================================")
        lines.append("Batch Size: \(formatBatchSize(recipe))")
        lines.append("")

        // Group ingredients by category
        var ingredientsByCategory: [IngredientCategory: [(Ingredient, RecipeIngredient)]] = [:]

        for recipeIngredient in recipe.ingredients {
            if let ingredient = ingredientLookup(recipeIngredient.ingredientId) {
                ingredientsByCategory[ingredient.category, default: []].append((ingredient, recipeIngredient))
            }
        }

        // Sort categories and output
        let sortedCategories = ingredientsByCategory.keys.sorted { $0.displayName < $1.displayName }

        for category in sortedCategories {
            guard let items = ingredientsByCategory[category] else { continue }

            lines.append(category.displayName.uppercased())
            lines.append("-----------------------------------")

            for (ingredient, recipeIngredient) in items {
                let ozAmount = recipeIngredient.volumeInOz
                let mlAmount = recipeIngredient.volumeInMl

                let checkbox = "[ ]"
                let ozFormatted = formatAmount(ozAmount, unit: .oz)
                let mlFormatted = formatAmount(mlAmount, unit: .ml)

                lines.append("\(checkbox) \(ingredient.name)")
                lines.append("    \(ozFormatted) / \(mlFormatted)")
            }

            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Import

    /// Import a recipe from JSON format
    /// - Parameters:
    ///   - json: JSON string to import
    ///   - ingredientDatabase: Database to resolve ingredient references
    /// - Returns: Imported recipe (or nil if ingredients can't be matched)
    public func importFromJSON(
        _ json: String,
        ingredientDatabase: IngredientDatabase
    ) throws -> Recipe {
        guard let data = json.data(using: .utf8) else {
            throw RecipeSerializerError.invalidInput
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportable = try decoder.decode(ExportableRecipe.self, from: data)
        // Accept current and prior 1.x exports
        let supportedVersions: Set<String> = ["1.0", "1.1", ExportableRecipe.currentVersion]
        guard supportedVersions.contains(exportable.version) else {
            throw RecipeSerializerError.versionMismatch(exportable.version)
        }
        return try createRecipe(from: exportable, ingredientDatabase: ingredientDatabase)
    }

    // MARK: - Private Helpers

    private func createExportable(
        _ recipe: Recipe,
        ingredientLookup: @escaping (UUID) -> Ingredient?
    ) -> ExportableRecipe {
        let ingredientData = recipe.ingredients.map { recipeIngredient -> ExportableRecipe.IngredientData in
            if let ingredient = ingredientLookup(recipeIngredient.ingredientId) {
                return ExportableRecipe.IngredientData(
                    name: ingredient.name,
                    amount: recipeIngredient.amount,
                    unit: recipeIngredient.unit.rawValue,
                    abv: ingredient.abv,
                    brix: ingredient.brix,
                    category: ingredient.category.rawValue,
                    isLocked: recipeIngredient.isLocked
                )
            }
            return ExportableRecipe.IngredientData(
                name: "Unknown Ingredient",
                amount: recipeIngredient.amount,
                unit: recipeIngredient.unit.rawValue,
                abv: 0,
                brix: 0,
                category: IngredientCategory.misc.rawValue,
                isLocked: recipeIngredient.isLocked
            )
        }

        let recipeData = ExportableRecipe.RecipeData(
            id: recipe.id.uuidString,
            name: recipe.name,
            description: recipe.description,
            targetBatchSize: recipe.targetBatchSize,
            targetUnit: recipe.targetUnit.rawValue,
            ingredients: ingredientData,
            createdAt: recipe.createdAt,
            modifiedAt: recipe.modifiedAt
        )

        return ExportableRecipe(
            version: ExportableRecipe.currentVersion,
            exportedAt: Date(),
            recipe: recipeData
        )
    }

    private func createRecipe(
        from exportable: ExportableRecipe,
        ingredientDatabase: IngredientDatabase
    ) throws -> Recipe {
        var recipeIngredients: [RecipeIngredient] = []
        var unmatchedIngredients: [String] = []

        for ingredientData in exportable.recipe.ingredients {
            let unit = MeasurementUnit(rawValue: ingredientData.unit) ?? .oz
            let isLocked = ingredientData.isLocked ?? false

            // Prefer exact name match in the local database
            if let matchingIngredient = ingredientDatabase.search(ingredientData.name).first(where: {
                $0.name.lowercased() == ingredientData.name.lowercased()
            }) {
                let recipeIngredient = RecipeIngredient(
                    ingredientId: matchingIngredient.id,
                    amount: ingredientData.amount,
                    unit: unit,
                    isLocked: isLocked
                )
                recipeIngredients.append(recipeIngredient)
            } else {
                // Recreate missing ingredients as custom entries so imports stay complete
                let category = IngredientCategory(rawValue: ingredientData.category) ?? .misc
                let custom = Ingredient(
                    name: ingredientData.name,
                    category: category,
                    abv: ingredientData.abv,
                    brix: ingredientData.brix,
                    defaultUnit: unit,
                    isCustom: true,
                    notes: "Imported with recipe"
                )
                ingredientDatabase.addCustomIngredient(custom)
                unmatchedIngredients.append(ingredientData.name)

                recipeIngredients.append(RecipeIngredient(
                    ingredientId: custom.id,
                    amount: ingredientData.amount,
                    unit: unit,
                    isLocked: isLocked
                ))
            }
        }

        if recipeIngredients.isEmpty && !exportable.recipe.ingredients.isEmpty {
            throw RecipeSerializerError.noMatchingIngredients(unmatchedIngredients)
        }

        let targetUnit = MeasurementUnit(rawValue: exportable.recipe.targetUnit) ?? .oz

        return Recipe(
            id: UUID(),  // Generate new ID for imported recipe
            name: exportable.recipe.name,
            description: exportable.recipe.description,
            ingredients: recipeIngredients,
            targetBatchSize: exportable.recipe.targetBatchSize,
            targetUnit: targetUnit,
            createdAt: Date(),  // Use current date for import
            modifiedAt: Date()
        )
    }

    private func formatAmount(_ amount: Double, unit: MeasurementUnit) -> String {
        switch unit {
        case .ml:
            return "\(Int(amount.rounded())) \(unit.abbreviation)"
        case .cup:
            return String(format: "%.1f %@", amount, unit.abbreviation)
        default:
            if amount == Double(Int(amount)) {
                return "\(Int(amount)) \(unit.abbreviation)"
            } else {
                return String(format: "%.2f %@", amount, unit.abbreviation)
            }
        }
    }

    private func formatBatchSize(_ recipe: Recipe) -> String {
        let converted = MeasurementUnit.oz.convert(recipe.targetBatchSize, to: recipe.targetUnit)
        return formatAmount(converted, unit: recipe.targetUnit)
    }
}

// MARK: - Errors

public enum RecipeSerializerError: Error, LocalizedError {
    case encodingFailed
    case invalidInput
    case noMatchingIngredients([String])
    case versionMismatch(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode recipe to JSON"
        case .invalidInput:
            return "Invalid input data"
        case .noMatchingIngredients(let names):
            return "Could not find matching ingredients: \(names.joined(separator: ", "))"
        case .versionMismatch(let version):
            return "Unsupported recipe format version: \(version)"
        }
    }
}
