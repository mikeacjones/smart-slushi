import SwiftUI
import SwiftData
import SmartSlushiFeature

@main
struct SmartSlushiApp: App {
    /// Model container with iCloud sync enabled
    /// Recipes and preferences automatically sync across devices
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer.smartSlushiContainer()
        } catch {
            // Fall back to local-only storage if CloudKit fails
            // This can happen if user isn't signed into iCloud
            do {
                modelContainer = try ModelContainer.smartSlushiLocalContainer()
            } catch {
                fatalError("Failed to create model container: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
