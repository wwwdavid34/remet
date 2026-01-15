import SwiftUI
import SwiftData

struct PracticeHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]
    @State private var showingQuiz = false

    private var peopleWithFaces: [Person] {
        people.filter { !$0.embeddings.isEmpty }
    }

    private var peopleNeedingReview: [Person] {
        peopleWithFaces.filter { $0.needsReview }
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
                                    .foregroundStyle(.secondary)
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

                    // Start Practice Button
                    if !peopleWithFaces.isEmpty {
                        VStack(spacing: 12) {
                            Button {
                                showingQuiz = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(peopleNeedingReview.isEmpty ? "Practice All Faces" : "Start Review")
                                            .font(.headline)
                                        if !peopleNeedingReview.isEmpty {
                                            Text("\(peopleNeedingReview.count) faces waiting for you")
                                                .font(.caption)
                                                .opacity(0.9)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                }
                                .foregroundStyle(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.teal, AppColors.teal.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: AppColors.teal.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal)

                            Text("Spaced repetition helps cement faces in long-term memory")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
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
                                    ReviewPersonRow(person: person)
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
                    people: peopleNeedingReview.isEmpty ? peopleWithFaces : peopleNeedingReview
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
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
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
                                .foregroundStyle(srData.accuracy >= 0.8 ? AppColors.success : .secondary)
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
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    PracticeHomeView()
        .modelContainer(for: [Person.self], inMemory: true)
}
