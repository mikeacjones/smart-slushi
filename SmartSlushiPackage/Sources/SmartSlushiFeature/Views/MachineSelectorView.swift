import SwiftUI

// MARK: - Machine Selector View

/// A compact view for selecting a target slushi machine
@available(iOS 17.0, *)
struct MachineSelectorView: View {
    @Binding var selectedMachineId: UUID
    @Environment(MachineStore.self) private var machineStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Built-in machines
            VStack(alignment: .leading, spacing: 8) {
                Text("Built-in Machines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                ForEach(machineStore.builtInMachines, id: \.id) { machine in
                    MachineOptionRow(
                        machine: machine,
                        isSelected: selectedMachineId == machine.id,
                        onSelect: {
                            withAnimation {
                                selectedMachineId = machine.id
                            }
                        }
                    )
                }
            }

            // Custom machines (if any)
            if !machineStore.customMachines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Machines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    ForEach(machineStore.customMachines, id: \.id) { machine in
                        MachineOptionRow(
                            machine: machine,
                            isSelected: selectedMachineId == machine.id,
                            onSelect: {
                                withAnimation {
                                    selectedMachineId = machine.id
                                }
                            }
                        )
                    }
                }
            }

            // Info text
            Text("Select the machine you'll be using. Each machine has different ABV and Brix limits that affect what recipes will freeze properly.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Machine Option Row

@available(iOS 17.0, *)
struct MachineOptionRow: View {
    let machine: SlushiMachine
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(machine.name)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        Label("Max \(String(format: "%.0f", machine.maxABV))%", systemImage: "flame")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("Brix \(String(format: "%.0f", machine.minBrix))-\(String(format: "%.0f", machine.maxBrix))", systemImage: "drop.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Label("\(String(format: "%.0f", machine.capacityOz)) oz", systemImage: "cylinder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .labelStyle(.titleOnly)
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Machine Detail View

/// Shows detailed information about a machine
@available(iOS 17.0, *)
struct MachineDetailView: View {
    let machine: SlushiMachine

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text(machine.name)
                        .font(.title2.bold())

                    if machine.isCustom {
                        Text("Custom Machine")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            Divider()

            // Constraints
            VStack(alignment: .leading, spacing: 12) {
                Text("Freezing Constraints")
                    .font(.headline)

                ConstraintRow(
                    icon: "flame.fill",
                    title: "Maximum ABV",
                    value: "\(String(format: "%.0f", machine.maxABV))%",
                    description: "Higher ABV drinks won't freeze properly"
                )

                ConstraintRow(
                    icon: "drop.fill",
                    title: "Brix Range",
                    value: "\(String(format: "%.0f", machine.minBrix)) - \(String(format: "%.0f", machine.maxBrix))",
                    description: "Sugar content needed for proper texture"
                )

                ConstraintRow(
                    icon: "target",
                    title: "Optimal Brix",
                    value: "\(String(format: "%.0f", machine.optimalBrixRange.lowerBound)) - \(String(format: "%.0f", machine.optimalBrixRange.upperBound))",
                    description: "Best range for perfect slush"
                )
            }

            Divider()

            // Capacity
            VStack(alignment: .leading, spacing: 12) {
                Text("Capacity")
                    .font(.headline)

                ConstraintRow(
                    icon: "cylinder",
                    title: "Total Capacity",
                    value: "\(String(format: "%.0f", machine.capacityOz)) oz",
                    description: "Maximum volume"
                )

                ConstraintRow(
                    icon: "cylinder.split.1x2",
                    title: "Working Capacity",
                    value: "\(String(format: "%.0f", machine.workingCapacityOz)) oz",
                    description: "Recommended fill level"
                )
            }

            if let notes = machine.notes, !notes.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)

                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - Constraint Row

@available(iOS 17.0, *)
struct ConstraintRow: View {
    let icon: String
    let title: String
    let value: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                    Spacer()
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Machine Selector") {
    MachineSelectorView(selectedMachineId: .constant(SlushiMachine.default.id))
        .environment(MachineStore.shared)
        .padding()
}

@available(iOS 17.0, *)
#Preview("Machine Detail") {
    MachineDetailView(machine: .slushiMax)
}
