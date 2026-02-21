import SwiftUI
import SwiftData
import TipKit

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

    private let spacedReviewTip = SpacedReviewTip()
    private let setFiltersTip = SetFiltersTip()

    // Custom group quiz filters
    @State private var showCustomFilters = false
    @State private var showingFilteredQuiz = false
    @State private var customFilterFavoritesOnly = false
    @State private var customFilterRelationship: String? = nil
    @State private var customFilterContext: String? = nil
    @State private var customFilterTagIds: Set<UUID> = []

    private var peopleWithFaces: [Person] {
        people.filter { !($0.embeddings ?? []).isEmpty && !$0.isMe }
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

    private var filteredQuizPeople: [Person] {
        var result = peopleWithFaces
        if customFilterFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        if let rel = customFilterRelationship {
            result = result.filter { $0.relationship == rel }
        }
        if let ctx = customFilterContext {
            result = result.filter { $0.contextTag == ctx }
        }
        if !customFilterTagIds.isEmpty {
            result = result.filter { person in
                let personTagIds = Set((person.tags ?? []).map { $0.id })
                return !customFilterTagIds.isDisjoint(with: personTagIds)
            }
        }
        return result
    }

    private var hasCustomFilters: Bool {
        customFilterFavoritesOnly || customFilterRelationship != nil || customFilterContext != nil || !customFilterTagIds.isEmpty
    }

    private var customFilterSummary: String {
        var parts: [String] = []
        if customFilterFavoritesOnly { parts.append(String(localized: "Favorites")) }
        if let rel = customFilterRelationship { parts.append(rel) }
        if let ctx = customFilterContext { parts.append(ctx) }
        if !customFilterTagIds.isEmpty {
            parts.append(String(localized: "\(customFilterTagIds.count) tags"))
        }
        return parts.isEmpty ? String(localized: "All People") : parts.joined(separator: " · ")
    }

    private var tagsInUse: [Tag] {
        var seenIds = Set<UUID>()
        var result: [Tag] = []
        for person in peopleWithFaces {
            for tag in person.tags ?? [] {
                if !seenIds.contains(tag.id) {
                    seenIds.insert(tag.id)
                    result.append(tag)
                }
            }
        }
        return result.sorted { $0.name < $1.name }
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
        let allAttempts = people.flatMap { $0.quizAttempts ?? [] }

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
                                    SpacedReviewTip().invalidate(reason: .actionPerformed)
                                    selectedMode = .spaced
                                    showingQuiz = true
                                }
                                .popoverTip(spacedReviewTip)

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

                        // Custom Group section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.2.crop.square.stack")
                                        .foregroundStyle(AppColors.teal)
                                    Text(String(localized: "Custom Group"))
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)

                            Button {
                                SetFiltersTip().invalidate(reason: .actionPerformed)
                                showCustomFilters = true
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(AppColors.teal.opacity(0.15))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "line.3.horizontal.decrease.circle")
                                            .font(.title3)
                                            .foregroundStyle(AppColors.teal)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(localized: "Set Filters"))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppColors.textPrimary)

                                        Text(customFilterSummary)
                                            .font(.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text("\(filteredQuizPeople.count)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(AppColors.teal)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppColors.teal.opacity(0.1))
                                        .clipShape(Capsule())

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                .padding(12)
                                .contentShape(Rectangle())
                                .glassCard(intensity: .thin, cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                            .popoverTip(setFiltersTip)
                            .padding(.horizontal)

                            if hasCustomFilters {
                                Button {
                                    showingFilteredQuiz = true
                                } label: {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text(String(localized: "Start Quiz"))
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(filteredQuizPeople.isEmpty ? Color.gray : AppColors.teal)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(filteredQuizPeople.isEmpty)
                                .padding(.horizontal)
                            }
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
                                    .contentShape(Rectangle())
                                    .tintedGlassBackground(AppColors.coral, tintOpacity: 0.05, cornerRadius: 14)
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
            .fullScreenCover(isPresented: $showingFilteredQuiz) {
                FaceQuizView(
                    people: filteredQuizPeople.shuffled(),
                    allPeople: peopleWithFaces,
                    mode: .random
                )
            }
            .sheet(isPresented: $showCustomFilters) {
                QuizFilterSheet(
                    filterFavoritesOnly: $customFilterFavoritesOnly,
                    selectedRelationship: $customFilterRelationship,
                    selectedContext: $customFilterContext,
                    selectedTagIds: $customFilterTagIds,
                    availableTags: tagsInUse,
                    matchCount: filteredQuizPeople.count
                )
                .presentationDetents([.medium, .large])
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

// MARK: - Quiz Filter Sheet

struct QuizFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filterFavoritesOnly: Bool
    @Binding var selectedRelationship: String?
    @Binding var selectedContext: String?
    @Binding var selectedTagIds: Set<UUID>

    let availableTags: [Tag]
    let matchCount: Int

    private var relationships: [String] { AppSettings.shared.customRelationships }
    private var contexts: [String] { AppSettings.shared.customContexts }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $filterFavoritesOnly) {
                        Label(String(localized: "Favorites Only"), systemImage: "star.fill")
                            .foregroundStyle(.primary)
                    }
                    .tint(.yellow)
                }

                Section {
                    Button {
                        selectedRelationship = nil
                    } label: {
                        HStack {
                            Text(String(localized: "Any"))
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedRelationship == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppColors.coral)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    ForEach(relationships, id: \.self) { rel in
                        Button {
                            selectedRelationship = rel
                        } label: {
                            HStack {
                                Text(rel)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedRelationship == rel {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColors.coral)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "Relationship"))
                }

                Section {
                    Button {
                        selectedContext = nil
                    } label: {
                        HStack {
                            Text(String(localized: "Any"))
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedContext == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppColors.coral)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    ForEach(contexts, id: \.self) { ctx in
                        Button {
                            selectedContext = ctx
                        } label: {
                            HStack {
                                Text(ctx)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedContext == ctx {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColors.coral)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "Context"))
                }

                if !availableTags.isEmpty {
                    Section {
                        ForEach(availableTags) { tag in
                            Button {
                                if selectedTagIds.contains(tag.id) {
                                    selectedTagIds.remove(tag.id)
                                } else {
                                    selectedTagIds.insert(tag.id)
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 12, height: 12)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTagIds.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppColors.coral)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(String(localized: "Tags"))
                    }
                }
            }
            .navigationTitle(String(localized: "Quiz Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Reset")) {
                        filterFavoritesOnly = false
                        selectedRelationship = nil
                        selectedContext = nil
                        selectedTagIds.removeAll()
                    }
                    .foregroundStyle(AppColors.coral)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(String(localized: "\(matchCount) people match"))
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(matchCount > 0 ? AppColors.teal : AppColors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Supporting Views

struct PracticeStatCard: View {
    let value: String
    let label: LocalizedStringKey
    let icon: String
    let color: Color
    var trend: Int? = nil
    @Environment(\.colorScheme) private var colorScheme

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
        .tintedGlassBackground(color, tintOpacity: 0.08, cornerRadius: 16, interactive: false)
    }
}

struct ReviewPersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            // Face thumbnail
            ZStack {
                if let profileEmbedding = person.profileEmbedding,
                   let uiImage = UIImage(data: profileEmbedding.faceCropData) {
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
        .contentShape(Rectangle())
        .glassCard(intensity: .thin, cornerRadius: 14)
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
            .contentShape(Rectangle())
            .glassCard(intensity: .thin, cornerRadius: 14)
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
