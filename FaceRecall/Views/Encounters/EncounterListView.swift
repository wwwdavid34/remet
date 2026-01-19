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
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]

    @State private var showScanner = false
    @State private var searchText = ""
    @State private var selectedTagFilters: Set<UUID> = []
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedLocation: String? = nil
    @State private var selectedSortOption: EncounterSortOption = .dateNewest
    @State private var showFilters = false
    @State private var filterRefreshId = UUID()

    /// Tags that are currently assigned to at least one encounter
    var tagsInUse: [Tag] {
        var seenIds = Set<UUID>()
        var result: [Tag] = []
        for encounter in encounters {
            for tag in encounter.tags {
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
                encounter.people.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Filter by selected tags
        if !selectedTagFilters.isEmpty {
            result = result.filter { encounter in
                let encounterTagIds = Set(encounter.tags.map { $0.id })
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

        // Apply sorting
        switch selectedSortOption {
        case .dateNewest:
            result.sort { $0.date > $1.date }
        case .dateOldest:
            result.sort { $0.date < $1.date }
        case .mostPeople:
            result.sort { $0.people.count > $1.people.count }
        case .fewestPeople:
            result.sort { $0.people.count < $1.people.count }
        }

        return result
    }

    var hasAnyTags: Bool {
        !tagsInUse.isEmpty
    }

    var hasActiveFilters: Bool {
        selectedTimeFilter != .all || selectedLocation != nil || !selectedTagFilters.isEmpty || selectedSortOption != .dateNewest
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedTimeFilter != .all { count += 1 }
        if selectedLocation != nil { count += 1 }
        if selectedSortOption != .dateNewest { count += 1 }
        count += selectedTagFilters.count
        return count
    }

    var body: some View {
        Group {
            if encounters.isEmpty {
                emptyStateView
            } else {
                encountersList
            }
        }
        .navigationTitle(String(localized: "Encounters"))
        .searchable(text: $searchText, prompt: String(localized: "Search occasions, locations, people"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
        .sheet(isPresented: $showFilters, onDismiss: {
            // Force refresh when filter sheet closes
            filterRefreshId = UUID()
        }) {
            EncounterFilterSheet(
                selectedTimeFilter: $selectedTimeFilter,
                selectedLocation: $selectedLocation,
                selectedTagFilters: $selectedTagFilters,
                selectedSortOption: $selectedSortOption,
                availableLocations: locationsInUse,
                availableTags: tagsInUse
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showScanner) {
            EncounterScannerView()
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "person.2.crop.square.stack",
            title: WittyCopy.emptyEncountersTitle,
            subtitle: WittyCopy.emptyEncountersSubtitle,
            actionTitle: "Add Encounter",
            action: { showScanner = true }
        )
    }

    @ViewBuilder
    private var encountersList: some View {
        VStack(spacing: 0) {
            // Tag filter bar
            if hasAnyTags {
                TagFilterView(
                    availableTags: tagsInUse,
                    selectedTags: $selectedTagFilters,
                    onClear: { selectedTagFilters.removeAll() }
                )
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }

            List {
                ForEach(filteredEncounters) { encounter in
                    NavigationLink {
                        EncounterDetailView(encounter: encounter)
                    } label: {
                        EncounterRowView(encounter: encounter)
                    }
                }
                .onDelete(perform: deleteEncounters)
            }
        }
    }

    private func deleteEncounters(at offsets: IndexSet) {
        for index in offsets {
            let encounter = filteredEncounters[index]
            modelContext.delete(encounter)
        }
    }
}

struct EncounterRowView: View {
    let encounter: Encounter

    private var photoCount: Int {
        encounter.photos.isEmpty ? 1 : encounter.photos.count
    }

    private var personCount: Int {
        encounter.people.count
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with badges
            ZStack(alignment: .bottomTrailing) {
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

                // Badges stack
                VStack(spacing: 2) {
                    if photoCount > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "photo.stack")
                            Text("\(photoCount)")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(3)
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
                        .padding(3)
                        .background(Capsule().fill(AppColors.teal))
                        .foregroundStyle(.white)
                    }
                }
                .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let occasion = encounter.occasion, !occasion.isEmpty {
                    Text(occasion)
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text("Encounter")
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                // People names
                if !encounter.people.isEmpty {
                    Text(encounter.people.map(\.name).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                // Show tags
                if !encounter.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(encounter.tags.prefix(3)) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tag.color.opacity(0.2))
                                .foregroundStyle(tag.color)
                                .clipShape(Capsule())
                        }
                        if encounter.tags.count > 3 {
                            Text("+\(encounter.tags.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textMuted)
                        }
                    }
                }

                HStack(spacing: 8) {
                    if let location = encounter.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .foregroundStyle(AppColors.teal)
                    }

                    Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(AppColors.textMuted)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Sheet

struct EncounterFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTimeFilter: TimeFilter
    @Binding var selectedLocation: String?
    @Binding var selectedTagFilters: Set<UUID>
    @Binding var selectedSortOption: EncounterSortOption

    let availableLocations: [String]
    let availableTags: [Tag]

    var body: some View {
        NavigationStack {
            List {
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
