import SwiftUI
import SwiftData

struct EncounterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]

    @State private var showScanner = false
    @State private var searchText = ""

    var filteredEncounters: [Encounter] {
        if searchText.isEmpty {
            return encounters
        }
        return encounters.filter { encounter in
            encounter.occasion?.localizedCaseInsensitiveContains(searchText) == true ||
            encounter.location?.localizedCaseInsensitiveContains(searchText) == true ||
            encounter.people.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
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
        ContentUnavailableView(
            "No Encounters Yet",
            systemImage: "person.2.crop.square.stack",
            description: Text("Scan your photos to record encounters with people")
        )
    }

    @ViewBuilder
    private var encountersList: some View {
        List {
            ForEach(filteredEncounters) { encounter in
                NavigationLink(value: encounter) {
                    EncounterRowView(encounter: encounter)
                }
            }
            .onDelete(perform: deleteEncounters)
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

    private var faceCount: Int {
        encounter.totalFaceCount
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
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 70, height: 70)
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
                        .background(Capsule().fill(.purple))
                        .foregroundStyle(.white)
                    }

                    if faceCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.fill")
                            Text("\(faceCount)")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(3)
                        .background(Capsule().fill(.blue))
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
                        .foregroundStyle(.secondary)
                }

                // People names
                if !encounter.people.isEmpty {
                    Text(encounter.people.map(\.name).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    if let location = encounter.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                    }

                    Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EncounterListView()
}
