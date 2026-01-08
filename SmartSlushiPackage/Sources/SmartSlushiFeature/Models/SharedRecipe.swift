import Foundation

// MARK: - Exported Ingredient

/// Self-contained ingredient data for shared recipes
/// Unlike RecipeIngredient which references an ingredientId, this contains all ingredient data inline
public struct ExportedIngredient: Codable, Hashable, Sendable {
    public let name: String
    public let category: String
    public let abv: Double
    public let brix: Double
    public let amount: Double
    public let unit: String

    public init(
        name: String,
        category: String,
        abv: Double,
        brix: Double,
        amount: Double,
        unit: String
    ) {
        self.name = name
        self.category = category
        self.abv = abv
        self.brix = brix
        self.amount = amount
        self.unit = unit
    }

    /// Convert from a RecipeIngredient using an ingredient lookup
    public init(from recipeIngredient: RecipeIngredient, ingredient: Ingredient) {
        self.name = ingredient.name
        self.category = ingredient.category.rawValue
        self.abv = ingredient.abv
        self.brix = ingredient.brix
        self.amount = recipeIngredient.amount
        self.unit = recipeIngredient.unit.rawValue
    }

    /// Try to match this exported ingredient to a database ingredient and create a RecipeIngredient
    public func toRecipeIngredient(using database: IngredientDatabase) -> RecipeIngredient? {
        // Try to find matching ingredient by name (case-insensitive)
        guard let matchingIngredient = database.search(name).first(where: {
            $0.name.lowercased() == name.lowercased()
        }) else {
            return nil
        }

        let ingredientUnit = MeasurementUnit(rawValue: unit) ?? .oz

        return RecipeIngredient(
            ingredientId: matchingIngredient.id,
            amount: amount,
            unit: ingredientUnit
        )
    }
}

// MARK: - Shared Recipe

/// A recipe shared in the CloudKit public database
public struct SharedRecipe: Identifiable, Sendable {
    /// CloudKit record ID (recordName)
    public let id: String

    /// Anonymous CloudKit user record ID of the author
    public let authorId: String

    /// Recipe name
    public let name: String

    /// Recipe description
    public let description: String?

    /// Custom notes added by the author when publishing
    public let authorNotes: String?

    /// Self-contained ingredient list (not referencing local database)
    public let ingredients: [ExportedIngredient]

    /// Target batch size in ounces
    public let targetBatchSize: Double

    /// Preferred display unit
    public let targetUnit: MeasurementUnit

    /// When the recipe was first published
    public let publishedAt: Date

    /// When the recipe was last updated
    public let updatedAt: Date

    /// Pre-calculated final ABV for display and sorting
    public let finalABV: Double

    /// Pre-calculated final Brix for display
    public let finalBrix: Double

    /// Number of upvotes
    public private(set) var upvoteCount: Int

    /// Number of downvotes
    public private(set) var downvoteCount: Int

    /// Net score (upvotes - downvotes)
    public var score: Int { upvoteCount - downvoteCount }

    /// Total number of votes
    public var totalVotes: Int { upvoteCount + downvoteCount }

    /// Number of reports against this recipe
    public let reportCount: Int

    /// Whether the recipe is hidden due to reports
    public let isHidden: Bool

    public init(
        id: String,
        authorId: String,
        name: String,
        description: String?,
        authorNotes: String?,
        ingredients: [ExportedIngredient],
        targetBatchSize: Double,
        targetUnit: MeasurementUnit,
        publishedAt: Date,
        updatedAt: Date,
        finalABV: Double,
        finalBrix: Double,
        upvoteCount: Int = 0,
        downvoteCount: Int = 0,
        reportCount: Int = 0,
        isHidden: Bool = false
    ) {
        self.id = id
        self.authorId = authorId
        self.name = name
        self.description = description
        self.authorNotes = authorNotes
        self.ingredients = ingredients
        self.targetBatchSize = targetBatchSize
        self.targetUnit = targetUnit
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.finalABV = finalABV
        self.finalBrix = finalBrix
        self.upvoteCount = upvoteCount
        self.downvoteCount = downvoteCount
        self.reportCount = reportCount
        self.isHidden = isHidden
    }

    /// Create from a SavedRecipe for publishing
    public static func create(
        from savedRecipe: SavedRecipe,
        authorId: String,
        authorNotes: String?,
        ingredientLookup: (UUID) -> Ingredient?,
        stats: RecipeStats
    ) -> SharedRecipe {
        let exportedIngredients = savedRecipe.ingredients.compactMap { recipeIngredient -> ExportedIngredient? in
            guard let ingredient = ingredientLookup(recipeIngredient.ingredientId) else {
                return nil
            }
            return ExportedIngredient(from: recipeIngredient, ingredient: ingredient)
        }

        return SharedRecipe(
            id: UUID().uuidString, // Will be replaced by CloudKit
            authorId: authorId,
            name: savedRecipe.name,
            description: savedRecipe.recipeDescription,
            authorNotes: authorNotes,
            ingredients: exportedIngredients,
            targetBatchSize: savedRecipe.targetBatchSize,
            targetUnit: savedRecipe.targetUnit,
            publishedAt: Date(),
            updatedAt: Date(),
            finalABV: stats.finalABV,
            finalBrix: stats.finalBrix
        )
    }

    /// Create from a Recipe for publishing
    public static func create(
        from recipe: Recipe,
        authorId: String,
        authorNotes: String?,
        ingredientLookup: (UUID) -> Ingredient?,
        stats: RecipeStats
    ) -> SharedRecipe {
        let exportedIngredients = recipe.ingredients.compactMap { recipeIngredient -> ExportedIngredient? in
            guard let ingredient = ingredientLookup(recipeIngredient.ingredientId) else {
                return nil
            }
            return ExportedIngredient(from: recipeIngredient, ingredient: ingredient)
        }

        return SharedRecipe(
            id: UUID().uuidString, // Will be replaced by CloudKit
            authorId: authorId,
            name: recipe.name,
            description: recipe.description,
            authorNotes: authorNotes,
            ingredients: exportedIngredients,
            targetBatchSize: recipe.targetBatchSize,
            targetUnit: recipe.targetUnit,
            publishedAt: Date(),
            updatedAt: Date(),
            finalABV: stats.finalABV,
            finalBrix: stats.finalBrix
        )
    }

    /// Convert to a local Recipe for editing/importing
    public func toRecipe(using database: IngredientDatabase) -> Recipe {
        let recipeIngredients = ingredients.compactMap { exported in
            exported.toRecipeIngredient(using: database)
        }

        return Recipe(
            name: name,
            description: description,
            ingredients: recipeIngredients,
            targetBatchSize: targetBatchSize,
            targetUnit: targetUnit
        )
    }

    /// Create a copy with updated vote counts
    public func withVoteCounts(upvotes: Int, downvotes: Int) -> SharedRecipe {
        var copy = self
        copy.upvoteCount = upvotes
        copy.downvoteCount = downvotes
        return copy
    }
}

// MARK: - Hashable

extension SharedRecipe: Hashable {
    public static func == (lhs: SharedRecipe, rhs: SharedRecipe) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
