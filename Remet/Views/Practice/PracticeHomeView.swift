import SwiftUI
import SwiftData

// MARK: - Quiz Mode

enum QuizMode: String, CaseIterable {
    case spaced
    case random
    case troubleFaces

    var localizedName: String {
        switch self {
        case .spaced: return String(localized: "Spaced Review")
        case .random: return String(localized: "Random")
        case .troubleFaces: return String(localized: "Trouble Faces")
        }
    }

    var icon: String {
        switch self {
        case .spaced: return "clock.badge"
        case .random: return "shuffle"
        case .troubleFaces: return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .spaced: return AppColors.teal
        case .random: return AppColors.softPurple
        case .troubleFaces: return AppColors.coral
        }
    }

    var localizedDescription: String {
        switch self {
        case .spaced: return String(localized: "Due for review")
        case .random: return String(localized: "Mix it up")
        case .troubleFaces: return String(localized: "Need more practice")
        }
    }
}

struct PracticeHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]
    @State private var showingQuiz = false
    @State private var selectedMode: QuizMode = .spaced

    private var peopleWithFaces: [Person] {
        people.filter { !$0.embeddings.isEmpty && !$0.isMe }
    }

    private var peopleNeedingReview: [Person] {
        peopleWithFaces.filter { $0.needsReview }
    }

    private var troubleFaces: [Person] {
        peopleWithFaces.filter { person in
            guard let srData = person.spacedRepetitionData else { return false }
            return srData.totalAttempts >= 2 && srData.accuracy < 0.6
        }.sorted { p1, p2 in
            (p1.spacedRepetitionData?.accuracy ?? 1) < (p2.spacedRepetitionData?.accuracy ?? 1)
        }
    }

    private func peopleForMode(_ mode: QuizMode) -> [Person] {
        switch mode {
        case .spaced:
            return peopleNeedingReview.isEmpty ? peopleWithFaces : peopleNeedingReview
        case .random:
            return peopleWithFaces.shuffled()
        case .troubleFaces:
            return troubleFaces.isEmpty ? peopleWithFaces : troubleFaces
        }
    }

    private func countForMode(_ mode: QuizMode) -> Int {
        switch mode {
        case .spaced:
            return peopleNeedingReview.isEmpty ? peopleWithFaces.count : peopleNeedingReview.count
        case .random:
            return peopleWithFaces.count
        case .troubleFaces:
            return troubleFaces.count
        }
    }

    private var totalAttempts: Int {
        people.reduce(0) { $0 + ($1.spacedRepetitionData?.totalAttempts ?? 0) }
    }

    private var totalCorrect: Int {
        people.reduce(0) { $0 + ($1.spacedRepetitionData?.correctAttempts ?? 0) }
    }

    private var overallAccuracy: Double {
        totalAttempts > 0 ? Double(totalCorrect) / Double(totalAttempts) : 0
    }

    /// Calculate accuracy trend compared to previous week
    private var weeklyTrend: Int? {
        let calendar = Calendar.current
        let now = Date()
        guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) else {
            return nil
        }

        // Get all quiz attempts
        let allAttempts = people.flatMap { $0.quizAttempts }

        // This week's attempts
        let thisWeekAttempts = allAttempts.filter { $0.attemptedAt >= oneWeekAgo }
        let thisWeekCorrect = thisWeekAttempts.filter { $0.wasCorrect }.count
        let thisWeekTotal = thisWeekAttempts.count

        // Last week's attempts
        let lastWeekAttempts = allAttempts.filter { $0.attemptedAt >= twoWeeksAgo && $0.attemptedAt < oneWeekAgo }
        let lastWeekCorrect = lastWeekAttempts.filter { $0.wasCorrect }.count
        let lastWeekTotal = lastWeekAttempts.count

        // Need at least some attempts in both weeks
        guard thisWeekTotal >= 3, lastWeekTotal >= 3 else { return nil }

        let thisWeekAccuracy = Double(thisWeekCorrect) / Double(thisWeekTotal)
        let lastWeekAccuracy = Double(lastWeekCorrect) / Double(lastWeekTotal)

        let difference = Int((thisWeekAccuracy - lastWeekAccuracy) * 100)

        // Only show if meaningful change
        return abs(difference) >= 2 ? difference : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Motivational Header
                    if !peopleWithFaces.isEmpty {
                        VStack(spacing: 8) {
                            Text(WittyCopy.random(from: WittyCopy.quizGreetings))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)

                            if totalAttempts > 0 {
                                Text("You've practiced \(totalAttempts) times with \(Int(overallAccuracy * 100))% accuracy")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // Stats Overview
                    HStack(spacing: 12) {
                        PracticeStatCard(
                            value: peopleNeedingReview.isEmpty ? "✓" : "\(peopleNeedingReview.count)",
                            label: peopleNeedingReview.isEmpty ? "All Caught Up" : "Due Today",
                            icon: peopleNeedingReview.isEmpty ? "checkmark.circle.fill" : "clock.badge",
                            color: peopleNeedingReview.isEmpty ? AppColors.success : AppColors.warning
                        )

                        PracticeStatCard(
                            value: totalAttempts > 0 ? "\(Int(overallAccuracy * 100))%" : "-",
                            label: "Accuracy",
                            icon: "target",
                            color: overallAccuracy >= 0.8 ? AppColors.success : (overallAccuracy >= 0.5 ? AppColors.warning : AppColors.coral),
                            trend: weeklyTrend
                        )

                        PracticeStatCard(
                            value: "\(masteredCount)",
                            label: "Mastered",
                            icon: "star.fill",
                            color: AppColors.softPurple
                        )
                    }
                    .padding(.horizontal)

                    // Quiz Mode Selection
                    if !peopleWithFaces.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose Your Challenge")
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(spacing: 10) {
                                // Spaced Review with Recommended badge
                                QuizModeButton(
                                    mode: .spaced,
                                    count: countForMode(.spaced),
                                    isDisabled: false,
                                    isRecommended: true
                                ) {
                                    selectedMode = .spaced
                                    showingQuiz = true
                                }

                                // Random mode
                                QuizModeButton(
                                    mode: .random,
                                    count: countForMode(.random),
                                    isDisabled: false
                                ) {
                                    selectedMode = .random
                                    showingQuiz = true
                                }
                            }
                            .padding(.horizontal)

                            Text("Spaced repetition helps cement faces in long-term memory")
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)
                                .italic()
                                .padding(.horizontal)
                        }

                        // Trouble Faces section - only shown when there are struggling faces
                        if !troubleFaces.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(AppColors.coral)
                                        Text("Extra Practice Needed")
                                            .font(.headline)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)

                                Text("These \(troubleFaces.count) faces need more attention — you've got this!")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .padding(.horizontal)

                                Button {
                                    selectedMode = .troubleFaces
                                    showingQuiz = true
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.coral.opacity(0.15))
                                                .frame(width: 44, height: 44)

                                            Image(systemName: "bolt.heart.fill")
                                                .font(.title3)
                                                .foregroundStyle(AppColors.coral)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Focus Practice")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(AppColors.textPrimary)

                                            Text("Drill the tricky ones")
                                                .font(.caption)
                                                .foregroundStyle(AppColors.textSecondary)
                                        }

                                        Spacer()

                                        Text("\(troubleFaces.count)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.coral)
                                            .clipShape(Capsule())

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textMuted)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(AppColors.cardBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(AppColors.coral.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: AppColors.coral.opacity(0.1), radius: 6, x: 0, y: 3)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }

                    // People Due Section
                    if !peopleNeedingReview.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.crop.circle.badge.clock")
                                        .foregroundStyle(AppColors.warning)
                                    Text("Ready for Review")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)

                            LazyVStack(spacing: 10) {
                                ForEach(peopleNeedingReview.sorted { p1, p2 in
                                    (p1.spacedRepetitionData?.nextReviewDate ?? .distantPast) < (p2.spacedRepetitionData?.nextReviewDate ?? .distantPast)
                                }) { person in
                                    NavigationLink {
                                        PersonDetailView(person: person)
                                    } label: {
                                        ReviewPersonRow(person: person)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Empty State
                    if peopleWithFaces.isEmpty {
                        EmptyStateView(
                            icon: "brain.head.profile",
                            title: WittyCopy.emptyPracticeTitle,
                            subtitle: WittyCopy.emptyPracticeSubtitle
                        )
                        .padding(.top, 20)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .statusBarFade()
            .navigationTitle("Practice")
            .fullScreenCover(isPresented: $showingQuiz) {
                FaceQuizView(
                    people: peopleForMode(selectedMode),
                    mode: selectedMode
                )
            }
        }
    }

    private var masteredCount: Int {
        peopleWithFaces.filter { person in
            guard let srData = person.spacedRepetitionData else { return false }
            return srData.accuracy >= 0.8 && srData.totalAttempts >= 3
        }.count
    }
}

// MARK: - Supporting Views

struct PracticeStatCard: View {
    let value: String
    let label: LocalizedStringKey
    let icon: String
    let color: Color
    var trend: Int? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(abs(trend))% this week")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(trend > 0 ? AppColors.success : AppColors.coral)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 3)
    }
}

struct ReviewPersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            // Face thumbnail
            ZStack {
                if let embedding = person.embeddings.first,
                   let uiImage = UIImage(data: embedding.faceCropData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.coral.opacity(0.3), AppColors.teal.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.white)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)

                if let srData = person.spacedRepetitionData {
                    HStack(spacing: 8) {
                        if srData.daysUntilReview < 0 {
                            Label(String(localized: "\(abs(srData.daysUntilReview))d overdue"), systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(AppColors.warning)
                        } else if srData.daysUntilReview == 0 {
                            Label(String(localized: "Due today"), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(AppColors.warning)
                        }

                        if srData.totalAttempts > 0 {
                            Text("\(Int(srData.accuracy * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(srData.accuracy >= 0.8 ? AppColors.success : AppColors.textSecondary)
                        }
                    }
                } else {
                    Label(String(localized: "New face - never practiced"), systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppColors.teal)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct QuizModeButton: View {
    let mode: QuizMode
    let count: Int
    let isDisabled: Bool
    var isRecommended: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: mode.icon)
                        .font(.title3)
                        .foregroundStyle(mode.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.localizedName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 6) {
                        Text(mode.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        if isRecommended {
                            Text("Best for learning")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.success)
                        }
                    }
                }

                Spacer()

                if count > 0 || mode == .random {
                    Text(mode == .troubleFaces && count == 0 ? "None" : "\(count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(mode.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(mode.color.opacity(0.1))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    PracticeHomeView()
        .modelContainer(for: [Person.self], inMemory: true)
}
