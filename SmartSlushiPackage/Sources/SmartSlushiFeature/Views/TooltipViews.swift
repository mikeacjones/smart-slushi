import SwiftUI

// MARK: - Tooltip Content

/// Defines the content for educational tooltips
enum TooltipContent: String, CaseIterable, Identifiable {
    case brix
    case abv
    case slushability
    case freezingPoint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brix: return "What is Brix?"
        case .abv: return "What is ABV?"
        case .slushability: return "Slushability"
        case .freezingPoint: return "Freezing Point"
        }
    }

    var icon: String {
        switch self {
        case .brix: return "drop.fill"
        case .abv: return "flame.fill"
        case .slushability: return "snowflake"
        case .freezingPoint: return "thermometer.snowflake"
        }
    }

    var iconColor: Color {
        switch self {
        case .brix: return .purple
        case .abv: return .orange
        case .slushability: return .blue
        case .freezingPoint: return .cyan
        }
    }

    var explanation: String {
        switch self {
        case .brix:
            return "Brix measures the sugar content of your drink as a percentage by weight. For perfect slush texture, aim for 13-15 Brix."

        case .abv:
            return "ABV (Alcohol By Volume) measures the alcohol percentage. Keep it under 10% for proper freezing—higher alcohol prevents slush formation."

        case .slushability:
            return "Slushability indicates whether your recipe will freeze properly. A balanced recipe needs the right combination of sugar and alcohol."

        case .freezingPoint:
            return "Alcohol lowers the freezing point. Your Ninja Slushi operates around -6°C to -10°C. If the freezing point is too low, it won't freeze."
        }
    }

    var targetRange: String {
        switch self {
        case .brix: return "Target: 13-15 Brix"
        case .abv: return "Target: 0-10% ABV"
        case .slushability: return "Optimal when green"
        case .freezingPoint: return "Above -9°C"
        }
    }

    var tips: [String] {
        switch self {
        case .brix:
            return [
                "Too low = icy/hard texture",
                "Too high = soupy/won't freeze",
                "Cold suppresses sweetness—frozen drinks need more sugar than cocktails"
            ]

        case .abv:
            return [
                "Above 10% = soft or won't freeze",
                "Above 12% = won't form slush at all",
                "Add water to reduce ABV"
            ]

        case .slushability:
            return [
                "Green = Perfect slush texture",
                "Yellow = May have issues",
                "Red = Won't freeze properly"
            ]

        case .freezingPoint:
            return [
                "Formula: -0.4°C × ABV%",
                "10% ABV = -4°C freezing point",
                "Lower = harder to freeze"
            ]
        }
    }
}

// MARK: - Tooltip View

/// A modal view that explains a concept
@available(iOS 17.0, *)
struct TooltipView: View {
    let content: TooltipContent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with icon
                    VStack(spacing: 12) {
                        Image(systemName: content.icon)
                            .font(.system(size: 56))
                            .foregroundStyle(content.iconColor)

                        Text(content.title)
                            .font(.title.bold())

                        Text(content.targetRange)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(content.iconColor.opacity(0.15))
                            .foregroundStyle(content.iconColor)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 20)

                    // Main explanation
                    Text(content.explanation)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    // Tips section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Tips")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(content.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)

                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
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
        .presentationDetents([.medium])
    }
}

// MARK: - Info Button

/// A small info button that shows a tooltip when tapped
@available(iOS 17.0, *)
struct TooltipButton: View {
    let content: TooltipContent
    @State private var showingTooltip = false
    @Environment(UserSettingsManager.self) private var settingsManager

    var body: some View {
        if settingsManager.settings.showTooltips {
            Button {
                showingTooltip = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingTooltip) {
                TooltipView(content: content)
            }
        }
    }
}

// MARK: - Inline Tooltip Label

/// A label with an optional tooltip info button
@available(iOS 17.0, *)
struct TooltipLabel: View {
    let text: String
    let tooltip: TooltipContent?
    var font: Font = .caption
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(font)
                .foregroundStyle(color)

            if let tooltip {
                TooltipButton(content: tooltip)
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Brix Tooltip") {
    TooltipView(content: .brix)
}

@available(iOS 17.0, *)
#Preview("ABV Tooltip") {
    TooltipView(content: .abv)
}

@available(iOS 17.0, *)
#Preview("Tooltip Button") {
    TooltipButton(content: .slushability)
        .environment(UserSettingsManager.shared)
}
