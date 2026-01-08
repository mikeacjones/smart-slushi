import SwiftUI

// MARK: - Home View

/// Dashboard home view with navigation to all app areas
@available(iOS 17.0, *)
public struct HomeView: View {
    @Environment(RecipeStore.self) private var recipeStore
    @Environment(SharedRecipeStore.self) private var sharedRecipeStore
    @Environment(IngredientDatabase.self) private var database
    @Environment(UserSettingsManager.self) private var settingsManager

    // Navigation state
    @State private var showingRecipeBuilder = false
    @State private var showingSavedRecipes = false
    @State private var showingTemplates = false
    @State private var showingCommunityRecipes = false
    @State private var showingSettings = false

    // For loading recipes into builder
    @State private var recipeToEdit: Recipe?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    welcomeHeader
                    quickActionsGrid
                    recentRecipesSection
                }
                .padding()
            }
            .navigationTitle("Smart Slushi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingRecipeBuilder) {
                NavigationStack {
                    RecipeBuilderView(recipe: recipeToEdit)
                        .environment(database)
                        .environment(recipeStore)
                        .environment(settingsManager)
                        .environment(sharedRecipeStore)
                }
            }
            .sheet(isPresented: $showingSavedRecipes) {
                SavedRecipesView { savedRecipe in
                    recipeToEdit = savedRecipe.toRecipe()
                    showingSavedRecipes = false
                    showingRecipeBuilder = true
                }
                .environment(database)
                .environment(recipeStore)
                .environment(sharedRecipeStore)
            }
            .sheet(isPresented: $showingTemplates) {
                RecipeTemplatesView { template in
                    recipeToEdit = template.createRecipe(targetBatchSize: 24)
                    showingTemplates = false
                    showingRecipeBuilder = true
                }
            }
            .sheet(isPresented: $showingCommunityRecipes) {
                SharedRecipesView { importedRecipe in
                    recipeToEdit = importedRecipe
                    showingCommunityRecipes = false
                    showingRecipeBuilder = true
                }
                .environment(sharedRecipeStore)
                .environment(database)
                .environment(recipeStore)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environment(settingsManager)
            }
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)

            Text("What would you like to create?")
                .font(.title.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Quick Actions Grid

    private var quickActionsGrid: some View {
        VStack(spacing: 16) {
            // Primary action - New Recipe
            DashboardCard(
                title: "New Recipe",
                subtitle: "Start from scratch",
                icon: "plus.circle.fill",
                color: .blue,
                style: .large
            ) {
                recipeToEdit = nil
                showingRecipeBuilder = true
            }

            // Secondary actions grid
            HStack(spacing: 16) {
                DashboardCard(
                    title: "My Recipes",
                    subtitle: savedRecipesSubtitle,
                    icon: "folder.fill",
                    color: .green,
                    badge: recipeStore.savedRecipes.isEmpty ? nil : "\(recipeStore.savedRecipes.count)"
                ) {
                    showingSavedRecipes = true
                }

                DashboardCard(
                    title: "Templates",
                    subtitle: "Pre-built recipes",
                    icon: "doc.text.fill",
                    color: .orange
                ) {
                    showingTemplates = true
                }
            }

            // Community action
            DashboardCard(
                title: "Community",
                subtitle: "Discover shared recipes",
                icon: "globe",
                color: .purple
            ) {
                showingCommunityRecipes = true
            }
        }
    }

    private var savedRecipesSubtitle: String {
        let count = recipeStore.savedRecipes.count
        if count == 0 {
            return "No saved recipes"
        } else if count == 1 {
            return "1 saved recipe"
        } else {
            return "\(count) saved recipes"
        }
    }

    // MARK: - Recent Recipes Section

    @ViewBuilder
    private var recentRecipesSection: some View {
        let recentRecipes = Array(recipeStore.savedRecipes.prefix(3))

        if !recentRecipes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Recipes")
                        .font(.headline)

                    Spacer()

                    Button("See All") {
                        showingSavedRecipes = true
                    }
                    .font(.subheadline)
                }

                VStack(spacing: 8) {
                    ForEach(recentRecipes) { savedRecipe in
                        RecentRecipeRow(recipe: savedRecipe) {
                            recipeToEdit = savedRecipe.toRecipe()
                            showingRecipeBuilder = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Dashboard Card

@available(iOS 17.0, *)
struct DashboardCard: View {
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    var badge: String? = nil
    var style: CardStyle = .standard

    let action: () -> Void

    enum CardStyle {
        case standard
        case large
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: style == .large ? 16 : 12) {
                HStack {
                    Image(systemName: icon)
                        .font(style == .large ? .title : .title2)
                        .foregroundStyle(color)

                    Spacer()

                    if let badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.15))
                            .foregroundStyle(color)
                            .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(style == .large ? .title2.weight(.semibold) : .headline)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(style == .large ? 20 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Recipe Row

@available(iOS 17.0, *)
struct RecentRecipeRow: View {
    let recipe: SavedRecipe
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: recipe.isFavorite ? "star.fill" : "drop.fill")
                            .foregroundStyle(recipe.isFavorite ? .yellow : .blue)
                    }

                // Details
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(recipe.ingredients.count) ingredients")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formattedDate)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: recipe.modifiedAt, relativeTo: Date())
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    HomeView()
        .environment(RecipeStore())
        .environment(SharedRecipeStore())
        .environment(IngredientDatabase.shared)
        .environment(UserSettingsManager.shared)
}
