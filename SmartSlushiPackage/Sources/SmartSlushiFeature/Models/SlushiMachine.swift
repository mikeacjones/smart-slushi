import Foundation

// MARK: - Slushi Machine

/// Represents a slush machine with its freezing constraints and capacity
/// Machines define the ABV and Brix ranges that will produce optimal results
public struct SlushiMachine: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String

    /// Maximum ABV the machine can handle (higher ABV = lower freezing point)
    public var maxABV: Double

    /// Minimum Brix for proper texture (too low = icy)
    public var minBrix: Double

    /// Maximum Brix before it won't freeze properly (too high = runny)
    public var maxBrix: Double

    /// Machine capacity in ounces
    public var capacityOz: Double

    /// Working capacity (with headroom) in ounces
    public var workingCapacityOz: Double

    /// Whether this is a user-created custom machine
    public var isCustom: Bool

    /// Optional notes about the machine
    public var notes: String?

    public init(
        id: UUID = UUID(),
        name: String,
        maxABV: Double,
        minBrix: Double,
        maxBrix: Double,
        capacityOz: Double,
        workingCapacityOz: Double? = nil,
        isCustom: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.maxABV = maxABV
        self.minBrix = minBrix
        self.maxBrix = maxBrix
        self.capacityOz = capacityOz
        self.workingCapacityOz = workingCapacityOz ?? (capacityOz * 0.9)
        self.isCustom = isCustom
        self.notes = notes
    }

    /// Optimal Brix range for this machine (middle of the acceptable range)
    public var optimalBrixRange: ClosedRange<Double> {
        let midpoint = (minBrix + maxBrix) / 2
        let optimalLow = max(minBrix, midpoint - 1)
        let optimalHigh = min(maxBrix, midpoint + 1)
        return optimalLow...optimalHigh
    }

    /// Optimal ABV range (conservative to ensure freezing)
    public var optimalABVRange: ClosedRange<Double> {
        // Optimal is typically 50-80% of max ABV
        let optimalMax = maxABV * 0.8
        let optimalMin = min(5, optimalMax * 0.5)
        return optimalMin...optimalMax
    }

    /// Check if given ABV and Brix values are within machine constraints
    public func isWithinConstraints(abv: Double, brix: Double) -> Bool {
        abv <= maxABV && brix >= minBrix && brix <= maxBrix
    }

    /// Evaluate the ABV for this machine
    public func evaluateABV(_ abv: Double) -> MachineConstraintStatus {
        if abv > maxABV {
            return .exceeded(message: "ABV \(String(format: "%.1f", abv))% exceeds machine max of \(String(format: "%.0f", maxABV))%")
        }
        if abv > maxABV * 0.9 {
            return .nearLimit(message: "ABV approaching machine limit")
        }
        if abv > maxABV * 0.8 {
            return .acceptable
        }
        return .optimal
    }

    /// Evaluate the Brix for this machine
    public func evaluateBrix(_ brix: Double) -> MachineConstraintStatus {
        if brix < minBrix {
            return .exceeded(message: "Brix \(String(format: "%.1f", brix)) below machine min of \(String(format: "%.0f", minBrix))")
        }
        if brix > maxBrix {
            return .exceeded(message: "Brix \(String(format: "%.1f", brix)) exceeds machine max of \(String(format: "%.0f", maxBrix))")
        }
        if brix < minBrix + 1 || brix > maxBrix - 1 {
            return .nearLimit(message: "Brix near machine limits")
        }
        if optimalBrixRange.contains(brix) {
            return .optimal
        }
        return .acceptable
    }
}

// MARK: - Machine Constraint Status

/// Status of a value relative to machine constraints
public enum MachineConstraintStatus: Equatable, Sendable {
    case optimal
    case acceptable
    case nearLimit(message: String)
    case exceeded(message: String)

    public var isValid: Bool {
        switch self {
        case .optimal, .acceptable, .nearLimit:
            return true
        case .exceeded:
            return false
        }
    }
}

// MARK: - Built-in Machine Presets

extension SlushiMachine {
    /// Ninja SLUSHi 72oz (FS300)
    /// Walmart exclusive model with 3 presets. 72oz vessel, 48oz max fill.
    /// ABV range: 2.8%-16%, requires minimum 4% sugar (~10-11 Brix minimum)
    public static let ninjaSlushi72oz = SlushiMachine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Ninja SLUSHi 72oz",
        maxABV: 16,
        minBrix: 11,
        maxBrix: 17,
        capacityOz: 72,
        workingCapacityOz: 48,
        isCustom: false,
        notes: "FS300 model (Walmart exclusive). 72oz vessel with 48oz max fill. 3 presets: Slush, Spiked Slush, Milkshake. ABV range 2.8%-16%."
    )

    /// Ninja SLUSHi 88oz (FS301)
    /// Full-featured model with 5 presets. 88oz vessel, 64oz max fill.
    /// ABV range: 2.8%-16%, requires minimum 4% sugar (~10-11 Brix minimum)
    public static let ninjaSlushi88oz = SlushiMachine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Ninja SLUSHi 88oz",
        maxABV: 16,
        minBrix: 11,
        maxBrix: 17,
        capacityOz: 88,
        workingCapacityOz: 64,
        isCustom: false,
        notes: "FS301 model. 88oz vessel with 64oz max fill. 5 presets: Slush, Spiked Slush, Frappé, Milkshake, Frozen Juice. ABV range 2.8%-16%."
    )

    /// Ninja SLUSHi MAX (FS605) - XXL Smart Frozen Drink Maker
    /// 150oz party-sized capacity with higher ABV tolerance (up to 20%)
    public static let slushiMax = SlushiMachine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Ninja SLUSHi MAX",
        maxABV: 20,
        minBrix: 10,
        maxBrix: 18,
        capacityOz: 150,
        workingCapacityOz: 112,
        isCustom: false,
        notes: "FS605 model. XXL party-sized machine with 150oz vessel, 112oz max fill. Supports up to 20% ABV with Spiked Slush Max preset and SlushAssist™ technology."
    )

    /// Generic Home Machine - Conservative defaults for unknown machines
    public static let genericHome = SlushiMachine(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Generic Home Machine",
        maxABV: 10,
        minBrix: 13,
        maxBrix: 15,
        capacityOz: 48,
        workingCapacityOz: 44,
        isCustom: false,
        notes: "Safe defaults for most home frozen drink machines. Use conservative settings if unsure of your machine's capabilities."
    )

    /// All built-in machine presets
    public static let builtInMachines: [SlushiMachine] = [
        .ninjaSlushi72oz,
        .ninjaSlushi88oz,
        .slushiMax,
        .genericHome
    ]

    /// Default machine (Ninja SLUSHi 88oz - most common model)
    public static let `default` = ninjaSlushi88oz
}

// MARK: - Migration from NinjaSlushiModel

extension SlushiMachine {
    /// Create a SlushiMachine from the legacy NinjaSlushiModel enum
    public init(from legacyModel: NinjaSlushiModel) {
        switch legacyModel {
        case .standard72oz:
            self = .ninjaSlushi72oz
        case .large88oz:
            self = .ninjaSlushi88oz
        }
    }
}
