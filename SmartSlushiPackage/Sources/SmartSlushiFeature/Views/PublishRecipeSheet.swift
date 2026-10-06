import SwiftUI

// MARK: - Publish Recipe Sheet

/// Sheet for publishing a recipe to the community
@available(iOS 17.0, *)
public struct PublishRecipeSheet: View {
    @Environment(SharedRecipeStore.self) private var sharedStore
    @Environment(IngredientDatabase.self) private var database
    @Environment(\.dismiss) private var dismiss

    /// The recipe to publish (in-memory Recipe)
    private let recipe: Recipe?

    /// The saved recipe to publish (from database)
    private let savedRecipe: SavedRecipe?

    @State private var authorNotes: String = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    private let calculator = SlushCalculator()

    /// Initialize with an in-memory Recipe
    public init(recipe: Recipe) {
        self.recipe = recipe
        self.savedRecipe = nil
    }

    /// Initialize with a SavedRecipe from the database
    public init(savedRecipe: SavedRecipe) {
        self.recipe = nil
        self.savedRecipe = savedRecipe
    }

    private var recipeName: String {
        recipe?.name ?? savedRecipe?.name ?? "Untitled"
    }

    private var recipeIngredients: [RecipeIngredient] {
        recipe?.ingredients ?? savedRecipe?.ingredients ?? []
    }

    private var recipeDescription: String? {
        recipe?.description ?? savedRecipe?.recipeDescription
    }

    private var stats: RecipeStats {
        calculator.calculateStats(
            for: recipeIngredients,
            ingredientLookup: database.lookupFunction()
        )
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Recipe preview
                    recipePreviewSection

                    // Stats preview
                    statsPreviewSection

                    // Ingredients preview
                    ingredientsPreviewSection

                    // Author notes
                    authorNotesSection

                    // Guidelines
                    guidelinesSection
                }
                .padding()
            }
            .navigationTitle("Share Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(sharedStore.isPublishing)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        publishRecipe()
                    } label: {
                        if sharedStore.isPublishing {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Publish")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(sharedStore.isPublishing || recipeName.isEmpty || recipeIngredients.isEmpty)
                }
            }
            .interactiveDismissDisabled(sharedStore.isPublishing)
            .alert("Recipe Published!", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your recipe is now available in the community. Other users can view, vote, and import it.")
            }
            .alert("Failed to Publish", isPresented: $showingErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Recipe Preview Section

    private var recipePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recipe Preview", systemImage: "doc.text")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(recipeName)
                    .font(.title2.weight(.semibold))

                if let description = recipeDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Stats Preview Section

    private var statsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)

            HStack(spacing: 16) {
                statItem(title: "ABV", value: String(format: "%.1f%%", stats.finalABV))
                statItem(title: "Brix", value: String(format: "%.1f", stats.finalBrix))
                statItem(title: "Batch", value: formattedBatchSize)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedBatchSize: String {
        let sizeOz = recipe?.targetBatchSize ?? savedRecipe?.targetBatchSize ?? 72
        let unit = recipe?.targetUnit ?? savedRecipe?.targetUnit ?? .oz
        let converted = MeasurementUnit.oz.convert(sizeOz, to: unit)
        switch unit {
        case .ml:
            return "\(Int(converted.rounded())) \(unit.abbreviation)"
        case .cup:
            return String(format: "%.1f %@", converted, unit.abbreviation)
        default:
            return "\(Int(converted.rounded())) \(unit.abbreviation)"
        }
    }

    // MARK: - Ingredients Preview Section

    private var ingredientsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients")
                    .font(.headline)

                Spacer()

                Text("\(recipeIngredients.count) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(recipeIngredients.prefix(5).enumerated()), id: \.offset) { index, ingredient in
                    if let info = database.ingredient(for: ingredient.ingredientId) {
                        HStack {
                            Text(info.name)
                                .font(.subheadline)

                            Spacer()

                            Text("\(formattedAmount(ingredient.amount, unit: ingredient.unit))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)

                        if index < min(4, recipeIngredients.count - 1) {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }

                if recipeIngredients.count > 5 {
                    Text("+ \(recipeIngredients.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func formattedAmount(_ amount: Double, unit: MeasurementUnit) -> String {
        if amount == Double(Int(amount)) {
            return "\(Int(amount)) \(unit.abbreviation)"
        } else {
            return String(format: "%.2f %@", amount, unit.abbreviation)
        }
    }

    // MARK: - Author Notes Section

    private var authorNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Author Notes")
                    .font(.headline)

                Text("Optional - Add tips, variations, or your story behind this recipe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $authorNotes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

            Text("\(authorNotes.count)/500 characters")
                .font(.caption2)
                .foregroundStyle(authorNotes.count > 500 ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Guidelines Section

    private var guidelinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Community Guidelines")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                guidelineItem(icon: "checkmark.circle", text: "Share original or adapted recipes", color: .green)
                guidelineItem(icon: "checkmark.circle", text: "Include helpful tips and notes", color: .green)
                guidelineItem(icon: "xmark.circle", text: "Don't share inappropriate content", color: .red)
                guidelineItem(icon: "xmark.circle", text: "Don't spam or advertise", color: .red)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func guidelineItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)

            Text(text)
        }
    }

    // MARK: - Publishing

    private func publishRecipe() {
        let notes = authorNotes.isEmpty ? nil : String(authorNotes.prefix(500))

        Task {
            do {
                if let recipe = recipe {
                    _ = try await sharedStore.publishRecipe(
                        from: recipe,
                        authorNotes: notes,
                        ingredientLookup: database.lookupFunction(),
                        calculator: calculator
                    )
                } else if let savedRecipe = savedRecipe {
                    _ = try await sharedStore.publishRecipe(
                        from: savedRecipe,
                        authorNotes: notes,
                        ingredientLookup: database.lookupFunction(),
                        calculator: calculator
                    )
                }
                showingSuccessAlert = true
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    PublishRecipeSheet(recipe: Recipe(
        name: "Classic Frozen Margarita",
        description: "A refreshing frozen margarita"
    ))
    .environment(SharedRecipeStore())
    .environment(IngredientDatabase.shared)
}
