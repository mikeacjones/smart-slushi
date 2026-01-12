import SwiftUI

// MARK: - Machine Settings View

/// View for managing slushi machines (viewing built-in and creating/editing custom)
@available(iOS 17.0, *)
public struct MachineSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MachineStore.self) private var machineStore

    @State private var showingAddMachine = false
    @State private var editingMachine: SlushiMachine?
    @State private var showingDeleteConfirmation = false
    @State private var machineToDelete: SlushiMachine?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Current selection
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        VStack(alignment: .leading) {
                            Text("Currently Selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(machineStore.selectedMachine.name)
                                .font(.headline)
                        }

                        Spacer()

                        Text("Max \(String(format: "%.0f", machineStore.selectedMachine.maxABV))% ABV")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Active Machine")
                }

                // Built-in machines
                Section {
                    ForEach(machineStore.builtInMachines, id: \.id) { machine in
                        MachineListRow(
                            machine: machine,
                            isSelected: machineStore.selectedMachineId == machine.id,
                            onSelect: {
                                machineStore.selectMachine(machine)
                            }
                        )
                    }
                } header: {
                    Text("Built-in Machines")
                } footer: {
                    Text("Built-in machines cannot be edited or deleted.")
                }

                // Custom machines
                Section {
                    if machineStore.customMachines.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.dashed")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)

                                Text("No custom machines")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(machineStore.customMachines, id: \.id) { machine in
                            MachineListRow(
                                machine: machine,
                                isSelected: machineStore.selectedMachineId == machine.id,
                                onSelect: {
                                    machineStore.selectMachine(machine)
                                }
                            )
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    machineToDelete = machine
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingMachine = machine
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }

                    Button {
                        showingAddMachine = true
                    } label: {
                        Label("Add Custom Machine", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Custom Machines")
                } footer: {
                    Text("Create custom machines with specific ABV and Brix limits for your equipment.")
                }
            }
            .navigationTitle("Machines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddMachine) {
                MachineEditorView(mode: .create)
                    .environment(machineStore)
            }
            .sheet(item: $editingMachine) { machine in
                MachineEditorView(mode: .edit(machine))
                    .environment(machineStore)
            }
            .alert("Delete Machine?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let machine = machineToDelete {
                        machineStore.deleteMachine(machine)
                    }
                }
            } message: {
                if let machine = machineToDelete {
                    Text("Are you sure you want to delete \"\(machine.name)\"? This cannot be undone.")
                }
            }
        }
    }
}

// MARK: - Machine List Row

@available(iOS 17.0, *)
struct MachineListRow: View {
    let machine: SlushiMachine
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(machine.name)
                            .font(.body)
                            .foregroundStyle(.primary)

                        if machine.isCustom {
                            Text("Custom")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 16) {
                        Text("Max \(String(format: "%.0f", machine.maxABV))% ABV")
                        Text("Brix \(String(format: "%.0f", machine.minBrix))-\(String(format: "%.0f", machine.maxBrix))")
                        Text("\(String(format: "%.0f", machine.capacityOz)) oz")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Machine Editor View

@available(iOS 17.0, *)
struct MachineEditorView: View {
    enum Mode: Identifiable {
        case create
        case edit(SlushiMachine)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let machine): return machine.id.uuidString
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(MachineStore.self) private var machineStore

    let mode: Mode

    @State private var name: String = ""
    @State private var maxABV: Double = 12
    @State private var minBrix: Double = 11
    @State private var maxBrix: Double = 17
    @State private var capacityOz: Double = 72
    @State private var workingCapacityOz: Double = 64
    @State private var notes: String = ""

    @State private var showingValidationError = false
    @State private var validationMessage = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingMachine: SlushiMachine? {
        if case .edit(let machine) = mode { return machine }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info
                Section {
                    TextField("Machine Name", text: $name)
                } header: {
                    Text("Name")
                }

                // ABV Constraints
                Section {
                    HStack {
                        Text("Maximum ABV")
                        Spacer()
                        TextField(
                            "ABV",
                            value: $maxABV,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Alcohol Limit")
                } footer: {
                    Text("The highest ABV percentage this machine can freeze. Most home machines max out at 10-12%.")
                }

                // Brix Constraints
                Section {
                    HStack {
                        Text("Minimum Brix")
                        Spacer()
                        TextField(
                            "Min",
                            value: $minBrix,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    }

                    HStack {
                        Text("Maximum Brix")
                        Spacer()
                        TextField(
                            "Max",
                            value: $maxBrix,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    }
                } header: {
                    Text("Sugar Content (Brix)")
                } footer: {
                    Text("The acceptable Brix range for this machine. Too low freezes icy, too high won't freeze.")
                }

                // Capacity
                Section {
                    HStack {
                        Text("Total Capacity")
                        Spacer()
                        TextField(
                            "oz",
                            value: $capacityOz,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }
                    .onChange(of: capacityOz) { _, newValue in
                        // Auto-adjust working capacity if it exceeds total
                        if workingCapacityOz > newValue {
                            workingCapacityOz = newValue * 0.9
                        }
                    }

                    HStack {
                        Text("Working Capacity")
                        Spacer()
                        TextField(
                            "oz",
                            value: $workingCapacityOz,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        Text("oz")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Capacity")
                } footer: {
                    Text("Working capacity is the recommended fill level, leaving headroom for expansion.")
                }

                // Notes
                Section {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }

                // Presets
                if !isEditing {
                    Section {
                        Button("Copy from Ninja SLUSHi 72oz") {
                            applyPreset(.ninjaSlushi72oz)
                        }

                        Button("Copy from Ninja SLUSHi 88oz") {
                            applyPreset(.ninjaSlushi88oz)
                        }

                        Button("Copy from Ninja SLUSHi MAX") {
                            applyPreset(.slushiMax)
                        }

                        Button("Copy from Generic Home Machine") {
                            applyPreset(.genericHome)
                        }
                    } header: {
                        Text("Start from Preset")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Machine" : "New Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveMachine()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
            .alert("Invalid Configuration", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .onAppear {
                if let machine = existingMachine {
                    name = machine.name
                    maxABV = machine.maxABV
                    minBrix = machine.minBrix
                    maxBrix = machine.maxBrix
                    capacityOz = machine.capacityOz
                    workingCapacityOz = machine.workingCapacityOz
                    notes = machine.notes ?? ""
                }
            }
        }
    }

    private func applyPreset(_ machine: SlushiMachine) {
        maxABV = machine.maxABV
        minBrix = machine.minBrix
        maxBrix = machine.maxBrix
        capacityOz = machine.capacityOz
        workingCapacityOz = machine.workingCapacityOz
        if name.isEmpty || name == "My Custom Machine" {
            name = "Custom \(machine.name)"
        }
    }

    private func saveMachine() {
        // Validate
        guard !name.isEmpty else {
            validationMessage = "Please enter a machine name."
            showingValidationError = true
            return
        }

        guard minBrix < maxBrix else {
            validationMessage = "Minimum Brix must be less than maximum Brix."
            showingValidationError = true
            return
        }

        guard workingCapacityOz <= capacityOz else {
            validationMessage = "Working capacity cannot exceed total capacity."
            showingValidationError = true
            return
        }

        let machine = SlushiMachine(
            id: existingMachine?.id ?? UUID(),
            name: name,
            maxABV: maxABV,
            minBrix: minBrix,
            maxBrix: maxBrix,
            capacityOz: capacityOz,
            workingCapacityOz: workingCapacityOz,
            isCustom: true,
            notes: notes.isEmpty ? nil : notes
        )

        if isEditing {
            machineStore.updateMachine(machine)
        } else {
            machineStore.addCustomMachine(machine)
        }

        dismiss()
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Machine Settings") {
    MachineSettingsView()
        .environment(MachineStore.shared)
}

@available(iOS 17.0, *)
#Preview("Machine Editor - Create") {
    MachineEditorView(mode: .create)
        .environment(MachineStore.shared)
}

@available(iOS 17.0, *)
#Preview("Machine Editor - Edit") {
    MachineEditorView(mode: .edit(.slushiMax))
        .environment(MachineStore.shared)
}
