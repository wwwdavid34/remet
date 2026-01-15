import SwiftUI
import SwiftData

struct FaceQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let people: [Person]

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
                        // Progress
                        ProgressView(value: Double(currentIndex), total: Double(shuffledPeople.count))
                            .padding(.horizontal)

                        Text("\(currentIndex + 1) of \(shuffledPeople.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Face display
                        if let embedding = currentPerson.embeddings.randomElement(),
                           let uiImage = UIImage(data: embedding.faceCropData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 180, height: 180)
                                .clipShape(Circle())
                                .shadow(radius: 10)
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 180, height: 180)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 70))
                                        .foregroundStyle(.gray)
                                }
                        }

                        Spacer()

                        if showingResult {
                            // Result view
                            QuizResultView(
                                person: currentPerson,
                                wasCorrect: wasCorrect,
                                userGuess: selectedAnswer ?? ""
                            )

                            Button(currentIndex < shuffledPeople.count - 1 ? "Next" : "Finish") {
                                if currentIndex < shuffledPeople.count - 1 {
                                    nextQuestion()
                                } else {
                                    showingSessionComplete = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else {
                            // Multiple choice options
                            VStack(spacing: 12) {
                                Text("Who is this?")
                                    .font(.headline)

                                ForEach(currentOptions, id: \.self) { option in
                                    Button {
                                        selectAnswer(option)
                                    } label: {
                                        Text(option)
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color(.systemGray6))
                                            .foregroundStyle(.primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button("I Don't Know") {
                                    selectAnswer(nil)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                } else {
                    Text("No people to quiz")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End") {
                        if sessionStats.totalAttempts > 0 {
                            showingSessionComplete = true
                        } else {
                            dismiss()
                        }
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

        // Get wrong answers from other people
        var wrongAnswers = shuffledPeople
            .filter { $0.id != correctPerson.id }
            .map { $0.name }
            .shuffled()

        // Take up to 3 wrong answers
        let wrongCount = min(3, wrongAnswers.count)
        wrongAnswers = Array(wrongAnswers.prefix(wrongCount))

        // Combine and shuffle
        currentOptions = (wrongAnswers + [correctPerson.name]).shuffled()
    }

    private func selectAnswer(_ answer: String?) {
        guard let person = currentPerson else { return }

        selectedAnswer = answer
        let responseTime = Int(Date().timeIntervalSince(quizStartTime) * 1000)
        wasCorrect = answer == person.name

        // Update session stats
        sessionStats.totalAttempts += 1
        if wasCorrect {
            sessionStats.correctAttempts += 1
        }

        // Record quiz attempt
        let attempt = QuizAttempt(
            wasCorrect: wasCorrect,
            responseTimeMs: responseTime,
            userGuess: answer
        )
        attempt.person = person
        person.quizAttempts.append(attempt)
        modelContext.insert(attempt)

        // Update spaced repetition data
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

        // SM-2 Algorithm
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

            // Increase ease factor slightly for correct answers
            srData.easeFactor = min(2.5, srData.easeFactor + 0.1)
        } else {
            srData.repetitions = 0
            srData.interval = 1

            // Decrease ease factor for incorrect answers
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
            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(wasCorrect ? .green : .red)

            Text(person.name)
                .font(.title2)
                .fontWeight(.bold)

            if !wasCorrect && !userGuess.isEmpty {
                Text("You said: \(userGuess)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Context info
            VStack(alignment: .leading, spacing: 8) {
                if let company = person.company {
                    HStack {
                        Image(systemName: "building.2")
                        Text(company)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if let howWeMet = person.howWeMet {
                    HStack {
                        Image(systemName: "person.2")
                        Text(howWeMet)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if let contextTag = person.contextTag {
                    HStack {
                        Image(systemName: "tag")
                        Text(contextTag)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                // Talking points
                if !person.talkingPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Talking Points:")
                            .font(.caption)
                            .fontWeight(.medium)

                        ForEach(person.talkingPoints.prefix(3), id: \.self) { point in
                            HStack(alignment: .top) {
                                Text("-")
                                Text(point)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Session Complete View

struct SessionCompleteView: View {
    let stats: QuizSessionStats
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    VStack {
                        Text("\(stats.totalAttempts)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(stats.correctAttempts)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Correct")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(Int(stats.accuracy * 100))%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(stats.accuracy >= 0.8 ? .green : (stats.accuracy >= 0.5 ? .orange : .red))
                        Text("Accuracy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if stats.accuracy >= 0.8 {
                Text("Great job! Keep up the excellent work!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if stats.accuracy >= 0.5 {
                Text("Good effort! Practice makes perfect.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Don't worry, keep practicing! You'll improve.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
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
