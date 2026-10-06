import Foundation
import SwiftData

// MARK: - Saved Recipe (SwiftData Model)

/// A persisted recipe using SwiftData
@available(iOS 17.0, macOS 14.0, *)
@Model
public final class SavedRecipe {
    /// Unique identifier
    public var id: UUID

    /// Recipe name
    public var name: String

    /// Optional description
    public var recipeDescription: String?

    /// If this recipe was created from a template
    public var baseRecipeId: UUID?

    /// JSON-encoded ingredients
    public var ingredientsData: Data

    /// JSON-encoded custom ingredient snapshots referenced by this recipe (for CloudKit sync)
    public var customIngredientsData: Data

    /// Target batch size in ounces
    public var targetBatchSize: Double

    /// Preferred display unit (stored as string)
    public var targetUnitRaw: String

    /// When the recipe was created
    public var createdAt: Date

    /// When the recipe was last modified
    public var modifiedAt: Date

    /// Whether this recipe is marked as favorite
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        recipeDescription: String? = nil,
        baseRecipeId: UUID? = nil,
        ingredientsData: Data = Data(),
        customIngredientsData: Data = Data(),
        targetBatchSize: Double = 64,
        targetUnitRaw: String = "oz",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.recipeDescription = recipeDescription
        self.baseRecipeId = baseRecipeId
        self.ingredientsData = ingredientsData
        self.customIngredientsData = customIngredientsData
        self.targetBatchSize = targetBatchSize
        self.targetUnitRaw = targetUnitRaw
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isFavorite = isFavorite
    }
}

// MARK: - Conversion Between Recipe and SavedRecipe

@available(iOS 17.0, macOS 14.0, *)
extension SavedRecipe {
    /// The target unit as a MeasurementUnit enum
    public var targetUnit: MeasurementUnit {
        get {
            MeasurementUnit(rawValue: targetUnitRaw) ?? .oz
        }
        set {
            targetUnitRaw = newValue.rawValue
        }
    }

    /// Decoded ingredients array
    public var ingredients: [RecipeIngredient] {
        get {
            guard !ingredientsData.isEmpty else { return [] }
            do {
                return try JSONDecoder().decode([RecipeIngredient].self, from: ingredientsData)
            } catch {
                print("Error decoding ingredients: \(error)")
                return []
            }
        }
        set {
            do {
                ingredientsData = try JSONEncoder().encode(newValue)
            } catch {
                print("Error encoding ingredients: \(error)")
                ingredientsData = Data()
            }
        }
    }

    /// Decoded custom ingredient snapshots
    public var customIngredients: [Ingredient] {
        get {
            guard !customIngredientsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([Ingredient].self, from: customIngredientsData)) ?? []
        }
        set {
            customIngredientsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Create a SavedRecipe from a Recipe, optionally capturing custom ingredient snapshots
    public convenience init(
        from recipe: Recipe,
        isFavorite: Bool = false,
        customIngredients: [Ingredient] = []
    ) {
        let ingredientsData: Data
        do {
            ingredientsData = try JSONEncoder().encode(recipe.ingredients)
        } catch {
            ingredientsData = Data()
        }

        let customData = (try? JSONEncoder().encode(customIngredients)) ?? Data()

        self.init(
            id: recipe.id,
            name: recipe.name,
            recipeDescription: recipe.description,
            baseRecipeId: recipe.baseRecipeId,
            ingredientsData: ingredientsData,
            customIngredientsData: customData,
            targetBatchSize: recipe.targetBatchSize,
            targetUnitRaw: recipe.targetUnit.rawValue,
            createdAt: recipe.createdAt,
            modifiedAt: recipe.modifiedAt,
            isFavorite: isFavorite
        )
    }

    /// Convert to a Recipe struct
    public func toRecipe() -> Recipe {
        Recipe(
            id: id,
            name: name,
            description: recipeDescription,
            baseRecipeId: baseRecipeId,
            ingredients: ingredients,
            targetBatchSize: targetBatchSize,
            targetUnit: targetUnit,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    /// Restore any embedded custom ingredients into the local database
    public func restoreCustomIngredients(into database: IngredientDatabase) {
        for ingredient in customIngredients {
            if database.ingredient(for: ingredient.id) == nil {
                database.addCustomIngredient(ingredient)
            }
        }
    }

    /// Update from a Recipe struct, refreshing custom ingredient snapshots
    public func update(from recipe: Recipe, customIngredients: [Ingredient] = []) {
        name = recipe.name
        recipeDescription = recipe.description
        baseRecipeId = recipe.baseRecipeId
        ingredients = recipe.ingredients
        self.customIngredients = customIngredients
        targetBatchSize = recipe.targetBatchSize
        targetUnit = recipe.targetUnit
        modifiedAt = Date()
    }
}

// MARK: - User Preferences (SwiftData Model)

/// Persisted user preferences using SwiftData
/// Note: No unique constraint on identifier to support CloudKit sync.
/// Multiple devices may create preferences before syncing - RecipeStore handles deduplication.
@available(iOS 17.0, macOS 14.0, *)
@Model
public final class UserPreferencesStore {
    /// Singleton marker (always "default")
    /// CloudKit sync may create duplicates which are merged in RecipeStore.loadUserPreferences()
    public var identifier: String

    /// Default batch size in ounces
    public var defaultBatchSize: Double

    /// Default measurement unit (stored as string)
    public var defaultUnitRaw: String

    /// Ninja Slushi model capacity (72 or 88 oz)
    public var machineCapacity: Double

    /// Sweetness preference (0.0 to 1.0)
    public var sweetnessLevel: Double

    /// Thickness preference (0.0 to 1.0)
    public var slushThickness: Double

    /// Alcohol strength preference (0.0 to 1.0)
    public var alcoholStrength: Double

    /// Recent ingredient IDs (JSON encoded)
    public var recentIngredientIdsData: Data

    /// Serving size in ounces for serving calculations
    public var servingSizeOz: Double = 8

    public init(
        identifier: String = "default",
        defaultBatchSize: Double = 64,
        defaultUnitRaw: String = "oz",
        machineCapacity: Double = 72,
        sweetnessLevel: Double = 0.5,
        slushThickness: Double = 0.5,
        alcoholStrength: Double = 0.5,
        recentIngredientIdsData: Data = Data(),
        servingSizeOz: Double = 8
    ) {
        self.identifier = identifier
        self.defaultBatchSize = defaultBatchSize
        self.defaultUnitRaw = defaultUnitRaw
        self.machineCapacity = machineCapacity
        self.sweetnessLevel = sweetnessLevel
        self.slushThickness = slushThickness
        self.alcoholStrength = alcoholStrength
        self.recentIngredientIdsData = recentIngredientIdsData
        self.servingSizeOz = servingSizeOz
    }
}

@available(iOS 17.0, macOS 14.0, *)
extension UserPreferencesStore {
    /// Default unit as MeasurementUnit enum
    public var defaultUnit: MeasurementUnit {
        get { MeasurementUnit(rawValue: defaultUnitRaw) ?? .oz }
        set { defaultUnitRaw = newValue.rawValue }
    }

    /// Recent ingredient IDs
    public var recentIngredientIds: [UUID] {
        get {
            guard !recentIngredientIdsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: recentIngredientIdsData)) ?? []
        }
        set {
            recentIngredientIdsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Convert to DrinkPreferences struct
    public func toDrinkPreferences() -> DrinkPreferences {
        DrinkPreferences(
            sweetnessLevel: sweetnessLevel,
            slushThickness: slushThickness,
            alcoholStrength: alcoholStrength
        )
    }

    /// Update from DrinkPreferences struct
    public func update(from preferences: DrinkPreferences) {
        sweetnessLevel = preferences.sweetnessLevel
        slushThickness = preferences.slushThickness
        alcoholStrength = preferences.alcoholStrength
    }
}
