import SwiftUI

// MARK: - Shared Recipes View

/// Browse and discover community shared recipes
@available(iOS 17.0, *)
public struct SharedRecipesView: View {
    @Environment(SharedRecipeStore.self) private var sharedStore
    @Environment(IngredientDatabase.self) private var database
    @Environment(RecipeStore.self) private var recipeStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRecipe: SharedRecipe?
    @State private var showingMyRecipes = false

    /// Callback when a recipe is imported
    let onImportRecipe: (Recipe) -> Void

    public init(onImportRecipe: @escaping (Recipe) -> Void) {
        self.onImportRecipe = onImportRecipe
    }

    public var body: some View {
        NavigationStack {
            Group {
                if sharedStore.isLoading && sharedStore.recipes.isEmpty {
                    loadingView
                } else if let error = sharedStore.error {
                    errorView(error: error)
                } else if sharedStore.recipes.isEmpty {
                    emptyStateView
                } else {
                    recipeListView
                }
            }
            .navigationTitle("Community Recipes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: Bindable(sharedStore).searchText,
                prompt: "Search recipes"
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingMyRecipes = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                        .accessibilityLabel("My Published Recipes")

                        sortMenu
                    }
                }
            }
            .task {
                if sharedStore.recipes.isEmpty {
                    await sharedStore.loadRecipes()
                }
            }
            .refreshable {
                await sharedStore.refresh()
            }
            .sheet(item: $selectedRecipe) { recipe in
                SharedRecipeDetailView(recipe: recipe, onImport: { importedRecipe in
                    onImportRecipe(importedRecipe)
                    selectedRecipe = nil
                    dismiss()
                })
                .environment(sharedStore)
                .environment(database)
            }
            .sheet(isPresented: $showingMyRecipes) {
                MyPublishedRecipesView()
                    .environment(sharedStore)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading community recipes...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(error: SharedRecipeStoreError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: errorIcon(for: error))
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(errorTitle(for: error))
                .font(.title2.weight(.semibold))

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await sharedStore.refresh()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorIcon(for error: SharedRecipeStoreError) -> String {
        switch error {
        case .notAuthenticated:
            return "icloud.slash"
        case .networkError:
            return "wifi.slash"
        default:
            return "exclamationmark.triangle"
        }
    }

    private func errorTitle(for error: SharedRecipeStoreError) -> String {
        switch error {
        case .notAuthenticated:
            return "Sign In Required"
        case .networkError:
            return "Connection Error"
        default:
            return "Something Went Wrong"
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe.americas")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Recipes Yet")
                .font(.title2.weight(.semibold))

            Text("Be the first to share a recipe with the community!")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await sharedStore.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recipe List View

    private var recipeListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(sharedStore.recipes) { recipe in
                    SharedRecipeRow(
                        recipe: recipe,
                        voteState: sharedStore.voteState(for: recipe),
                        onSelect: {
                            selectedRecipe = recipe
                        },
                        onUpvote: {
                            Task {
                                await sharedStore.toggleUpvote(recipe)
                            }
                        },
                        onDownvote: {
                            Task {
                                await sharedStore.toggleDownvote(recipe)
                            }
                        }
                    )
                    .padding(.horizontal)
                }

                if sharedStore.hasMoreResults {
                    loadMoreButton
                }
            }
            .padding(.vertical)
        }
    }

    private var loadMoreButton: some View {
        Group {
            if sharedStore.isLoadingMore {
                ProgressView()
                    .padding()
            } else {
                Button {
                    Task {
                        await sharedStore.loadMoreRecipes()
                    }
                } label: {
                    Text("Load More")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Sort Menu

    @ViewBuilder
    private var sortMenu: some View {
        @Bindable var store = sharedStore
        Menu {
            Picker("Sort By", selection: $store.sortOrder) {
                ForEach(SharedRecipeQuery.SortOrder.allCases, id: \.self) { order in
                    Label(order.rawValue, systemImage: order.icon)
                        .tag(order)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort recipes")
    }
}

// MARK: - Shared Recipe Row

@available(iOS 17.0, *)
public struct SharedRecipeRow: View {
    let recipe: SharedRecipe
    let voteState: VoteState
    let onSelect: () -> Void
    let onUpvote: () -> Void
    let onDownvote: () -> Void

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Stats
                        HStack(spacing: 12) {
                            Label(String(format: "%.1f%%", recipe.finalABV), systemImage: "drop.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Label(String(format: "%.0f Brix", recipe.finalBrix), systemImage: "cube.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Label("\(recipe.ingredients.count)", systemImage: "list.bullet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)
                }

                // Author notes preview
                if let notes = recipe.authorNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Footer
                HStack {
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(recipe.name)
            .accessibilityHint("Opens recipe details")

            // Voting buttons outside the select gesture to avoid nested buttons
            HStack(spacing: 4) {
                voteButton(isUpvote: true)

                Text("\(recipe.score)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(scoreColor)
                    .frame(minWidth: 24)
                    .accessibilityLabel("Score \(recipe.score)")

                voteButton(isUpvote: false)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func voteButton(isUpvote: Bool) -> some View {
        let isActive = isUpvote ? voteState.isUpvoted : voteState.isDownvoted

        Button(action: isUpvote ? onUpvote : onDownvote) {
            Image(systemName: isUpvote ? "arrow.up" : "arrow.down")
                .font(.subheadline.weight(isActive ? .bold : .regular))
                .foregroundStyle(isActive ? (isUpvote ? .green : .red) : .secondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(isActive ? (isUpvote ? Color.green.opacity(0.15) : Color.red.opacity(0.15)) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isUpvote ? "Upvote" : "Downvote")
    }

    private var scoreColor: Color {
        if recipe.score > 0 {
            return .green
        } else if recipe.score < 0 {
            return .red
        } else {
            return .secondary
        }
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: recipe.publishedAt, relativeTo: Date())
    }
}

// MARK: - My Published Recipes View

@available(iOS 17.0, *)
public struct MyPublishedRecipesView: View {
    @Environment(SharedRecipeStore.self) private var sharedStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var recipeToDelete: SharedRecipe?

    public var body: some View {
        NavigationStack {
            Group {
                if sharedStore.isLoadingMyRecipes && sharedStore.myPublishedRecipes.isEmpty {
                    ProgressView()
                } else if sharedStore.myPublishedRecipes.isEmpty {
                    emptyStateView
                } else {
                    recipeListView
                }
            }
            .navigationTitle("My Published Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await sharedStore.loadMyPublishedRecipes()
            }
            .alert("Delete Recipe?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let recipe = recipeToDelete {
                        Task {
                            try? await sharedStore.deletePublishedRecipe(recipe)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    recipeToDelete = nil
                }
            } message: {
                Text("This will remove the recipe from the community. This action cannot be undone.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Published Recipes")
                .font(.headline)

            Text("Recipes you share with the community will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var recipeListView: some View {
        List {
            ForEach(sharedStore.myPublishedRecipes) { recipe in
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.headline)

                    HStack(spacing: 16) {
                        Label("\(recipe.upvoteCount)", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundStyle(.green)

                        Label("\(recipe.downvoteCount)", systemImage: "arrow.down")
                            .font(.caption)
                            .foregroundStyle(.red)

                        Spacer()

                        Text(formattedDate(recipe.publishedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        recipeToDelete = recipe
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    SharedRecipesView { _ in }
        .environment(SharedRecipeStore())
        .environment(IngredientDatabase.shared)
        .environment(RecipeStore())
}
