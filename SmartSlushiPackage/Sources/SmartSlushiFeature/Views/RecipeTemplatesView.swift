import SwiftUI

// MARK: - Recipe Templates View

/// Screen displaying available recipe templates that users can start from
@available(iOS 17.0, *)
public struct RecipeTemplatesView: View {
    @Environment(RecipeTemplateStore.self) private var templateStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedCategory: String?

    /// Called when a template is selected
    let onSelectTemplate: (RecipeTemplate) -> Void

    public init(onSelectTemplate: @escaping (RecipeTemplate) -> Void) {
        self.onSelectTemplate = onSelectTemplate
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    categoryFilter
                    templateGrid
                }
                .padding()
            }
            .navigationTitle("Recipe Templates")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryPill(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(templateStore.categories, id: \.id) { category in
                    CategoryPill(
                        title: category.name,
                        icon: nil,
                        emoji: category.icon,
                        isSelected: selectedCategory == category.id
                    ) {
                        selectedCategory = category.id
                    }
                }
            }
        }
    }

    // MARK: - Template Grid

    private var templateGrid: some View {
        let filteredTemplates = getFilteredTemplates()

        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 16
        ) {
            ForEach(filteredTemplates, id: \.id) { template in
                TemplateCard(template: template) {
                    selectTemplate(template)
                }
            }
        }
    }

    // MARK: - Filtering

    private func getFilteredTemplates() -> [RecipeTemplate] {
        var templates = templateStore.templates

        // Filter by category if selected
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            templates = templateStore.search(searchText)
            if let category = selectedCategory {
                templates = templates.filter { $0.category == category }
            }
        }

        return templates
    }

    // MARK: - Actions

    private func selectTemplate(_ template: RecipeTemplate) {
        onSelectTemplate(template)
        dismiss()
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    var icon: String?
    var emoji: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji)
                        .font(.body)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Card

@available(iOS 17.0, *)
struct TemplateCard: View {
    @Environment(RecipeTemplateStore.self) private var templateStore

    let template: RecipeTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Header with category icon
                HStack {
                    Text(templateStore.categoryIcon(for: template.category))
                        .font(.title)

                    Spacer()

                    // ABV and Brix badges
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(String(format: "%.0f", template.baseABV))% ABV")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\(String(format: "%.0f", template.baseBrix)) Brix")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Name
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Description
                if let description = template.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Ingredient count
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("\(template.baseIngredients.count) ingredients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Detail View

@available(iOS 17.0, *)
struct TemplateDetailView: View {
    @Environment(IngredientDatabase.self) private var database
    @Environment(RecipeTemplateStore.self) private var templateStore
    @Environment(\.dismiss) private var dismiss

    let template: RecipeTemplate
    let onUseTemplate: (RecipeTemplate) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                statsSection
                ingredientsSection
                if let notes = template.notes, !notes.isEmpty {
                    notesSection(notes)
                }
                useTemplateButton
            }
            .padding()
        }
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(templateStore.categoryIcon(for: template.category))
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(templateStore.categoryDisplayName(for: template.category))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let flavorProfile = template.flavorProfile {
                        Text(flavorProfile)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let description = template.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expected Stats")
                .font(.headline)

            HStack(spacing: 24) {
                StatItem(label: "ABV", value: String(format: "%.1f%%", template.baseABV))
                StatItem(label: "Brix", value: String(format: "%.1f", template.baseBrix))
                if let dilution = template.dilutionRatio {
                    StatItem(label: "Water", value: "\(Int(dilution * 100))%")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)

            ForEach(template.baseIngredients, id: \.id) { recipeIngredient in
                let ingredient = database.ingredient(for: recipeIngredient.ingredientId)
                HStack {
                    Text(ingredient?.name ?? "Unknown")
                        .font(.body)

                    Spacer()

                    Text("\(String(format: "%.1f", recipeIngredient.amount)) \(recipeIngredient.unit.abbreviation)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                if recipeIngredient.id != template.baseIngredients.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var useTemplateButton: some View {
        Button {
            onUseTemplate(template)
            dismiss()
        } label: {
            Text("Use This Template")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    RecipeTemplatesView { _ in }
        .environment(RecipeTemplateStore.shared)
        .environment(IngredientDatabase.shared)
}
