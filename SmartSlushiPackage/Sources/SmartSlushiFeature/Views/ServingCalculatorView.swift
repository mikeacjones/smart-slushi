import SwiftUI

// MARK: - Serving Calculator View

/// View for calculating batch size based on number of servings
/// Allows users to specify people count, servings per person, and serving size
@available(iOS 17.0, *)
struct ServingCalculatorView: View {
    @Environment(IngredientDatabase.self) private var database
    @Environment(UserSettingsManager.self) private var settingsManager
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let onApply: (Recipe) -> Void

    @State private var numberOfPeople: Int = 4
    @State private var servingsPerPerson: Int = 2
    @State private var customServingSize: Double = 8
    @State private var useCustomServingSize: Bool = false

    private let calculator = SlushCalculator()

    /// Preset options for number of people
    private static let peoplePresets = [2, 4, 6, 8, 10, 12]

    /// Preset options for servings per person
    private static let servingsPresets = [1, 2, 3, 4]

    init(
        recipe: Recipe,
        onApply: @escaping (Recipe) -> Void
    ) {
        self.recipe = recipe
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summaryCard
                    servingSizeSection
                    peopleSection
                    servingsPerPersonSection
                    calculationResultCard
                    machineCapacityWarning
                }
                .padding()
            }
            .navigationTitle("Scale by Servings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyScaling()
                    }
                    .fontWeight(.semibold)
                    .disabled(totalServings == 0)
                }
            }
            .onAppear {
                customServingSize = settingsManager.settings.servingSizeOz
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Computed Properties

    private var effectiveServingSize: Double {
        useCustomServingSize ? customServingSize : settingsManager.settings.servingSizeOz
    }

    private var totalServings: Int {
        numberOfPeople * servingsPerPerson
    }

    private var totalVolumeOz: Double {
        calculator.calculateTotalVolumeForServings(
            numberOfPeople: numberOfPeople,
            servingsPerPerson: servingsPerPerson,
            servingSizeOz: effectiveServingSize
        )
    }

    private var currentRecipeVolumeOz: Double {
        recipe.ingredients.reduce(0.0) { $0 + $1.volumeInOz }
    }

    private var scaleFactor: Double {
        guard currentRecipeVolumeOz > 0 else { return 1.0 }
        return totalVolumeOz / currentRecipeVolumeOz
    }

    private var machineCapacity: Double {
        settingsManager.settings.machineModel.workingCapacity
    }

    private var exceedsMachineCapacity: Bool {
        totalVolumeOz > machineCapacity
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 8) {
            Text("Quick Calculate")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("\(numberOfPeople)")
                    .font(.title.bold())
                    .foregroundStyle(.blue)

                Text("people")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("×")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                Text("\(servingsPerPerson)")
                    .font(.title.bold())
                    .foregroundStyle(.blue)

                Text(servingsPerPerson == 1 ? "serving" : "servings")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("=")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                Text("\(totalServings)")
                    .font(.title.bold())
                    .foregroundStyle(.green)

                Text("total")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Serving Size Section

    private var servingSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Serving Size")
                    .font(.headline)

                Spacer()

                Text("\(Int(effectiveServingSize)) oz per serving")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Preset buttons
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(UserSettings.servingSizePresets, id: \.sizeOz) { preset in
                    Button {
                        withAnimation {
                            customServingSize = preset.sizeOz
                            useCustomServingSize = true
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(Int(preset.sizeOz)) oz")
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(effectiveServingSize == preset.sizeOz ? .blue : .primary)
                }
            }

            // Custom size stepper
            HStack {
                Text("Custom:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Stepper(
                    value: Binding(
                        get: { customServingSize },
                        set: {
                            customServingSize = $0
                            useCustomServingSize = true
                        }
                    ),
                    in: 4...24,
                    step: 1
                ) {
                    Text("\(Int(customServingSize)) oz")
                        .font(.subheadline.weight(.medium))
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - People Section

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Number of People")
                    .font(.headline)

                Spacer()

                Text("\(numberOfPeople)")
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 8) {
                ForEach(Self.peoplePresets, id: \.self) { count in
                    Button {
                        withAnimation {
                            numberOfPeople = count
                        }
                    } label: {
                        Text("\(count)")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(numberOfPeople == count ? .blue : .primary)
                }
            }

            Stepper("Custom: \(numberOfPeople)", value: $numberOfPeople, in: 1...50)
                .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Servings Per Person Section

    private var servingsPerPersonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Servings Per Person")
                    .font(.headline)

                Spacer()

                Text("\(servingsPerPerson)")
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 8) {
                ForEach(Self.servingsPresets, id: \.self) { count in
                    Button {
                        withAnimation {
                            servingsPerPerson = count
                        }
                    } label: {
                        Text("\(count)")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(servingsPerPerson == count ? .blue : .primary)
                }
            }

            Stepper("Custom: \(servingsPerPerson)", value: $servingsPerPerson, in: 1...10)
                .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Calculation Result Card

    private var calculationResultCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Total Volume Needed")
                    .font(.headline)

                Spacer()
            }

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", totalVolumeOz))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(exceedsMachineCapacity ? .orange : .green)

                    Text("ounces")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 50)

                VStack(spacing: 4) {
                    Text(String(format: "%.1f", MeasurementUnit.oz.convert(totalVolumeOz, to: .cup)))
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)

                    Text("cups")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 50)

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", MeasurementUnit.oz.convert(totalVolumeOz, to: .ml)))
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)

                    Text("ml")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if currentRecipeVolumeOz > 0 {
                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scale Factor")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.2fx", scaleFactor))
                            .font(.headline)
                            .foregroundStyle(scaleFactor > 1 ? .green : .orange)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Current Recipe")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(Int(currentRecipeVolumeOz)) oz")
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Machine Capacity Warning

    @ViewBuilder
    private var machineCapacityWarning: some View {
        if exceedsMachineCapacity {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Exceeds Machine Capacity")
                        .font(.subheadline.weight(.medium))

                    Text("Your \(settingsManager.settings.machineModel.displayName) has a working capacity of \(Int(machineCapacity)) oz. You may need to make multiple batches.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let batchesNeeded = Int(ceil(totalVolumeOz / machineCapacity))
                    Text("Estimated batches needed: \(batchesNeeded)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }

                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func applyScaling() {
        guard currentRecipeVolumeOz > 0 else {
            dismiss()
            return
        }

        let scaledRecipe = calculator.scaleRecipe(
            recipe,
            toBatchSize: totalVolumeOz,
            ingredientLookup: database.lookupFunction()
        )

        onApply(scaledRecipe)
        dismiss()
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    let sampleRecipe = Recipe(
        name: "Margarita",
        ingredients: [
            RecipeIngredient(
                ingredientId: UUID(),
                amount: 2.0,
                unit: .oz,
                isLocked: false
            ),
            RecipeIngredient(
                ingredientId: UUID(),
                amount: 1.0,
                unit: .oz,
                isLocked: false
            ),
            RecipeIngredient(
                ingredientId: UUID(),
                amount: 0.75,
                unit: .oz,
                isLocked: false
            )
        ],
        targetBatchSize: 48
    )

    return ServingCalculatorView(
        recipe: sampleRecipe,
        onApply: { _ in }
    )
    .environment(IngredientDatabase.shared)
    .environment(UserSettingsManager.shared)
}
