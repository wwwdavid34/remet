import SwiftUI
import SwiftData

struct FaceQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let people: [Person]
    var allPeople: [Person]? = nil
    var mode: QuizMode = .spaced

    @State private var currentIndex = 0
    @State private var shuffledPeople: [Person] = []
    @State private var currentOptions: [String] = []
    @State private var selectedAnswer: String?
    @State private var showingResult = false
    @State private var wasCorrect = false
    @State private var quizStartTime = Date()
    @State private var sessionStats = QuizSessionStats()
    @State private var showingSessionComplete = false

    var body: some View {
        NavigationStack {
            Group {
                if showingSessionComplete {
                    SessionCompleteView(
                        stats: sessionStats,
                        onDismiss: { dismiss() }
                    )
                } else if let currentPerson = currentPerson {
                    VStack(spacing: 20) {
                        // Mode indicator + Progress
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .foregroundStyle(mode.color)
                                Text(mode.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(mode.color)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(mode.color.opacity(0.1))
                            .clipShape(Capsule())

                            ProgressView(value: Double(currentIndex), total: Double(shuffledPeople.count))
                                .tint(mode.color)

                            Text("\(currentIndex + 1) of \(shuffledPeople.count)")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal)

                        Spacer()

                        // Face display
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.coral.opacity(0.1), AppColors.teal.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 200, height: 200)

                            if let embedding = (currentPerson.embeddings ?? []).randomElement(),
                               let uiImage = UIImage(data: embedding.faceCropData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 180, height: 180)
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
                                    .frame(width: 180, height: 180)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 70))
                                            .foregroundStyle(.white)
                                    }
                            }
                        }
                        .shadow(color: AppColors.coral.opacity(0.2), radius: 20, x: 0, y: 10)

                        Spacer()

                        if showingResult {
                            // Result view
                            QuizResultView(
                                person: currentPerson,
                                wasCorrect: wasCorrect,
                                userGuess: selectedAnswer ?? ""
                            )

                            Button {
                                if currentIndex < shuffledPeople.count - 1 {
                                    nextQuestion()
                                } else {
                                    showingSessionComplete = true
                                }
                            } label: {
                                HStack {
                                    Text(currentIndex < shuffledPeople.count - 1 ? "Next Face" : "See Results")
                                    Image(systemName: "arrow.right")
                                }
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.teal)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal)
                        } else {
                            // Multiple choice options
                            VStack(spacing: 14) {
                                Text("Who is this?")
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                ForEach(currentOptions, id: \.self) { option in
                                    Button {
                                        selectAnswer(option)
                                    } label: {
                                        Text(option)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(AppColors.cardBackground)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .shadow(color: AppColors.teal.opacity(0.12), radius: 6, x: 0, y: 3)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    selectAnswer(nil)
                                } label: {
                                    Text("I don't remember")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.coral)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                } else {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.questionmark",
                        title: "No faces to quiz",
                        subtitle: "Add some people first, then come back for practice!"
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if sessionStats.totalAttempts > 0 {
                            showingSessionComplete = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("End")
                            .foregroundStyle(AppColors.coral)
                    }
                }
            }
        }
        .onAppear {
            setupQuiz()
        }
    }

    private var currentPerson: Person? {
        guard currentIndex < shuffledPeople.count else { return nil }
        return shuffledPeople[currentIndex]
    }

    private func setupQuiz() {
        shuffledPeople = people.shuffled()
        quizStartTime = Date()
        generateOptions()
    }

    private func generateOptions() {
        guard let correctPerson = currentPerson else { return }

        let namePool = allPeople ?? shuffledPeople
        var wrongAnswers = namePool
            .filter { $0.id != correctPerson.id }
            .map { $0.name }
            .shuffled()

        let wrongCount = min(3, wrongAnswers.count)
        wrongAnswers = Array(wrongAnswers.prefix(wrongCount))

        currentOptions = (wrongAnswers + [correctPerson.name]).shuffled()
    }

    private func selectAnswer(_ answer: String?) {
        guard let person = currentPerson else { return }

        selectedAnswer = answer
        let responseTime = Int(Date().timeIntervalSince(quizStartTime) * 1000)
        wasCorrect = answer == person.name

        sessionStats.totalAttempts += 1
        if wasCorrect {
            sessionStats.correctAttempts += 1
        }

        let attempt = QuizAttempt(
            wasCorrect: wasCorrect,
            responseTimeMs: responseTime,
            userGuess: answer
        )
        attempt.person = person
        person.quizAttempts = (person.quizAttempts ?? []) + [attempt]
        modelContext.insert(attempt)

        updateSpacedRepetition(for: person, wasCorrect: wasCorrect)

        try? modelContext.save()
        showingResult = true
    }

    private func updateSpacedRepetition(for person: Person, wasCorrect: Bool) {
        let srData = person.spacedRepetitionData ?? SpacedRepetitionData()

        if person.spacedRepetitionData == nil {
            srData.person = person
            person.spacedRepetitionData = srData
            modelContext.insert(srData)
        }

        srData.totalAttempts += 1
        srData.lastReviewDate = Date()

        if wasCorrect {
            srData.correctAttempts += 1
            srData.repetitions += 1

            if srData.repetitions == 1 {
                srData.interval = 1
            } else if srData.repetitions == 2 {
                srData.interval = 6
            } else {
                srData.interval = Int(Double(srData.interval) * srData.easeFactor)
            }

            srData.easeFactor = min(2.5, srData.easeFactor + 0.1)
        } else {
            srData.repetitions = 0
            srData.interval = 1
            srData.easeFactor = max(1.3, srData.easeFactor - 0.2)
        }

        srData.nextReviewDate = Calendar.current.date(byAdding: .day, value: srData.interval, to: Date()) ?? Date()
    }

    private func nextQuestion() {
        showingResult = false
        wasCorrect = false
        selectedAnswer = nil
        currentIndex += 1
        quizStartTime = Date()
        generateOptions()
    }
}

// MARK: - Quiz Result View

struct QuizResultView: View {
    let person: Person
    let wasCorrect: Bool
    let userGuess: String

    var body: some View {
        VStack(spacing: 12) {
            // Witty feedback
            Text(wasCorrect ? WittyCopy.random(from: WittyCopy.quizCorrect) : WittyCopy.random(from: WittyCopy.quizIncorrect))
                .font(.headline)
                .foregroundStyle(wasCorrect ? AppColors.success : AppColors.coral)

            // Result icon
            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(wasCorrect ? AppColors.success : AppColors.coral)

            Text(person.name)
                .font(.title2)
                .fontWeight(.bold)

            if !wasCorrect && !userGuess.isEmpty {
                Text("You guessed: \(userGuess)")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Context info card
            if person.company != nil || person.howWeMet != nil || person.contextTag != nil || !person.talkingPoints.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if let company = person.company {
                        Label(company, systemImage: "building.2")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if let howWeMet = person.howWeMet {
                        Label(howWeMet, systemImage: "person.2")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if let contextTag = person.contextTag {
                        Label(contextTag, systemImage: "tag")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.teal)
                    }

                    if !person.talkingPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Talking Points")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.coral)

                            ForEach(person.talkingPoints.prefix(2), id: \.self) { point in
                                Text("• \(point)")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Session Complete View

struct SessionCompleteView: View {
    let stats: QuizSessionStats
    let onDismiss: () -> Void

    private var motivationalMessage: String {
        if stats.accuracy >= 0.8 {
            return WittyCopy.random(from: WittyCopy.sessionComplete80Plus)
        } else if stats.accuracy >= 0.5 {
            return WittyCopy.random(from: WittyCopy.sessionComplete50to80)
        } else {
            return WittyCopy.random(from: WittyCopy.sessionCompleteUnder50)
        }
    }

    var body: some View {
        VStack(spacing: 28) {
            // Trophy/celebration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.warmYellow.opacity(0.3), AppColors.coral.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: stats.accuracy >= 0.8 ? "trophy.fill" : (stats.accuracy >= 0.5 ? "star.fill" : "heart.fill"))
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.coral, AppColors.warmYellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Session Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)

                Text(motivationalMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Stats
            HStack(spacing: 20) {
                SessionStatBadge(value: "\(stats.totalAttempts)", label: "Attempted", color: AppColors.teal)
                SessionStatBadge(value: "\(stats.correctAttempts)", label: "Correct", color: AppColors.success)
                SessionStatBadge(value: "\(Int(stats.accuracy * 100))%", label: "Accuracy", color: stats.accuracy >= 0.8 ? AppColors.success : (stats.accuracy >= 0.5 ? AppColors.warning : AppColors.coral))
            }
            .padding(.horizontal)

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [AppColors.coral, AppColors.coral.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct SessionStatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quiz Session Stats

struct QuizSessionStats {
    var totalAttempts = 0
    var correctAttempts = 0

    var accuracy: Double {
        totalAttempts > 0 ? Double(correctAttempts) / Double(totalAttempts) : 0
    }
}

#Preview {
    FaceQuizView(people: [])
}
