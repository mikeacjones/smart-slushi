import Foundation

// MARK: - Ninja Slushi Model

/// Supported Ninja Slushi machine models
public enum NinjaSlushiModel: String, Codable, CaseIterable, Sendable {
    case standard72oz = "72oz"
    case large88oz = "88oz"

    public var displayName: String {
        switch self {
        case .standard72oz: return "Ninja Slushi 72oz"
        case .large88oz: return "Ninja Slushi 88oz"
        }
    }

    /// Total barrel capacity in ounces
    public var totalCapacity: Double {
        switch self {
        case .standard72oz: return 72
        case .large88oz: return 88
        }
    }

    /// Recommended working capacity (leave headroom)
    public var workingCapacity: Double {
        switch self {
        case .standard72oz: return 64
        case .large88oz: return 80
        }
    }

    /// Typical freeze time range in minutes
    public var freezeTimeRange: ClosedRange<Int> {
        15...60
    }
}

// MARK: - Drink Preferences

/// User preferences for drink taste that map to target ABV and Brix ranges
public struct DrinkPreferences: Codable, Sendable {
    /// Sweetness level: 0.0 (very tart) to 1.0 (very sweet), default 0.5
    public var sweetnessLevel: Double

    /// Slush thickness: 0.0 (sippable) to 1.0 (thick), default 0.5
    public var slushThickness: Double

    /// Alcohol strength: 0.0 (light) to 1.0 (strong), default 0.5
    public var alcoholStrength: Double

    public init(
        sweetnessLevel: Double = 0.5,
        slushThickness: Double = 0.5,
        alcoholStrength: Double = 0.5
    ) {
        self.sweetnessLevel = sweetnessLevel.clamped(to: 0...1)
        self.slushThickness = slushThickness.clamped(to: 0...1)
        self.alcoholStrength = alcoholStrength.clamped(to: 0...1)
    }

    /// Default balanced preferences
    public static let balanced = DrinkPreferences()

    /// Preset for a tart, light, sippable drink
    public static let tartAndLight = DrinkPreferences(
        sweetnessLevel: 0.2,
        slushThickness: 0.3,
        alcoholStrength: 0.3
    )

    /// Preset for a sweet, thick, strong drink
    public static let sweetAndStrong = DrinkPreferences(
        sweetnessLevel: 0.8,
        slushThickness: 0.7,
        alcoholStrength: 0.8
    )
}

// MARK: - Optimization Targets

/// Target ranges calculated from user preferences
public struct OptimizationTargets: Sendable {
    public let brixRange: ClosedRange<Double>
    public let abvRange: ClosedRange<Double>

    public init(brixRange: ClosedRange<Double>, abvRange: ClosedRange<Double>) {
        self.brixRange = brixRange
        self.abvRange = abvRange
    }

    /// Default slushability targets
    public static let `default` = OptimizationTargets(
        brixRange: 13...15,
        abvRange: 5...10
    )
}

extension DrinkPreferences {
    /// Convert preferences to optimization targets
    public func toOptimizationTargets() -> OptimizationTargets {
        // Sweetness: 0.0 = tart (Brix 12-13), 1.0 = sweet (Brix 15-16)
        let brixBase = 12.0 + (sweetnessLevel * 3.0)

        // Thickness: adjusts Brix slightly (+/- 0.5)
        let thicknessAdjust = (slushThickness - 0.5) * 1.0

        let brixLow = brixBase + thicknessAdjust
        let brixHigh = brixLow + 1.0

        // Alcohol: 0.0 = light (5-6%), 1.0 = strong (9-10%)
        let abvBase = 5.0 + (alcoholStrength * 4.0)
        let abvLow = abvBase
        let abvHigh = abvBase + 1.0

        return OptimizationTargets(
            brixRange: brixLow...brixHigh,
            abvRange: abvLow...abvHigh
        )
    }
}

// MARK: - User Preferences (App Settings)

/// Global app preferences stored in UserDefaults
public struct UserSettings: Codable, Sendable {
    /// Default batch size for new recipes, always stored in ounces
    public var defaultBatchSize: Double

    /// Preferred measurement unit
    public var preferredUnit: MeasurementUnit

    /// User's Ninja Slushi model
    public var machineModel: NinjaSlushiModel

    /// Default drink preferences
    public var drinkPreferences: DrinkPreferences

    /// Whether to show tooltips
    public var showTooltips: Bool

    /// Whether onboarding has been completed
    public var hasCompletedOnboarding: Bool

    /// Serving size in ounces for serving calculations (default 8oz)
    public var servingSizeOz: Double

    public init(
        defaultBatchSize: Double = 64,
        preferredUnit: MeasurementUnit = .oz,
        machineModel: NinjaSlushiModel = .standard72oz,
        drinkPreferences: DrinkPreferences = .balanced,
        showTooltips: Bool = true,
        hasCompletedOnboarding: Bool = false,
        servingSizeOz: Double = 8
    ) {
        self.defaultBatchSize = defaultBatchSize
        self.preferredUnit = preferredUnit
        self.machineModel = machineModel
        self.drinkPreferences = drinkPreferences
        self.showTooltips = showTooltips
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.servingSizeOz = servingSizeOz
    }

    /// Default settings
    public static let `default` = UserSettings()

    /// Common serving size presets in ounces
    public static let servingSizePresets: [(label: String, sizeOz: Double)] = [
        ("6 oz (Small)", 6),
        ("8 oz (Standard)", 8),
        ("10 oz (Medium)", 10),
        ("12 oz (Large)", 12),
        ("16 oz (Extra Large)", 16)
    ]
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
