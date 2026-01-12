import Foundation
import SwiftData
import Observation

// MARK: - Recipe Store

/// Manages saved recipes using SwiftData
@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class RecipeStore {
    /// The SwiftData model context
    private var modelContext: ModelContext?

    /// Cached saved recipes (updated when changes occur)
    public private(set) var savedRecipes: [SavedRecipe] = []

    /// User preferences from persistent storage
    public private(set) var userPreferences: UserPreferencesStore?

    /// Sort order for recipes
    public enum SortOrder: String, CaseIterable, Sendable {
        case dateCreated = "Date Created"
        case dateModified = "Date Modified"
        case name = "Name"
        case favorites = "Favorites First"
    }

    /// Current sort order
    public var sortOrder: SortOrder = .dateModified {
        didSet {
            sortRecipes()
        }
    }

    public init() {}

    // MARK: - Setup

    /// Configure the store with a model context
    public func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRecipes()
        loadUserPreferences()
    }

    // MARK: - Recipe Operations

    /// Load all saved recipes from the database
    private func loadRecipes() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<SavedRecipe>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )

        do {
            savedRecipes = try context.fetch(descriptor)
            sortRecipes()
        } catch {
            print("Error loading recipes: \(error)")
            savedRecipes = []
        }
    }

    /// Sort recipes based on current sort order
    private func sortRecipes() {
        switch sortOrder {
        case .dateCreated:
            savedRecipes.sort { $0.createdAt > $1.createdAt }
        case .dateModified:
            savedRecipes.sort { $0.modifiedAt > $1.modifiedAt }
        case .name:
            savedRecipes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .favorites:
            savedRecipes.sort {
                if $0.isFavorite != $1.isFavorite {
                    return $0.isFavorite
                }
                return $0.modifiedAt > $1.modifiedAt
            }
        }
    }

    /// Save a recipe to the database
    public func save(_ recipe: Recipe, isFavorite: Bool = false) {
        guard let context = modelContext else { return }

        // Check if recipe already exists
        if let existing = savedRecipes.first(where: { $0.id == recipe.id }) {
            existing.update(from: recipe)
        } else {
            let savedRecipe = SavedRecipe(from: recipe, isFavorite: isFavorite)
            context.insert(savedRecipe)
            savedRecipes.append(savedRecipe)
        }

        do {
            try context.save()
            sortRecipes()
        } catch {
            print("Error saving recipe: \(error)")
        }
    }

    /// Delete a saved recipe
    public func delete(_ recipe: SavedRecipe) {
        guard let context = modelContext else { return }

        context.delete(recipe)
        savedRecipes.removeAll { $0.id == recipe.id }

        do {
            try context.save()
        } catch {
            print("Error deleting recipe: \(error)")
        }
    }

    /// Delete a recipe by ID
    public func delete(id: UUID) {
        guard let recipe = savedRecipes.first(where: { $0.id == id }) else { return }
        delete(recipe)
    }

    /// Toggle favorite status for a recipe
    public func toggleFavorite(_ recipe: SavedRecipe) {
        recipe.isFavorite.toggle()
        recipe.modifiedAt = Date()

        guard let context = modelContext else { return }
        do {
            try context.save()
            sortRecipes()
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }

    /// Get a recipe by ID
    public func recipe(for id: UUID) -> SavedRecipe? {
        savedRecipes.first { $0.id == id }
    }

    /// Check if a recipe with the given ID exists
    public func exists(id: UUID) -> Bool {
        savedRecipes.contains { $0.id == id }
    }

    /// Get favorite recipes
    public var favoriteRecipes: [SavedRecipe] {
        savedRecipes.filter { $0.isFavorite }
    }

    /// Search recipes by name
    public func search(_ query: String) -> [SavedRecipe] {
        guard !query.isEmpty else { return savedRecipes }
        let lowercasedQuery = query.lowercased()
        return savedRecipes.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            ($0.recipeDescription?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    // MARK: - User Preferences

    /// Load or create user preferences
    /// Handles potential duplicates from CloudKit sync by keeping the most recently used one
    private func loadUserPreferences() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<UserPreferencesStore>(
            predicate: #Predicate { $0.identifier == "default" }
        )

        do {
            let results = try context.fetch(descriptor)

            if results.isEmpty {
                // Create default preferences
                let defaults = UserPreferencesStore()
                context.insert(defaults)
                try context.save()
                userPreferences = defaults
            } else if results.count == 1 {
                // Normal case - single preferences record
                userPreferences = results.first
            } else {
                // CloudKit sync may have created duplicates - merge and keep the most customized one
                // Keep the one that appears most customized (non-default values)
                let sorted = results.sorted { prefs1, prefs2 in
                    // Prioritize preferences with more recent ingredients or non-default settings
                    let score1 = prefs1.recentIngredientIds.count + (prefs1.machineCapacity != 72 ? 10 : 0)
                    let score2 = prefs2.recentIngredientIds.count + (prefs2.machineCapacity != 72 ? 10 : 0)
                    return score1 > score2
                }

                let preferred = sorted[0]
                userPreferences = preferred

                // Remove duplicates
                for duplicate in sorted.dropFirst() {
                    // Merge recent ingredients before deleting
                    var mergedRecent = preferred.recentIngredientIds
                    for id in duplicate.recentIngredientIds where !mergedRecent.contains(id) {
                        mergedRecent.append(id)
                    }
                    preferred.recentIngredientIds = Array(mergedRecent.prefix(10))

                    context.delete(duplicate)
                }

                try context.save()
            }
        } catch {
            print("Error loading user preferences: \(error)")
        }
    }

    /// Save user preferences
    public func savePreferences() {
        guard let context = modelContext else { return }

        do {
            try context.save()
        } catch {
            print("Error saving preferences: \(error)")
        }
    }

    /// Update drink preferences
    public func updateDrinkPreferences(_ preferences: DrinkPreferences) {
        userPreferences?.update(from: preferences)
        savePreferences()
    }

    /// Add ingredient to recent list
    public func markIngredientAsRecentlyUsed(_ id: UUID) {
        guard let prefs = userPreferences else { return }

        var recent = prefs.recentIngredientIds
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)

        // Keep only last 10
        if recent.count > 10 {
            recent = Array(recent.prefix(10))
        }

        prefs.recentIngredientIds = recent
        savePreferences()
    }
}

// MARK: - Model Container Configuration

@available(iOS 17.0, macOS 14.0, *)
public extension ModelContainer {
    /// CloudKit container identifier for iCloud sync
    static let cloudKitContainerIdentifier = "iCloud.com.smartslushi.app"

    /// Create a model container for Smart Slushi with iCloud sync enabled
    /// Data automatically syncs to iCloud when user is signed in, with offline support
    static func smartSlushiContainer() throws -> ModelContainer {
        let schema = Schema([
            SavedRecipe.self,
            UserPreferencesStore.self,
            SavedMachine.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    /// Create a local-only container (no CloudKit sync)
    /// Use this for users who prefer to keep data local
    static func smartSlushiLocalContainer() throws -> ModelContainer {
        let schema = Schema([
            SavedRecipe.self,
            UserPreferencesStore.self,
            SavedMachine.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }

    /// Create an in-memory container for previews and testing
    static func smartSlushiPreviewContainer() throws -> ModelContainer {
        let schema = Schema([
            SavedRecipe.self,
            UserPreferencesStore.self,
            SavedMachine.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
