import SwiftUI

// MARK: - App Colors

enum AppColors {
    // Primary palette - warm and friendly
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)       // #FF6B6B
    static let teal = Color(red: 0.31, green: 0.80, blue: 0.77)       // #4ECDC4
    static let warmYellow = Color(red: 1.0, green: 0.90, blue: 0.55)  // #FFE66D
    static let softPurple = Color(red: 0.58, green: 0.44, blue: 0.86) // #9370DB

    // Backgrounds
    static let warmBackground = Color(red: 0.99, green: 0.97, blue: 0.95)  // Warm cream
    static let cardBackground = Color.white

    // Semantic colors
    static let primary = coral
    static let secondary = teal
    static let accent = warmYellow
    static let success = Color(red: 0.4, green: 0.8, blue: 0.5)       // Soft green
    static let warning = Color(red: 1.0, green: 0.7, blue: 0.3)       // Warm orange

    // Gradients
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
        "Your brain says thanks!"
    ]

    static let quizIncorrect = [
        "Almost! You'll get it next time.",
        "That's what practice is for!",
        "Learning in progress...",
        "Every miss makes you stronger!",
        "Your brain is taking notes."
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
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct GradientCard: ViewModifier {
    let colors: [Color]

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: colors[0].opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
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
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.coral, AppColors.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

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
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppColors.primaryGradient)
                        .clipShape(Capsule())
                }
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
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
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
