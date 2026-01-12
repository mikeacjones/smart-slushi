import Foundation
import SwiftData

// MARK: - Saved Machine (SwiftData Model)

/// A persisted custom slushi machine using SwiftData
@available(iOS 17.0, macOS 14.0, *)
@Model
public final class SavedMachine {
    /// Unique identifier
    public var id: UUID

    /// Machine name
    public var name: String

    /// Maximum ABV the machine can handle
    public var maxABV: Double

    /// Minimum Brix for proper texture
    public var minBrix: Double

    /// Maximum Brix before it won't freeze
    public var maxBrix: Double

    /// Machine capacity in ounces
    public var capacityOz: Double

    /// Working capacity in ounces
    public var workingCapacityOz: Double

    /// Optional notes about the machine
    public var notes: String?

    /// When the machine was created
    public var createdAt: Date

    /// When the machine was last modified
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        maxABV: Double = 12,
        minBrix: Double = 11,
        maxBrix: Double = 17,
        capacityOz: Double = 72,
        workingCapacityOz: Double = 64,
        notes: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.maxABV = maxABV
        self.minBrix = minBrix
        self.maxBrix = maxBrix
        self.capacityOz = capacityOz
        self.workingCapacityOz = workingCapacityOz
        self.notes = notes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Conversion Between SlushiMachine and SavedMachine

@available(iOS 17.0, macOS 14.0, *)
extension SavedMachine {
    /// Create a SavedMachine from a SlushiMachine
    public convenience init(from machine: SlushiMachine) {
        self.init(
            id: machine.id,
            name: machine.name,
            maxABV: machine.maxABV,
            minBrix: machine.minBrix,
            maxBrix: machine.maxBrix,
            capacityOz: machine.capacityOz,
            workingCapacityOz: machine.workingCapacityOz,
            notes: machine.notes
        )
    }

    /// Convert to a SlushiMachine struct
    public func toMachine() -> SlushiMachine {
        SlushiMachine(
            id: id,
            name: name,
            maxABV: maxABV,
            minBrix: minBrix,
            maxBrix: maxBrix,
            capacityOz: capacityOz,
            workingCapacityOz: workingCapacityOz,
            isCustom: true,
            notes: notes
        )
    }

    /// Update from a SlushiMachine struct
    public func update(from machine: SlushiMachine) {
        name = machine.name
        maxABV = machine.maxABV
        minBrix = machine.minBrix
        maxBrix = machine.maxBrix
        capacityOz = machine.capacityOz
        workingCapacityOz = machine.workingCapacityOz
        notes = machine.notes
        modifiedAt = Date()
    }
}
