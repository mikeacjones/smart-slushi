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
        HomeView()
            .environment(database)
            .environment(templateStore)
            .environment(recipeStore)
            .environment(settingsManager)
            .environment(sharedRecipeStore)
            .onAppear {
                recipeStore.configure(with: modelContext)
                // Show onboarding if not completed
                if !settingsManager.settings.hasCompletedOnboarding {
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
