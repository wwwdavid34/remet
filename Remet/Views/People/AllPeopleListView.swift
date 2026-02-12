import SwiftUI
import SwiftData

enum PersonSortOption: String, CaseIterable, Identifiable {
    case nameAZ = "Name A-Z"
    case nameZA = "Name Z-A"
    case newestFirst = "Newest First"
    case mostEncounters = "Most Encounters"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nameAZ: return "textformat.abc"
        case .nameZA: return "textformat.abc"
        case .newestFirst: return "clock"
        case .mostEncounters: return "person.2.fill"
        }
    }
}

struct AllPeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]

    @State private var searchText = ""
    @State private var selectedTagFilters: Set<UUID> = []
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedSortOption: PersonSortOption = .nameAZ
    @State private var showFilters = false
    @State private var filterRefreshId = UUID()

    // Multi-select for merge/delete
    @State private var isSelectMode = false
    @State private var selectedPersonIds: Set<UUID> = []
    @State private var showMergeSheet = false
    @State private var showDeleteSelectedConfirmation = false

    /// Tags that are currently assigned to at least one person
    var tagsInUse: [Tag] {
        var seenIds = Set<UUID>()
        var result: [Tag] = []
        for person in people {
            for tag in person.tags ?? [] {
                if !seenIds.contains(tag.id) {
                    seenIds.insert(tag.id)
                    result.append(tag)
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    var filteredPeople: [Person] {
        _ = filterRefreshId

        var result = people.filter { !$0.isMe }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { person in
                person.name.localizedCaseInsensitiveContains(searchText) ||
                person.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                (person.tags ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Filter by selected tags
        if !selectedTagFilters.isEmpty {
            result = result.filter { person in
                let personTagIds = Set((person.tags ?? []).map { $0.id })
                return !selectedTagFilters.isDisjoint(with: personTagIds)
            }
        }

        // Filter by time
        if selectedTimeFilter != .all, let dateRange = selectedTimeFilter.dateRange {
            result = result.filter { person in
                person.createdAt >= dateRange.start && person.createdAt <= dateRange.end
            }
        }

        // Apply sorting
        switch selectedSortOption {
        case .nameAZ:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .newestFirst:
            result.sort { $0.createdAt > $1.createdAt }
        case .mostEncounters:
            result.sort { ($0.encounters ?? []).count > ($1.encounters ?? []).count }
        }

        return result
    }

    var hasAnyTags: Bool {
        !tagsInUse.isEmpty
    }

    var hasActiveFilters: Bool {
        selectedTimeFilter != .all || !selectedTagFilters.isEmpty || selectedSortOption != .nameAZ
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedTimeFilter != .all { count += 1 }
        if selectedSortOption != .nameAZ { count += 1 }
        count += selectedTagFilters.count
        return count
    }

    var body: some View {
        List {
            if people.filter({ !$0.isMe }).isEmpty {
                ContentUnavailableView {
                    Label("No People Yet", systemImage: "person.3")
                } description: {
                    Text("People you've met will appear here.")
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

                ForEach(filteredPeople) { person in
                    if isSelectMode {
                        Button {
                            toggleSelection(person.id)
                        } label: {
                            HStack {
                                Image(systemName: selectedPersonIds.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedPersonIds.contains(person.id) ? AppColors.teal : .secondary)
                                    .font(.title3)
                                PersonRow(person: person)
                            }
                        }
                        .foregroundStyle(.primary)
                    } else {
                        NavigationLink {
                            PersonDetailView(person: person)
                        } label: {
                            PersonRow(person: person)
                        }
                    }
                }
                .onDelete(perform: isSelectMode ? nil : deletePeople)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectMode && !selectedPersonIds.isEmpty {
                selectModeBar
            }
        }
        .alert("Delete \(selectedPersonIds.count) \(selectedPersonIds.count == 1 ? "Person" : "People")?", isPresented: $showDeleteSelectedConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedPeople()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .navigationTitle("All People")
        .searchable(text: $searchText, prompt: "Search name, notes, tags")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !people.filter({ !$0.isMe }).isEmpty {
                    Button {
                        withAnimation {
                            isSelectMode.toggle()
                            if !isSelectMode {
                                selectedPersonIds.removeAll()
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
            filterRefreshId = UUID()
        }) {
            PersonFilterSheet(
                selectedTimeFilter: $selectedTimeFilter,
                selectedTagFilters: $selectedTagFilters,
                selectedSortOption: $selectedSortOption,
                availableTags: tagsInUse
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMergeSheet) {
            let selected = people.filter { selectedPersonIds.contains($0.id) }
            if selected.count >= 2 {
                PersonMergeView(people: selected) {
                    withAnimation {
                        isSelectMode = false
                        selectedPersonIds.removeAll()
                    }
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedPersonIds.contains(id) {
            selectedPersonIds.remove(id)
        } else {
            selectedPersonIds.insert(id)
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
                .background(selectedPersonIds.count >= 2 ? AppColors.teal : AppColors.teal.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selectedPersonIds.count < 2)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            let person = filteredPeople[index]
            modelContext.delete(person)
        }
        try? modelContext.save()
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
}

// MARK: - Filter Sheet

struct PersonFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTimeFilter: TimeFilter
    @Binding var selectedTagFilters: Set<UUID>
    @Binding var selectedSortOption: PersonSortOption

    let availableTags: [Tag]

    var body: some View {
        NavigationStack {
            List {
                // Sort Options
                Section {
                    ForEach(PersonSortOption.allCases) { option in
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
                    Text("Added")
                        .foregroundStyle(.secondary)
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
            .navigationTitle("Filter People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedSortOption = .nameAZ
                        selectedTimeFilter = .all
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
