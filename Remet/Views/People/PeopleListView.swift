import SwiftUI
import SwiftData
import UIKit

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var searchText = ""
    @State private var showAddPerson = false
    @State private var selectedTagFilters: Set<UUID> = []
    @State private var showQuickCapture = false

    /// Tags that are currently assigned to at least one person
    var tagsInUse: [Tag] {
        var seenIds = Set<UUID>()
        var result: [Tag] = []
        for person in people {
            for tag in person.tags {
                if !seenIds.contains(tag.id) {
                    seenIds.insert(tag.id)
                    result.append(tag)
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    /// The user's own profile (if exists)
    var meProfile: Person? {
        people.first { $0.isMe }
    }

    var filteredPeople: [Person] {
        var result = people

        // Hide "Me" if setting is disabled
        if !AppSettings.shared.showMeInPeopleList {
            result = result.filter { !$0.isMe }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // Filter by selected tags
        if !selectedTagFilters.isEmpty {
            result = result.filter { person in
                let personTagIds = Set(person.tags.map { $0.id })
                return !selectedTagFilters.isDisjoint(with: personTagIds)
            }
        }

        // Sort: "Me" first (if visible), then alphabetically
        result.sort { p1, p2 in
            if p1.isMe { return true }
            if p2.isMe { return false }
            return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
        }

        return result
    }

    var hasAnyTags: Bool {
        !tagsInUse.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    emptyStateView
                } else {
                    peopleList
                }
            }
            .navigationTitle("People")
            .searchable(text: $searchText, prompt: "Search people")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPerson = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPerson) {
                AddPersonView()
            }
            .fullScreenCover(isPresented: $showQuickCapture) {
                QuickCaptureView()
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "person.3",
            title: WittyCopy.emptyPeopleTitle,
            subtitle: WittyCopy.emptyPeopleSubtitle,
            actionTitle: "Add Someone",
            action: { showQuickCapture = true }
        )
    }

    @ViewBuilder
    private var peopleList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Tag filter bar
                if hasAnyTags {
                    TagFilterView(
                        availableTags: tagsInUse,
                        selectedTags: $selectedTagFilters,
                        onClear: { selectedTagFilters.removeAll() }
                    )
                }

                // People count
                HStack {
                    Text("\(filteredPeople.count) people")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                // People cards
                LazyVStack(spacing: 10) {
                    ForEach(filteredPeople) { person in
                        NavigationLink(value: person) {
                            PersonRow(person: person)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: Person.self) { person in
            PersonDetailView(person: person)
        }
    }

    private func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            let person = filteredPeople[index]
            modelContext.delete(person)
        }
    }
}

struct PersonRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let person: Person

    var body: some View {
        HStack(spacing: 14) {
            personThumbnail

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(person.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if person.isMe {
                        Text(String(localized: "You"))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.softPurple)
                            .clipShape(Capsule())
                    }
                }

                if let relationship = person.relationship, !person.isMe {
                    Text(relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if person.isMe {
                    Text(String(localized: "Your profile"))
                        .font(.caption)
                        .foregroundStyle(AppColors.softPurple)
                }

                // Show tags
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
                        if person.tags.count > 3 {
                            Text("+\(person.tags.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if let lastSeen = person.lastSeenAt {
                    Text("Last viewed \(lastSeen.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                // Face count badge
                if person.embeddings.count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "face.smiling")
                            .font(.caption2)
                        Text("\(person.embeddings.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppColors.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.teal.opacity(0.12))
                    .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .glassCard(intensity: .thin, cornerRadius: 14)
    }

    @ViewBuilder
    private var personThumbnail: some View {
        if let firstEmbedding = person.embeddings.first,
           let image = UIImage(data: firstEmbedding.faceCropData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
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
                .frame(width: 54, height: 54)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
        }
    }
}

#Preview {
    PeopleListView()
        .modelContainer(for: Person.self, inMemory: true)
}
