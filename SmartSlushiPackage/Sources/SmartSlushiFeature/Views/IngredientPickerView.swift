import SwiftUI

// MARK: - Ingredient Picker View

/// A searchable, categorized view for selecting ingredients
@available(iOS 17.0, *)
public struct IngredientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(IngredientDatabase.self) private var database

    @State private var searchText = ""
    @State private var selectedCategory: IngredientCategory?

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
                        // TODO: Navigate to custom ingredient creation
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search ingredients")
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
                        ForEach(database.ingredients(in: category)) { ingredient in
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
        let usedCategories = Set(database.ingredients.map { $0.category })
        return IngredientCategory.allCases.filter { usedCategories.contains($0) }
    }

    // MARK: - Actions

    private func selectIngredient(_ ingredient: Ingredient) {
        onSelect(ingredient)
        dismiss()
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
                    Text(ingredient.name)
                        .font(.body)
                        .foregroundStyle(.primary)

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
