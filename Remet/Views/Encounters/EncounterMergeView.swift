import SwiftUI
import SwiftData

struct EncounterMergeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let encounters: [Encounter]
    let onMerged: () -> Void

    @State private var primaryId: UUID
    @State private var combineNotes = true
    @State private var isMerging = false

    init(encounters: [Encounter], onMerged: @escaping () -> Void) {
        self.encounters = encounters.sorted { $0.date < $1.date }
        self.onMerged = onMerged
        // Default primary: encounter with earliest date (most likely has correct metadata)
        _primaryId = State(initialValue: encounters.min(by: { $0.date < $1.date })?.id ?? encounters[0].id)
    }

    private var primaryEncounter: Encounter? {
        encounters.first { $0.id == primaryId }
    }

    private var secondaryEncounters: [Encounter] {
        encounters.filter { $0.id != primaryId }
    }

    private var totalPhotos: Int {
        encounters.reduce(0) { $0 + max(($1.photos ?? []).count, $1.imageData != nil ? 1 : 0) }
    }

    private var totalPeople: Int {
        var ids = Set<UUID>()
        for e in encounters {
            for p in e.people ?? [] { ids.insert(p.id) }
        }
        return ids.count
    }

    private var totalTags: Int {
        var ids = Set<UUID>()
        for e in encounters {
            for t in e.tags ?? [] { ids.insert(t.id) }
        }
        return ids.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Primary encounter picker
                Section {
                    ForEach(encounters) { encounter in
                        Button {
                            primaryId = encounter.id
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
                                    if let location = encounter.location {
                                        Text(location)
                                            .font(.caption)
                                            .foregroundStyle(AppColors.teal)
                                    }
                                }

                                Spacer()

                                if encounter.id == primaryId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.teal)
                                        .font(.title3)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Keep metadata from")
                } footer: {
                    Text("The selected encounter's occasion, location, date, and coordinates will be used for the merged result.")
                }

                // Options
                Section {
                    Toggle(isOn: $combineNotes) {
                        Label("Combine notes", systemImage: "note.text")
                    }
                    .tint(AppColors.teal)
                } header: {
                    Text("Options")
                } footer: {
                    Text("Appends notes from all encounters into one.")
                }

                // Preview
                Section("Merged Result") {
                    HStack {
                        Label("\(totalPhotos)", systemImage: "photo.stack")
                        Spacer()
                        Text("photos")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("\(totalPeople)", systemImage: "person.2")
                        Spacer()
                        Text("people")
                            .foregroundStyle(.secondary)
                    }

                    if totalTags > 0 {
                        HStack {
                            Label("\(totalTags)", systemImage: "tag")
                            Spacer()
                            Text("tags")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Merge button
                Section {
                    Button {
                        performMerge()
                    } label: {
                        HStack {
                            Spacer()
                            if isMerging {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Merge \(encounters.count) Encounters")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isMerging)
                    .foregroundStyle(AppColors.coral)
                }
            }
            .navigationTitle("Merge Encounters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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

    private func performMerge() {
        guard let primary = primaryEncounter else { return }
        isMerging = true

        let service = EncounterManagementService(modelContext: modelContext)
        service.mergeEncounters(
            primary: primary,
            secondaries: secondaryEncounters,
            combineNotes: combineNotes
        )

        isMerging = false
        onMerged()
        dismiss()
    }
}
