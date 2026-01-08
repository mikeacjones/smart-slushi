import SwiftUI

// MARK: - Recipe Filter Sheet

/// Sheet for filtering community recipes by alcohol type and ABV range
@available(iOS 17.0, *)
struct RecipeFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: RecipeFilter

    var body: some View {
        NavigationStack {
            Form {
                alcoholTypeSection
                abvRangeSection

                if filter.hasActiveFilters {
                    resetSection
                }
            }
            .navigationTitle("Filter Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Alcohol Type Section

    private var alcoholTypeSection: some View {
        Section {
            ForEach(RecipeFilter.filterableCategories, id: \.self) { category in
                Button {
                    toggleCategory(category)
                } label: {
                    HStack {
                        Label(category.displayName, systemImage: iconForCategory(category))
                            .foregroundStyle(.primary)

                        Spacer()

                        if filter.alcoholCategories.contains(category) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        } header: {
            Text("Alcohol Type")
        } footer: {
            Text("Show recipes containing selected alcohol types. Select multiple to expand results.")
        }
    }

    private func toggleCategory(_ category: IngredientCategory) {
        if filter.alcoholCategories.contains(category) {
            filter.alcoholCategories.remove(category)
        } else {
            filter.alcoholCategories.insert(category)
        }
    }

    private func iconForCategory(_ category: IngredientCategory) -> String {
        switch category {
        case .spirit: return "flame"
        case .liqueur: return "drop.triangle"
        case .wine: return "wineglass"
        case .beer: return "mug"
        default: return "drop"
        }
    }

    // MARK: - ABV Range Section

    private var abvRangeSection: some View {
        Section {
            ForEach(RecipeFilter.ABVPreset.allCases, id: \.self) { preset in
                Button {
                    toggleABVPreset(preset)
                } label: {
                    HStack {
                        Label(preset.rawValue, systemImage: preset.icon)
                            .foregroundStyle(.primary)

                        Spacer()

                        if filter.abvRange == preset.range {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        } header: {
            Text("ABV Range")
        } footer: {
            Text("Filter recipes by their final alcohol content.")
        }
    }

    private func toggleABVPreset(_ preset: RecipeFilter.ABVPreset) {
        if filter.abvRange == preset.range {
            filter.abvRange = nil
        } else {
            filter.abvRange = preset.range
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                withAnimation {
                    filter.reset()
                }
            } label: {
                HStack {
                    Spacer()
                    Label("Reset All Filters", systemImage: "xmark.circle")
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    @Previewable @State var filter = RecipeFilter()

    RecipeFilterSheet(filter: $filter)
}
