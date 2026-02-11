import SwiftUI
import SwiftData

struct MovePhotosDestinationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Encounter.date, order: .reverse) private var allEncounters: [Encounter]

    let sourceEncounter: Encounter
    let selectedPhotoIds: Set<UUID>
    let onMoved: (_ sourceDeleted: Bool) -> Void

    @State private var searchText = ""
    @State private var isMoving = false

    private var availableEncounters: [Encounter] {
        let others = allEncounters.filter { $0.id != sourceEncounter.id }
        if searchText.isEmpty { return others }
        return others.filter { encounter in
            encounter.occasion?.localizedCaseInsensitiveContains(searchText) == true ||
            encounter.location?.localizedCaseInsensitiveContains(searchText) == true ||
            (encounter.people ?? []).contains { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Create new encounter (= split)
                Section {
                    Button {
                        moveToNewEncounter()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create New Encounter")
                                    .fontWeight(.medium)
                                Text("Split selected photos into a new encounter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .foregroundStyle(AppColors.teal)
                        }
                    }
                    .disabled(isMoving)
                }

                // Existing encounters
                if !availableEncounters.isEmpty {
                    Section("Move to Existing Encounter") {
                        ForEach(availableEncounters) { encounter in
                            Button {
                                moveToEncounter(encounter)
                            } label: {
                                HStack(spacing: 12) {
                                    encounterThumbnail(encounter)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(encounter.occasion ?? "Encounter")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text(encounter.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !(encounter.people ?? []).isEmpty {
                                            Text((encounter.people ?? []).prefix(3).map(\.name).joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Image(systemName: "photo")
                                        Text("\((encounter.photos ?? []).count)")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(isMoving)
                        }
                    }
                }
            }
            .navigationTitle("Move \(selectedPhotoIds.count) Photos")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search encounters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isMoving {
                    ProgressView("Moving photos...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @ViewBuilder
    private func encounterThumbnail(_ encounter: Encounter) -> some View {
        if let imageData = encounter.displayImageData ?? encounter.thumbnailData,
           let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.warmGradient)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "person.2")
                        .foregroundStyle(AppColors.coral)
                }
        }
    }

    private func moveToNewEncounter() {
        isMoving = true
        let service = EncounterManagementService(modelContext: modelContext)
        let result = service.movePhotosToNewEncounter(photoIds: selectedPhotoIds, from: sourceEncounter)
        isMoving = false
        dismiss()
        onMoved(result.sourceDeleted)
    }

    private func moveToEncounter(_ destination: Encounter) {
        isMoving = true
        let service = EncounterManagementService(modelContext: modelContext)
        let sourceDeleted = service.movePhotos(photoIds: selectedPhotoIds, from: sourceEncounter, to: destination)
        isMoving = false
        dismiss()
        onMoved(sourceDeleted)
    }
}
