import SwiftUI
import SwiftData

enum EncounterSortOption: String, CaseIterable, Identifiable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case mostPeople = "Most People"
    case fewestPeople = "Fewest People"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dateNewest: return "arrow.down.circle"
        case .dateOldest: return "arrow.up.circle"
        case .mostPeople: return "person.3.fill"
        case .fewestPeople: return "person.fill"
        }
    }
}

enum TimeFilter: String, CaseIterable, Identifiable {
    case all = "All Time"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case last3Months = "Last 3 Months"
    case thisYear = "This Year"

    var id: String { rawValue }

    var dateRange: (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .all:
            return nil
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .thisWeek:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .thisMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -3, to: now)!
            return (start, now)
        case .thisYear:
            let start = calendar.date(byAdding: .year, value: -1, to: now)!
            return (start, now)
        }
    }
}

struct EncounterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]

    @State private var showScanner = false
    @State private var searchText = ""
    @State private var selectedTagFilters: Set<UUID> = []
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedLocation: String? = nil
    @State private var selectedSortOption: EncounterSortOption = .dateNewest
    @State private var filterFavoritesOnly = false
    @State private var showFilters = false
    @State private var filterRefreshId = UUID()

    // Multi-select for merge/delete
    @State private var isSelectMode = false
    @State private var selectedEncounterIds: Set<UUID> = []
    @State private var showMergeSheet = false
    @State private var showDeleteSelectedConfirmation = false
    @State private var selectedEncounter: Encounter?

    /// Tags that are currently assigned to at least one encounter
    var tagsInUse: [Tag] {
        var seenIds = Set<UUID>()
        var result: [Tag] = []
        for encounter in encounters {
            for tag in encounter.tags ?? [] {
                if !seenIds.contains(tag.id) {
                    seenIds.insert(tag.id)
                    result.append(tag)
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    /// Unique locations from all encounters
    var locationsInUse: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for encounter in encounters {
            if let location = encounter.location, !location.isEmpty, !seen.contains(location) {
                seen.insert(location)
                result.append(location)
            }
        }
        return result.sorted()
    }

    var filteredEncounters: [Encounter] {
        // Force dependency on refresh ID to ensure updates
        _ = filterRefreshId

        var result = encounters

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { encounter in
                encounter.occasion?.localizedCaseInsensitiveContains(searchText) == true ||
                encounter.location?.localizedCaseInsensitiveContains(searchText) == true ||
                (encounter.people ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Filter by selected tags
        if !selectedTagFilters.isEmpty {
            result = result.filter { encounter in
                let encounterTagIds = Set((encounter.tags ?? []).map { $0.id })
                return !selectedTagFilters.isDisjoint(with: encounterTagIds)
            }
        }

        // Filter by time - explicit check for non-all filter
        if selectedTimeFilter != .all, let dateRange = selectedTimeFilter.dateRange {
            let startDate = dateRange.start
            let endDate = dateRange.end
            result = result.filter { encounter in
                encounter.date >= startDate && encounter.date <= endDate
            }
        }

        // Filter by location - case-insensitive comparison
        if let location = selectedLocation, !location.isEmpty {
            result = result.filter { encounter in
                encounter.location?.localizedCaseInsensitiveCompare(location) == .orderedSame
            }
        }

        // Filter by favorites
        if filterFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        // Apply sorting
        switch selectedSortOption {
        case .dateNewest:
            result.sort { $0.date > $1.date }
        case .dateOldest:
            result.sort { $0.date < $1.date }
        case .mostPeople:
            result.sort { ($0.people ?? []).count > ($1.people ?? []).count }
        case .fewestPeople:
            result.sort { ($0.people ?? []).count < ($1.people ?? []).count }
        }

        return result
    }

    var hasAnyTags: Bool {
        !tagsInUse.isEmpty
    }

    var hasActiveFilters: Bool {
        selectedTimeFilter != .all || selectedLocation != nil || !selectedTagFilters.isEmpty || selectedSortOption != .dateNewest || filterFavoritesOnly
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedTimeFilter != .all { count += 1 }
        if selectedLocation != nil { count += 1 }
        if selectedSortOption != .dateNewest { count += 1 }
        if filterFavoritesOnly { count += 1 }
        count += selectedTagFilters.count
        return count
    }

    var body: some View {
        List {
            if encounters.isEmpty {
                ContentUnavailableView {
                    Label(WittyCopy.emptyEncountersTitle, systemImage: "person.2.crop.square.stack")
                } description: {
                    Text(WittyCopy.emptyEncountersSubtitle)
                } actions: {
                    Button("Add Encounter") { showScanner = true }
                        .buttonStyle(.borderedProminent)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                // Tag filter bar
                if hasAnyTags {
                    Section {
                        TagFilterView(
                            availableTags: tagsInUse,
                            selectedTags: $selectedTagFilters,
                            onClear: { selectedTagFilters.removeAll() }
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                ForEach(filteredEncounters) { encounter in
                    if isSelectMode {
                        Button {
                            toggleSelection(encounter.id)
                        } label: {
                            HStack {
                                Image(systemName: selectedEncounterIds.contains(encounter.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedEncounterIds.contains(encounter.id) ? AppColors.teal : .secondary)
                                    .font(.title3)
                                EncounterRowView(encounter: encounter)
                            }
                        }
                        .foregroundStyle(.primary)
                    } else {
                        Button {
                            selectedEncounter = encounter
                        } label: {
                            EncounterRowView(encounter: encounter)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation {
                                    encounter.isFavorite.toggle()
                                }
                            } label: {
                                Label(
                                    encounter.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: encounter.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                    }
                }
                .onDelete(perform: isSelectMode ? nil : deleteEncounters)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectMode && !selectedEncounterIds.isEmpty {
                selectModeBar
            }
        }
        .alert("Delete \(selectedEncounterIds.count) Encounter\(selectedEncounterIds.count == 1 ? "" : "s")?", isPresented: $showDeleteSelectedConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedEncounters()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .navigationDestination(item: $selectedEncounter) { encounter in
            EncounterDetailView(encounter: encounter)
        }
        .navigationTitle(String(localized: "Encounters"))
        .searchable(text: $searchText, prompt: String(localized: "Search occasions, locations, people"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarLeading) {
                if !encounters.isEmpty {
                    Button {
                        withAnimation {
                            isSelectMode.toggle()
                            if !isSelectMode {
                                selectedEncounterIds.removeAll()
                            }
                        }
                    } label: {
                        Text(isSelectMode ? "Cancel" : "Select")
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if !isSelectMode {
                    Button {
                        showFilters.toggle()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundStyle(hasActiveFilters ? AppColors.coral : AppColors.teal)
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Circle().fill(AppColors.coral))
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showFilters, onDismiss: {
            // Force refresh when filter sheet closes
            filterRefreshId = UUID()
        }) {
            EncounterFilterSheet(
                selectedTimeFilter: $selectedTimeFilter,
                selectedLocation: $selectedLocation,
                selectedTagFilters: $selectedTagFilters,
                selectedSortOption: $selectedSortOption,
                filterFavoritesOnly: $filterFavoritesOnly,
                availableLocations: locationsInUse,
                availableTags: tagsInUse
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showScanner) {
            EncounterScannerView()
        }
        .sheet(isPresented: $showMergeSheet) {
            let selected = encounters.filter { selectedEncounterIds.contains($0.id) }
            if selected.count >= 2 {
                EncounterMergeView(encounters: selected) {
                    withAnimation {
                        isSelectMode = false
                        selectedEncounterIds.removeAll()
                    }
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedEncounterIds.contains(id) {
            selectedEncounterIds.remove(id)
        } else {
            selectedEncounterIds.insert(id)
        }
    }

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
                showMergeSheet = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.merge")
                    Text("Merge")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedEncounterIds.count >= 2 ? AppColors.teal : AppColors.teal.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedEncounterIds.count < 2)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func deleteEncounters(at offsets: IndexSet) {
        for index in offsets {
            let encounter = filteredEncounters[index]
            modelContext.delete(encounter)
        }
        try? modelContext.save()
    }

    private func deleteSelectedEncounters() {
        for encounter in encounters where selectedEncounterIds.contains(encounter.id) {
            modelContext.delete(encounter)
        }
        try? modelContext.save()
        withAnimation {
            isSelectMode = false
            selectedEncounterIds.removeAll()
        }
    }
}

struct EncounterRowView: View {
    let encounter: Encounter

    private var photoCount: Int {
        (encounter.photos ?? []).isEmpty ? 1 : (encounter.photos ?? []).count
    }

    private var personCount: Int {
        (encounter.people ?? []).count
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail + badges below
            VStack(spacing: 6) {
                if let imageData = encounter.displayImageData ?? encounter.thumbnailData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.coral.opacity(0.2), AppColors.teal.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .overlay {
                            Image(systemName: "person.2")
                                .font(.title2)
                                .foregroundStyle(AppColors.coral)
                        }
                }

                // Badges
                HStack(spacing: 4) {
                    if photoCount > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "photo.stack")
                            Text("\(photoCount)")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.softPurple))
                        .foregroundStyle(.white)
                    }

                    if personCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.fill")
                            Text("\(personCount)")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.teal))
                        .foregroundStyle(.white)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if encounter.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    if let occasion = encounter.occasion, !occasion.isEmpty {
                        Text(occasion)
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text("Encounter")
                            .font(.headline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                // People names
                if !(encounter.people ?? []).isEmpty {
                    Text((encounter.people ?? []).map(\.name).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                // Show tags
                if !(encounter.tags ?? []).isEmpty {
                    HStack(spacing: 4) {
                        ForEach((encounter.tags ?? []).prefix(3)) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tag.color.opacity(0.2))
                                .foregroundStyle(tag.color)
                                .clipShape(Capsule())
                        }
                        if (encounter.tags ?? []).count > 3 {
                            Text("+\((encounter.tags ?? []).count - 3)")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                }

                if let location = encounter.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(AppColors.teal)
                        .lineLimit(1)
                }

                Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .glassCard(intensity: .thin, cornerRadius: 14)
    }
}

// MARK: - Filter Sheet

struct EncounterFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTimeFilter: TimeFilter
    @Binding var selectedLocation: String?
    @Binding var selectedTagFilters: Set<UUID>
    @Binding var selectedSortOption: EncounterSortOption
    @Binding var filterFavoritesOnly: Bool

    let availableLocations: [String]
    let availableTags: [Tag]

    var body: some View {
        NavigationStack {
            List {
                // Favorites Filter
                Section {
                    Toggle(isOn: $filterFavoritesOnly) {
                        Label("Favorites Only", systemImage: "star.fill")
                            .foregroundStyle(.primary)
                    }
                    .tint(.yellow)
                }

                // Sort Options
                Section {
                    ForEach(EncounterSortOption.allCases) { option in
                        Button {
                            selectedSortOption = option
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundStyle(AppColors.teal)
                                    .frame(width: 24)
                                Text(option.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColors.coral)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Sort By")
                        .foregroundStyle(.secondary)
                }

                // Time Filter
                Section {
                    ForEach(TimeFilter.allCases) { filter in
                        Button {
                            selectedTimeFilter = filter
                        } label: {
                            HStack {
                                Text(filter.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedTimeFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColors.coral)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Time Period")
                        .foregroundStyle(.secondary)
                }

                // Location Filter
                if !availableLocations.isEmpty {
                    Section {
                        Button {
                            selectedLocation = nil
                        } label: {
                            HStack {
                                Text("All Locations")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedLocation == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppColors.coral)
                                        .fontWeight(.semibold)
                                }
                            }
                        }

                        ForEach(availableLocations, id: \.self) { location in
                            Button {
                                selectedLocation = location
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(AppColors.teal)
                                    Text(location)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedLocation == location {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppColors.coral)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Location")
                            .foregroundStyle(.secondary)
                    }
                }

                // Tag Filter
                if !availableTags.isEmpty {
                    Section {
                        ForEach(availableTags) { tag in
                            Button {
                                if selectedTagFilters.contains(tag.id) {
                                    selectedTagFilters.remove(tag.id)
                                } else {
                                    selectedTagFilters.insert(tag.id)
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 12, height: 12)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTagFilters.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppColors.coral)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Tags")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Filter Encounters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedSortOption = .dateNewest
                        selectedTimeFilter = .all
                        selectedLocation = nil
                        selectedTagFilters.removeAll()
                        filterFavoritesOnly = false
                    }
                    .foregroundStyle(AppColors.coral)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    EncounterListView()
}
