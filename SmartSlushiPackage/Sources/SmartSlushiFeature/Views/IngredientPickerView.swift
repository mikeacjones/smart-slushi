import SwiftUI

// MARK: - Ingredient Picker View

/// A searchable, categorized view for selecting ingredients
@available(iOS 17.0, *)
public struct IngredientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(IngredientDatabase.self) private var database

    @State private var searchText = ""
    @State private var selectedCategory: IngredientCategory?
    @State private var showingCustomIngredient = false

    let onSelect: (Ingredient) -> Void

    public init(onSelect: @escaping (Ingredient) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilter
                ingredientList
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCustomIngredient = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create custom ingredient")
                }
            }
            .searchable(text: $searchText, prompt: "Search ingredients")
            .sheet(isPresented: $showingCustomIngredient) {
                CustomIngredientSheet { ingredient in
                    database.addCustomIngredient(ingredient)
                    selectIngredient(ingredient)
                }
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation {
                        selectedCategory = nil
                    }
                }

                ForEach(IngredientCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGray6))
    }

    // MARK: - Ingredient List

    private var ingredientList: some View {
        List {
            // Recent ingredients section
            if !database.recentIngredients.isEmpty && searchText.isEmpty && selectedCategory == nil {
                Section("Recent") {
                    ForEach(database.recentIngredients.prefix(5)) { ingredient in
                        IngredientListRow(ingredient: ingredient) {
                            selectIngredient(ingredient)
                        }
                    }
                }
            }

            // Custom ingredients
            if !database.customIngredients.isEmpty && searchText.isEmpty && selectedCategory == nil {
                Section("Custom") {
                    ForEach(database.customIngredients) { ingredient in
                        IngredientListRow(ingredient: ingredient) {
                            selectIngredient(ingredient)
                        }
                    }
                }
            }

            // Filtered ingredients
            if selectedCategory != nil || !searchText.isEmpty {
                ForEach(filteredIngredients) { ingredient in
                    IngredientListRow(ingredient: ingredient) {
                        selectIngredient(ingredient)
                    }
                }
            } else {
                // Group by category when showing all
                ForEach(categoriesWithIngredients, id: \.self) { category in
                    Section(category.displayName) {
                        ForEach(database.ingredients(in: category).filter { !$0.isCustom }) { ingredient in
                            IngredientListRow(ingredient: ingredient) {
                                selectIngredient(ingredient)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Computed Properties

    private var filteredIngredients: [Ingredient] {
        var ingredients = database.ingredients

        // Filter by category if selected
        if let category = selectedCategory {
            ingredients = ingredients.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            ingredients = ingredients.filter { $0.name.lowercased().contains(query) }
        }

        return ingredients.sorted { $0.name < $1.name }
    }

    private var categoriesWithIngredients: [IngredientCategory] {
        let usedCategories = Set(database.ingredients.filter { !$0.isCustom }.map { $0.category })
        return IngredientCategory.allCases.filter { usedCategories.contains($0) }
    }

    // MARK: - Actions

    private func selectIngredient(_ ingredient: Ingredient) {
        onSelect(ingredient)
        dismiss()
    }
}

// MARK: - Custom Ingredient Sheet

@available(iOS 17.0, *)
struct CustomIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: IngredientCategory = .misc
    @State private var abv: Double = 0
    @State private var brix: Double = 0
    @State private var notes = ""

    let onSave: (Ingredient) -> Void

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && abv >= 0 && abv <= 100
            && brix >= 0 && brix <= 100
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $category) {
                        ForEach(IngredientCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("ABV %")
                        Spacer()
                        TextField("0", value: $abv, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Text("Brix")
                        Spacer()
                        TextField("0", value: $brix, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                } header: {
                    Text("Composition")
                } footer: {
                    Text("ABV is alcohol by volume (0–100%). Brix is sugar content (0–100). Use label values when available.")
                }

                Section("Notes (optional)") {
                    TextField("e.g. brand or dilution", text: $notes)
                }
            }
            .navigationTitle("Custom Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let ingredient = Ingredient(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            abv: min(100, max(0, abv)),
                            brix: min(100, max(0, brix)),
                            isCustom: true,
                            notes: notes.isEmpty ? nil : notes
                        )
                        onSave(ingredient)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Ingredient List Row

struct IngredientListRow: View {
    let ingredient: Ingredient
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(ingredient.name)
                            .font(.body)
                            .foregroundStyle(.primary)

                        if ingredient.isCustom {
                            Text("Custom")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 12) {
                        if ingredient.abv > 0 {
                            Label("\(Int(ingredient.abv))% ABV", systemImage: "drop.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if ingredient.brix > 0 {
                            Label("\(Int(ingredient.brix)) Brix", systemImage: "cube.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .labelStyle(CompactLabelStyle())
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Label Style

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .imageScale(.small)
            configuration.title
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    IngredientPickerView { ingredient in
        print("Selected: \(ingredient.name)")
    }
    .environment(IngredientDatabase.shared)
}
