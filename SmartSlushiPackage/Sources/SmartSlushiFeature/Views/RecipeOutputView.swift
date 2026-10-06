import SwiftUI
import UIKit

// MARK: - Output Tab Selection

enum OutputTab: String, CaseIterable {
    case shoppingList = "Shopping List"
    case instructions = "Instructions"
    case share = "Share"

    var icon: String {
        switch self {
        case .shoppingList: return "cart"
        case .instructions: return "list.bullet.clipboard"
        case .share: return "square.and.arrow.up"
        }
    }
}

// MARK: - Shopping Item

struct ShoppingItem: Identifiable {
    let id = UUID()
    let ingredient: Ingredient
    let recipeIngredient: RecipeIngredient
    var isChecked: Bool = false
}

// MARK: - Recipe Output View

/// View displaying the finalized recipe with shopping list, instructions, and share options
@available(iOS 17.0, *)
public struct RecipeOutputView: View {
    @Environment(IngredientDatabase.self) private var database
    @Environment(UserSettingsManager.self) private var settingsManager
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let onImportRecipe: ((Recipe) -> Void)?

    @State private var selectedTab: OutputTab = .shoppingList
    @State private var shoppingItems: [IngredientCategory: [ShoppingItem]] = [:]
    @State private var showingShareSheet = false
    @State private var shareContent: String = ""
    @State private var showingExportOptions = false
    @State private var showingCopyConfirmation = false
    @State private var confirmationMessage = "Recipe copied to clipboard"

    private let calculator = SlushCalculator()
    private let serializer = RecipeSerializer()

    public init(recipe: Recipe, onImportRecipe: ((Recipe) -> Void)? = nil) {
        self.recipe = recipe
        self.onImportRecipe = onImportRecipe
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    ForEach(OutputTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab Content
                TabView(selection: $selectedTab) {
                    shoppingListView
                        .tag(OutputTab.shoppingList)

                    instructionsView
                        .tag(OutputTab.instructions)

                    shareView
                        .tag(OutputTab.share)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                buildShoppingItems()
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [shareContent])
            }
            .alert("Copied!", isPresented: $showingCopyConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(confirmationMessage)
            }
        }
    }

    // MARK: - Shopping List View

    private var shoppingListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe info header
                recipeInfoCard

                // Shopping items by category
                ForEach(sortedCategories, id: \.self) { category in
                    if let items = shoppingItems[category], !items.isEmpty {
                        shoppingCategorySection(category: category, items: items)
                    }
                }

                // Quick actions
                quickActionsSection
            }
            .padding()
        }
    }

    private var recipeInfoCard: some View {
        let stats = calculateStats()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Batch Size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatBatchSize())
                        .font(.title3.bold())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Servings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("~\(stats.servings)")
                        .font(.title3.bold())
                }
            }

            Divider()

            HStack(spacing: 24) {
                StatPill(label: "ABV", value: String(format: "%.1f%%", stats.finalABV))
                StatPill(label: "Brix", value: String(format: "%.1f", stats.finalBrix))
                StatPill(label: "Freeze", value: String(format: "%.0fF", stats.freezingPointFahrenheit))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func shoppingCategorySection(category: IngredientCategory, items: [ShoppingItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.displayName)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ShoppingItemRow(
                        item: item,
                        isChecked: binding(for: category, at: index)
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }

    private func binding(for category: IngredientCategory, at index: Int) -> Binding<Bool> {
        Binding(
            get: {
                shoppingItems[category]?[index].isChecked ?? false
            },
            set: { newValue in
                shoppingItems[category]?[index].isChecked = newValue
            }
        )
    }

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Button {
                copyShoppingList()
            } label: {
                Label("Copy Shopping List", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)

            Button {
                clearAllChecks()
            } label: {
                Label("Clear All Checks", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    // MARK: - Instructions View

    private var instructionsView: some View {
        let stats = calculateStats()

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Overview
                instructionSection(
                    number: 0,
                    title: "Overview",
                    icon: "info.circle.fill"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This recipe makes approximately \(stats.servings) servings.")
                        Text("Total volume: \(String(format: "%.0f oz", stats.totalVolumeOz)) (\(String(format: "%.0f ml", stats.totalVolumeMl))")
                            .foregroundStyle(.secondary)
                    }
                }

                // Step 1: Gather ingredients
                instructionSection(
                    number: 1,
                    title: "Gather Ingredients",
                    icon: "cart.fill"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check the Shopping List tab to ensure you have all ingredients.")
                        Text("Chill liquids before mixing for faster freezing.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                // Step 2: Measure
                instructionSection(
                    number: 2,
                    title: "Measure Ingredients",
                    icon: "ruler.fill"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Measure each ingredient precisely:")

                        ForEach(recipe.ingredients) { recipeIngredient in
                            if let ingredient = database.ingredient(for: recipeIngredient.ingredientId) {
                                HStack {
                                    Text(formatAmount(recipeIngredient.amount, unit: recipeIngredient.unit))
                                        .fontWeight(.medium)
                                    Text(ingredient.name)
                                }
                                .font(.callout)
                            }
                        }
                    }
                }

                // Step 3: Combine
                instructionSection(
                    number: 3,
                    title: "Combine & Mix",
                    icon: "arrow.triangle.merge"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pour all ingredients into a large pitcher or bowl.")
                        Text("Stir well to combine, ensuring any syrups are fully dissolved.")
                        Text("Taste and adjust sweetness if needed.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                // Step 4: Add to machine
                instructionSection(
                    number: 4,
                    title: "Add to Ninja Slushi",
                    icon: "snowflake"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pour the mixture into your Ninja Slushi barrel.")

                        if stats.totalVolumeOz > settingsManager.settings.machineModel.totalCapacity {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("This batch exceeds \(Int(settingsManager.settings.machineModel.totalCapacity))oz (\(settingsManager.settings.machineModel.displayName)). You may need to make multiple batches.")
                            }
                            .font(.callout)
                        } else if stats.totalVolumeOz > settingsManager.settings.machineModel.workingCapacity {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Above the recommended \(Int(settingsManager.settings.machineModel.workingCapacity))oz working capacity. Leave headroom for expansion while freezing.")
                            }
                            .font(.callout)
                        }

                        Text("Fill between MIN and MAX lines.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                // Step 5: Freeze
                instructionSection(
                    number: 5,
                    title: "Freeze",
                    icon: "timer"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Close the lid and select your frozen drink setting.")

                        let freezeTime = estimateFreezeTime(stats: stats)
                        Text("Estimated freeze time: \(freezeTime)")
                            .fontWeight(.medium)

                        Text("The machine will beep when ready. Check consistency and run another cycle if needed.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                // Step 6: Serve
                instructionSection(
                    number: 6,
                    title: "Serve & Enjoy",
                    icon: "wineglass.fill"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dispense into glasses using the built-in spout.")
                        Text("Garnish as desired and serve immediately.")

                        if stats.finalABV > 0 {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                                Text("ABV: \(String(format: "%.1f", stats.finalABV))% - Please drink responsibly")
                            }
                            .font(.callout)
                            .padding(.top, 4)
                        }
                    }
                }

                // Tips section
                tipsSection(stats: stats)
            }
            .padding()
        }
    }

    private func instructionSection(
        number: Int,
        title: String,
        icon: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(number == 0 ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)

                if number == 0 {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                } else {
                    Text("\(number)")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)

                content()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func tipsSection(stats: RecipeStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pro Tips", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 8) {
                tipRow("Pre-chill ingredients for 30 minutes for faster freezing")
                tipRow("If too icy, let it sit 5 minutes and remix")
                tipRow("If too soft, run another freeze cycle")

                if stats.finalBrix < calculator.optimalBrixRange(forABV: stats.finalABV).lowerBound {
                    tipRow("Sugar is below the optimal range for this ABV — texture may be icier")
                }

                if stats.finalABV > 8 {
                    tipRow("Higher alcohol content may require longer freeze time")
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(text)
                .font(.callout)
        }
    }

    // MARK: - Share View

    private var shareView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Preview Card
                sharePreviewCard

                // Share Options
                VStack(spacing: 12) {
                    shareButton(
                        title: "Copy as Text",
                        subtitle: "Copy recipe to clipboard",
                        icon: "doc.on.doc",
                        action: copyAsText
                    )

                    shareButton(
                        title: "Copy Shopping List",
                        subtitle: "Copy ingredients only",
                        icon: "cart",
                        action: copyShoppingList
                    )

                    shareButton(
                        title: "Share Recipe",
                        subtitle: "Share via Messages, Email, etc.",
                        icon: "square.and.arrow.up",
                        action: shareRecipe
                    )

                    shareButton(
                        title: "Export JSON",
                        subtitle: "Export for backup or import",
                        icon: "doc.badge.arrow.up",
                        action: exportJSON
                    )
                }

                // Import Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Import Recipe")
                        .font(.headline)

                    Text("To import a recipe, paste JSON content and tap Import.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button {
                        importFromClipboard()
                    } label: {
                        Label("Import from Clipboard", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    private var sharePreviewCard: some View {
        let stats = calculateStats()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.name)
                    .font(.title3.bold())

                Text("\(recipe.ingredients.count) ingredients | \(String(format: "%.0f oz", stats.totalVolumeOz)) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Label("\(String(format: "%.1f", stats.finalABV))% ABV", systemImage: "drop.fill")
                    Label("\(String(format: "%.1f", stats.finalBrix)) Brix", systemImage: "cube.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func shareButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func buildShoppingItems() {
        var items: [IngredientCategory: [ShoppingItem]] = [:]

        for recipeIngredient in recipe.ingredients {
            if let ingredient = database.ingredient(for: recipeIngredient.ingredientId) {
                let item = ShoppingItem(
                    ingredient: ingredient,
                    recipeIngredient: recipeIngredient
                )
                items[ingredient.category, default: []].append(item)
            }
        }

        shoppingItems = items
    }

    private func copyAsText() {
        let text = serializer.exportToText(
            recipe,
            ingredientLookup: database.lookupFunction()
        )
        UIPasteboard.general.string = text
        confirmationMessage = "Recipe copied to clipboard"
        showingCopyConfirmation = true

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func copyShoppingList() {
        let text = serializer.exportToShoppingList(
            recipe,
            ingredientLookup: database.lookupFunction()
        )
        UIPasteboard.general.string = text
        confirmationMessage = "Recipe copied to clipboard"
        showingCopyConfirmation = true

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func shareRecipe() {
        shareContent = serializer.exportToText(
            recipe,
            ingredientLookup: database.lookupFunction()
        )
        showingShareSheet = true
    }

    private func exportJSON() {
        do {
            let json = try serializer.exportToJSON(
                recipe,
                ingredientLookup: database.lookupFunction()
            )
            UIPasteboard.general.string = json
            confirmationMessage = "Recipe copied to clipboard"
            showingCopyConfirmation = true

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func importFromClipboard() {
        guard let clipboardContent = UIPasteboard.general.string, !clipboardContent.isEmpty else {
            confirmationMessage = "Clipboard is empty — copy a recipe JSON first."
            showingCopyConfirmation = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }

        do {
            let importedRecipe = try serializer.importFromJSON(clipboardContent, ingredientDatabase: database)
            onImportRecipe?(importedRecipe)
            confirmationMessage = "Recipe imported successfully"
            showingCopyConfirmation = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()
        } catch {
            confirmationMessage = "Couldn't import recipe. Check that the clipboard has valid Smart Slushi JSON."
            showingCopyConfirmation = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    private func clearAllChecks() {
        for category in shoppingItems.keys {
            if var items = shoppingItems[category] {
                for index in items.indices {
                    items[index].isChecked = false
                }
                shoppingItems[category] = items
            }
        }
    }

    // MARK: - Helpers

    private var sortedCategories: [IngredientCategory] {
        shoppingItems.keys.sorted { $0.displayName < $1.displayName }
    }

    private func calculateStats() -> RecipeStats {
        calculator.calculateStats(
            for: recipe.ingredients,
            ingredientLookup: database.lookupFunction(),
            servingSizeOz: settingsManager.settings.servingSizeOz
        )
    }

    private func formatBatchSize() -> String {
        let unit = recipe.targetUnit
        // Prefer actual ingredient volume when the recipe has contents
        let volumeOz: Double
        if recipe.ingredients.isEmpty {
            volumeOz = recipe.targetBatchSize
        } else {
            volumeOz = recipe.ingredients.reduce(0.0) { $0 + $1.volumeInOz }
        }
        let volume = MeasurementUnit.oz.convert(volumeOz, to: unit)

        switch unit {
        case .ml:
            return "\(Int(volume)) ml"
        case .cup:
            return String(format: "%.1f cups", volume)
        default:
            return "\(Int(volume.rounded())) oz"
        }
    }

    private func formatAmount(_ amount: Double, unit: MeasurementUnit) -> String {
        if amount == Double(Int(amount)) {
            return "\(Int(amount)) \(unit.abbreviation)"
        } else {
            return String(format: "%.2f %@", amount, unit.abbreviation)
        }
    }

    private func estimateFreezeTime(stats: RecipeStats) -> String {
        // Base time on volume and ABV relative to the user's machine capacity
        let capacity = max(1, settingsManager.settings.machineModel.workingCapacity)
        let volumeFactor = stats.totalVolumeOz / capacity
        let abvFactor = 1.0 + (stats.finalABV / 20.0)  // Higher ABV = longer time

        let baseMinutes = 20.0
        let estimatedMinutes = baseMinutes * volumeFactor * abvFactor

        if estimatedMinutes < 25 {
            return "15-25 minutes"
        } else if estimatedMinutes < 40 {
            return "25-40 minutes"
        } else {
            return "40-60 minutes"
        }
    }
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    let item: ShoppingItem
    @Binding var isChecked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                isChecked.toggle()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.ingredient.name)
            .accessibilityValue(isChecked ? "Checked" : "Unchecked")
            .accessibilityHint("Marks shopping list item")
            .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.ingredient.name)
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(formatOz())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("/")
                        .font(.caption)
                        .foregroundStyle(.quaternary)

                    Text(formatMl())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.ingredient.abv > 0 {
                Text("\(Int(item.ingredient.abv))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func formatOz() -> String {
        let oz = item.recipeIngredient.volumeInOz
        if oz == Double(Int(oz)) {
            return "\(Int(oz)) oz"
        } else {
            return String(format: "%.2f oz", oz)
        }
    }

    private func formatMl() -> String {
        let ml = item.recipeIngredient.volumeInMl
        return "\(Int(ml.rounded())) ml"
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Share Sheet (UIKit Bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    RecipeOutputView(recipe: Recipe(name: "Preview Recipe"))
        .environment(IngredientDatabase.shared)
        .environment(UserSettingsManager.shared)
}
