import SwiftUI
import UIKit

// MARK: - App Colors

enum AppColors {
    // MARK: - Brand Colors (Adaptive for Dark Mode)

    /// Primary brand color - coral/salmon
    static let coral = Color(
        light: Color(red: 1.0, green: 0.42, blue: 0.42),      // #FF6B6B
        dark: Color(red: 1.0, green: 0.50, blue: 0.50)        // Slightly brighter for dark mode
    )

    /// Secondary brand color - teal
    static let teal = Color(
        light: Color(red: 0.31, green: 0.80, blue: 0.77),     // #4ECDC4
        dark: Color(red: 0.40, green: 0.85, blue: 0.82)       // Slightly brighter for dark mode
    )

    /// Accent color - warm yellow
    static let warmYellow = Color(
        light: Color(red: 1.0, green: 0.90, blue: 0.55),      // #FFE66D
        dark: Color(red: 1.0, green: 0.85, blue: 0.45)        // Adjusted for dark mode
    )

    /// Soft purple accent
    static let softPurple = Color(
        light: Color(red: 0.58, green: 0.44, blue: 0.86),     // #9370DB
        dark: Color(red: 0.68, green: 0.54, blue: 0.92)       // Brighter for dark mode
    )

    // MARK: - Semantic Text Colors (Use System Colors)

    /// Primary text - use for main content
    static var textPrimary: Color { .primary }

    /// Secondary text - use for subtitles, captions
    static var textSecondary: Color { .secondary }

    /// Muted text - use for disabled, tertiary content
    static var textMuted: Color { Color(UIColor.tertiaryLabel) }

    // MARK: - Background Colors (Use System Backgrounds)

    /// Primary background
    static var background: Color { Color(UIColor.systemBackground) }

    /// Grouped background (for lists, settings)
    static var groupedBackground: Color { Color(UIColor.systemGroupedBackground) }

    /// Card/elevated surface background
    static var cardBackground: Color { Color(UIColor.secondarySystemBackground) }

    /// Nested content within cards
    static var tertiaryBackground: Color { Color(UIColor.tertiarySystemBackground) }

    // MARK: - Semantic Action Colors

    /// Primary action color
    static var primary: Color { coral }

    /// Secondary action color
    static var secondary: Color { teal }

    /// Accent color for highlights
    static var accent: Color { warmYellow }

    /// Success state - using system green for accessibility
    static var success: Color { .green }

    /// Warning state - using system orange for accessibility
    static var warning: Color { .orange }

    /// Error/destructive state
    static var error: Color { .red }

    // MARK: - Gradients

    static let primaryGradient = LinearGradient(
        colors: [coral, coral.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let tealGradient = LinearGradient(
        colors: [teal, teal.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [coral.opacity(0.1), teal.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Legacy Support (for gradual migration)

    /// Card shadow - use sparingly, prefer elevation in dark mode
    static var cardShadow: Color { Color.black.opacity(0.06) }
}

// MARK: - Adaptive Color Extension

extension Color {
    /// Creates a color that adapts to light/dark mode
    init(light: Color, dark: Color) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Witty Copy

enum WittyCopy {
    // Empty states
    static var emptyPeopleTitle: String { String(localized: "Your memory palace awaits") }
    static var emptyPeopleSubtitle: String { String(localized: "Add your first person and watch the magic happen. Your future self will thank you.") }

    static var emptyPracticeTitle: String { String(localized: "Nothing to quiz... yet") }
    static var emptyPracticeSubtitle: String { String(localized: "Add some faces first, then come back when your brain's ready for a workout.") }

    static var emptyEncountersTitle: String { String(localized: "No encounters recorded") }
    static var emptyEncountersSubtitle: String { String(localized: "Every great relationship starts somewhere. Start capturing those moments!") }

    // Quiz encouragement
    static var quizGreetings: [String] { [
        String(localized: "Time to flex those brain muscles!"),
        String(localized: "Let's see what you remember..."),
        String(localized: "Your neurons are warming up!"),
        String(localized: "Ready to impress yourself?"),
        String(localized: "Challenge accepted?")
    ] }

    static var quizCorrect: [String] { [
        String(localized: "Nailed it!"),
        String(localized: "You're on fire!"),
        String(localized: "Memory champion!"),
        String(localized: "Boom! Got it!"),
        String(localized: "Your brain says thanks!"),
        String(localized: "Look at you go!"),
        String(localized: "Absolutely stellar!"),
        String(localized: "That's the one!"),
        String(localized: "You remembered!"),
        String(localized: "Perfect recall!"),
        String(localized: "Gold star for you!"),
        String(localized: "Crushed it!"),
        String(localized: "Face: recognized!"),
        String(localized: "Neural pathways firing!"),
        String(localized: "Your memory impresses me!"),
        String(localized: "Spot on!"),
        String(localized: "Like a pro!"),
        String(localized: "Mental high-five!"),
        String(localized: "Synapse success!")
    ] }

    static var quizIncorrect: [String] { [
        String(localized: "Almost! You'll get it next time."),
        String(localized: "That's what practice is for!"),
        String(localized: "Learning in progress..."),
        String(localized: "Every miss makes you stronger!"),
        String(localized: "Your brain is taking notes."),
        String(localized: "Not quite, but you're learning!"),
        String(localized: "Close! Keep at it!"),
        String(localized: "Building those connections..."),
        String(localized: "Memory under construction!"),
        String(localized: "One step closer to mastery!"),
        String(localized: "The neurons are rewiring!"),
        String(localized: "Practice makes progress!"),
        String(localized: "Your brain appreciates the workout!"),
        String(localized: "Feedback received, adjusting..."),
        String(localized: "Next time you'll nail it!"),
        String(localized: "Oops! But hey, now you know!"),
        String(localized: "Adding to the memory bank..."),
        String(localized: "Brain update downloading...")
    ] }

    static var sessionComplete80Plus: [String] { [
        String(localized: "Absolutely crushing it!"),
        String(localized: "Your memory is elite!"),
        String(localized: "Future you is impressed!"),
        String(localized: "Memory master status: unlocked!")
    ] }

    static var sessionComplete50to80: [String] { [
        String(localized: "Solid work! Keep building!"),
        String(localized: "Getting better every session!"),
        String(localized: "The neurons are connecting!"),
        String(localized: "Progress looks good on you!")
    ] }

    static var sessionCompleteUnder50: [String] { [
        String(localized: "Every expert was once a beginner!"),
        String(localized: "Rome wasn't built in a day!"),
        String(localized: "You showed up - that's what counts!"),
        String(localized: "Practice makes progress!")
    ] }

    // Home screen
    static var reviewNudge: [String] { [
        String(localized: "Your brain requested a workout"),
        String(localized: "Some friendly faces need attention"),
        String(localized: "Time for a quick review sesh?"),
        String(localized: "Your memory muscles are getting restless")
    ] }

    static var noReviewsNeeded: [String] { [
        String(localized: "All caught up! You're a star!"),
        String(localized: "Memory inbox: zero. Nice work!"),
        String(localized: "Nothing due - you're ahead of the game!")
    ] }

    // Quick capture
    static var captureHints: [String] { [
        String(localized: "Smile! This one's for your memory bank."),
        String(localized: "Capturing a new connection..."),
        String(localized: "Another face for the collection!")
    ] }

    // Random greeting based on time
    static var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "Good morning!")
        case 12..<17: return String(localized: "Good afternoon!")
        case 17..<21: return String(localized: "Good evening!")
        default: return String(localized: "Burning the midnight oil?")
        }
    }

    static func random(from array: [String]) -> String {
        array.randomElement() ?? array[0]
    }
}

// MARK: - Custom View Modifiers

/// Standard card style - uses liquid glass on iOS 26+, material on earlier versions
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.thinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35),
                                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.08),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

/// Gradient card with glass overlay effect
struct GradientCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let colors: [Color]

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    // Glass overlay for depth
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial.opacity(0.3))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: colorScheme == .dark ? colors[0].opacity(0.2) : colors[0].opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

/// Elevated card style - uses glass effect for elevation
struct ElevatedCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.1),
                radius: 10,
                x: 0,
                y: 5
            )
    }
}

/// Subtle card for inline content - minimal glass effect
struct SubtleCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2),
                        lineWidth: 0.5
                    )
            }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func elevatedCard() -> some View {
        modifier(ElevatedCardStyle())
    }

    func gradientCard(colors: [Color]) -> some View {
        modifier(GradientCard(colors: colors))
    }

    func subtleCard() -> some View {
        modifier(SubtleCardStyle())
    }
}

// MARK: - Reusable Components

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppColors.coral)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.coral)
                .controlSize(.large)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 40)
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            color.opacity(0.3),
                            Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "brain.head.profile",
        title: WittyCopy.emptyPracticeTitle,
        subtitle: WittyCopy.emptyPracticeSubtitle,
        actionTitle: "Add Someone",
        action: {}
    )
}

#Preview("Stat Badge") {
    HStack {
        StatBadge(value: "12", label: "People", color: AppColors.coral)
        StatBadge(value: "87%", label: "Accuracy", color: AppColors.teal)
    }
    .padding()
}
