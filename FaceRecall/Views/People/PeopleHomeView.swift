import SwiftUI
import SwiftData
import Combine

/// Unified view combining Home dashboard and People list
/// Primary tab for browsing and managing people
struct PeopleHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedTagFilters: Set<UUID> = []
    @State private var selectedPerson: Person?
    @State private var selectedEncounter: Encounter?
    @State private var showAccount = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showSearchField = false
    @FocusState private var searchFieldFocused: Bool

    // Cached computed values for performance
    @State private var cachedPeopleNeedingReview: [Person] = []
    @State private var cachedTagsInUse: [Tag] = []
    @State private var cachedFilteredPeople: [Person] = []

    // Header fade threshold
    private let headerFadeThreshold: CGFloat = 60

    // MARK: - Computed Properties (lightweight)

    private var recentEncounters: [Encounter] {
        Array(encounters.prefix(3))
    }

    private var reviewsDueToday: Int {
        cachedPeopleNeedingReview.count
    }

    private var isSearching: Bool {
        !debouncedSearchText.isEmpty || !selectedTagFilters.isEmpty
    }

    // MARK: - Cache Update Functions

    private func updateCaches() {
        cachedPeopleNeedingReview = people.filter { $0.needsReview }

        var seenIds = Set<UUID>()
        var tags: [Tag] = []
        for person in people {
            for tag in person.tags {
                if !seenIds.contains(tag.id) {
                    seenIds.insert(tag.id)
                    tags.append(tag)
                }
            }
        }
        cachedTagsInUse = tags.sorted { $0.name < $1.name }

        updateFilteredPeople()
    }

    private func updateFilteredPeople() {
        var result = people

        if !debouncedSearchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(debouncedSearchText) ||
                $0.tags.contains { $0.name.localizedCaseInsensitiveContains(debouncedSearchText) }
            }
        }

        if !selectedTagFilters.isEmpty {
            result = result.filter { person in
                let personTagIds = Set(person.tags.map { $0.id })
                return !selectedTagFilters.isDisjoint(with: personTagIds)
            }
        }

        cachedFilteredPeople = result
    }

    // MARK: - Body

    private var headerOpacity: Double {
        let fadeStart: CGFloat = 0
        let fadeEnd: CGFloat = headerFadeThreshold
        if scrollOffset <= fadeStart { return 1 }
        if scrollOffset >= fadeEnd { return 0 }
        return Double(1 - (scrollOffset - fadeStart) / (fadeEnd - fadeStart))
    }

    private var headerIsHidden: Bool {
        scrollOffset > headerFadeThreshold
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Scroll offset tracker
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: -geo.frame(in: .named("scroll")).minY
                        )
                    }
                    .frame(height: 0)

                    // Header: Title + Search + Account
                    headerView
                        .opacity(headerOpacity)
                        .frame(height: headerIsHidden ? 0 : nil)
                        .clipped()

                    // Animated search field
                    if showSearchField {
                        searchFieldView
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    VStack(spacing: 20) {
                        if people.isEmpty {
                            emptyState
                        } else if isSearching {
                            // Search results only
                            searchResultsSection
                        } else {
                            // Full dashboard view
                            dashboardContent
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.bottom, 80) // Space for floating tab bar
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
            .navigationDestination(item: $selectedPerson) { person in
                PersonDetailView(person: person)
            }
            .sheet(item: $selectedEncounter) { encounter in
                NavigationStack {
                    EncounterDetailView(encounter: encounter)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { selectedEncounter = nil }
                            }
                        }
                }
            }
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    AccountView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showAccount = false }
                            }
                        }
                }
            }
            .task {
                updateCaches()
            }
            .onChange(of: people) {
                updateCaches()
            }
            .onChange(of: debouncedSearchText) {
                updateFilteredPeople()
            }
            .onChange(of: selectedTagFilters) {
                updateFilteredPeople()
            }
            .onChange(of: searchText) {
                // Debounce search text to avoid lag while typing
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    if searchText == self.searchText {
                        debouncedSearchText = searchText
                    }
                }
            }
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("Remet")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppColors.coral)

            Spacer()

            // Search button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showSearchField.toggle()
                    if showSearchField {
                        searchFieldFocused = true
                    } else {
                        searchText = ""
                        searchFieldFocused = false
                    }
                }
            } label: {
                Image(systemName: showSearchField ? "xmark" : "magnifyingglass")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.coral)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            // Account button
            Button {
                showAccount = true
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.coral)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .safeAreaPadding(.top)
    }

    // MARK: - Search Field View

    @ViewBuilder
    private var searchFieldView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search people...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFieldFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private var dashboardContent: some View {
        VStack(spacing: 20) {
            // Compact stats bar
            statsBar
                .padding(.horizontal)

            // Review nudge (if needed)
            if !cachedPeopleNeedingReview.isEmpty {
                reviewNudgeSection
            }

            // Recent encounters (compact)
            if !recentEncounters.isEmpty {
                recentEncountersSection
            }

            // Tag filter bar
            if !cachedTagsInUse.isEmpty {
                TagFilterView(
                    availableTags: cachedTagsInUse,
                    selectedTags: $selectedTagFilters,
                    onClear: { selectedTagFilters.removeAll() }
                )
            }

            // People list
            peopleListSection
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Bar

    @ViewBuilder
    private var statsBar: some View {
        HStack(spacing: 16) {
            // People count
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(AppColors.coral)
                Text("\(people.count) people")
                    .fontWeight(.medium)
            }
            .font(.subheadline)

            Spacer()

            // Review status
            if reviewsDueToday > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.warning)
                        .frame(width: 8, height: 8)
                    Text("\(reviewsDueToday) due")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.warning)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                    Text("All Caught Up")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.success)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Review Nudge Section

    @ViewBuilder
    private var reviewNudgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(AppColors.warning)
                    Text("Practice These")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                Text("\(cachedPeopleNeedingReview.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.warning.opacity(0.15))
                    .foregroundStyle(AppColors.warning)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(cachedPeopleNeedingReview.prefix(8)) { person in
                        Button {
                            selectedPerson = person
                        } label: {
                            CompactPersonCard(person: person, showReviewBadge: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Encounters Section

    @ViewBuilder
    private var recentEncountersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundStyle(AppColors.teal)
                    Text("Recent")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                NavigationLink {
                    EncounterListView()
                } label: {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(AppColors.coral)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentEncounters) { encounter in
                        Button {
                            selectedEncounter = encounter
                        } label: {
                            CompactEncounterCard(encounter: encounter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - People List Section

    @ViewBuilder
    private var peopleListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All People")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(cachedFilteredPeople.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            LazyVStack(spacing: 10) {
                ForEach(cachedFilteredPeople) { person in
                    NavigationLink(value: person) {
                        PersonRow(person: person)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Results")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(cachedFilteredPeople.count) found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if cachedFilteredPeople.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(AppColors.textMuted)
                    Text(String(localized: "No matches for \"\(searchText)\""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(cachedFilteredPeople) { person in
                        NavigationLink(value: person) {
                            PersonRow(person: person)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.coral.opacity(0.2), AppColors.teal.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 50))
                    .foregroundStyle(AppColors.coral)
            }

            VStack(spacing: 8) {
                Text("No People Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Tap the camera button below to add someone you've met")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
        .frame(minHeight: 400)
    }
}

// MARK: - Compact Person Card

struct CompactPersonCard: View {
    let person: Person
    var showReviewBadge: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Face thumbnail
                if let embedding = person.embeddings.first,
                   let uiImage = UIImage(data: embedding.faceCropData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
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
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.white)
                        }
                }

                // Review badge
                if showReviewBadge, let daysOverdue = person.spacedRepetitionData?.daysUntilReview, daysOverdue < 0 {
                    Circle()
                        .fill(AppColors.warning)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Text("\(min(abs(daysOverdue), 9))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 4, y: -4)
                }
            }

            Text(person.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(width: 72)
    }
}

// MARK: - Compact Encounter Card

struct CompactEncounterCard: View {
    let encounter: Encounter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thumbnail
            if let imageData = encounter.displayImageData ?? encounter.thumbnailData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.teal.opacity(0.2), AppColors.softPurple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 70)
                    .overlay {
                        Image(systemName: "person.2")
                            .foregroundStyle(AppColors.teal)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(encounter.occasion ?? "Encounter")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100)
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    PeopleHomeView()
        .modelContainer(for: [Person.self, Encounter.self], inMemory: true)
}
