import Foundation
import Observation

/// Manages user settings persistence using UserDefaults
@Observable
@MainActor
public final class UserSettingsManager: Sendable {
    private static let userDefaultsKey = "com.smartslushi.userSettings"

    public static let shared = UserSettingsManager()

    public private(set) var settings: UserSettings {
        didSet {
            save()
        }
    }

    private init() {
        self.settings = Self.loadFromUserDefaults() ?? .default
    }

    // MARK: - Public Methods

    /// Update the default batch size
    public func setDefaultBatchSize(_ size: Double) {
        settings.defaultBatchSize = max(1, size)
    }

    /// Update the preferred measurement unit
    public func setPreferredUnit(_ unit: MeasurementUnit) {
        settings.preferredUnit = unit
    }

    /// Update the machine model
    public func setMachineModel(_ model: NinjaSlushiModel) {
        settings.machineModel = model
    }

    /// Update the default drink preferences
    public func setDrinkPreferences(_ preferences: DrinkPreferences) {
        settings.drinkPreferences = preferences
    }

    /// Update tooltip visibility
    public func setShowTooltips(_ show: Bool) {
        settings.showTooltips = show
    }

    /// Update the serving size (in ounces)
    public func setServingSize(_ sizeOz: Double) {
        settings.servingSizeOz = max(1, sizeOz) // Ensure minimum 1oz
    }

    /// Mark onboarding as completed
    public func completeOnboarding() {
        settings.hasCompletedOnboarding = true
    }

    /// Reset onboarding (for testing)
    public func resetOnboarding() {
        settings.hasCompletedOnboarding = false
    }

    /// Reset all settings to defaults
    public func resetToDefaults() {
        settings = .default
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        } catch {
            print("Failed to save user settings: \(error)")
        }
    }

    private static func loadFromUserDefaults() -> UserSettings? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(UserSettings.self, from: data)
        } catch {
            print("Failed to load user settings: \(error)")
            return nil
        }
    }
}
