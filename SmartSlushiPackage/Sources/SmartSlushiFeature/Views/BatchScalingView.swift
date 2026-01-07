import SwiftUI

// MARK: - Scaling Mode

/// Mode for batch scaling - by specific size or by number of servings
enum BatchScalingMode: String, CaseIterable {
    case bySize = "By Size"
    case byServings = "By Servings"
}

// MARK: - Scaling Result

/// Result of a batch scaling operation showing before/after amounts
struct ScalingResult: Identifiable {
    let id = UUID()
    let originalBatchSize: Double
    let targetBatchSize: Double
    let scaleFactor: Double
    let ingredientChanges: [IngredientScaleChange]
    let displayUnit: MeasurementUnit

    struct IngredientScaleChange: Identifiable {
        let id = UUID()
        let ingredientName: String
        let originalAmount: Double
        let scaledAmount: Double
        let unit: MeasurementUnit
    }
}

// MARK: - Batch Scaling View

/// View for scaling a recipe to a different batch size while maintaining proportions
@available(iOS 17.0, *)
struct BatchScalingView: View {
    @Environment(IngredientDatabase.self) private var database
    @Environment(UserSettingsManager.self) private var settingsManager
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let displayUnit: MeasurementUnit
    let onApply: (Recipe) -> Void

    // Scaling mode toggle
    @State private var scalingMode: BatchScalingMode = .bySize

    // By Size mode state
    @State private var targetSizeInput: String = ""
    @State private var selectedUnit: MeasurementUnit = .oz
    @State private var scalingResult: ScalingResult?

    // By Servings mode state
    @State private var numberOfPeople: Int = 4
    @State private var servingsPerPerson: Int = 2

    private let calculator = SlushCalculator()

    /// Common batch size presets in ounces
    private static let batchPresets: [(label: String, sizeOz: Double)] = [
        ("24 oz", 24),
        ("48 oz", 48),
        ("72 oz", 72),
        ("96 oz", 96)
    ]

    /// Scale factor presets
    private static let scaleFactorPresets: [(label: String, factor: Double)] = [
        ("0.5x", 0.5),
        ("2x", 2.0),
        ("3x", 3.0)
    ]

    /// Preset options for number of people
    private static let peoplePresets = [2, 4, 6, 8]

    /// Preset options for servings per person
    private static let servingsPresets = [1, 2, 3]

    init(
        recipe: Recipe,
        displayUnit: MeasurementUnit,
        onApply: @escaping (Recipe) -> Void
    ) {
        self.recipe = recipe
        self.displayUnit = displayUnit
        self.onApply = onApply

        // Initialize with current batch size
        let currentTotal = recipe.ingredients.reduce(0.0) { $0 + $1.volumeInOz }
        let displayValue = MeasurementUnit.oz.convert(currentTotal, to: displayUnit)
        _targetSizeInput = State(initialValue: formatForUnit(displayValue, unit: displayUnit))
        _selectedUnit = State(initialValue: displayUnit)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    scalingModeSelector
                    currentBatchInfo

                    switch scalingMode {
                    case .bySize:
                        targetBatchSection
                        quickPresetsSection
                    case .byServings:
                        servingsInputSection
                        servingsCalculationResult
                    }

                    if let result = scalingResult {
                        scalingPreview(result)
                    }
                }
                .padding()
            }
            .navigationTitle("Scale Batch")
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
                    .disabled(scalingResult == nil || scalingResult?.scaleFactor == 1.0)
                }
            }
            .onAppear {
                calculatePreview()
            }
            .onChange(of: scalingMode) { _, _ in
                calculatePreview()
            }
            .onChange(of: numberOfPeople) { _, _ in
                if scalingMode == .byServings {
                    calculateServingsPreview()
                }
            }
            .onChange(of: servingsPerPerson) { _, _ in
                if scalingMode == .byServings {
                    calculateServingsPreview()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Scaling Mode Selector

    private var scalingModeSelector: some View {
        Picker("Scaling Mode", selection: $scalingMode) {
            ForEach(BatchScalingMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Servings Input Section

    private var servingsInputSection: some View {
        VStack(spacing: 16) {
            // Serving size info
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundStyle(.blue)

                Text("Serving Size: \(Int(settingsManager.settings.servingSizeOz)) oz")
                    .font(.subheadline)

                Spacer()

                Button {
                    // This would navigate to settings, but for now just show info
                } label: {
                    Text("Change in Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // People input
            VStack(alignment: .leading, spacing: 8) {
                Text("Number of People")
                    .font(.subheadline.weight(.medium))

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

                    Stepper("", value: $numberOfPeople, in: 1...50)
                        .labelsHidden()
                        .frame(width: 100)
                }
            }

            // Servings per person input
            VStack(alignment: .leading, spacing: 8) {
                Text("Servings Per Person")
                    .font(.subheadline.weight(.medium))

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

                    Stepper("", value: $servingsPerPerson, in: 1...10)
                        .labelsHidden()
                        .frame(width: 100)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Servings Calculation Result

    private var servingsCalculationResult: some View {
        let totalServings = numberOfPeople * servingsPerPerson
        let servingSize = settingsManager.settings.servingSizeOz
        let totalVolumeOz = calculator.calculateTotalVolumeForServings(
            numberOfPeople: numberOfPeople,
            servingsPerPerson: servingsPerPerson,
            servingSizeOz: servingSize
        )
        let machineCapacity = settingsManager.settings.machineModel.workingCapacity
        let exceedsCapacity = totalVolumeOz > machineCapacity

        return VStack(spacing: 12) {
            // Calculation breakdown
            HStack(spacing: 4) {
                Text("\(numberOfPeople)")
                    .font(.title2.bold())
                    .foregroundStyle(.blue)

                Text("×")
                    .foregroundStyle(.secondary)

                Text("\(servingsPerPerson)")
                    .font(.title2.bold())
                    .foregroundStyle(.blue)

                Text("×")
                    .foregroundStyle(.secondary)

                Text("\(Int(servingSize)) oz")
                    .font(.title2.bold())
                    .foregroundStyle(.blue)

                Text("=")
                    .foregroundStyle(.secondary)

                Text("\(Int(totalVolumeOz)) oz")
                    .font(.title2.bold())
                    .foregroundStyle(exceedsCapacity ? .orange : .green)
            }

            Text("\(totalServings) total servings")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if exceedsCapacity {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    let batchesNeeded = Int(ceil(totalVolumeOz / machineCapacity))
                    Text("Exceeds capacity - need \(batchesNeeded) batches")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Servings Preview Calculation

    private func calculateServingsPreview() {
        let servingSize = settingsManager.settings.servingSizeOz
        let totalVolumeOz = calculator.calculateTotalVolumeForServings(
            numberOfPeople: numberOfPeople,
            servingsPerPerson: servingsPerPerson,
            servingSizeOz: servingSize
        )

        // Update the target size input to match
        targetSizeInput = formatForUnit(
            MeasurementUnit.oz.convert(totalVolumeOz, to: selectedUnit),
            unit: selectedUnit
        )

        // Calculate preview using the computed volume
        calculatePreviewForTargetOz(totalVolumeOz)
    }

    private func calculatePreviewForTargetOz(_ targetSizeOz: Double) {
        let currentTotal = recipe.ingredients.reduce(0.0) { $0 + $1.volumeInOz }

        guard currentTotal > 0 else {
            scalingResult = nil
            return
        }

        let scaleFactor = targetSizeOz / currentTotal

        // Build ingredient changes
        var changes: [ScalingResult.IngredientScaleChange] = []
        for ingredient in recipe.ingredients {
            if let dbIngredient = database.ingredient(for: ingredient.ingredientId) {
                changes.append(ScalingResult.IngredientScaleChange(
                    ingredientName: dbIngredient.name,
                    originalAmount: ingredient.amount,
                    scaledAmount: ingredient.amount * scaleFactor,
                    unit: ingredient.unit
                ))
            }
        }

        scalingResult = ScalingResult(
            originalBatchSize: currentTotal,
            targetBatchSize: targetSizeOz,
            scaleFactor: scaleFactor,
            ingredientChanges: changes,
            displayUnit: selectedUnit
        )
    }

    // MARK: - Current Batch Info

    private var currentBatchInfo: some View {
        let currentTotal = recipe.ingredients.reduce(0.0) { $0 + $1.volumeInOz }
        let displayValue = MeasurementUnit.oz.convert(currentTotal, to: selectedUnit)

        return VStack(spacing: 8) {
            Text("Current Batch")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formatForUnit(displayValue, unit: selectedUnit) + " " + selectedUnit.abbreviation)
                .font(.title.bold())

            Text("\(recipe.ingredients.count) ingredients")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Target Batch Section

    private var targetBatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scale To")
                .font(.headline)

            HStack(spacing: 12) {
                TextField("Size", text: $targetSizeInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                    .onChange(of: targetSizeInput) { _, _ in
                        calculatePreview()
                    }

                Picker("Unit", selection: $selectedUnit) {
                    Text("oz").tag(MeasurementUnit.oz)
                    Text("cup").tag(MeasurementUnit.cup)
                    Text("ml").tag(MeasurementUnit.ml)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedUnit) { oldUnit, newUnit in
                    convertTargetSize(from: oldUnit, to: newUnit)
                }
            }

            if let result = scalingResult, result.scaleFactor != 1.0 {
                HStack {
                    Image(systemName: result.scaleFactor > 1.0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(result.scaleFactor > 1.0 ? .green : .orange)

                    Text("Scale factor: \(String(format: "%.2f", result.scaleFactor))x")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Quick Presets

    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Scale")
                .font(.headline)

            // Scale factor presets
            HStack(spacing: 8) {
                ForEach(Self.scaleFactorPresets, id: \.label) { preset in
                    Button {
                        applyScaleFactor(preset.factor)
                    } label: {
                        Text(preset.label)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("Common Sizes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            // Batch size presets
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Self.batchPresets, id: \.sizeOz) { preset in
                    Button {
                        applyPresetSize(preset.sizeOz)
                    } label: {
                        Text(preset.label)
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(isCurrentSize(preset.sizeOz) ? .green : .primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Scaling Preview

    private func scalingPreview(_ result: ScalingResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.headline)

                Spacer()

                if result.scaleFactor != 1.0 {
                    Text("\(result.scaleFactor > 1.0 ? "+" : "")\(String(format: "%.0f", (result.scaleFactor - 1.0) * 100))%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(result.scaleFactor > 1.0 ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(result.scaleFactor > 1.0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            ForEach(result.ingredientChanges) { change in
                ingredientChangeRow(change, scaleFactor: result.scaleFactor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func ingredientChangeRow(_ change: ScalingResult.IngredientScaleChange, scaleFactor: Double) -> some View {
        HStack {
            Text(change.ingredientName)
                .font(.body)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                // Original amount (dimmed)
                Text(formatAmount(change.originalAmount, unit: change.unit))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if scaleFactor != 1.0 {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // New amount (highlighted)
                    Text(formatAmount(change.scaledAmount, unit: change.unit))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(scaleFactor > 1.0 ? .green : .orange)
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func calculatePreview() {
        // Handle different modes
        switch scalingMode {
        case .bySize:
            calculateSizePreview()
        case .byServings:
            calculateServingsPreview()
        }
    }

    private func calculateSizePreview() {
        guard let targetValue = Double(targetSizeInput), targetValue > 0 else {
            scalingResult = nil
            return
        }

        // Convert target to oz for calculation
        let targetSizeOz = selectedUnit.convert(targetValue, to: .oz)
        calculatePreviewForTargetOz(targetSizeOz)
    }

    private func applyScaleFactor(_ factor: Double) {
        let currentTotal = recipe.ingredients.reduce(0.0) { $0 + $1.volumeInOz }
        let newSize = currentTotal * factor
        let displayValue = MeasurementUnit.oz.convert(newSize, to: selectedUnit)
        targetSizeInput = formatForUnit(displayValue, unit: selectedUnit)
        calculatePreview()
    }

    private func applyPresetSize(_ sizeOz: Double) {
        let displayValue = MeasurementUnit.oz.convert(sizeOz, to: selectedUnit)
        targetSizeInput = formatForUnit(displayValue, unit: selectedUnit)
        calculatePreview()
    }

    private func convertTargetSize(from oldUnit: MeasurementUnit, to newUnit: MeasurementUnit) {
        guard let currentValue = Double(targetSizeInput), currentValue > 0 else { return }
        let converted = oldUnit.convert(currentValue, to: newUnit)
        targetSizeInput = formatForUnit(converted, unit: newUnit)
    }

    private func applyScaling() {
        guard let result = scalingResult, result.scaleFactor != 1.0 else { return }

        let scaledRecipe = calculator.scaleRecipe(
            recipe,
            toBatchSize: result.targetBatchSize,
            ingredientLookup: database.lookupFunction()
        )

        onApply(scaledRecipe)
        dismiss()
    }

    // MARK: - Helpers

    private func isCurrentSize(_ sizeOz: Double) -> Bool {
        guard let targetValue = Double(targetSizeInput), targetValue > 0 else { return false }
        let targetOz = selectedUnit.convert(targetValue, to: .oz)
        return abs(targetOz - sizeOz) < 0.5
    }

    private func formatAmount(_ amount: Double, unit: MeasurementUnit) -> String {
        if unit == .ml {
            return String(format: "%.0f %@", amount, unit.abbreviation)
        } else if amount < 1 {
            return String(format: "%.2f %@", amount, unit.abbreviation)
        } else {
            return String(format: "%.1f %@", amount, unit.abbreviation)
        }
    }
}

// MARK: - Helper Function

private func formatForUnit(_ value: Double, unit: MeasurementUnit) -> String {
    switch unit {
    case .ml:
        return String(format: "%.0f", value)
    case .cup:
        return String(format: "%.1f", value)
    default:
        return String(format: "%.0f", value)
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    let sampleRecipe = Recipe(
        name: "Test Recipe",
        ingredients: [
            RecipeIngredient(
                ingredientId: UUID(),
                amount: 2.0,
                unit: .oz,
                isLocked: false
            ),
            RecipeIngredient(
                ingredientId: UUID(),
                amount: 1.5,
                unit: .oz,
                isLocked: false
            )
        ],
        targetBatchSize: 48
    )

    return BatchScalingView(
        recipe: sampleRecipe,
        displayUnit: .oz,
        onApply: { _ in }
    )
    .environment(IngredientDatabase.shared)
}
