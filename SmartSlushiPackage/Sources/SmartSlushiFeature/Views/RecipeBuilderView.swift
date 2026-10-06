import SwiftUI
import UIKit

// MARK: - Optimization Result

/// Result of an auto-balance operation showing what changed
struct OptimizationResult: Identifiable {
    let id = UUID()
    let beforeStats: RecipeStats
    let afterStats: RecipeStats
    let ingredientChanges: [IngredientChange]
    let targetBrixRange: ClosedRange<Double>
    let targetABVRange: ClosedRange<Double>

    struct IngredientChange: Identifiable {
        let id = UUID()
        let ingredientName: String
        let previousAmount: Double?
        let newAmount: Double
        let unit: MeasurementUnit

        var isNewIngredient: Bool {
            previousAmount == nil
        }

        var amountDifference: Double {
            guard let previous = previousAmount else { return newAmount }
            return newAmount - previous
        }
    }

    var wasSuccessful: Bool {
        afterStats.slushabilityStatus.isOptimal ||
        (targetBrixRange.contains(afterStats.finalBrix) &&
         (targetABVRange.contains(afterStats.finalABV) || afterStats.finalABV < targetABVRange.lowerBound))
    }
}

// MARK: - Recipe Builder View

/// Main view for creating and editing slush recipes
@available(iOS 17.0, *)
public struct RecipeBuilderView: View {
    @Environment(IngredientDatabase.self) private var database
    @Environment(RecipeStore.self) private var recipeStore
    @Environment(UserSettingsManager.self) private var settingsManager
    @Environment(SharedRecipeStore.self) private var sharedRecipeStore

    @State private var recipe: Recipe
    @State private var showingIngredientPicker = false
    @State private var showingTemplates = false
    @State private var showingSavedRecipes = false
    @State private var showingSettings = false
    @State private var showingPreferences = false
    @State private var preferences = DrinkPreferences.balanced
    @State private var isAutoBalancing = false
    @State private var displayUnit: MeasurementUnit = .oz
    @State private var batchSizeInput: String = ""
    @State private var optimizationResult: OptimizationResult?
    @State private var showingOptimizationResult = false
    @State private var showingSaveConfirmation = false
    @State private var showingRecipeOutput = false
    @State private var showingBatchScaling = false
    @State private var showingCommunityRecipes = false
    @State private var showingPublishSheet = false
    @State private var pendingLoadedRecipe: Recipe?
    @State private var hasAppliedInitialDefaults = false

    private let calculator = SlushCalculator()
    private let optimizer = RecipeOptimizer()
    private let shouldApplySettingsDefaults: Bool

    /// Units available for batch size display
    private static let volumeDisplayUnits: [MeasurementUnit] = [.oz, .cup, .ml]

    public init(recipe: Recipe? = nil) {
        let initialRecipe = recipe ?? Recipe(name: "New Recipe")
        let initialDisplayUnit = initialRecipe.targetUnit
        let initialDisplayValue = MeasurementUnit.oz.convert(initialRecipe.targetBatchSize, to: initialDisplayUnit)
        let initialBatchInput: String
        if initialDisplayUnit == .ml {
            initialBatchInput = String(format: "%.0f", initialDisplayValue)
        } else if initialDisplayUnit == .cup {
            initialBatchInput = String(format: "%.1f", initialDisplayValue)
        } else {
            initialBatchInput = String(format: "%.0f", initialDisplayValue)
        }

        self.shouldApplySettingsDefaults = recipe == nil
        _recipe = State(initialValue: initialRecipe)
        _batchSizeInput = State(initialValue: initialBatchInput)
        _displayUnit = State(initialValue: initialRecipe.targetUnit)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    recipeHeader
                    quickStatsBar
                    ingredientsList
                    preferencesSection
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Recipe Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingTemplates = true
                        } label: {
                            Label("Load Template", systemImage: "doc.text")
                        }

                        Button {
                            showingSavedRecipes = true
                        } label: {
                            Label("Saved Recipes", systemImage: "folder")
                        }

                        Divider()

                        Button {
                            showingCommunityRecipes = true
                        } label: {
                            Label("Community Recipes", systemImage: "globe")
                        }

                        Button {
                            showingPublishSheet = true
                        } label: {
                            Label("Share to Community", systemImage: "square.and.arrow.up")
                        }
                        .disabled(recipe.ingredients.isEmpty || recipe.name.isEmpty)

                        Divider()

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingIngredientPicker) {
                IngredientPickerView { ingredient in
                    addIngredient(ingredient)
                }
            }
            .sheet(isPresented: $showingTemplates) {
                RecipeTemplatesView { template in
                    loadTemplate(template)
                }
            }
            .sheet(isPresented: $showingSavedRecipes, onDismiss: applyPendingLoadedRecipe) {
                SavedRecipesView { loadedRecipe in
                    pendingLoadedRecipe = loadedRecipe
                }
            }
            .sheet(isPresented: $showingOptimizationResult) {
                if let result = optimizationResult {
                    OptimizationResultView(result: result) {
                        showingOptimizationResult = false
                    }
                }
            }
            .alert("Recipe Saved", isPresented: $showingSaveConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your recipe has been saved successfully.")
            }
            .sheet(isPresented: $showingRecipeOutput) {
                RecipeOutputView(recipe: recipe) { importedRecipe in
                    withAnimation {
                        recipe = importedRecipe
                        displayUnit = recipe.targetUnit
                        batchSizeInput = formatBatchSize(recipe.targetBatchSize, for: displayUnit)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environment(settingsManager)
            }
            .sheet(isPresented: $showingBatchScaling) {
                BatchScalingView(
                    recipe: recipe,
                    displayUnit: displayUnit
                ) { scaledRecipe in
                    withAnimation {
                        recipe = scaledRecipe
                        batchSizeInput = formatBatchSize(scaledRecipe.targetBatchSize, for: displayUnit)
                    }
                }
                .environment(database)
                .environment(settingsManager)
            }
            .sheet(isPresented: $showingCommunityRecipes) {
                SharedRecipesView { importedRecipe in
                    withAnimation {
                        recipe = importedRecipe
                        displayUnit = recipe.targetUnit
                        batchSizeInput = formatBatchSize(recipe.targetBatchSize, for: displayUnit)
                    }
                }
                .environment(sharedRecipeStore)
                .environment(database)
                .environment(recipeStore)
            }
            .sheet(isPresented: $showingPublishSheet) {
                PublishRecipeSheet(recipe: recipe)
                    .environment(sharedRecipeStore)
                    .environment(database)
            }
            .onAppear {
                applyUserDefaultsIfNeeded()
                // Always sync taste preferences from settings (including when editing a saved recipe)
                if !shouldApplySettingsDefaults || hasAppliedInitialDefaults {
                    preferences = settingsManager.settings.drinkPreferences
                }
            }
        }
    }

    // MARK: - Recipe Header

    private var recipeHeader: some View {
        VStack(spacing: 12) {
            TextField("Recipe Name", text: $recipe.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .accessibilityLabel("Recipe name")

            HStack(spacing: 8) {
                Text("Batch Size:")
                    .foregroundStyle(.secondary)

                TextField("Size", text: $batchSizeInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Batch size")
                    .accessibilityValue("\(batchSizeInput) \(displayUnit.abbreviation)")
                    .onChange(of: batchSizeInput) { _, newValue in
                        updateBatchSize(from: newValue)
                    }

                Picker("Unit", selection: $displayUnit) {
                    ForEach(Self.volumeDisplayUnits, id: \.self) { unit in
                        Text(unit.abbreviation).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .accessibilityLabel("Batch size unit")
                .onChange(of: displayUnit) { oldUnit, newUnit in
                    convertBatchSize(from: oldUnit, to: newUnit)
                }

                Button {
                    showingBatchScaling = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .disabled(recipe.ingredients.isEmpty)
                .accessibilityLabel("Scale batch size")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func updateBatchSize(from input: String) {
        guard let value = Double(input), value > 0 else { return }
        // Store internally always in oz
        let valueInOz = displayUnit.convert(value, to: .oz)
        let previousSize = recipe.targetBatchSize

        recipe.targetBatchSize = valueInOz
        recipe.targetUnit = displayUnit

        // Scale existing ingredients so the batch-size field drives the recipe
        guard !recipe.ingredients.isEmpty, previousSize > 0, abs(valueInOz - previousSize) > 0.01 else {
            return
        }
        recipe = calculator.scaleRecipe(
            recipe,
            toBatchSize: valueInOz,
            ingredientLookup: database.lookupFunction()
        )
    }

    private func convertBatchSize(from oldUnit: MeasurementUnit, to newUnit: MeasurementUnit) {
        guard let currentValue = Double(batchSizeInput), currentValue > 0 else { return }
        let convertedValue = oldUnit.convert(currentValue, to: newUnit)
        // Format based on unit - ml uses whole numbers, oz and cups use decimals
        if newUnit == .ml {
            batchSizeInput = String(format: "%.0f", convertedValue)
        } else if newUnit == .cup {
            batchSizeInput = String(format: "%.1f", convertedValue)
        } else {
            batchSizeInput = String(format: "%.0f", convertedValue)
        }
        recipe.targetUnit = newUnit
    }

    // MARK: - Quick Stats Bar

    private var quickStatsBar: some View {
        let stats = calculateCurrentStats()
        let targets = preferences.toOptimizationTargets()

        return QuickStatsBar(
            stats: stats,
            displayUnit: displayUnit,
            targetBrixRange: targets.brixRange,
            targetABVRange: targets.abvRange
        )
    }

    // MARK: - Ingredients List

    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients")
                    .font(.headline)

                Spacer()

                Button {
                    showingIngredientPicker = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
            }

            if recipe.ingredients.isEmpty {
                emptyIngredientsView
            } else {
                ForEach($recipe.ingredients) { $recipeIngredient in
                    IngredientRow(
                        recipeIngredient: $recipeIngredient,
                        ingredient: database.ingredient(for: recipeIngredient.ingredientId),
                        onDelete: {
                            removeIngredient(recipeIngredient)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var emptyIngredientsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No ingredients yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Add Ingredient") {
                showingIngredientPicker = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    showingPreferences.toggle()
                }
            } label: {
                HStack {
                    Text("Taste Preferences")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: showingPreferences ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showingPreferences {
                VStack(spacing: 16) {
                    PreferenceSlider(
                        title: "Sweetness",
                        value: Binding(
                            get: { preferences.sweetnessLevel },
                            set: { newValue in
                                preferences.sweetnessLevel = newValue
                                settingsManager.setDrinkPreferences(preferences)
                                recipeStore.updateDrinkPreferences(preferences)
                            }
                        ),
                        leftLabel: "Tart",
                        rightLabel: "Sweet"
                    )

                    PreferenceSlider(
                        title: "Thickness",
                        value: Binding(
                            get: { preferences.slushThickness },
                            set: { newValue in
                                preferences.slushThickness = newValue
                                settingsManager.setDrinkPreferences(preferences)
                                recipeStore.updateDrinkPreferences(preferences)
                            }
                        ),
                        leftLabel: "Sippable",
                        rightLabel: "Thick"
                    )

                    PreferenceSlider(
                        title: "Strength",
                        value: Binding(
                            get: { preferences.alcoholStrength },
                            set: { newValue in
                                preferences.alcoholStrength = newValue
                                settingsManager.setDrinkPreferences(preferences)
                                recipeStore.updateDrinkPreferences(preferences)
                            }
                        ),
                        leftLabel: "Light",
                        rightLabel: "Strong"
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                autoBalance()
            } label: {
                HStack {
                    if isAutoBalancing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text("Auto-Balance Recipe")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(recipe.ingredients.isEmpty || isAutoBalancing)

            HStack(spacing: 12) {
                Button {
                    showingRecipeOutput = true
                } label: {
                    Label("View Recipe", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .disabled(recipe.ingredients.isEmpty)

                Button {
                    clearRecipe()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(recipe.ingredients.isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func applyUserDefaultsIfNeeded() {
        guard shouldApplySettingsDefaults, !hasAppliedInitialDefaults else { return }
        hasAppliedInitialDefaults = true

        preferences = settingsManager.settings.drinkPreferences

        let preferredUnit = settingsManager.settings.preferredUnit
        // defaultBatchSize is always stored in ounces
        let defaultBatchSizeOz = max(1, settingsManager.settings.defaultBatchSize)

        recipe.targetBatchSize = defaultBatchSizeOz
        recipe.targetUnit = preferredUnit
        displayUnit = preferredUnit
        batchSizeInput = formatBatchSize(defaultBatchSizeOz, for: preferredUnit)
    }

    private func calculateCurrentStats() -> RecipeStats {
        calculator.calculateStats(
            for: recipe.ingredients,
            ingredientLookup: database.lookupFunction(),
            servingSizeOz: settingsManager.settings.servingSizeOz
        )
    }

    private func addIngredient(_ ingredient: Ingredient) {
        let recipeIngredient = RecipeIngredient(
            ingredientId: ingredient.id,
            amount: 1.0,
            unit: ingredient.defaultUnit,
            isLocked: false
        )
        recipe.ingredients.append(recipeIngredient)
        recipe.modifiedAt = Date()
        recipeStore.markIngredientAsRecentlyUsed(ingredient.id)
        database.markAsRecentlyUsed(ingredient.id)
    }

    private func removeIngredient(_ ingredient: RecipeIngredient) {
        recipe.ingredients.removeAll { $0.id == ingredient.id }
        recipe.modifiedAt = Date()
    }

    private func autoBalance() {
        guard let water = database.water,
              let simpleSyrup = database.simpleSyrup else {
            return
        }

        isAutoBalancing = true

        // Capture before stats and original batch size
        let beforeStats = calculateCurrentStats()
        let originalBatchSize = beforeStats.totalVolumeOz
        let beforeIngredients = Dictionary(
            uniqueKeysWithValues: recipe.ingredients.map { ($0.ingredientId, $0.amount) }
        )

        // Run optimization
        let targets = preferences.toOptimizationTargets()
        var balanced = optimizer.autoBalance(
            recipe: recipe,
            targetBrixRange: targets.brixRange,
            targetABVRange: targets.abvRange,
            ingredientLookup: database.lookupFunction(),
            waterIngredientId: water.id,
            sweetenerIngredientId: simpleSyrup.id
        )

        // Scale back to original batch size to maintain volume while preserving optimized ratios
        if originalBatchSize > 0 {
            balanced = calculator.scaleRecipe(
                balanced,
                toBatchSize: originalBatchSize,
                ingredientLookup: database.lookupFunction()
            )
        }

        // Calculate after stats (now at original batch size with optimized ratios)
        let afterStats = calculator.calculateStats(
            for: balanced.ingredients,
            ingredientLookup: database.lookupFunction()
        )

        // Determine ingredient changes
        var ingredientChanges: [OptimizationResult.IngredientChange] = []
        for ingredient in balanced.ingredients {
            let previousAmount = beforeIngredients[ingredient.ingredientId]
            let ingredientName = database.ingredient(for: ingredient.ingredientId)?.name ?? "Unknown"

            // Only include if it's new or the amount changed
            if previousAmount == nil || abs(ingredient.amount - (previousAmount ?? 0)) > 0.01 {
                ingredientChanges.append(OptimizationResult.IngredientChange(
                    ingredientName: ingredientName,
                    previousAmount: previousAmount,
                    newAmount: ingredient.amount,
                    unit: ingredient.unit
                ))
            }
        }

        // Create optimization result
        let result = OptimizationResult(
            beforeStats: beforeStats,
            afterStats: afterStats,
            ingredientChanges: ingredientChanges,
            targetBrixRange: targets.brixRange,
            targetABVRange: targets.abvRange
        )

        withAnimation {
            recipe = balanced
            isAutoBalancing = false
            optimizationResult = result

            // Trigger haptic feedback
            if result.wasSuccessful {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            }

            // Show result sheet
            showingOptimizationResult = true
        }
    }

    private func saveRecipe() {
        recipe.modifiedAt = Date()
        recipeStore.save(recipe)
        showingSaveConfirmation = true
    }

    private func loadTemplate(_ template: RecipeTemplate) {
        withAnimation {
            recipe = template.createRecipe(targetBatchSize: recipe.targetBatchSize)
            recipe.targetUnit = displayUnit
            batchSizeInput = formatBatchSize(recipe.targetBatchSize, for: displayUnit)
        }
    }

    private func applyPendingLoadedRecipe() {
        guard let loadedRecipe = pendingLoadedRecipe else { return }
        pendingLoadedRecipe = nil
        loadSavedRecipe(loadedRecipe)
    }

    private func loadSavedRecipe(_ loadedRecipe: Recipe) {
        withAnimation {
            recipe = loadedRecipe
            displayUnit = recipe.targetUnit
            batchSizeInput = formatBatchSize(recipe.targetBatchSize, for: displayUnit)
        }
    }

    private func formatBatchSize(_ sizeInOz: Double, for unit: MeasurementUnit) -> String {
        let converted = MeasurementUnit.oz.convert(sizeInOz, to: unit)
        if unit == .ml {
            return String(format: "%.0f", converted)
        } else if unit == .cup {
            return String(format: "%.1f", converted)
        } else {
            return String(format: "%.0f", converted)
        }
    }

    private func clearRecipe() {
        withAnimation {
            recipe.ingredients.removeAll()
            recipe.modifiedAt = Date()
        }
    }
}

// MARK: - Quick Stats Bar

@available(iOS 17.0, *)
struct QuickStatsBar: View {
    let stats: RecipeStats
    let displayUnit: MeasurementUnit
    let targetBrixRange: ClosedRange<Double>
    let targetABVRange: ClosedRange<Double>
    @Environment(UserSettingsManager.self) private var settingsManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                StatBadgeWithTarget(
                    title: "ABV",
                    value: String(format: "%.1f%%", stats.finalABV),
                    targetRange: String(format: "%.0f-%.0f%%", targetABVRange.lowerBound, targetABVRange.upperBound),
                    status: abvStatus,
                    isInTargetRange: isABVInTargetRange,
                    tooltip: settingsManager.settings.showTooltips ? .abv : nil
                )

                StatBadgeWithTarget(
                    title: "Brix",
                    value: String(format: "%.1f", stats.finalBrix),
                    targetRange: String(format: "%.0f-%.0f", targetBrixRange.lowerBound, targetBrixRange.upperBound),
                    status: brixStatus,
                    isInTargetRange: isBrixInTargetRange,
                    tooltip: settingsManager.settings.showTooltips ? .brix : nil
                )

                StatBadge(
                    title: "Volume",
                    value: formattedVolume,
                    status: .neutral
                )

                StatBadge(
                    title: "Servings",
                    value: "\(stats.servings)",
                    subtitle: "@ \(Int(settingsManager.settings.servingSizeOz)) oz",
                    status: .neutral
                )
            }

            SlushabilityIndicator(
                status: stats.slushabilityStatus,
                showTooltip: settingsManager.settings.showTooltips
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var formattedVolume: String {
        switch displayUnit {
        case .ml:
            return String(format: "%.0f ml", stats.totalVolumeMl)
        case .cup:
            let cups = MeasurementUnit.oz.convert(stats.totalVolumeOz, to: .cup)
            return String(format: "%.1f cups", cups)
        case .liter:
            let liters = stats.totalVolumeMl / 1000.0
            return String(format: "%.1f L", liters)
        default:
            return String(format: "%.0f oz", stats.totalVolumeOz)
        }
    }

    private var isABVInTargetRange: Bool {
        targetABVRange.contains(stats.finalABV) || stats.finalABV < targetABVRange.lowerBound
    }

    private var isBrixInTargetRange: Bool {
        targetBrixRange.contains(stats.finalBrix)
    }

    private var abvStatus: StatStatus {
        if stats.finalABV > 12 { return .bad }
        if stats.finalABV > 10 { return .warning }
        if isABVInTargetRange { return .good }
        return .neutral
    }

    private var brixStatus: StatStatus {
        if stats.finalBrix < 11 || stats.finalBrix > 17 { return .bad }
        if isBrixInTargetRange { return .good }
        if stats.finalBrix < 13 || stats.finalBrix > 15 { return .warning }
        return .neutral
    }
}

// MARK: - Stat Badge

enum StatStatus {
    case good, warning, bad, neutral

    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .bad: return .red
        case .neutral: return .secondary
        }
    }
}

struct StatBadge: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let status: StatStatus

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(status.color)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat Badge with Target Range

@available(iOS 17.0, *)
struct StatBadgeWithTarget: View {
    let title: String
    let value: String
    let targetRange: String
    let status: StatStatus
    let isInTargetRange: Bool
    var tooltip: TooltipContent? = nil

    @State private var showingTooltip = false

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if tooltip != nil {
                    Image(systemName: "info.circle")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }

            Text(value)
                .font(.headline)
                .foregroundStyle(status.color)

            HStack(spacing: 2) {
                Image(systemName: isInTargetRange ? "target" : "arrow.right")
                    .font(.system(size: 8))
                Text(targetRange)
                    .font(.system(size: 9))
            }
            .foregroundStyle(isInTargetRange ? .green : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if tooltip != nil {
                showingTooltip = true
            }
        }
        .sheet(isPresented: $showingTooltip) {
            if let tooltip {
                TooltipView(content: tooltip)
            }
        }
    }
}

// MARK: - Slushability Indicator

@available(iOS 17.0, *)
struct SlushabilityIndicator: View {
    let status: SlushabilityStatus
    var showTooltip: Bool = true

    @State private var showingTooltip = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            Text(status.message)
                .font(.subheadline)
                .foregroundStyle(textColor)

            if showTooltip {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            if showTooltip {
                showingTooltip = true
            }
        }
        .sheet(isPresented: $showingTooltip) {
            TooltipView(content: .slushability)
        }
    }

    private var iconName: String {
        switch status {
        case .optimal: return "checkmark.circle.fill"
        case .tooSweet, .notSweetEnough, .tooAlcoholic: return "exclamationmark.triangle.fill"
        case .willNotFreeze: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .optimal: return .green
        case .tooSweet, .notSweetEnough, .tooAlcoholic, .warning: return .orange
        case .willNotFreeze: return .red
        }
    }

    private var textColor: Color {
        switch status {
        case .optimal: return .primary
        default: return .primary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .optimal: return .green.opacity(0.15)
        case .tooSweet, .notSweetEnough, .tooAlcoholic, .warning: return .orange.opacity(0.15)
        case .willNotFreeze: return .red.opacity(0.15)
        }
    }
}

// MARK: - Ingredient Row

@available(iOS 17.0, *)
struct IngredientRow: View {
    @Binding var recipeIngredient: RecipeIngredient
    let ingredient: Ingredient?
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                recipeIngredient.isLocked.toggle()
            } label: {
                Image(systemName: recipeIngredient.isLocked ? "lock.fill" : "lock.open")
                    .foregroundStyle(recipeIngredient.isLocked ? .orange : .secondary)
                    .frame(width: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recipeIngredient.isLocked ? "Unlock ingredient" : "Lock ingredient")
            .accessibilityHint("Locked ingredients are not changed by auto-balance")

            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient?.name ?? "Unknown")
                    .font(.body)

                if let ingredient {
                    HStack(spacing: 8) {
                        if ingredient.abv > 0 {
                            Text("\(Int(ingredient.abv))% ABV")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if ingredient.brix > 0 {
                            Text("\(Int(ingredient.brix)) Brix")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                TextField("", value: $recipeIngredient.amount, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .disabled(recipeIngredient.isLocked)
                    .accessibilityLabel("Amount")
                    .accessibilityValue("\(recipeIngredient.amount) \(recipeIngredient.unit.abbreviation)")

                Picker("Unit", selection: $recipeIngredient.unit) {
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        Text(unit.abbreviation).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 60)
                .disabled(recipeIngredient.isLocked)
                .accessibilityLabel("Unit")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(ingredient?.name ?? "ingredient")")
        }
        .padding(.vertical, 8)
        .opacity(recipeIngredient.isLocked ? 0.85 : 1)
    }
}

// MARK: - Preference Slider

struct PreferenceSlider: View {
    let title: String
    @Binding var value: Double
    let leftLabel: String
    let rightLabel: String

    // Track if we've hit the optimal range to provide haptic feedback
    @State private var wasInOptimalRange = false

    /// Optimal range is around the middle (0.4-0.6) for balanced drinks
    private var isInOptimalRange: Bool {
        value >= 0.4 && value <= 0.6
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()

                // Show "Balanced" indicator when in optimal range
                if isInOptimalRange {
                    Text("Balanced")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text(leftLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)

                Slider(value: $value, in: 0...1)
                    .accessibilityLabel(title)
                    .accessibilityValue(String(format: "%.0f percent", value * 100))
                    .onChange(of: value) { _, newValue in
                        let nowInRange = newValue >= 0.4 && newValue <= 0.6
                        if nowInRange && !wasInOptimalRange {
                            // Just entered optimal range - light haptic
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                        }
                        wasInOptimalRange = nowInRange
                    }

                Text(rightLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }
}

// MARK: - Optimization Result View

@available(iOS 17.0, *)
struct OptimizationResultView: View {
    let result: OptimizationResult
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    resultHeader
                    statsComparison
                    if !result.ingredientChanges.isEmpty {
                        ingredientChangesSection
                    }
                    targetRangesInfo
                }
                .padding()
            }
            .navigationTitle("Optimization Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var resultHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: result.wasSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(result.wasSuccessful ? .green : .orange)

            Text(result.wasSuccessful ? "Recipe Balanced!" : "Partially Balanced")
                .font(.title2.bold())

            Text(result.wasSuccessful ?
                 "Your recipe is now optimized for perfect slush texture." :
                 "Recipe improved but may need manual adjustments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(result.wasSuccessful ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statsComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Before & After")
                .font(.headline)

            HStack(spacing: 16) {
                // Before column
                VStack(spacing: 12) {
                    Text("Before")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    StatComparisonItem(
                        label: "ABV",
                        value: String(format: "%.1f%%", result.beforeStats.finalABV),
                        status: abvStatus(for: result.beforeStats.finalABV)
                    )

                    StatComparisonItem(
                        label: "Brix",
                        value: String(format: "%.1f", result.beforeStats.finalBrix),
                        status: brixStatus(for: result.beforeStats.finalBrix)
                    )

                    StatComparisonItem(
                        label: "Volume",
                        value: String(format: "%.0f oz", result.beforeStats.totalVolumeOz),
                        status: .neutral
                    )
                }
                .frame(maxWidth: .infinity)

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                // After column
                VStack(spacing: 12) {
                    Text("After")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    StatComparisonItem(
                        label: "ABV",
                        value: String(format: "%.1f%%", result.afterStats.finalABV),
                        status: abvStatus(for: result.afterStats.finalABV)
                    )

                    StatComparisonItem(
                        label: "Brix",
                        value: String(format: "%.1f", result.afterStats.finalBrix),
                        status: brixStatus(for: result.afterStats.finalBrix)
                    )

                    StatComparisonItem(
                        label: "Volume",
                        value: String(format: "%.0f oz", result.afterStats.totalVolumeOz),
                        status: .neutral
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var ingredientChangesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjustments Made")
                .font(.headline)

            ForEach(result.ingredientChanges) { change in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.ingredientName)
                            .font(.body)

                        if change.isNewIngredient {
                            Text("Added")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text("Increased")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if change.isNewIngredient {
                            Text("+\(formatAmount(change.newAmount, unit: change.unit))")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.green)
                        } else {
                            Text("+\(formatAmount(change.amountDifference, unit: change.unit))")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.blue)

                            Text("\(formatAmount(change.previousAmount ?? 0, unit: change.unit)) → \(formatAmount(change.newAmount, unit: change.unit))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)

                if change.id != result.ingredientChanges.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var targetRangesInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Ranges")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brix Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.0f", result.targetBrixRange.lowerBound))-\(String(format: "%.0f", result.targetBrixRange.upperBound))")
                        .font(.body.weight(.medium))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("ABV Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.0f", result.targetABVRange.lowerBound))-\(String(format: "%.0f", result.targetABVRange.upperBound))%")
                        .font(.body.weight(.medium))
                }
            }

            Text("Based on your taste preferences")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatAmount(_ amount: Double, unit: MeasurementUnit) -> String {
        String(format: "%.1f %@", amount, unit.abbreviation)
    }

    private func abvStatus(for abv: Double) -> StatStatus {
        if abv > 12 { return .bad }
        if abv > 10 { return .warning }
        if abv >= 5 { return .good }
        return .neutral
    }

    private func brixStatus(for brix: Double) -> StatStatus {
        if brix < 11 || brix > 17 { return .bad }
        if brix < 13 || brix > 15 { return .warning }
        return .good
    }
}

// MARK: - Stat Comparison Item

struct StatComparisonItem: View {
    let label: String
    let value: String
    let status: StatStatus

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .foregroundStyle(status.color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(status == .good ? status.color.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    RecipeBuilderView()
        .environment(IngredientDatabase.shared)
        .environment(RecipeStore())
        .environment(UserSettingsManager.shared)
}
