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
                    // Stats Overview
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            PracticeStatCard(
                                title: "Due Today",
                                value: "\(peopleNeedingReview.count)",
                                subtitle: "people to review",
                                color: peopleNeedingReview.isEmpty ? .green : .orange
                            )

                            PracticeStatCard(
                                title: "Accuracy",
                                value: totalAttempts > 0 ? "\(Int(overallAccuracy * 100))%" : "-",
                                subtitle: "\(totalCorrect)/\(totalAttempts) correct",
                                color: overallAccuracy >= 0.8 ? .green : (overallAccuracy >= 0.5 ? .orange : .red)
                            )
                        }

                        HStack(spacing: 16) {
                            PracticeStatCard(
                                title: "Total People",
                                value: "\(peopleWithFaces.count)",
                                subtitle: "with faces saved",
                                color: .blue
                            )

                            PracticeStatCard(
                                title: "Mastered",
                                value: "\(masteredCount)",
                                subtitle: "high accuracy",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Start Practice Button
                    if !peopleWithFaces.isEmpty {
                        VStack(spacing: 12) {
                            Button {
                                showingQuiz = true
                            } label: {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                    Text(peopleNeedingReview.isEmpty ? "Practice All" : "Start Review (\(peopleNeedingReview.count))")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)

                            if !peopleNeedingReview.isEmpty {
                                Text("Review due people first for best memory retention")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // People Due Section
                    if !peopleNeedingReview.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Due for Review")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVStack(spacing: 8) {
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
                        VStack(spacing: 16) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)

                            Text("No People to Practice")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Add people with face photos to start practicing. The quiz will help you remember names through spaced repetition.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
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
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ReviewPersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            // Face thumbnail
            if let embedding = person.embeddings.first,
               let uiImage = UIImage(data: embedding.faceCropData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let srData = person.spacedRepetitionData {
                    HStack(spacing: 8) {
                        if srData.daysUntilReview < 0 {
                            Text("\(abs(srData.daysUntilReview))d overdue")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else if srData.daysUntilReview == 0 {
                            Text("Due today")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if srData.totalAttempts > 0 {
                            Text("\(Int(srData.accuracy * 100))% accuracy")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("New - never practiced")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    PracticeHomeView()
        .modelContainer(for: [Person.self], inMemory: true)
}
