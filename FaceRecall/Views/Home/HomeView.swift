import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var people: [Person]
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]

    @State private var showQuickCapture = false
    @State private var showPractice = false
    @State private var selectedPerson: Person?
    @State private var selectedEncounter: Encounter?

    private var peopleNeedingReview: [Person] {
        people.filter { $0.needsReview }
    }

    private var peopleWithFaces: [Person] {
        people.filter { !$0.embeddings.isEmpty }
    }

    private var recentEncounters: [Encounter] {
        Array(encounters.prefix(5))
    }

    private var totalPeople: Int {
        people.count
    }

    private var reviewsDueToday: Int {
        peopleNeedingReview.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards
                    HStack(spacing: 16) {
                        StatCard(
                            title: "People",
                            value: "\(totalPeople)",
                            icon: "person.3.fill",
                            color: .blue
                        )

                        StatCard(
                            title: "Due for Review",
                            value: "\(reviewsDueToday)",
                            icon: "brain.head.profile",
                            color: reviewsDueToday > 0 ? .orange : .green
                        )
                    }
                    .padding(.horizontal)

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            QuickActionButton(
                                title: "Add Person",
                                icon: "person.badge.plus",
                                color: .blue
                            ) {
                                showQuickCapture = true
                            }

                            QuickActionButton(
                                title: "Start Practice",
                                icon: "brain.head.profile",
                                color: .purple
                            ) {
                                showPractice = true
                            }
                            .disabled(peopleWithFaces.isEmpty)
                            .opacity(peopleWithFaces.isEmpty ? 0.5 : 1)
                        }
                        .padding(.horizontal)
                    }

                    // People to Review Section
                    if !peopleNeedingReview.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Due for Review")
                                    .font(.headline)
                                Spacer()
                                Text("\(peopleNeedingReview.count) people")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(peopleNeedingReview.prefix(10)) { person in
                                        Button {
                                            selectedPerson = person
                                        } label: {
                                            PersonReviewCard(person: person)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Recent Activity
                    if !recentEncounters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Encounters")
                                    .font(.headline)
                                Spacer()
                                NavigationLink("See All") {
                                    EncounterListView()
                                }
                                .font(.subheadline)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(recentEncounters) { encounter in
                                    Button {
                                        selectedEncounter = encounter
                                    } label: {
                                        RecentEncounterRow(encounter: encounter)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Empty State
                    if people.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.3")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)

                            Text("No People Yet")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Start by adding people you want to remember. Use the Add tab to capture a photo or import from your library.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            Button {
                                showQuickCapture = true
                            } label: {
                                Label("Add Your First Person", systemImage: "person.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Face Recall")
            .navigationDestination(item: $selectedPerson) { person in
                PersonDetailView(person: person)
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
            .fullScreenCover(isPresented: $showQuickCapture) {
                QuickCaptureView()
            }
            .fullScreenCover(isPresented: $showPractice) {
                FaceQuizView(people: peopleNeedingReview.isEmpty ? peopleWithFaces : peopleNeedingReview)
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct PersonReviewCard: View {
    let person: Person

    var body: some View {
        VStack(spacing: 8) {
            // Face thumbnail placeholder
            if let embedding = person.embeddings.first,
               let uiImage = UIImage(data: embedding.faceCropData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    }
            }

            Text(person.name)
                .font(.caption)
                .lineLimit(1)

            if let daysOverdue = person.spacedRepetitionData?.daysUntilReview, daysOverdue < 0 {
                Text("\(abs(daysOverdue))d overdue")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: 80)
    }
}

struct RecentEncounterRow: View {
    let encounter: Encounter

    var body: some View {
        HStack {
            // Thumbnail
            if let photoData = encounter.displayImageData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(encounter.occasion ?? "Encounter")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                    if !encounter.people.isEmpty {
                        Text("- \(encounter.people.count) people")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let location = encounter.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Person.self, Encounter.self], inMemory: true)
}
