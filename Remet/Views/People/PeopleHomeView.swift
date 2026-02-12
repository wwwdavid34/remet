import SwiftUI
import SwiftData

/// Unified view combining Home dashboard and People list
/// Primary tab for browsing and managing people
struct PeopleHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]

    @State private var selectedTagFilters: Set<UUID> = []
    @State private var selectedPerson: Person?
    @State private var selectedEncounter: Encounter?
    @State private var showAccount = false
    @State private var showAllEncounters = false
    @State private var scrollOffset: CGFloat = 0

    // Multi-select for merge/delete
    @State private var isSelectMode = false
    @State private var selectedPersonIds: Set<UUID> = []
    @State private var showPersonMergeSheet = false
    @State private var showDeleteSelectedConfirmation = false

    // Search state
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var selectedSearchTab: SearchTab = .all
    @FocusState private var searchFieldFocused: Bool

    enum SearchTab: String, CaseIterable {
        case all = "All"
        case people = "People"
        case encounters = "Encounters"
    }

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

    // MARK: - Search Computed Properties

    private var searchFilteredPeople: [Person] {
        guard !searchText.isEmpty else { return [] }
        return people.filter { person in
            person.name.localizedCaseInsensitiveContains(searchText) ||
            person.notes?.localizedCaseInsensitiveContains(searchText) == true ||
            (person.tags ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var searchFilteredEncounters: [Encounter] {
        guard !searchText.isEmpty else { return [] }
        return encounters.filter { encounter in
            encounter.occasion?.localizedCaseInsensitiveContains(searchText) == true ||
            encounter.location?.localizedCaseInsensitiveContains(searchText) == true ||
            (encounter.people ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) } ||
            (encounter.tags ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var hasSearchResults: Bool {
        !searchFilteredPeople.isEmpty || !searchFilteredEncounters.isEmpty
    }

    // MARK: - Cache Update Functions

    private func updateCaches() {
        cachedPeopleNeedingReview = people.filter { $0.needsReview }

        var seenIds = Set<UUID>()
        var tags: [Tag] = []
        for person in people {
            for tag in person.tags ?? [] {
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

        if !selectedTagFilters.isEmpty {
            result = result.filter { person in
                let personTagIds = Set((person.tags ?? []).map { $0.id })
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
                        .opacity(showSearch ? 1 : headerOpacity)
                        .frame(height: showSearch ? nil : (headerIsHidden ? 0 : nil))
                        .clipped()

                    VStack(spacing: 20) {
                        if showSearch {
                            searchContent
                        } else if people.isEmpty {
                            emptyState
                        } else {
                            dashboardContent
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            .background(Color(.systemGroupedBackground))
            .statusBarFade()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedPerson) { person in
                PersonDetailView(person: person)
            }
            .sheet(isPresented: $showAllEncounters) {
                NavigationStack {
                    EncounterListView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showAllEncounters = false }
                            }
                        }
                }
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
            .sheet(isPresented: $showPersonMergeSheet) {
                PersonMergeView(people: people.filter { selectedPersonIds.contains($0.id) }) {
                    withAnimation {
                        isSelectMode = false
                        selectedPersonIds.removeAll()
                    }
                }
            }
            .alert("Delete Selected?", isPresented: $showDeleteSelectedConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSelectedPeople()
                }
            } message: {
                Text("Delete \(selectedPersonIds.count) selected people? This cannot be undone.")
            }
            .overlay(alignment: .bottom) {
                if isSelectMode && !selectedPersonIds.isEmpty {
                    selectModeBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task {
                updateCaches()
            }
            .onChange(of: people) {
                updateCaches()
            }
            .onChange(of: selectedTagFilters) {
                updateFilteredPeople()
            }
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 10) {
            if showSearch {
                // Expanded search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search people, encounters, tags...", text: $searchText)
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
                .glassCard(intensity: .thin, cornerRadius: 16)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity)
                ))

                Button {
                    dismissSearch()
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.coral)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Text("Remet")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppColors.coral)

                Spacer()

                // Select button (only when people exist)
                if !people.isEmpty {
                    Button {
                        withAnimation {
                            isSelectMode.toggle()
                            if !isSelectMode {
                                selectedPersonIds.removeAll()
                            }
                        }
                    } label: {
                        Text(isSelectMode ? "Cancel" : "Select")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.coral)
                    }
                }

                // Search button
                Button {
                    activateSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.coral)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .glassCard(intensity: .thin, cornerRadius: 22)

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
                .glassCard(intensity: .thin, cornerRadius: 22)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .safeAreaPadding(.top)
    }

    private func activateSearch() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showSearch = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            searchFieldFocused = true
        }
    }

    private func dismissSearch() {
        searchFieldFocused = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showSearch = false
            searchText = ""
            selectedSearchTab = .all
        }
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
        .glassCard(intensity: .thin, cornerRadius: 12)
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
                .padding(.top, 4)
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
                Button {
                    showAllEncounters = true
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
                Text(isSelectMode ? "\(selectedPersonIds.count) Selected" : "All People")
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
                    if isSelectMode {
                        Button {
                            togglePersonSelection(person.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedPersonIds.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedPersonIds.contains(person.id) ? AppColors.coral : .secondary)
                                    .font(.title3)
                                PersonRow(person: person)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            selectedPerson = person
                        } label: {
                            PersonRow(person: person)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func togglePersonSelection(_ id: UUID) {
        if selectedPersonIds.contains(id) {
            selectedPersonIds.remove(id)
        } else {
            selectedPersonIds.insert(id)
        }
    }

    // MARK: - Select Mode Bar

    @ViewBuilder
    private var selectModeBar: some View {
        HStack(spacing: 12) {
            Button {
                showDeleteSelectedConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.coral)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                showPersonMergeSheet = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.merge")
                    Text("Merge")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedPersonIds.count >= 2 ? AppColors.teal : AppColors.teal.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedPersonIds.count < 2)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func deleteSelectedPeople() {
        for person in people where selectedPersonIds.contains(person.id) {
            modelContext.delete(person)
        }
        try? modelContext.save()
        withAnimation {
            isSelectMode = false
            selectedPersonIds.removeAll()
        }
    }

    // MARK: - Search Content

    @ViewBuilder
    private var searchContent: some View {
        VStack(spacing: 0) {
            if searchText.isEmpty {
                // Prompt state
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundStyle(AppColors.textMuted)
                    Text("Search people, encounters, and tags")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                }
                .frame(minHeight: 300)
            } else if !hasSearchResults {
                // No results
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundStyle(AppColors.textMuted)
                    Text("No Results")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("No matches for \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                }
                .frame(minHeight: 300)
            } else {
                // Results with tab picker
                Picker("Category", selection: $selectedSearchTab) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        Text(searchTabLabel(for: tab)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // People results
                if (selectedSearchTab == .all || selectedSearchTab == .people) && !searchFilteredPeople.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedSearchTab == .all {
                            Label("People (\(searchFilteredPeople.count))", systemImage: "person.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.coral)
                                .padding(.horizontal)
                        }

                        LazyVStack(spacing: 0) {
                            ForEach(searchFilteredPeople) { person in
                                Button {
                                    selectedPerson = person
                                } label: {
                                    PersonSearchRow(person: person, searchText: searchText)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 78)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Encounters results
                if (selectedSearchTab == .all || selectedSearchTab == .encounters) && !searchFilteredEncounters.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if selectedSearchTab == .all {
                            Label("Encounters (\(searchFilteredEncounters.count))", systemImage: "person.2.crop.square.stack")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColors.teal)
                                .padding(.horizontal)
                                .padding(.top, 12)
                        }

                        LazyVStack(spacing: 0) {
                            ForEach(searchFilteredEncounters) { encounter in
                                Button {
                                    selectedEncounter = encounter
                                } label: {
                                    EncounterSearchRow(encounter: encounter, searchText: searchText)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 78)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .transition(.opacity)
    }

    private func searchTabLabel(for tab: SearchTab) -> String {
        switch tab {
        case .all:
            let total = searchFilteredPeople.count + searchFilteredEncounters.count
            return total > 0 ? "All (\(total))" : "All"
        case .people:
            return searchFilteredPeople.count > 0 ? "People (\(searchFilteredPeople.count))" : "People"
        case .encounters:
            return searchFilteredEncounters.count > 0 ? "Encounters (\(searchFilteredEncounters.count))" : "Encounters"
        }
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
                if let embedding = person.embeddings?.first,
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
        .contentShape(Rectangle())
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
        .contentShape(Rectangle())
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
