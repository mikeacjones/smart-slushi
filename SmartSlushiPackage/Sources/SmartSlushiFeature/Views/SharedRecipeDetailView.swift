import SwiftUI

// MARK: - Shared Recipe Detail View

/// Detailed view of a shared recipe with voting and import options
@available(iOS 17.0, *)
public struct SharedRecipeDetailView: View {
    @Environment(SharedRecipeStore.self) private var sharedStore
    @Environment(IngredientDatabase.self) private var database
    @Environment(\.dismiss) private var dismiss

    let recipe: SharedRecipe
    let onImport: (Recipe) -> Void

    @State private var showingReportSheet = false
    @State private var showingReportConfirmation = false
    @State private var selectedReportReason: ReportReason = .inappropriate
    @State private var hasReported = false
    @State private var showingImportConfirmation = false

    public init(recipe: SharedRecipe, onImport: @escaping (Recipe) -> Void) {
        self.recipe = recipe
        self.onImport = onImport
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with voting
                    headerSection

                    // Author notes
                    if let notes = recipe.authorNotes, !notes.isEmpty {
                        authorNotesSection(notes: notes)
                    }

                    // Recipe stats
                    statsSection

                    // Ingredients
                    ingredientsSection

                    // Import button
                    importSection
                }
                .padding()
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showingReportSheet = true
                        } label: {
                            Label("Report Recipe", systemImage: "flag")
                        }
                        .disabled(hasReported)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                hasReported = await sharedStore.hasReported(recipe)
            }
            .sheet(isPresented: $showingReportSheet) {
                reportSheet
            }
            .alert("Recipe Imported", isPresented: $showingImportConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The recipe has been added to your saved recipes.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Large voting controls
            HStack(spacing: 24) {
                Spacer()

                voteButton(isUpvote: true)

                VStack(spacing: 4) {
                    Text("\(recipe.score)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(scoreColor)

                    Text("score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 60)

                voteButton(isUpvote: false)

                Spacer()
            }

            // Vote counts
            HStack(spacing: 24) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(.green)
                    Text("\(recipe.upvoteCount)")
                }
                .font(.subheadline)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.red)
                    Text("\(recipe.downvoteCount)")
                }
                .font(.subheadline)
            }
            .foregroundStyle(.secondary)

            // Published date
            Text("Published \(formattedDate)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func voteButton(isUpvote: Bool) -> some View {
        let voteState = sharedStore.voteState(for: recipe)
        let isActive = isUpvote ? voteState.isUpvoted : voteState.isDownvoted

        Button {
            Task {
                if isUpvote {
                    await sharedStore.toggleUpvote(recipe)
                } else {
                    await sharedStore.toggleDownvote(recipe)
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isUpvote ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(isActive ? (isUpvote ? .green : .red) : .secondary)

                Text(isUpvote ? "Upvote" : "Downvote")
                    .font(.caption2)
                    .foregroundStyle(isActive ? (isUpvote ? .green : .red) : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var scoreColor: Color {
        if recipe.score > 0 { return .green }
        if recipe.score < 0 { return .red }
        return .primary
    }

    // MARK: - Author Notes Section

    private func authorNotesSection(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Author Notes", systemImage: "quote.bubble")
                .font(.headline)

            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe Stats")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard(title: "ABV", value: String(format: "%.1f%%", recipe.finalABV), icon: "drop.fill", color: .blue)
                statCard(title: "Brix", value: String(format: "%.1f", recipe.finalBrix), icon: "cube.fill", color: .orange)
                statCard(title: "Batch Size", value: "\(Int(recipe.targetBatchSize)) \(recipe.targetUnit.abbreviation)", icon: "flask", color: .purple)
                statCard(title: "Ingredients", value: "\(recipe.ingredients.count)", icon: "list.bullet", color: .green)
            }
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.weight(.semibold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ingredient.name)
                                .font(.body)

                            Text(ingredient.category.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(formattedAmount(ingredient))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)

                    if index < recipe.ingredients.count - 1 {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func formattedAmount(_ ingredient: ExportedIngredient) -> String {
        let amount = ingredient.amount
        let unit = ingredient.unit

        if amount == Double(Int(amount)) {
            return "\(Int(amount)) \(unit)"
        } else {
            return String(format: "%.2f %@", amount, unit)
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        VStack(spacing: 12) {
            Button {
                importRecipe()
            } label: {
                Label("Import to My Recipes", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)

            Text("Import this recipe to edit and customize it in your recipe builder.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func importRecipe() {
        let localRecipe = sharedStore.importToPersonal(recipe, database: database)
        onImport(localRecipe)
    }

    // MARK: - Report Sheet

    private var reportSheet: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ReportReason.allCases, id: \.self) { reason in
                        Button {
                            selectedReportReason = reason
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reason.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Text(reason.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedReportReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Why are you reporting this recipe?")
                }
            }
            .navigationTitle("Report Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingReportSheet = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func submitReport() {
        Task {
            do {
                try await sharedStore.reportRecipe(recipe, reason: selectedReportReason)
                hasReported = true
                showingReportSheet = false
            } catch {
                // Show error alert if needed
                print("Failed to submit report: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: recipe.publishedAt, relativeTo: Date())
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    let sampleRecipe = SharedRecipe(
        id: "preview-1",
        authorId: "user-1",
        name: "Classic Frozen Margarita",
        description: "A refreshing frozen margarita perfect for summer",
        authorNotes: "Pro tip: Use fresh lime juice for the best results. Adjust the simple syrup to taste.",
        ingredients: [
            ExportedIngredient(name: "Tequila Blanco", category: "spirit", abv: 40, brix: 0, amount: 2, unit: "oz"),
            ExportedIngredient(name: "Lime Juice", category: "citrus", abv: 0, brix: 8, amount: 1, unit: "oz"),
            ExportedIngredient(name: "Triple Sec", category: "liqueur", abv: 40, brix: 35, amount: 1, unit: "oz"),
            ExportedIngredient(name: "Simple Syrup", category: "sweetener", abv: 0, brix: 65, amount: 0.5, unit: "oz")
        ],
        targetBatchSize: 72,
        targetUnit: .oz,
        publishedAt: Date().addingTimeInterval(-86400),
        updatedAt: Date().addingTimeInterval(-86400),
        finalABV: 8.5,
        finalBrix: 14.2,
        upvoteCount: 42,
        downvoteCount: 3
    )

    SharedRecipeDetailView(recipe: sampleRecipe) { _ in }
        .environment(SharedRecipeStore())
        .environment(IngredientDatabase.shared)
}
