import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @State private var searchText = ""
    @State private var showAddPerson = false

    var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        }
        return people.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No People Yet",
            systemImage: "person.3",
            description: Text("Import a photo to start adding people")
        )
    }

    @ViewBuilder
    private var peopleList: some View {
        List {
            ForEach(filteredPeople) { person in
                NavigationLink(value: person) {
                    PersonRow(person: person)
                }
            }
            .onDelete(perform: deletePeople)
        }
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
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            personThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.headline)

                if let relationship = person.relationship {
                    Text(relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastSeen = person.lastSeenAt {
                    Text("Last seen \(lastSeen.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text("\(person.embeddings.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemFill))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var personThumbnail: some View {
        if let firstEmbedding = person.embeddings.first,
           let image = UIImage(data: firstEmbedding.faceCropData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PeopleListView()
        .modelContainer(for: Person.self, inMemory: true)
}
