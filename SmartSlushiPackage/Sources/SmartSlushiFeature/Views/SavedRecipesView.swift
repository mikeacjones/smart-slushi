import SwiftUI

// MARK: - Saved Recipes View

/// Screen displaying user's saved recipes
@available(iOS 17.0, *)
public struct SavedRecipesView: View {
    @Environment(RecipeStore.self) private var recipeStore
    @Environment(IngredientDatabase.self) private var database
    @Environment(SharedRecipeStore.self) private var sharedRecipeStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var recipeToDelete: SavedRecipe?
    @State private var recipeToPublish: SavedRecipe?
    @State private var showingPublishSheet = false

    /// Called when a recipe is selected to load
    let onSelectRecipe: (Recipe) -> Void

    public init(onSelectRecipe: @escaping (Recipe) -> Void) {
        self.onSelectRecipe = onSelectRecipe
    }

    public var body: some View {
        NavigationStack {
            Group {
                if recipeStore.savedRecipes.isEmpty {
                    emptyStateView
                } else {
                    recipeListView
                }
            }
            .navigationTitle("Saved Recipes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
            .alert("Delete Recipe?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let recipe = recipeToDelete {
                        deleteRecipe(recipe)
                    }
                }
                Button("Cancel", role: .cancel) {
                    recipeToDelete = nil
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .sheet(isPresented: $showingPublishSheet) {
                if let recipe = recipeToPublish {
                    PublishRecipeSheet(savedRecipe: recipe)
                        .environment(sharedRecipeStore)
                        .environment(database)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Saved Recipes")
                .font(.title2.weight(.semibold))

            Text("Recipes you save will appear here.\nTap 'Save' in the recipe builder to save a recipe.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recipe List

    private var recipeListView: some View {
        List {
            ForEach(filteredRecipes, id: \.id) { savedRecipe in
                SavedRecipeRow(
                    savedRecipe: savedRecipe,
                    onSelect: {
                        selectRecipe(savedRecipe)
                    },
                    onToggleFavorite: {
                        recipeStore.toggleFavorite(savedRecipe)
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        recipeToDelete = savedRecipe
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        recipeToPublish = savedRecipe
                        showingPublishSheet = true
                    } label: {
                        Label("Share", systemImage: "globe")
                    }
                    .tint(.blue)

                    Button {
                        recipeStore.toggleFavorite(savedRecipe)
                    } label: {
                        Label(
                            savedRecipe.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: savedRecipe.isFavorite ? "star.slash" : "star.fill"
                        )
                    }
                    .tint(.yellow)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Sort Menu

    @ViewBuilder
    private var sortMenu: some View {
        @Bindable var store = recipeStore
        Menu {
            Picker("Sort By", selection: $store.sortOrder) {
                ForEach(RecipeStore.SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort recipes")
    }

    // MARK: - Filtering

    private var filteredRecipes: [SavedRecipe] {
        if searchText.isEmpty {
            return recipeStore.savedRecipes
        }
        return recipeStore.search(searchText)
    }

    // MARK: - Actions

    private func selectRecipe(_ recipe: SavedRecipe) {
        recipe.restoreCustomIngredients(into: database)
        onSelectRecipe(recipe.toRecipe())
        dismiss()
    }

    private func deleteRecipe(_ recipe: SavedRecipe) {
        recipeStore.delete(recipe)
        recipeToDelete = nil
    }
}

// MARK: - Saved Recipe Row

@available(iOS 17.0, *)
struct SavedRecipeRow: View {
    @Environment(IngredientDatabase.self) private var database

    let savedRecipe: SavedRecipe
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    private let calculator = SlushCalculator()

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Favorite indicator
                if savedRecipe.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(savedRecipe.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        // Stats
                        let stats = calculateStats()
                        Label(String(format: "%.1f%%", stats.finalABV), systemImage: "drop.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label(String(format: "%.0f Brix", stats.finalBrix), systemImage: "cube.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("\(savedRecipe.ingredients.count)", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func calculateStats() -> RecipeStats {
        calculator.calculateStats(
            for: savedRecipe.ingredients,
            ingredientLookup: database.lookupFunction()
        )
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Modified " + formatter.localizedString(for: savedRecipe.modifiedAt, relativeTo: Date())
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    SavedRecipesView { _ in }
        .environment(RecipeStore())
        .environment(IngredientDatabase.shared)
}
