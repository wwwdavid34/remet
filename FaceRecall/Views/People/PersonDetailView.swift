import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allEncounters: [Encounter]
    @Bindable var person: Person
    @State private var isEditing = false
    @State private var selectedEncounter: Encounter?
    @State private var showEncounterDetail = false
    @State private var showFaceSourcePhoto = false
    @State private var selectedEmbedding: FaceEmbedding?
    @State private var showDeleteConfirmation = false
    @State private var showTagPicker = false
    @State private var selectedTags: [Tag] = []
    @State private var showAddNoteSheet = false
    @State private var showQuiz = false
    @State private var expandedSections: Set<String> = ["talkingPoints", "timeline"]

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    private func findEncounter(for embedding: FaceEmbedding) -> Encounter? {
        guard let encounterId = embedding.encounterId else { return nil }
        return allEncounters.first { $0.id == encounterId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                quickActionsSection
                tagsSection
                talkingPointsSection
                interestsSection
                howWeMetSection
                interactionTimelineSection
                personalDetailsSection
                encountersSection
                facesSection
            }
            .padding()
            .onAppear {
                selectedTags = person.tags
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isEditing.toggle()
                    } label: {
                        Label(isEditing ? "Done Editing" : "Edit Details", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Person", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Person", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(person)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \(person.name)? This will also remove all their face samples.")
        }
        .sheet(isPresented: $showEncounterDetail) {
            if let encounter = selectedEncounter {
                NavigationStack {
                    EncounterDetailView(encounter: encounter)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showEncounterDetail = false
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showTagPicker, onDismiss: {
            person.tags = selectedTags
        }) {
            TagPickerView(selectedTags: $selectedTags, title: "Tags for \(person.name)")
        }
        .sheet(isPresented: $showAddNoteSheet) {
            AddNoteSheet(person: person)
        }
        .fullScreenCover(isPresented: $showQuiz) {
            FaceQuizView(people: [person])
        }
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            Button {
                showAddNoteSheet = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.title3)
                    Text("Add Note")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                showQuiz = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                    Text("Practice")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(person.embeddings.isEmpty)

            if let phone = person.phone, let url = URL(string: "tel:\(phone)") {
                Link(destination: url) {
                    VStack(spacing: 4) {
                        Image(systemName: "phone")
                            .font(.title3)
                        Text("Call")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)

            InlineTagEditor(
                tags: person.tags,
                onAddTag: {
                    selectedTags = person.tags
                    showTagPicker = true
                },
                onRemoveTag: { tag in
                    person.tags.removeAll { $0.id == tag.id }
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var talkingPointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Talking Points")
                    .font(.headline)
                Spacer()
                Button {
                    addTalkingPoint()
                } label: {
                    Image(systemName: "plus.circle")
                }
            }

            if person.talkingPoints.isEmpty {
                Text("Add talking points to remember for your next conversation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(person.talkingPoints.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top) {
                            Image(systemName: "lightbulb")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(point)
                                .font(.subheadline)
                            Spacer()
                            Button {
                                removeTalkingPoint(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Interests")
                    .font(.headline)
                Spacer()
                Button {
                    addInterest()
                } label: {
                    Image(systemName: "plus.circle")
                }
            }

            if person.interests.isEmpty {
                Text("Add interests to find common ground")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(person.interests.enumerated()), id: \.offset) { index, interest in
                        HStack(spacing: 4) {
                            Text(interest)
                                .font(.caption)
                            Button {
                                removeInterest(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var howWeMetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How We Met")
                .font(.headline)

            if isEditing {
                TextField("Where did you meet?", text: Binding(
                    get: { person.howWeMet ?? "" },
                    set: { person.howWeMet = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            } else if let howWeMet = person.howWeMet, !howWeMet.isEmpty {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundStyle(.secondary)
                    Text(howWeMet)
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Button {
                    isEditing = true
                } label: {
                    Text("Add how you met")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var interactionTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Interaction Timeline")
                    .font(.headline)
                Spacer()
                Button {
                    showAddNoteSheet = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }

            if person.interactionNotes.isEmpty && person.encounters.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No interactions yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 12) {
                    // Show recent notes
                    ForEach(person.recentNotes) { note in
                        InteractionNoteRow(note: note, onDelete: {
                            deleteNote(note)
                        })
                    }

                    // Show encounters in timeline
                    ForEach(person.encounters.prefix(3)) { encounter in
                        EncounterTimelineRow(encounter: encounter) {
                            selectedEncounter = encounter
                            showEncounterDetail = true
                        }
                    }
                }
            }
        }
    }

    // Helper methods for editing
    private func addTalkingPoint() {
        let alert = UIAlertController(title: "Add Talking Point", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Something to discuss next time" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                var points = person.talkingPoints
                points.append(text)
                person.talkingPoints = points
            }
        })
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }

    private func removeTalkingPoint(at index: Int) {
        var points = person.talkingPoints
        points.remove(at: index)
        person.talkingPoints = points
    }

    private func addInterest() {
        let alert = UIAlertController(title: "Add Interest", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "e.g., Photography, Hiking" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                var interests = person.interests
                interests.append(text)
                person.interests = interests
            }
        })
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }

    private func removeInterest(at index: Int) {
        var interests = person.interests
        interests.remove(at: index)
        person.interests = interests
    }

    private func deleteNote(_ note: InteractionNote) {
        modelContext.delete(note)
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            if let firstEmbedding = person.embeddings.first,
               let image = UIImage(data: firstEmbedding.faceCropData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.secondary)
            }

            if isEditing {
                TextField("Name", text: $person.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)
            } else {
                Text(person.name)
                    .font(.title)
                    .fontWeight(.bold)
            }

            if let company = person.company, !isEditing {
                Text(company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var personalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Details")
                .font(.headline)

            if isEditing {
                editableDetails
            } else {
                readOnlyDetails
            }
        }
    }

    @ViewBuilder
    private var readOnlyDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let relationship = person.relationship {
                InfoRow(icon: "person.2", title: "Relationship", value: relationship)
            }

            if let company = person.company {
                InfoRow(icon: "building.2", title: "Company", value: company)
            }

            if let jobTitle = person.jobTitle {
                InfoRow(icon: "briefcase", title: "Title", value: jobTitle)
            }

            if let email = person.email {
                InfoRow(icon: "envelope", title: "Email", value: email)
            }

            if let phone = person.phone {
                InfoRow(icon: "phone", title: "Phone", value: phone)
            }

            if let context = person.contextTag {
                InfoRow(icon: "tag", title: "Context", value: context)
            }

            InfoRow(
                icon: "calendar",
                title: "Added",
                value: person.createdAt.formatted(date: .abbreviated, time: .omitted)
            )

            if let lastSeen = person.lastSeenAt {
                InfoRow(
                    icon: "eye",
                    title: "Last Seen",
                    value: lastSeen.formatted(.relative(presentation: .named))
                )
            }

            InfoRow(
                icon: "person.2.crop.square.stack",
                title: "Encounters",
                value: "\(person.encounterCount)"
            )

            if let notes = person.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Notes", systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(notes)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var editableDetails: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.2")
                    .frame(width: 24)
                Picker("Relationship", selection: Binding(
                    get: { person.relationship ?? "" },
                    set: { person.relationship = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None").tag("")
                    Text("Family").tag("Family")
                    Text("Friend").tag("Friend")
                    Text("Coworker").tag("Coworker")
                    Text("Acquaintance").tag("Acquaintance")
                }
            }

            HStack {
                Image(systemName: "building.2")
                    .frame(width: 24)
                TextField("Company", text: Binding(
                    get: { person.company ?? "" },
                    set: { person.company = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                Image(systemName: "briefcase")
                    .frame(width: 24)
                TextField("Job Title", text: Binding(
                    get: { person.jobTitle ?? "" },
                    set: { person.jobTitle = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                Image(systemName: "envelope")
                    .frame(width: 24)
                TextField("Email", text: Binding(
                    get: { person.email ?? "" },
                    set: { person.email = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
            }

            HStack {
                Image(systemName: "phone")
                    .frame(width: 24)
                TextField("Phone", text: Binding(
                    get: { person.phone ?? "" },
                    set: { person.phone = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
            }

            HStack {
                Image(systemName: "tag")
                    .frame(width: 24)
                Picker("Context", selection: Binding(
                    get: { person.contextTag ?? "" },
                    set: { person.contextTag = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None").tag("")
                    Text("Work").tag("Work")
                    Text("School").tag("School")
                    Text("Gym").tag("Gym")
                    Text("Church").tag("Church")
                    Text("Neighborhood").tag("Neighborhood")
                }
            }

            VStack(alignment: .leading) {
                Label("Notes", systemImage: "note.text")
                    .font(.subheadline)
                TextEditor(text: Binding(
                    get: { person.notes ?? "" },
                    set: { person.notes = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var encountersSection: some View {
        if !person.encounters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Encounters")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(person.encounters.prefix(5)) { encounter in
                            Button {
                                selectedEncounter = encounter
                                showEncounterDetail = true
                            } label: {
                                EncounterThumbnail(encounter: encounter)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if person.encounters.count > 5 {
                    Text("+ \(person.encounters.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var facesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Face Samples")
                    .font(.headline)

                Spacer()

                Text("\(person.embeddings.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if person.embeddings.isEmpty {
                Text("No face samples yet")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(person.embeddings) { embedding in
                        if let image = UIImage(data: embedding.faceCropData) {
                            let hasEncounter = findEncounter(for: embedding) != nil

                            ZStack(alignment: .bottomTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay {
                                        if !hasEncounter {
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        }
                                    }

                                // Show indicator if source encounter exists
                                if hasEncounter {
                                    Image(systemName: "photo.fill")
                                        .font(.caption2)
                                        .padding(4)
                                        .background(Circle().fill(.blue))
                                        .foregroundStyle(.white)
                                        .offset(x: 4, y: 4)
                                }
                            }
                            .onTapGesture {
                                if let encounter = findEncounter(for: embedding) {
                                    selectedEmbedding = embedding
                                    selectedEncounter = encounter
                                    showFaceSourcePhoto = true
                                }
                            }
                            .contextMenu {
                                if let encounter = findEncounter(for: embedding) {
                                    Button {
                                        selectedEmbedding = embedding
                                        selectedEncounter = encounter
                                        showFaceSourcePhoto = true
                                    } label: {
                                        Label("View Source Photo", systemImage: "photo")
                                    }
                                } else {
                                    Text("No linked encounter")
                                }
                                Button(role: .destructive) {
                                    deleteEmbedding(embedding)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .padding(3)
                            .background(Circle().fill(.blue))
                            .foregroundStyle(.white)
                        Text("Has source photo")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .sheet(isPresented: $showFaceSourcePhoto) {
            if let encounter = selectedEncounter {
                FaceSourcePhotoView(encounter: encounter, person: person)
            }
        }
    }

    private func deleteEmbedding(_ embedding: FaceEmbedding) {
        modelContext.delete(embedding)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct EncounterThumbnail: View {
    let encounter: Encounter

    var body: some View {
        VStack {
            if let imageData = encounter.displayImageData ?? encounter.thumbnailData,
               let image = UIImage(data: imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Photo count badge for multi-photo encounters
                    if encounter.photos.count > 1 {
                        Text("\(encounter.photos.count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(3)
                            .background(Circle().fill(.purple))
                            .foregroundStyle(.white)
                            .offset(x: 4, y: -4)
                    }
                }
            }

            if let occasion = encounter.occasion {
                Text(occasion)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .frame(width: 80)
    }
}

// MARK: - Face Source Photo View
struct FaceSourcePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let encounter: Encounter
    let person: Person

    @State private var showEncounterDetail = false
    @State private var currentPhotoIndex = 0

    // Find photos that contain this person's face
    private var photosWithPerson: [(photo: EncounterPhoto, boxes: [FaceBoundingBox])] {
        encounter.photos.compactMap { photo in
            let matchingBoxes = photo.faceBoundingBoxes.filter { $0.personId == person.id }
            if !matchingBoxes.isEmpty {
                return (photo, matchingBoxes)
            }
            return nil
        }
    }

    // For legacy single-photo encounters
    private var legacyBoxes: [FaceBoundingBox] {
        encounter.faceBoundingBoxes.filter { $0.personId == person.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !photosWithPerson.isEmpty {
                        // Multi-photo encounter - show photos containing this person
                        multiPhotoSection
                    } else if let imageData = encounter.displayImageData,
                              let image = UIImage(data: imageData) {
                        // Legacy single-photo encounter
                        legacyPhotoSection(image: image)
                    }

                    // Encounter info card
                    encounterInfoCard

                    // View Full Encounter button
                    Button {
                        showEncounterDetail = true
                    } label: {
                        Label("View Full Encounter", systemImage: "arrow.right.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Source Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEncounterDetail) {
                NavigationStack {
                    EncounterDetailView(encounter: encounter)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showEncounterDetail = false
                                }
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var multiPhotoSection: some View {
        VStack(spacing: 8) {
            if photosWithPerson.count > 1 {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(Array(photosWithPerson.enumerated()), id: \.element.photo.id) { index, item in
                        photoWithOverlay(imageData: item.photo.imageData, boxes: item.photo.faceBoundingBoxes)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 350)

                Text("\(currentPhotoIndex + 1) of \(photosWithPerson.count) photos with \(person.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let first = photosWithPerson.first {
                photoWithOverlay(imageData: first.photo.imageData, boxes: first.photo.faceBoundingBoxes)
            }
        }
    }

    @ViewBuilder
    private func legacyPhotoSection(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    GeometryReader { geometry in
                        ForEach(encounter.faceBoundingBoxes) { box in
                            FaceSourceBoxOverlay(
                                box: box,
                                imageSize: image.size,
                                viewSize: geometry.size,
                                highlightPersonId: person.id
                            )
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func photoWithOverlay(imageData: Data, boxes: [FaceBoundingBox]) -> some View {
        if let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    GeometryReader { geometry in
                        ForEach(boxes) { box in
                            FaceSourceBoxOverlay(
                                box: box,
                                imageSize: image.size,
                                viewSize: geometry.size,
                                highlightPersonId: person.id
                            )
                        }
                    }
                }
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var encounterInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let occasion = encounter.occasion {
                Label(occasion, systemImage: "star")
            }
            if let location = encounter.location {
                Label(location, systemImage: "mappin")
            }
            Label(encounter.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")

            if encounter.photos.count > 1 {
                Label("\(encounter.photos.count) photos in this encounter", systemImage: "photo.stack")
            }

            if encounter.people.count > 1 {
                Label("\(encounter.people.count) people tagged", systemImage: "person.2")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FaceSourceBoxOverlay: View {
    let box: FaceBoundingBox
    let imageSize: CGSize
    let viewSize: CGSize
    let highlightPersonId: UUID

    var body: some View {
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        let x = offsetX + box.x * scaledWidth
        let y = offsetY + (1 - box.y - box.height) * scaledHeight
        let width = box.width * scaledWidth
        let height = box.height * scaledHeight

        let isHighlighted = box.personId == highlightPersonId
        let boxColor: Color = isHighlighted ? .yellow : (box.personId != nil ? .green : .orange)

        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(boxColor, lineWidth: isHighlighted ? 4 : 2)

            if let name = box.personName {
                Text(name)
                    .font(.caption2)
                    .fontWeight(isHighlighted ? .bold : .medium)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(boxColor)
                    .foregroundStyle(isHighlighted ? .black : .white)
                    .clipShape(Capsule())
                    .offset(y: 16)
            }
        }
        .frame(width: width, height: height)
        .position(x: x + width / 2, y: y + height / 2)
    }
}

// MARK: - Interaction Note Row

struct InteractionNoteRow: View {
    let note: InteractionNote
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: note.category.icon)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(6)
                .background(Circle().fill(categoryColor))

            VStack(alignment: .leading, spacing: 4) {
                Text(note.content)
                    .font(.subheadline)

                Text(note.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var categoryColor: Color {
        switch note.category {
        case .conversation: return .blue
        case .interest: return .yellow
        case .reminder: return .orange
        case .followUp: return .purple
        case .milestone: return .green
        case .general: return .gray
        }
    }
}

// MARK: - Encounter Timeline Row

struct EncounterTimelineRow: View {
    let encounter: Encounter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let imageData = encounter.thumbnailData ?? encounter.displayImageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(encounter.occasion ?? "Encounter")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Note Sheet

struct AddNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let person: Person

    @State private var noteContent = ""
    @State private var selectedCategory: InteractionCategory = .general

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(InteractionCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Note") {
                    TextEditor(text: $noteContent)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(noteContent.isEmpty)
                }
            }
        }
    }

    private func saveNote() {
        let note = InteractionNote(content: noteContent, category: selectedCategory)
        note.person = person
        person.interactionNotes.append(note)
        modelContext.insert(note)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(person: Person(name: "John Doe"))
    }
}
