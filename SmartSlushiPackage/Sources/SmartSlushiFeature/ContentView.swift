import SwiftUI
import SwiftData

@available(iOS 17.0, *)
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var database = IngredientDatabase.shared
    @State private var templateStore = RecipeTemplateStore.shared
    @State private var recipeStore = RecipeStore()
    @State private var settingsManager = UserSettingsManager.shared
    @State private var sharedRecipeStore = SharedRecipeStore()
    @State private var showingOnboarding = false

    public var body: some View {
        RecipeBuilderView()
            .environment(database)
            .environment(templateStore)
            .environment(recipeStore)
            .environment(settingsManager)
            .environment(sharedRecipeStore)
            .onAppear {
                recipeStore.configure(with: modelContext)
                if let recentIngredientIds = recipeStore.userPreferences?.recentIngredientIds {
                    database.setRecentIngredientIds(recentIngredientIds)
                }
                // Hydrate device settings from CloudKit-backed preferences when available.
                // Fresh factory-default rows must be seeded FROM UserDefaults, not the reverse,
                // or local settings get wiped on first launch / empty CloudKit.
                if recipeStore.preferencesWereJustCreated {
                    recipeStore.syncFromUserSettings(settingsManager.settings)
                } else if recipeStore.userPreferences != nil {
                    var merged = settingsManager.settings
                    recipeStore.mergeCloudPreferences(into: &merged)
                    settingsManager.replaceSettings(merged)
                } else {
                    recipeStore.syncFromUserSettings(settingsManager.settings)
                }
                // Show onboarding if not completed
                if !settingsManager.settings.hasCompletedOnboarding {
                    showingOnboarding = true
                }
            }
            .onChange(of: settingsManager.settings.hasCompletedOnboarding) { _, hasCompleted in
                // Re-show onboarding immediately when reset from Settings
                if !hasCompleted {
                    showingOnboarding = true
                }
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingView {
                    showingOnboarding = false
                }
                .environment(settingsManager)
            }
    }

    public init() {}
}
