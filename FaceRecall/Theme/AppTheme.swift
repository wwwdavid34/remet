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
    static let emptyPeopleTitle = "Your memory palace awaits"
    static let emptyPeopleSubtitle = "Add your first person and watch the magic happen. Your future self will thank you."

    static let emptyPracticeTitle = "Nothing to quiz... yet"
    static let emptyPracticeSubtitle = "Add some faces first, then come back when your brain's ready for a workout."

    static let emptyEncountersTitle = "No encounters recorded"
    static let emptyEncountersSubtitle = "Every great relationship starts somewhere. Start capturing those moments!"

    // Quiz encouragement
    static let quizGreetings = [
        "Time to flex those brain muscles!",
        "Let's see what you remember...",
        "Your neurons are warming up!",
        "Ready to impress yourself?",
        "Challenge accepted?"
    ]

    static let quizCorrect = [
        "Nailed it!",
        "You're on fire!",
        "Memory champion!",
        "Boom! Got it!",
        "Your brain says thanks!",
        "Look at you go!",
        "Absolutely stellar!",
        "That's the one!",
        "You remembered!",
        "Perfect recall!",
        "Gold star for you!",
        "Crushed it!",
        "Face: recognized!",
        "Neural pathways firing!",
        "Your memory impresses me!",
        "Spot on!",
        "Like a pro!",
        "Mental high-five!",
        "Synapse success!"
    ]

    static let quizIncorrect = [
        "Almost! You'll get it next time.",
        "That's what practice is for!",
        "Learning in progress...",
        "Every miss makes you stronger!",
        "Your brain is taking notes.",
        "Not quite, but you're learning!",
        "Close! Keep at it!",
        "Building those connections...",
        "Memory under construction!",
        "One step closer to mastery!",
        "The neurons are rewiring!",
        "Practice makes progress!",
        "Your brain appreciates the workout!",
        "Feedback received, adjusting...",
        "Next time you'll nail it!",
        "Oops! But hey, now you know!",
        "Adding to the memory bank...",
        "Brain update downloading..."
    ]

    static let sessionComplete80Plus = [
        "Absolutely crushing it!",
        "Your memory is elite!",
        "Future you is impressed!",
        "Memory master status: unlocked!"
    ]

    static let sessionComplete50to80 = [
        "Solid work! Keep building!",
        "Getting better every session!",
        "The neurons are connecting!",
        "Progress looks good on you!"
    ]

    static let sessionCompleteUnder50 = [
        "Every expert was once a beginner!",
        "Rome wasn't built in a day!",
        "You showed up - that's what counts!",
        "Practice makes progress!"
    ]

    // Home screen
    static let reviewNudge = [
        "Your brain requested a workout",
        "Some friendly faces need attention",
        "Time for a quick review sesh?",
        "Your memory muscles are getting restless"
    ]

    static let noReviewsNeeded = [
        "All caught up! You're a star!",
        "Memory inbox: zero. Nice work!",
        "Nothing due - you're ahead of the game!"
    ]

    // Quick capture
    static let captureHints = [
        "Smile! This one's for your memory bank.",
        "Capturing a new connection...",
        "Another face for the collection!"
    ]

    // Random greeting based on time
    static var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning!"
        case 12..<17: return "Good afternoon!"
        case 17..<21: return "Good evening!"
        default: return "Burning the midnight oil?"
        }
    }

    static func random(from array: [String]) -> String {
        array.randomElement() ?? array[0]
    }
}

// MARK: - Custom View Modifiers

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.08),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

struct GradientCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let colors: [Color]

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: colorScheme == .dark ? .clear : colors[0].opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

/// Elevated card style using system backgrounds
struct ElevatedCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: colorScheme == .dark ? .clear : Color.black.opacity(0.06),
                radius: 6,
                x: 0,
                y: 2
            )
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
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
