import SwiftUI
import SwiftData

struct EncounterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]

    @State private var showScanner = false
    @State private var searchText = ""
    @State private var selectedTagFilters: Set<UUID> = []

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

    var filteredEncounters: [Encounter] {
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

        return result
    }

    var hasAnyTags: Bool {
        !tagsInUse.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if encounters.isEmpty {
                    emptyStateView
                } else {
                    encountersList
                }
            }
            .navigationTitle("Encounters")
            .searchable(text: $searchText, prompt: "Search occasions, locations, people")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                EncounterScannerView()
            }
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
                    NavigationLink(value: encounter) {
                        EncounterRowView(encounter: encounter)
                    }
                }
                .onDelete(perform: deleteEncounters)
            }
        }
        .navigationDestination(for: Encounter.self) { encounter in
            EncounterDetailView(encounter: encounter)
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
                        .foregroundStyle(AppColors.textPrimary)
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

#Preview {
    EncounterListView()
}
