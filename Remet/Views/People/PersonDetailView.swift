import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allEncounters: [Encounter]
    @Query(sort: \Person.name) private var allPeople: [Person]
    @Bindable var person: Person
    @State private var showEditSheet = false
    @State private var selectedEncounter: Encounter?
    @State private var faceSourceEncounter: Encounter?
    @State private var selectedEmbedding: FaceEmbedding?
    @State private var showDeleteConfirmation = false
    @State private var showMergeWithPicker = false
    @State private var mergeTargetPerson: Person?
    @State private var showTagPicker = false
    @State private var selectedTags: [Tag] = []
    @State private var showEncountersTimeline = false
    @State private var expandedSections: Set<String> = ["talkingPoints", "timeline"]

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    /// Whether the person has key context info to show
    private var hasKeyContext: Bool {
        person.company != nil || person.contextTag != nil || person.howWeMet != nil || person.jobTitle != nil
    }

    private func findEncounter(for embedding: FaceEmbedding) -> Encounter? {
        guard let encounterId = embedding.encounterId else { return nil }
        return allEncounters.first { $0.id == encounterId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero section with photo, name, and quick actions
                heroSection

                // Key context card (company, context, how we met)
                if hasKeyContext {
                    keyContextCard
                }

                // Talking points - prominent when has content
                if !person.talkingPoints.isEmpty {
                    talkingPointsCard
                }

                // Tags & Interests combined
                if !(person.tags ?? []).isEmpty || !person.interests.isEmpty {
                    tagsAndInterestsSection
                }

                // Activity section (encounters + notes)
                if !(person.encounters ?? []).isEmpty || !(person.interactionNotes ?? []).isEmpty {
                    activitySection
                }

                // Expandable details section
                moreDetailsSection

                // Face samples at the bottom
                if !(person.embeddings ?? []).isEmpty {
                    facesSection
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .onAppear {
                selectedTags = person.tags ?? []
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label(String(localized: "Edit Details"), systemImage: "pencil")
                    }

                    Button {
                        showMergeWithPicker = true
                    } label: {
                        Label(String(localized: "Merge with..."), systemImage: "arrow.triangle.merge")
                    }

                    if !person.isMe {
                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label(String(localized: "Delete Person"), systemImage: "trash")
                        }
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
        .sheet(isPresented: $showMergeWithPicker) {
            PersonMergePickerView(
                currentPerson: person,
                allPeople: allPeople,
                onSelect: { target in
                    showMergeWithPicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        mergeTargetPerson = target
                    }
                }
            )
        }
        .sheet(item: $mergeTargetPerson) { target in
            PersonMergeView(people: [person, target]) {
                mergeTargetPerson = nil
                dismiss()
            }
        }
    }

    // MARK: - Helper Methods
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

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Photo and name row
            HStack(spacing: 16) {
                // Profile photo
                if let profileEmbedding = person.profileEmbedding,
                   let image = UIImage(data: profileEmbedding.faceCropData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
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
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                }

                // Name and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let relationship = person.relationship {
                        Text(relationship)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.teal)
                    }

                    // Met date
                    Text(String(localized: "Added \(person.createdAt.formatted(date: .abbreviated, time: .omitted))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Quick action buttons
            quickActionButtons
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var quickActionButtons: some View {
        let hasPhone = person.phone != nil && !person.phone!.isEmpty
        let hasEmail = person.email != nil && !person.email!.isEmpty

        if hasPhone || hasEmail {
            HStack(spacing: 12) {
                if let phone = person.phone, let url = URL(string: "tel:\(phone)") {
                    Link(destination: url) {
                        Label("Call", systemImage: "phone.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.success.opacity(0.12))
                            .foregroundStyle(AppColors.success)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                if let phone = person.phone, let smsUrl = URL(string: "sms:\(phone)") {
                    Link(destination: smsUrl) {
                        Label("Text", systemImage: "message.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.coral.opacity(0.12))
                            .foregroundStyle(AppColors.coral)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                if let email = person.email, let emailUrl = URL(string: "mailto:\(email)") {
                    Link(destination: emailUrl) {
                        Label("Email", systemImage: "envelope.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.teal.opacity(0.12))
                            .foregroundStyle(AppColors.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Key Context Card

    @ViewBuilder
    private var keyContextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let company = person.company {
                HStack(spacing: 10) {
                    Image(systemName: "building.2")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        if let jobTitle = person.jobTitle {
                            Text(jobTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Text(company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let context = person.contextTag {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(context)
                        .font(.subheadline)
                }
            }

            if let howWeMet = person.howWeMet, !howWeMet.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.2")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(howWeMet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Talking Points Card

    @ViewBuilder
    private var talkingPointsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Talking Points"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                Button {
                    addTalkingPoint()
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(person.talkingPoints.enumerated()), id: \.offset) { index, point in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(.secondary)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(point)
                            .font(.subheadline)
                        Spacer()
                        Button {
                            removeTalkingPoint(at: index)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Tags & Interests Section

    @ViewBuilder
    private var tagsAndInterestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tags
            if !(person.tags ?? []).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "tag")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(String(localized: "Tags"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Button {
                            selectedTags = person.tags ?? []
                            showTagPicker = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    FlowLayout(spacing: 6) {
                        ForEach(person.tags ?? []) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(tag.color.opacity(0.15))
                                .foregroundStyle(tag.color)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Interests
            if !person.interests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "heart")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(String(localized: "Interests"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Button {
                            addInterest()
                        } label: {
                            Image(systemName: "plus")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    FlowLayout(spacing: 6) {
                        ForEach(Array(person.interests.enumerated()), id: \.offset) { index, interest in
                            HStack(spacing: 4) {
                                Text(interest)
                                    .font(.caption)
                                Button {
                                    removeInterest(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemFill))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Activity Section

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            activityHeader
            activityContent
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var activityHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(localized: "Activity"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
            if !(person.encounters ?? []).isEmpty {
                Button {
                    showEncountersTimeline = true
                } label: {
                    Text(String(localized: "See All"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var activityContent: some View {
        VStack(spacing: 8) {
            encountersList
            notesList
        }
    }

    @ViewBuilder
    private var encountersList: some View {
        ForEach(Array((person.encounters ?? []).prefix(3))) { encounter in
            ActivityEncounterRow(encounter: encounter) {
                selectedEncounter = encounter
            }
        }
    }

    @ViewBuilder
    private var notesList: some View {
        ForEach(Array(person.recentNotes.prefix(2))) { note in
            ActivityNoteRow(note: note)
        }
    }

    // MARK: - More Details Section

    @ViewBuilder
    private var moreDetailsSection: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedSections.contains("details") },
                set: { if $0 { expandedSections.insert("details") } else { expandedSections.remove("details") } }
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // Contact linking (Premium feature)
                ContactLinkSection(person: person)
                    .padding(.bottom, 4)

                if let email = person.email {
                    DetailInfoRow(icon: "envelope", label: String(localized: "Email"), value: email)
                }
                if let phone = person.phone {
                    DetailInfoRow(icon: "phone", label: String(localized: "Phone"), value: phone)
                }
                if let notes = person.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Notes"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.subheadline)
                    }
                    .padding(.top, 4)
                }

                // Add talking point if empty
                if person.talkingPoints.isEmpty {
                    Button {
                        addTalkingPoint()
                    } label: {
                        Label(String(localized: "Add Talking Point"), systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.teal)
                    }
                    .padding(.top, 4)
                }

                // Add interest if empty
                if person.interests.isEmpty {
                    Button {
                        addInterest()
                    } label: {
                        Label(String(localized: "Add Interest"), systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.teal)
                    }
                }

                // Edit how we met
                Button {
                    editHowWeMet()
                } label: {
                    Label(person.howWeMet == nil ? String(localized: "Add How We Met") : String(localized: "Edit How We Met"), systemImage: "pencil.circle")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.teal)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(localized: "More Details"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .tint(.primary)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var encountersSection: some View {
        if !(person.encounters ?? []).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.crop.square.stack")
                            .foregroundStyle(AppColors.softPurple)
                        Text(String(localized: "Encounters"))
                            .font(.headline)
                    }

                    Spacer()

                    Button {
                        showEncountersTimeline = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(String(localized: "View All"))
                                .font(.subheadline)
                            Text("\((person.encounters ?? []).count)")
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
                        ForEach((person.encounters ?? []).prefix(5)) { encounter in
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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Face Samples"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                Text("\((person.embeddings ?? []).count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if (person.embeddings ?? []).isEmpty {
                Text("No face samples yet")
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(person.embeddings ?? []) { embedding in
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
                .padding(.top, 4)
            }
        }
        .sheet(item: $faceSourceEncounter) { encounter in
            FaceSourcePhotoView(encounter: encounter, person: person)
        }
    }

    private func deleteEmbedding(_ embedding: FaceEmbedding) {
        // Clear profile photo reference if this embedding was the profile
        if person.profileEmbeddingId == embedding.id {
            person.profileEmbeddingId = nil
        }

        // Check if person should be unlinked from the associated encounter
        if let encounterId = embedding.encounterId,
           let encounter = allEncounters.first(where: { $0.id == encounterId }) {
            // Count remaining embeddings for this person in this encounter (excluding the one being deleted)
            let remainingEmbeddings = (person.embeddings ?? []).filter {
                $0.id != embedding.id && $0.encounterId == encounterId
            }

            // If no other embeddings link this person to the encounter, remove from people list
            if remainingEmbeddings.isEmpty {
                encounter.people = (encounter.people ?? []).filter { $0.id != person.id }
            }
        }

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

/// Compact detail row for collapsible details section
struct DetailInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.teal)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

/// Activity section encounter row
struct ActivityEncounterRow: View {
    let encounter: Encounter
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                encounterThumbnail
                encounterInfo
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var encounterThumbnail: some View {
        if let imageData = encounter.displayImageData ?? encounter.thumbnailData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.teal.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundStyle(AppColors.teal)
                }
        }
    }

    @ViewBuilder
    private var encounterInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(encounter.occasion ?? String(localized: "Encounter"))
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Activity section note row
struct ActivityNoteRow: View {
    let note: InteractionNote

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "note.text")
                .font(.caption)
                .foregroundStyle(AppColors.softPurple)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.content)
                    .font(.caption)
                    .lineLimit(2)
                Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    if (encounter.photos ?? []).count > 1 {
                        Text("\((encounter.photos ?? []).count)")
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
        (encounter.photos ?? []).compactMap { photo in
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
                    if AppSettings.shared.showBoundingBoxes {
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
    }

    @ViewBuilder
    private func photoWithOverlay(imageData: Data, boxes: [FaceBoundingBox]) -> some View {
        if let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if AppSettings.shared.showBoundingBoxes {
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
                }
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var encounterInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let occasion = encounter.occasion {
                Label(occasion, systemImage: "star")
                    .foregroundStyle(.primary)
            }
            if let location = encounter.location {
                Label(location, systemImage: "mappin")
                    .foregroundStyle(.secondary)
            }
            Label(encounter.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                .foregroundStyle(.secondary)

            if (encounter.photos ?? []).count > 1 {
                Label("\((encounter.photos ?? []).count) photos in this encounter", systemImage: "photo.stack")
                    .foregroundStyle(.secondary)
            }

            if (encounter.people ?? []).count > 1 {
                Label("\((encounter.people ?? []).count) people tagged", systemImage: "person.2")
                    .foregroundStyle(.secondary)
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
        (person.encounters ?? []).sorted { $0.date > $1.date }
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

                                    if (encounter.photos ?? []).count > 1 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "photo.stack")
                                            Text("\((encounter.photos ?? []).count) photos")
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
    @Environment(\.modelContext) private var modelContext
    @Bindable var person: Person
    @Query private var allEncounters: [Encounter]

    @State private var showFacePicker = false

    private let photoColumns = [
        GridItem(.adaptive(minimum: 60), spacing: 8)
    ]

    // Find encounters with unassigned faces that could belong to this person
    private var encountersWithAvailableFaces: [Encounter] {
        allEncounters.filter { encounter in
            // Check if encounter has any unassigned face boxes
            let hasUnassignedFaces = (encounter.photos ?? []).contains { photo in
                photo.faceBoundingBoxes.contains { $0.personId == nil }
            } || encounter.faceBoundingBoxes.contains { $0.personId == nil }
            return hasUnassignedFaces
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Profile Photo Section - always show
                Section {
                    VStack(spacing: 12) {
                        // Current profile photo or placeholder
                        if let profileEmbedding = person.profileEmbedding,
                           let image = UIImage(data: profileEmbedding.faceCropData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.coral, lineWidth: 3)
                                )
                        } else {
                            // Placeholder when no profile photo
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.coral.opacity(0.3), AppColors.teal.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.white)
                                }
                        }

                        if (person.embeddings ?? []).isEmpty {
                            // No face samples - show add button
                            Text("No face photo assigned")
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)

                            Button {
                                showFacePicker = true
                            } label: {
                                Label("Add Face Photo", systemImage: "face.smiling")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(AppColors.coral)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Has face samples - show selection
                            Text("Tap to select profile photo")
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)

                            // Face samples grid
                            LazyVGrid(columns: photoColumns, spacing: 8) {
                                ForEach(person.embeddings ?? []) { embedding in
                                    if let image = UIImage(data: embedding.faceCropData) {
                                        let isSelected = person.profileEmbeddingId == embedding.id ||
                                            (person.profileEmbeddingId == nil && (person.embeddings ?? []).first?.id == embedding.id)

                                        Button {
                                            person.profileEmbeddingId = embedding.id
                                        } label: {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 60, height: 60)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(isSelected ? AppColors.coral : Color.clear, lineWidth: 2)
                                                )
                                                .overlay(alignment: .bottomTrailing) {
                                                    if isSelected {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .font(.caption)
                                                            .foregroundStyle(AppColors.coral)
                                                            .background(Circle().fill(.white))
                                                            .offset(x: 4, y: 4)
                                                    }
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                // Add more faces button
                                Button {
                                    showFacePicker = true
                                } label: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.teal.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Image(systemName: "plus")
                                                .font(.title3)
                                                .foregroundStyle(AppColors.teal)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Profile Photo")
                }

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
                        Picker(String(localized: "Context"), selection: Binding(
                            get: { person.contextTag ?? "" },
                            set: { person.contextTag = $0.isEmpty ? nil : $0 }
                        )) {
                            Text(String(localized: "Not set")).tag("")
                            Text(String(localized: "Work")).tag("Work")
                            Text(String(localized: "School")).tag("School")
                            Text(String(localized: "Gym")).tag("Gym")
                            Text(String(localized: "Church")).tag("Church")
                            Text(String(localized: "Neighborhood")).tag("Neighborhood")
                            Text(String(localized: "Online")).tag("Online")
                            Text(String(localized: "Event")).tag("Event")
                        }
                        .tint(AppColors.textPrimary)
                    }
                } header: {
                    Text("Work & Context")
                }

                // Contact Section
                Section {
                    // Link to iOS Contacts (Premium)
                    ContactLinkSection(person: person)

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
            .navigationTitle(String(localized: "Edit Details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showFacePicker) {
                FacePickerSheet(person: person, encounters: encountersWithAvailableFaces)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Face Picker Sheet

struct FacePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let person: Person
    let encounters: [Encounter]

    var body: some View {
        NavigationStack {
            ScrollView {
                if encounters.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "face.dashed")
                            .font(.system(size: 48))
                            .foregroundStyle(AppColors.textMuted)

                        Text("No Available Faces")
                            .font(.headline)

                        Text("Add a new encounter with photos to detect faces, or assign faces from existing encounters.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Select a face from your encounters to assign to \(person.name)")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal)

                        ForEach(encounters) { encounter in
                            EncounterFacePickerSection(
                                encounter: encounter,
                                person: person,
                                onFaceSelected: { faceData, box in
                                    assignFace(faceData: faceData, box: box, encounter: encounter)
                                }
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Add Face Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func assignFace(faceData: Data, box: FaceBoundingBox, encounter: Encounter) {
        // Create a new face embedding for this person
        // Note: vector is empty for now - the face matching will still work based on faceCropData
        // A background task could compute the actual embedding vector later if needed
        let embedding = FaceEmbedding(
            vector: Data(),
            faceCropData: faceData,
            encounterId: encounter.id
        )
        embedding.person = person

        modelContext.insert(embedding)
        person.embeddings = (person.embeddings ?? []) + [embedding]

        // Update the bounding box to link to this person
        if let photoIndex = (encounter.photos ?? []).firstIndex(where: { photo in
            photo.faceBoundingBoxes.contains { $0.id == box.id }
        }) {
            if let boxIndex = encounter.photos?[photoIndex].faceBoundingBoxes.firstIndex(where: { $0.id == box.id }) {
                encounter.photos?[photoIndex].faceBoundingBoxes[boxIndex].personId = person.id
                encounter.photos?[photoIndex].faceBoundingBoxes[boxIndex].personName = person.name
            }
        }

        // Also check legacy single-photo encounter boxes
        if let boxIndex = encounter.faceBoundingBoxes.firstIndex(where: { $0.id == box.id }) {
            encounter.faceBoundingBoxes[boxIndex].personId = person.id
            encounter.faceBoundingBoxes[boxIndex].personName = person.name
        }

        // Link encounter to person if not already
        if !(person.encounters ?? []).contains(where: { $0.id == encounter.id }) {
            person.encounters = (person.encounters ?? []) + [encounter]
        }

        dismiss()
    }
}

struct EncounterFacePickerSection: View {
    let encounter: Encounter
    let person: Person
    let onFaceSelected: (Data, FaceBoundingBox) -> Void

    // Get all unassigned faces from this encounter
    private var unassignedFaces: [(photo: EncounterPhoto?, box: FaceBoundingBox, faceImage: UIImage?)] {
        var faces: [(photo: EncounterPhoto?, box: FaceBoundingBox, faceImage: UIImage?)] = []

        // Multi-photo encounters
        for photo in encounter.photos ?? [] {
            if let image = UIImage(data: photo.imageData) {
                for box in photo.faceBoundingBoxes where box.personId == nil {
                    let faceImage = cropFace(from: image, box: box)
                    faces.append((photo, box, faceImage))
                }
            }
        }

        // Legacy single-photo encounters
        if let imageData = encounter.displayImageData,
           let image = UIImage(data: imageData) {
            for box in encounter.faceBoundingBoxes where box.personId == nil {
                // Skip if already included from photos array
                let alreadyIncluded = faces.contains { $0.box.id == box.id }
                if !alreadyIncluded {
                    let faceImage = cropFace(from: image, box: box)
                    faces.append((nil, box, faceImage))
                }
            }
        }

        return faces
    }

    var body: some View {
        if !unassignedFaces.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Encounter header
                HStack(spacing: 12) {
                    if let imageData = encounter.thumbnailData ?? encounter.displayImageData,
                       let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(encounter.occasion ?? "Encounter")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal)

                // Unassigned faces
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(unassignedFaces, id: \.box.id) { item in
                            if let faceImage = item.faceImage,
                               let faceData = faceImage.jpegData(compressionQuality: 0.8) {
                                Button {
                                    onFaceSelected(faceData, item.box)
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(uiImage: faceImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(AppColors.coral.opacity(0.5), lineWidth: 1)
                                            )

                                        Text("Assign")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.coral)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(AppColors.cardBackground)
        }
    }

    private func cropFace(from image: UIImage, box: FaceBoundingBox) -> UIImage? {
        let imageSize = image.size

        // Convert normalized coordinates to pixel coordinates
        let x = box.x * imageSize.width
        let y = (1 - box.y - box.height) * imageSize.height
        let width = box.width * imageSize.width
        let height = box.height * imageSize.height

        // Add some padding
        let padding: CGFloat = 0.15
        let paddedX = max(0, x - width * padding)
        let paddedY = max(0, y - height * padding)
        let paddedWidth = min(imageSize.width - paddedX, width * (1 + 2 * padding))
        let paddedHeight = min(imageSize.height - paddedY, height * (1 + 2 * padding))

        let cropRect = CGRect(x: paddedX, y: paddedY, width: paddedWidth, height: paddedHeight)

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
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
        person.interactionNotes = (person.interactionNotes ?? []) + [note]
        modelContext.insert(note)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(person: Person(name: "John Doe"))
    }
}
