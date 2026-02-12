import SwiftUI
import SwiftData

/// Settings screen for app preferences
@available(iOS 17.0, *)
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UserSettingsManager.self) private var settingsManager
    @Environment(RecipeStore.self) private var recipeStore

    @State private var showingResetConfirmation = false
    @State private var showingDeleteDataConfirmation = false
    @State private var showingAbout = false

    public var body: some View {
        NavigationStack {
            List {
                defaultsSection
                servingSizeSection
                machineSection
                displaySection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Reset Settings?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settingsManager.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their defaults. Your saved recipes will not be affected.")
            }
            .alert("Delete All Data?", isPresented: $showingDeleteDataConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all saved recipes. This action cannot be undone.")
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }

    // MARK: - Defaults Section

    private var defaultsSection: some View {
        Section {
            // Default Batch Size
            HStack {
                Text("Default Batch Size")

                Spacer()

                TextField(
                    "Size",
                    value: Binding(
                        get: { settingsManager.settings.defaultBatchSize },
                        set: { settingsManager.setDefaultBatchSize($0) }
                    ),
                    format: .number.precision(.fractionLength(0))
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)

                Text(settingsManager.settings.preferredUnit.abbreviation)
                    .foregroundStyle(.secondary)
            }

            // Preferred Unit
            Picker("Preferred Unit", selection: Binding(
                get: { settingsManager.settings.preferredUnit },
                set: { settingsManager.setPreferredUnit($0) }
            )) {
                Text("Ounces").tag(MeasurementUnit.oz)
                Text("Milliliters").tag(MeasurementUnit.ml)
                Text("Cups").tag(MeasurementUnit.cup)
            }
        } header: {
            Text("Recipe Defaults")
        } footer: {
            Text("These settings will be used for new recipes.")
        }
    }

    // MARK: - Serving Size Section

    private var servingSizeSection: some View {
        Section {
            // Serving Size Picker
            Picker("Serving Size", selection: Binding(
                get: { settingsManager.settings.servingSizeOz },
                set: { settingsManager.setServingSize($0) }
            )) {
                ForEach(UserSettings.servingSizePresets, id: \.sizeOz) { preset in
                    Text(preset.label).tag(preset.sizeOz)
                }
            }

            // Current serving size display
            HStack {
                Text("Volume per Serving")
                Spacer()
                Text("\(Int(settingsManager.settings.servingSizeOz)) oz")
                    .foregroundStyle(.secondary)
            }

            // Servings per batch info
            let machineCapacity = settingsManager.settings.machineModel.workingCapacity
            let servingsPerBatch = Int(machineCapacity / settingsManager.settings.servingSizeOz)
            HStack {
                Text("Servings per Full Batch")
                Spacer()
                Text("\(servingsPerBatch)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Serving Size")
        } footer: {
            Text("Used when calculating how many servings a recipe makes and when scaling by number of people.")
        }
    }

    // MARK: - Machine Section

    private var machineSection: some View {
        Section {
            Picker("Machine Model", selection: Binding(
                get: { settingsManager.settings.machineModel },
                set: { settingsManager.setMachineModel($0) }
            )) {
                ForEach(NinjaSlushiModel.allCases, id: \.self) { model in
                    VStack(alignment: .leading) {
                        Text(model.displayName)
                    }
                    .tag(model)
                }
            }

            HStack {
                Text("Working Capacity")
                Spacer()
                Text("\(Int(settingsManager.settings.machineModel.workingCapacity)) oz")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Freeze Time")
                Spacer()
                let range = settingsManager.settings.machineModel.freezeTimeRange
                Text("\(range.lowerBound)-\(range.upperBound) min")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Ninja Slushi Machine")
        } footer: {
            Text("Select your Ninja Slushi model for accurate capacity recommendations.")
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        Section {
            Toggle("Show Tooltips", isOn: Binding(
                get: { settingsManager.settings.showTooltips },
                set: { settingsManager.setShowTooltips($0) }
            ))

            Button("Show Onboarding Again") {
                settingsManager.resetOnboarding()
                dismiss()
            }
        } header: {
            Text("Display")
        } footer: {
            Text("Tooltips provide helpful explanations for Brix, ABV, and slushability.")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button("Reset Settings to Defaults") {
                showingResetConfirmation = true
            }
            .foregroundStyle(.orange)

            Button("Delete All Saved Recipes") {
                showingDeleteDataConfirmation = true
            }
            .foregroundStyle(.red)
        } header: {
            Text("Data Management")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            Button {
                showingAbout = true
            } label: {
                HStack {
                    Text("About Smart Slushi")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }

            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Actions

    private func deleteAllData() {
        do {
            try modelContext.delete(model: SavedRecipe.self)
            try modelContext.save()
            recipeStore.configure(with: modelContext)
        } catch {
            print("Failed to delete saved recipes: \(error)")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - About View

@available(iOS 17.0, *)
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Name
                    VStack(spacing: 12) {
                        Image(systemName: "snowflake.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)
                            .symbolRenderingMode(.hierarchical)

                        Text("Smart Slushi")
                            .font(.largeTitle.bold())

                        Text("Perfect Frozen Drinks, Every Time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About")
                            .font(.headline)

                        Text("Smart Slushi makes creating Ninja Slushi recipes effortless by handling all the complex Brix and ABV calculations automatically. Just tell us what drink you want, how much, and your taste preferences—we'll give you the exact ingredient amounts for perfect slush every time.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Science Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The Science")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            ScienceRow(
                                icon: "drop.fill",
                                title: "Brix",
                                description: "Sugar content (aim for 13-15)"
                            )

                            ScienceRow(
                                icon: "flame.fill",
                                title: "ABV",
                                description: "Alcohol percentage (keep under 10%)"
                            )

                            ScienceRow(
                                icon: "snowflake",
                                title: "Freezing Point",
                                description: "Must freeze at your machine's temperature"
                            )
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Credits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Credits")
                            .font(.headline)

                        Text("Built with ❤️ for frozen drink enthusiasts everywhere.")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text("Formulas based on research from:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Jeffrey Morgenthaler's cocktail science")
                            Text("• PUNCH Magazine")
                            Text("• Difford's Guide")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Science Row

struct ScienceRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    SettingsView()
        .environment(UserSettingsManager.shared)
        .environment(RecipeStore())
}
