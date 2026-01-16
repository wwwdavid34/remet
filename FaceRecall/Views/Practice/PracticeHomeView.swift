import SwiftUI
import SwiftData

// MARK: - Quiz Mode

enum QuizMode: String, CaseIterable {
    case spaced = "Spaced Review"
    case random = "Random"
    case troubleFaces = "Trouble Faces"

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

    var description: String {
        switch self {
        case .spaced: return "Due for review"
        case .random: return "Mix it up"
        case .troubleFaces: return "Need more practice"
        }
    }
}

struct PracticeHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]
    @State private var showingQuiz = false
    @State private var selectedMode: QuizMode = .spaced

    private var peopleWithFaces: [Person] {
        people.filter { !$0.embeddings.isEmpty }
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
                            value: "\(peopleNeedingReview.count)",
                            label: "Due Today",
                            icon: "clock.badge",
                            color: peopleNeedingReview.isEmpty ? AppColors.success : AppColors.warning
                        )

                        PracticeStatCard(
                            value: totalAttempts > 0 ? "\(Int(overallAccuracy * 100))%" : "-",
                            label: "Accuracy",
                            icon: "target",
                            color: overallAccuracy >= 0.8 ? AppColors.success : (overallAccuracy >= 0.5 ? AppColors.warning : AppColors.coral)
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
                                ForEach(QuizMode.allCases, id: \.self) { mode in
                                    QuizModeButton(
                                        mode: mode,
                                        count: countForMode(mode),
                                        isDisabled: mode == .troubleFaces && troubleFaces.isEmpty
                                    ) {
                                        selectedMode = mode
                                        showingQuiz = true
                                    }
                                }
                            }
                            .padding(.horizontal)

                            Text("Spaced repetition helps cement faces in long-term memory")
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)
                                .italic()
                                .padding(.horizontal)
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
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
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
                            Label("\(abs(srData.daysUntilReview))d overdue", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(AppColors.warning)
                        } else if srData.daysUntilReview == 0 {
                            Label("Due today", systemImage: "clock")
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
                    Label("New face - never practiced", systemImage: "sparkles")
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
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
