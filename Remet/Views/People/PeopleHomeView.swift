import SwiftUI
import SwiftData
import TipKit

/// Unified view combining Home dashboard and People list
/// Primary tab for browsing and managing people
struct PeopleHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]

    @State private var selectedPerson: Person?
    @State private var selectedEncounter: Encounter?
    @State private var showAccount = false
    @State private var showAllEncounters = false
    @State private var showAllPeople = false
    @State private var showPractice = false
    @State private var scrollOffset: CGFloat = 0

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

    // Tips
    private let newFaceTip = NewFaceTip()
    private let practiceTip = PracticeTip()

    // Header fade threshold
    private let headerFadeThreshold: CGFloat = 60

    // MARK: - Computed Properties (lightweight)

    private var recentEncounters: [Encounter] {
        Array(encounters.prefix(5))
    }

    private var showMe: Bool {
        AppSettings.shared.showMeInPeopleList
    }

    private var recentMet: [Person] {
        people.filter { !$0.isMe || showMe }
            .sorted { p1, p2 in
                if p1.isMe { return true }
                if p2.isMe { return false }
                return p1.createdAt > p2.createdAt
            }
            .prefix(8)
            .map { $0 }
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
        cachedPeopleNeedingReview = people.filter { $0.needsReview && !$0.isMe }
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
                        .allowsHitTesting(!headerIsHidden || showSearch)

                    VStack(spacing: 20) {
                        if showSearch {
                            searchContent
                        } else if !people.contains(where: { !$0.isMe || showMe }) {
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
            .sheet(isPresented: $showAllPeople) {
                NavigationStack {
                    AllPeopleListView()
                }
            }
            .sheet(isPresented: $showPractice) {
                NavigationStack {
                    PracticeHomeView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showPractice = false }
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

            // Recent met
            if !recentMet.isEmpty {
                recentMetSection
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Bar

    @ViewBuilder
    private var statsBar: some View {
        HStack(spacing: 12) {
            Button {
                showAllPeople = true
            } label: {
                DashboardStatCard(
                    value: "\(people.filter { !$0.isMe || showMe }.count)",
                    label: "People",
                    icon: "person.3.fill",
                    color: AppColors.coral
                )
            }
            .buttonStyle(.plain)
            .popoverTip(newFaceTip)

            Button {
                showAllEncounters = true
            } label: {
                DashboardStatCard(
                    value: "\(encounters.count)",
                    label: "Encounters",
                    icon: "person.2.crop.square.stack",
                    color: AppColors.teal
                )
            }
            .buttonStyle(.plain)

            Button {
                PracticeTip().invalidate(reason: .actionPerformed)
                showPractice = true
            } label: {
                DashboardStatCard(
                    value: reviewsDueToday > 0 ? "\(reviewsDueToday)" : "0",
                    label: reviewsDueToday > 0 ? "Due" : "Caught Up",
                    icon: reviewsDueToday > 0 ? "brain.head.profile" : "checkmark.circle.fill",
                    color: reviewsDueToday > 0 ? AppColors.warning : AppColors.success
                )
            }
            .buttonStyle(.plain)
            .popoverTip(practiceTip)
        }
    }

    // MARK: - Review Nudge Section

    @ViewBuilder
    private var reviewNudgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(AppColors.warning)
                Text("Practice These")
                    .font(.subheadline)
                    .fontWeight(.semibold)
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

                    if cachedPeopleNeedingReview.count > 8 {
                        Button { showPractice = true } label: {
                            OverflowBadge(remaining: cachedPeopleNeedingReview.count - 8, color: AppColors.warning)
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
            Button {
                showAllEncounters = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundStyle(AppColors.teal)
                    Text("Recent Encounters")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentEncounters) { encounter in
                        Button {
                            selectedEncounter = encounter
                        } label: {
                            EnhancedEncounterCard(encounter: encounter)
                        }
                        .buttonStyle(.plain)
                    }

                    if encounters.count > recentEncounters.count {
                        Button { showAllEncounters = true } label: {
                            OverflowBadge(remaining: encounters.count - recentEncounters.count, color: AppColors.teal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recent Met Section

    @ViewBuilder
    private var recentMetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showAllPeople = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(AppColors.coral)
                    Text("Recent Met")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentMet) { person in
                        Button {
                            selectedPerson = person
                        } label: {
                            EnhancedPersonCard(person: person)
                        }
                        .buttonStyle(.plain)
                    }

                    let totalPeople = people.filter { !$0.isMe || showMe }.count
                    if totalPeople > recentMet.count {
                        Button { showAllPeople = true } label: {
                            OverflowBadge(remaining: totalPeople - recentMet.count, color: AppColors.coral)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
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
                                    EncounterRowView(encounter: encounter)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
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
            TipView(newFaceTip)
                .padding(.horizontal)

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
                if let profileEmbedding = person.profileEmbedding,
                   let uiImage = UIImage(data: profileEmbedding.faceCropData) {
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

// MARK: - Dashboard Stat Card

struct DashboardStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .tintedGlassBackground(color, tintOpacity: 0.08, cornerRadius: 14)
    }
}

// MARK: - Enhanced Encounter Card

struct EnhancedEncounterCard: View {
    let encounter: Encounter

    private var personCount: Int {
        (encounter.people ?? []).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with people badge
            ZStack(alignment: .bottomTrailing) {
                if let imageData = encounter.displayImageData ?? encounter.thumbnailData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.teal.opacity(0.2), AppColors.softPurple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 180, height: 110)
                        .overlay {
                            Image(systemName: "person.2")
                                .font(.title2)
                                .foregroundStyle(AppColors.teal)
                        }
                }

                if personCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text("\(personCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(encounter.occasion ?? "Encounter")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let location = encounter.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }

                Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
        .padding(6)
        .frame(width: 192)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }
}

// MARK: - Enhanced Person Card

struct EnhancedPersonCard: View {
    let person: Person

    var body: some View {
        VStack(spacing: 8) {
            // Face thumbnail
            if let profileEmbedding = person.profileEmbedding,
               let uiImage = UIImage(data: profileEmbedding.faceCropData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
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
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
            }

            Text(person.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)

            if let relationship = person.relationship {
                Text(relationship)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 90)
        .contentShape(Rectangle())
    }
}

// MARK: - Overflow Card

struct OverflowBadge: View {
    let remaining: Int
    let color: Color

    var body: some View {
        Text("+\(remaining)")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .frame(width: 56, height: 56)
            .glassCard(intensity: .thin, cornerRadius: 28)
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
