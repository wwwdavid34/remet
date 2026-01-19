import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var allPeople: [Person]
    @Query(sort: \Encounter.date, order: .reverse) private var allEncounters: [Encounter]

    @State private var searchText = ""
    @State private var selectedTab: SearchTab = .all

    // Memory scan state
    @State private var showMemoryScan = false
    @State private var showImageMatch = false
    @State private var showPremiumRequired = false

    private var subscriptionManager: SubscriptionManager { .shared }

    enum SearchTab: String, CaseIterable {
        case all = "All"
        case people = "People"
        case encounters = "Encounters"
    }

    private var filteredPeople: [Person] {
        guard !searchText.isEmpty else { return [] }
        return allPeople.filter { person in
            person.name.localizedCaseInsensitiveContains(searchText) ||
            person.notes?.localizedCaseInsensitiveContains(searchText) == true ||
            person.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var filteredEncounters: [Encounter] {
        guard !searchText.isEmpty else { return [] }
        return allEncounters.filter { encounter in
            encounter.occasion?.localizedCaseInsensitiveContains(searchText) == true ||
            encounter.location?.localizedCaseInsensitiveContains(searchText) == true ||
            encounter.people.contains { $0.name.localizedCaseInsensitiveContains(searchText) } ||
            encounter.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var hasResults: Bool {
        !filteredPeople.isEmpty || !filteredEncounters.isEmpty
    }

    private var showPeople: Bool {
        selectedTab == .all || selectedTab == .people
    }

    private var showEncounters: Bool {
        selectedTab == .all || selectedTab == .encounters
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if searchText.isEmpty {
                    emptySearchState
                } else if !hasResults {
                    noResultsState
                } else {
                    searchResults
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search people, encounters, tags...")
            .fullScreenCover(isPresented: $showMemoryScan) {
                MemoryScanView()
            }
            .sheet(isPresented: $showImageMatch) {
                EphemeralMatchView()
            }
            .sheet(isPresented: $showPremiumRequired) {
                PaywallView()
            }
        }
    }

    @ViewBuilder
    private var emptySearchState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(AppColors.textMuted)

            Text("Search Everything")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary)

            Text("Find people, encounters, and tags across your entire collection.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Quick scan buttons
            VStack(spacing: 12) {
                Text("Or identify someone quickly")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 16) {
                    // Live Memory Scan (free)
                    Button {
                        showMemoryScan = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "eye")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Scan")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Use camera")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(AppColors.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel("Live Memory Scan")
                    .accessibilityHint("Scan a face with your camera to identify someone")

                    // Ephemeral Image Match (premium)
                    Button {
                        if subscriptionManager.isPremium {
                            showImageMatch = true
                        } else {
                            showPremiumRequired = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("From Photo")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(subscriptionManager.isPremium ? "Pick image" : "Premium")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(subscriptionManager.isPremium ? AppColors.softPurple : AppColors.textMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityLabel("Quick Match from Photo")
                    .accessibilityHint(subscriptionManager.isPremium ? "Select a photo to identify a face" : "Premium feature - upgrade to unlock")
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var noResultsState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(AppColors.textMuted)

            Text("No Results")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textPrimary)

            Text("No matches found for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Category", selection: $selectedTab) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Text(tabLabel(for: tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            List {
                // People section
                if showPeople && !filteredPeople.isEmpty {
                    Section {
                        ForEach(filteredPeople) { person in
                            NavigationLink(value: person) {
                                PersonSearchRow(person: person, searchText: searchText)
                            }
                        }
                    } header: {
                        if selectedTab == .all {
                            Label("People (\(filteredPeople.count))", systemImage: "person.fill")
                                .foregroundStyle(AppColors.coral)
                        }
                    }
                }

                // Encounters section
                if showEncounters && !filteredEncounters.isEmpty {
                    Section {
                        ForEach(filteredEncounters) { encounter in
                            NavigationLink(value: encounter) {
                                EncounterSearchRow(encounter: encounter, searchText: searchText)
                            }
                        }
                    } header: {
                        if selectedTab == .all {
                            Label("Encounters (\(filteredEncounters.count))", systemImage: "person.2.crop.square.stack")
                                .foregroundStyle(AppColors.teal)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationDestination(for: Person.self) { person in
            PersonDetailView(person: person)
        }
        .navigationDestination(for: Encounter.self) { encounter in
            EncounterDetailView(encounter: encounter)
        }
    }

    private func tabLabel(for tab: SearchTab) -> String {
        switch tab {
        case .all:
            let total = filteredPeople.count + filteredEncounters.count
            return total > 0 ? "All (\(total))" : "All"
        case .people:
            return filteredPeople.count > 0 ? "People (\(filteredPeople.count))" : "People"
        case .encounters:
            return filteredEncounters.count > 0 ? "Encounters (\(filteredEncounters.count))" : "Encounters"
        }
    }
}

// MARK: - Search Row Views

struct PersonSearchRow: View {
    let person: Person
    let searchText: String

    var body: some View {
        HStack(spacing: 12) {
            // Face thumbnail
            if let embedding = person.embeddings.first,
               let uiImage = UIImage(data: embedding.faceCropData) {
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
                            .foregroundStyle(AppColors.coral)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                if !person.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(person.tags.prefix(3)) { tag in
                            Text(tag.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tag.color.opacity(0.2))
                                .foregroundStyle(tag.color)
                                .clipShape(Capsule())
                        }
                    }
                }

                if let notes = person.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EncounterSearchRow: View {
    let encounter: Encounter
    let searchText: String

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageData = encounter.displayImageData ?? encounter.thumbnailData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.coral.opacity(0.2), AppColors.teal.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "person.2")
                            .foregroundStyle(AppColors.teal)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(encounter.occasion ?? "Encounter")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 8) {
                    if let location = encounter.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .foregroundStyle(AppColors.teal)
                    }

                    Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(AppColors.textMuted)
                }
                .font(.caption)

                if !encounter.people.isEmpty {
                    Text(encounter.people.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GlobalSearchView()
        .modelContainer(for: [Person.self, Encounter.self], inMemory: true)
}
