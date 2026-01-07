import SwiftUI

/// Onboarding page content
struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}

/// Onboarding flow shown on first launch
@available(iOS 17.0, *)
public struct OnboardingView: View {
    @Environment(UserSettingsManager.self) private var settingsManager
    @State private var currentPage = 0
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "snowflake.circle.fill",
            iconColor: .blue,
            title: "Welcome to Smart Slushi",
            subtitle: "Perfect Frozen Drinks Made Easy",
            description: "Create delicious frozen cocktails with your Ninja Slushi machine. We handle all the complex calculations so you get perfect texture every time."
        ),
        OnboardingPage(
            icon: "flask.fill",
            iconColor: .purple,
            title: "The Science Made Simple",
            subtitle: "Brix & ABV Explained",
            description: "Brix measures sugar (aim for 13-15), ABV measures alcohol (keep under 10%). The right balance creates that perfect slush texture—not too icy, not too soupy."
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            iconColor: .orange,
            title: "Auto-Balance Magic",
            subtitle: "One Tap Perfection",
            description: "Add your ingredients, adjust your taste preferences, then tap Auto-Balance. We'll calculate the exact amounts of water and sweetener to hit your targets."
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            iconColor: .green,
            title: "You're Ready!",
            subtitle: "Start Creating",
            description: "Pick a template to start or build your own recipe from scratch. Save your favorites and share them with friends!"
        )
    ]

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom controls
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                // Skip button
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }

    private func completeOnboarding() {
        settingsManager.completeOnboarding()
        onComplete()
    }
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundStyle(page.iconColor)
                .symbolRenderingMode(.hierarchical)

            // Text content
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.headline)
                    .foregroundStyle(page.iconColor)

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Quick Tour Overlay

/// A quick tour shown after onboarding to highlight key features
@available(iOS 17.0, *)
struct QuickTourOverlay: View {
    @Binding var isShowing: Bool
    @State private var currentStep = 0

    private let steps = [
        (title: "Recipe Header", description: "Name your recipe and set the batch size", yOffset: 0.15),
        (title: "Quick Stats", description: "Live ABV and Brix calculations with color indicators", yOffset: 0.28),
        (title: "Ingredients", description: "Tap + to add ingredients, edit amounts, swipe to delete", yOffset: 0.45),
        (title: "Preferences", description: "Adjust sweetness, thickness, and strength to your taste", yOffset: 0.65),
        (title: "Auto-Balance", description: "One tap to optimize your recipe for perfect slush", yOffset: 0.85)
    ]

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    advanceOrDismiss()
                }

            VStack {
                // Spotlight area (simulated)
                GeometryReader { geometry in
                    let step = steps[currentStep]

                    VStack(spacing: 8) {
                        Text(step.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text(step.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        Text("Tap to continue (\(currentStep + 1)/\(steps.count))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * step.yOffset
                    )
                }
            }
        }
        .transition(.opacity)
    }

    private func advanceOrDismiss() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        } else {
            withAnimation {
                isShowing = false
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    OnboardingView {
        print("Onboarding complete")
    }
    .environment(UserSettingsManager.shared)
}
