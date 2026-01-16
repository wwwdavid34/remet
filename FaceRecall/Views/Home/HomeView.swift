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
                VStack(spacing: 24) {
                    // Greeting Header
                    if !people.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(WittyCopy.timeBasedGreeting)
                                .font(.title2)
                                .fontWeight(.bold)

                            if reviewsDueToday > 0 {
                                Text(WittyCopy.random(from: WittyCopy.reviewNudge))
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            } else {
                                Text(WittyCopy.random(from: WittyCopy.noReviewsNeeded))
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.success)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }

                    // Stats Cards
                    HStack(spacing: 12) {
                        HomeStatCard(
                            title: "People",
                            value: "\(totalPeople)",
                            icon: "person.3.fill",
                            color: AppColors.coral
                        )

                        HomeStatCard(
                            title: "Due Today",
                            value: "\(reviewsDueToday)",
                            icon: "brain.head.profile",
                            color: reviewsDueToday > 0 ? AppColors.warning : AppColors.success
                        )
                    }
                    .padding(.horizontal)

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            HomeActionButton(
                                title: "New Face",
                                subtitle: "Capture someone new",
                                icon: "person.badge.plus",
                                gradient: [AppColors.coral, AppColors.coral.opacity(0.7)]
                            ) {
                                showQuickCapture = true
                            }

                            HomeActionButton(
                                title: "Practice",
                                subtitle: peopleWithFaces.isEmpty ? "Add people first" : "Train your memory",
                                icon: "brain.head.profile",
                                gradient: [AppColors.teal, AppColors.teal.opacity(0.7)]
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
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .foregroundStyle(AppColors.warning)
                                    Text("Needs Your Attention")
                                        .font(.headline)
                                }
                                Spacer()
                                Text("\(peopleNeedingReview.count) waiting")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppColors.warning.opacity(0.15))
                                    .clipShape(Capsule())
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
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundStyle(AppColors.teal)
                                    Text("Recent Encounters")
                                        .font(.headline)
                                }
                                Spacer()
                                NavigationLink {
                                    EncounterListView()
                                } label: {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.coral)
                                }
                            }
                            .padding(.horizontal)

                            VStack(spacing: 10) {
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
                        EmptyStateView(
                            icon: "face.smiling",
                            title: WittyCopy.emptyPeopleTitle,
                            subtitle: WittyCopy.emptyPeopleSubtitle,
                            actionTitle: "Add Your First Person",
                            action: { showQuickCapture = true }
                        )
                        .padding(.top, 20)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Remet")
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
                FaceQuizView(
                    people: peopleNeedingReview.isEmpty ? peopleWithFaces : peopleNeedingReview,
                    mode: .spaced
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct HomeStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct HomeActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: gradient[0].opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
}

struct PersonReviewCard: View {
    let person: Person

    var body: some View {
        VStack(spacing: 8) {
            // Face thumbnail
            ZStack {
                if let embedding = person.embeddings.first,
                   let uiImage = UIImage(data: embedding.faceCropData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
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
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                }

                // Overdue indicator
                if let daysOverdue = person.spacedRepetitionData?.daysUntilReview, daysOverdue < 0 {
                    Circle()
                        .fill(AppColors.warning)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Text("\(min(abs(daysOverdue), 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 22, y: -22)
                }
            }

            Text(person.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
        }
        .frame(width: 80)
        .padding(.vertical, 8)
    }
}

struct RecentEncounterRow: View {
    let encounter: Encounter

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let photoData = encounter.displayImageData,
               let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.coral.opacity(0.2), AppColors.teal.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "person.2")
                            .foregroundStyle(AppColors.coral)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(encounter.occasion ?? "Encounter")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 12) {
                    Label(encounter.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    if !encounter.people.isEmpty {
                        Label("\(encounter.people.count)", systemImage: "person.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

                if let location = encounter.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(AppColors.teal)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.textMuted)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.cardShadow, radius: 4, x: 0, y: 2)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Person.self, Encounter.self], inMemory: true)
}
