import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allEncounters: [Encounter]
    @Bindable var person: Person
    @State private var isEditing = false
    @State private var selectedEncounter: Encounter?
    @State private var showFaceSourcePhoto = false
    @State private var selectedEmbedding: FaceEmbedding?
    @State private var showDeleteConfirmation = false

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
                personalDetailsSection
                encountersSection
                facesSection
            }
            .padding()
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
                            NavigationLink(value: encounter) {
                                EncounterThumbnail(encounter: encounter)
                            }
                        }
                    }
                }

                if person.encounters.count > 5 {
                    Text("+ \(person.encounters.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationDestination(for: Encounter.self) { encounter in
                EncounterDetailView(encounter: encounter)
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

#Preview {
    NavigationStack {
        PersonDetailView(person: Person(name: "John Doe"))
    }
}
