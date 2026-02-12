import SwiftUI
import SwiftData

struct PersonMergeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let people: [Person]
    let onMerged: () -> Void

    @State private var primaryId: UUID
    @State private var combineNotes = true
    @State private var isMerging = false

    init(people: [Person], onMerged: @escaping () -> Void) {
        self.people = people.sorted { ($0.embeddings ?? []).count > ($1.embeddings ?? []).count }
        self.onMerged = onMerged
        // Default primary: person with most face samples (best face data)
        _primaryId = State(initialValue: people.max(by: {
            ($0.embeddings ?? []).count < ($1.embeddings ?? []).count
        })?.id ?? people.first?.id ?? UUID())
    }

    private var primaryPerson: Person? {
        people.first { $0.id == primaryId }
    }

    private var secondaryPeople: [Person] {
        people.filter { $0.id != primaryId }
    }

    private var totalFaceSamples: Int {
        people.reduce(0) { $0 + ($1.embeddings ?? []).count }
    }

    private var totalEncounters: Int {
        var ids = Set<UUID>()
        for p in people {
            for e in p.encounters ?? [] { ids.insert(e.id) }
        }
        return ids.count
    }

    private var totalTags: Int {
        var ids = Set<UUID>()
        for p in people {
            for t in p.tags ?? [] { ids.insert(t.id) }
        }
        return ids.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Primary person picker
                Section {
                    ForEach(people) { person in
                        Button {
                            primaryId = person.id
                        } label: {
                            HStack(spacing: 12) {
                                personThumbnail(person)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    if let relationship = person.relationship {
                                        Text(relationship)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\((person.embeddings ?? []).count) faces · \((person.encounters ?? []).count) encounters")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.teal)
                                }

                                Spacer()

                                if person.id == primaryId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.teal)
                                        .font(.title3)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Keep name and details from")
                } footer: {
                    Text("The selected person's name, relationship, and contact info will be used. Empty fields will be filled from others.")
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
                    Text("Appends notes from all people into one.")
                }

                // Preview
                Section("Merged Result") {
                    HStack {
                        Label("\(totalFaceSamples)", systemImage: "face.smiling")
                        Spacer()
                        Text("face samples")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("\(totalEncounters)", systemImage: "person.2.crop.square.stack")
                        Spacer()
                        Text("encounters")
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
                            Text("Merge \(people.count) People")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isMerging)
                    .foregroundStyle(AppColors.coral)
                }
            }
            .navigationTitle("Merge People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func personThumbnail(_ person: Person) -> some View {
        if let embedding = person.profileEmbedding,
           let image = UIImage(data: embedding.faceCropData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(AppColors.warmGradient)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(AppColors.coral)
                }
        }
    }

    private func performMerge() {
        guard let primary = primaryPerson else { return }
        guard !secondaryPeople.isEmpty else { return }
        isMerging = true

        let service = EncounterManagementService(modelContext: modelContext)
        service.mergePeople(
            primary: primary,
            secondaries: secondaryPeople,
            combineNotes: combineNotes
        )
        try? modelContext.save()

        isMerging = false
        dismiss()
        DispatchQueue.main.async {
            onMerged()
        }
    }
}

// MARK: - Person Merge Picker

/// Picker to select a person to merge with (used from PersonDetailView)
struct PersonMergePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let currentPerson: Person
    let allPeople: [Person]
    let onSelect: (Person) -> Void

    @State private var searchText = ""

    private var otherPeople: [Person] {
        let others = allPeople.filter { $0.id != currentPerson.id }
        guard !searchText.isEmpty else { return others }
        return others.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(otherPeople) { person in
                Button {
                    onSelect(person)
                } label: {
                    HStack(spacing: 12) {
                        if let embedding = person.profileEmbedding,
                           let image = UIImage(data: embedding.faceCropData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(AppColors.warmGradient)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(AppColors.coral)
                                }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name)
                                .fontWeight(.medium)
                            if let relationship = person.relationship {
                                Text(relationship)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)

                        Spacer()

                        Text("\((person.embeddings ?? []).count) faces")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search people")
            .navigationTitle("Merge \(currentPerson.name) with...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
