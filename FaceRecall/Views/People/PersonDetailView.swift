import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allEncounters: [Encounter]
    @Bindable var person: Person
    @State private var showEditSheet = false
    @State private var selectedEncounter: Encounter?
    @State private var faceSourceEncounter: Encounter?
    @State private var selectedEmbedding: FaceEmbedding?
    @State private var showDeleteConfirmation = false
    @State private var showTagPicker = false
    @State private var selectedTags: [Tag] = []
    @State private var showEncountersTimeline = false
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
            VStack(spacing: 20) {
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Details", systemImage: "pencil")
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
        .sheet(item: $selectedEncounter) { encounter in
            NavigationStack {
                EncounterDetailView(encounter: encounter)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                selectedEncounter = nil
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
        .sheet(isPresented: $showEditSheet) {
            EditPersonSheet(person: person)
        }
        .sheet(isPresented: $showEncountersTimeline) {
            EncountersTimelineSheet(person: person, onSelectEncounter: { encounter in
                showEncountersTimeline = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedEncounter = encounter
                }
            })
        }
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        if let phone = person.phone, let url = URL(string: "tel:\(phone)") {
            HStack(spacing: 12) {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.body)
                        Text("Call \(person.name.components(separatedBy: " ").first ?? person.name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.success.opacity(0.1))
                    .foregroundStyle(AppColors.success)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if let email = person.email, let emailUrl = URL(string: "mailto:\(email)") {
                    Link(destination: emailUrl) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.body)
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.teal.opacity(0.1))
                        .foregroundStyle(AppColors.teal)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        } else if let email = person.email, let emailUrl = URL(string: "mailto:\(email)") {
            Link(destination: emailUrl) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.body)
                    Text("Email \(person.name.components(separatedBy: " ").first ?? person.name)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.teal.opacity(0.1))
                .foregroundStyle(AppColors.teal)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(AppColors.coral)
                Text("Tags")
                    .font(.headline)
            }

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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppColors.warmYellow)
                    Text("Talking Points")
                        .font(.headline)
                }
                Spacer()
                Button {
                    addTalkingPoint()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.coral)
                }
            }

            if person.talkingPoints.isEmpty {
                Text("Add talking points to remember for your next conversation")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(person.talkingPoints.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(AppColors.warmYellow)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(point)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Button {
                                removeTalkingPoint(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppColors.textMuted)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
        }
    }

    @ViewBuilder
    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(AppColors.coral)
                    Text("Interests")
                        .font(.headline)
                }
                Spacer()
                Button {
                    addInterest()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.coral)
                }
            }

            if person.interests.isEmpty {
                Text("Add interests to find common ground")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(person.interests.enumerated()), id: \.offset) { index, interest in
                        HStack(spacing: 4) {
                            Text(interest)
                                .font(.caption)
                                .fontWeight(.medium)
                            Button {
                                removeInterest(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.teal.opacity(0.15))
                        .foregroundStyle(AppColors.teal)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var howWeMetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(AppColors.teal)
                    Text("How We Met")
                        .font(.headline)
                }
                Spacer()
                if person.howWeMet == nil || person.howWeMet?.isEmpty == true {
                    Button {
                        editHowWeMet()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppColors.coral)
                    }
                }
            }

            if let howWeMet = person.howWeMet, !howWeMet.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(AppColors.teal)
                        .padding(.top, 2)
                    Text(howWeMet)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button {
                        editHowWeMet()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(AppColors.textMuted)
                            .font(.caption)
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            } else {
                Text("Add where or how you first met")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var interactionTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(AppColors.softPurple)
                Text("Interaction Timeline")
                    .font(.headline)
            }

            if person.interactionNotes.isEmpty && person.encounters.isEmpty {
                Text("No interactions recorded yet")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
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

    private func editHowWeMet() {
        let currentValue = person.howWeMet ?? ""
        let alert = UIAlertController(title: "How We Met", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "e.g., Conference in NYC, Friend's party"
            textField.text = currentValue
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let text = alert.textFields?.first?.text {
                person.howWeMet = text.isEmpty ? nil : text
            }
        })
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
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
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.coral.opacity(0.3), AppColors.teal.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                    }
                    .shadow(radius: 4)
            }

            Text(person.name)
                .font(.title)
                .fontWeight(.bold)

            if let company = person.company {
                Text(company)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let relationship = person.relationship {
                Text(relationship)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.teal.opacity(0.15))
                    .foregroundStyle(AppColors.teal)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var personalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(AppColors.coral)
                    Text("Personal Details")
                        .font(.headline)
                }
                Spacer()
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(AppColors.coral)
                }
            }

            readOnlyDetails
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
                    title: "Last Viewed",
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
                        .foregroundStyle(AppColors.textSecondary)
                    Text(notes)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var encountersSection: some View {
        if !person.encounters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.crop.square.stack")
                            .foregroundStyle(AppColors.softPurple)
                        Text("Encounters")
                            .font(.headline)
                    }

                    Spacer()

                    Button {
                        showEncountersTimeline = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(.subheadline)
                            Text("\(person.encounters.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.softPurple.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .foregroundStyle(AppColors.softPurple)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(person.encounters.prefix(5)) { encounter in
                            Button {
                                selectedEncounter = encounter
                            } label: {
                                EncounterThumbnail(encounter: encounter)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var facesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "face.smiling")
                        .foregroundStyle(AppColors.coral)
                    Text("Face Samples")
                        .font(.headline)
                }

                Spacer()

                Text("\(person.embeddings.count)")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if person.embeddings.isEmpty {
                Text("No face samples yet")
                    .foregroundStyle(AppColors.textSecondary)
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
                                        .background(Circle().fill(AppColors.softPurple))
                                        .foregroundStyle(.white)
                                        .offset(x: 4, y: 4)
                                }
                            }
                            .onTapGesture {
                                if let encounter = findEncounter(for: embedding) {
                                    selectedEmbedding = embedding
                                    faceSourceEncounter = encounter
                                }
                            }
                            .contextMenu {
                                if let encounter = findEncounter(for: embedding) {
                                    Button {
                                        selectedEmbedding = embedding
                                        faceSourceEncounter = encounter
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
                            .background(Circle().fill(AppColors.softPurple))
                            .foregroundStyle(.white)
                        Text("Has source photo")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .sheet(item: $faceSourceEncounter) { encounter in
            FaceSourcePhotoView(encounter: encounter, person: person)
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
                .foregroundStyle(AppColors.teal)

            Text(title)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textPrimary)
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
                            .background(Circle().fill(AppColors.softPurple))
                            .foregroundStyle(.white)
                            .offset(x: 4, y: -4)
                    }
                }
            }

            if let occasion = encounter.occasion {
                Text(occasion)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
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
                    .foregroundStyle(AppColors.textSecondary)
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
                    .foregroundStyle(AppColors.warmYellow)
            }
            if let location = encounter.location {
                Label(location, systemImage: "mappin")
                    .foregroundStyle(AppColors.teal)
            }
            Label(encounter.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                .foregroundStyle(AppColors.textSecondary)

            if encounter.photos.count > 1 {
                Label("\(encounter.photos.count) photos in this encounter", systemImage: "photo.stack")
                    .foregroundStyle(AppColors.softPurple)
            }

            if encounter.people.count > 1 {
                Label("\(encounter.people.count) people tagged", systemImage: "person.2")
                    .foregroundStyle(AppColors.coral)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
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
                    .foregroundStyle(AppColors.textPrimary)

                Text(note.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(AppColors.textMuted)
            }

            Spacer()
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
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
        case .conversation: return AppColors.teal
        case .interest: return AppColors.warmYellow
        case .reminder: return AppColors.warning
        case .followUp: return AppColors.softPurple
        case .milestone: return AppColors.success
        case .general: return AppColors.textMuted
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
                        .fill(
                            LinearGradient(
                                colors: [AppColors.coral.opacity(0.3), AppColors.teal.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "person.2")
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(encounter.occasion ?? "Encounter")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 8) {
                        Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        if let location = encounter.location, !location.isEmpty {
                            Label(location, systemImage: "mappin")
                                .font(.caption)
                                .foregroundStyle(AppColors.teal)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Encounters Timeline Sheet

struct EncountersTimelineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let onSelectEncounter: (Encounter) -> Void

    var sortedEncounters: [Encounter] {
        person.encounters.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sortedEncounters) { encounter in
                        Button {
                            onSelectEncounter(encounter)
                        } label: {
                            HStack(spacing: 12) {
                                // Thumbnail
                                if let imageData = encounter.thumbnailData ?? encounter.displayImageData,
                                   let image = UIImage(data: imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [AppColors.coral.opacity(0.3), AppColors.teal.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Image(systemName: "person.2")
                                                .foregroundStyle(AppColors.textMuted)
                                        }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(encounter.occasion ?? "Encounter")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(AppColors.textPrimary)

                                    Text(encounter.date.formatted(date: .long, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)

                                    if let location = encounter.location, !location.isEmpty {
                                        Label(location, systemImage: "mappin")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.teal)
                                            .lineLimit(1)
                                    }

                                    if encounter.photos.count > 1 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "photo.stack")
                                            Text("\(encounter.photos.count) photos")
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.softPurple)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            .padding(12)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("All Encounters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Edit Person Sheet

struct EditPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person

    var body: some View {
        NavigationStack {
            Form {
                // Basic Info Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(AppColors.coral)
                            .frame(width: 24)
                        TextField("Name", text: $person.name)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(AppColors.teal)
                            .frame(width: 24)
                        Picker("Relationship", selection: Binding(
                            get: { person.relationship ?? "" },
                            set: { person.relationship = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("Not set").tag("")
                            Text("Family").tag("Family")
                            Text("Friend").tag("Friend")
                            Text("Coworker").tag("Coworker")
                            Text("Acquaintance").tag("Acquaintance")
                            Text("Client").tag("Client")
                            Text("Mentor").tag("Mentor")
                        }
                        .tint(AppColors.textPrimary)
                    }
                } header: {
                    Text("Basic Info")
                }

                // Work Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "building.2.fill")
                            .foregroundStyle(AppColors.softPurple)
                            .frame(width: 24)
                        TextField("Company", text: Binding(
                            get: { person.company ?? "" },
                            set: { person.company = $0.isEmpty ? nil : $0 }
                        ))
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "briefcase.fill")
                            .foregroundStyle(AppColors.softPurple)
                            .frame(width: 24)
                        TextField("Job Title", text: Binding(
                            get: { person.jobTitle ?? "" },
                            set: { person.jobTitle = $0.isEmpty ? nil : $0 }
                        ))
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(AppColors.softPurple)
                            .frame(width: 24)
                        Picker("Context", selection: Binding(
                            get: { person.contextTag ?? "" },
                            set: { person.contextTag = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("Not set").tag("")
                            Text("Work").tag("Work")
                            Text("School").tag("School")
                            Text("Gym").tag("Gym")
                            Text("Church").tag("Church")
                            Text("Neighborhood").tag("Neighborhood")
                            Text("Online").tag("Online")
                            Text("Event").tag("Event")
                        }
                        .tint(AppColors.textPrimary)
                    }
                } header: {
                    Text("Work & Context")
                }

                // Contact Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(AppColors.teal)
                            .frame(width: 24)
                        TextField("Email", text: Binding(
                            get: { person.email ?? "" },
                            set: { person.email = $0.isEmpty ? nil : $0 }
                        ))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(AppColors.success)
                            .frame(width: 24)
                        TextField("Phone", text: Binding(
                            get: { person.phone ?? "" },
                            set: { person.phone = $0.isEmpty ? nil : $0 }
                        ))
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    }
                } header: {
                    Text("Contact")
                }

                // Notes Section
                Section {
                    TextEditor(text: Binding(
                        get: { person.notes ?? "" },
                        set: { person.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 100)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Add any additional notes or reminders about this person")
                        .foregroundStyle(AppColors.textMuted)
                }
            }
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
