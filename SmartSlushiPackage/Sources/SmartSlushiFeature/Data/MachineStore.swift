import Foundation
import SwiftData
import Observation

// MARK: - Machine Store

/// Manages slushi machines including built-in presets and custom machines
@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class MachineStore {
    /// The SwiftData model context
    private var modelContext: ModelContext?

    /// All available machines (built-in + custom)
    public private(set) var machines: [SlushiMachine] = []

    /// Currently selected machine ID
    public var selectedMachineId: UUID {
        didSet {
            saveSelectedMachine()
        }
    }

    /// UserDefaults key for storing selected machine
    private static let selectedMachineKey = "selectedSlushiMachineId"

    public init() {
        // Load selected machine ID from UserDefaults, default to Ninja Slushi 72oz
        if let savedIdString = UserDefaults.standard.string(forKey: Self.selectedMachineKey),
           let savedId = UUID(uuidString: savedIdString) {
            self.selectedMachineId = savedId
        } else {
            self.selectedMachineId = SlushiMachine.default.id
        }

        // Initialize with built-in machines
        self.machines = SlushiMachine.builtInMachines
    }

    // MARK: - Setup

    /// Configure the store with a model context
    public func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCustomMachines()
    }

    // MARK: - Machine Access

    /// Get the currently selected machine
    public var selectedMachine: SlushiMachine {
        machines.first { $0.id == selectedMachineId } ?? .default
    }

    /// Get a machine by ID
    public func machine(for id: UUID) -> SlushiMachine? {
        machines.first { $0.id == id }
    }

    /// Get all built-in machines
    public var builtInMachines: [SlushiMachine] {
        machines.filter { !$0.isCustom }
    }

    /// Get all custom machines
    public var customMachines: [SlushiMachine] {
        machines.filter { $0.isCustom }
    }

    // MARK: - Machine Operations

    /// Load custom machines from the database
    private func loadCustomMachines() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<SavedMachine>(
            sortBy: [SortDescriptor(\.name)]
        )

        do {
            let savedMachines = try context.fetch(descriptor)
            let customMachines = savedMachines.map { $0.toMachine() }

            // Combine built-in and custom machines
            machines = SlushiMachine.builtInMachines + customMachines
        } catch {
            print("Error loading custom machines: \(error)")
            machines = SlushiMachine.builtInMachines
        }
    }

    /// Save the selected machine ID to UserDefaults
    private func saveSelectedMachine() {
        UserDefaults.standard.set(selectedMachineId.uuidString, forKey: Self.selectedMachineKey)
    }

    /// Add a new custom machine
    public func addCustomMachine(_ machine: SlushiMachine) {
        guard let context = modelContext else { return }

        let savedMachine = SavedMachine(from: machine)
        context.insert(savedMachine)

        do {
            try context.save()
            machines.append(machine)
        } catch {
            print("Error saving custom machine: \(error)")
        }
    }

    /// Update an existing custom machine
    public func updateMachine(_ machine: SlushiMachine) {
        guard let context = modelContext else { return }

        // Only allow updating custom machines
        guard machine.isCustom else { return }

        let descriptor = FetchDescriptor<SavedMachine>(
            predicate: #Predicate { $0.id == machine.id }
        )

        do {
            if let savedMachine = try context.fetch(descriptor).first {
                savedMachine.update(from: machine)
                try context.save()

                // Update in-memory list
                if let index = machines.firstIndex(where: { $0.id == machine.id }) {
                    machines[index] = machine
                }
            }
        } catch {
            print("Error updating custom machine: \(error)")
        }
    }

    /// Delete a custom machine
    public func deleteMachine(_ machine: SlushiMachine) {
        guard let context = modelContext else { return }

        // Only allow deleting custom machines
        guard machine.isCustom else { return }

        let descriptor = FetchDescriptor<SavedMachine>(
            predicate: #Predicate { $0.id == machine.id }
        )

        do {
            if let savedMachine = try context.fetch(descriptor).first {
                context.delete(savedMachine)
                try context.save()

                // Remove from in-memory list
                machines.removeAll { $0.id == machine.id }

                // If the deleted machine was selected, switch to default
                if selectedMachineId == machine.id {
                    selectedMachineId = SlushiMachine.default.id
                }
            }
        } catch {
            print("Error deleting custom machine: \(error)")
        }
    }

    /// Delete a custom machine by ID
    public func deleteMachine(id: UUID) {
        guard let machine = machine(for: id) else { return }
        deleteMachine(machine)
    }

    /// Create a new custom machine with default values
    public func createNewCustomMachine(name: String = "My Custom Machine") -> SlushiMachine {
        SlushiMachine(
            name: name,
            maxABV: 12,
            minBrix: 11,
            maxBrix: 17,
            capacityOz: 72,
            workingCapacityOz: 64,
            isCustom: true
        )
    }

    /// Select a machine by ID
    public func selectMachine(_ id: UUID) {
        guard machines.contains(where: { $0.id == id }) else { return }
        selectedMachineId = id
    }

    /// Select a machine
    public func selectMachine(_ machine: SlushiMachine) {
        selectMachine(machine.id)
    }
}

// MARK: - Shared Instance

@available(iOS 17.0, macOS 14.0, *)
extension MachineStore {
    /// Shared instance for app-wide use
    @MainActor
    public static let shared = MachineStore()
}
