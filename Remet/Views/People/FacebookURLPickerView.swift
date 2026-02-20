import SwiftUI
import SwiftData

/// Presents a list of people so the user can assign a shared Facebook profile URL
/// to a specific person's profile.
struct FacebookURLPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.name) private var people: [Person]

    let facebookURL: URL

    @State private var searchText = ""
    @State private var saveError: Error?
    @State private var showSaveError = false

    private var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people.filter { !$0.isMe }
        }
        return people.filter {
            !$0.isMe && $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredPeople) { person in
                Button {
                    assignURL(to: person)
                } label: {
                    HStack(spacing: 14) {
                        personAvatar(person)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            if let existing = person.facebookURL, !existing.isEmpty {
                                Text(String(localized: "Replaces existing Facebook link"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: String(localized: "Search people"))
            .navigationTitle(String(localized: "Add Facebook Link"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if filteredPeople.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No People"),
                        systemImage: "person.slash",
                        description: Text(String(localized: "Add people to Remet first."))
                    )
                }
            }
            .alert(String(localized: "Could Not Save"), isPresented: $showSaveError) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(saveError?.localizedDescription ?? String(localized: "The Facebook link could not be saved. Please try again."))
            }
        }
    }

    @ViewBuilder
    private func personAvatar(_ person: Person) -> some View {
        if let embedding = person.profileEmbedding,
           let image = UIImage(data: embedding.faceCropData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(.systemFill))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(person.name.prefix(1).uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func assignURL(to person: Person) {
        person.facebookURL = facebookURL.absoluteString
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error
            showSaveError = true
        }
    }
}

#Preview {
    FacebookURLPickerView(facebookURL: URL(string: "https://www.facebook.com/johndoe")!)
        .modelContainer(for: [Person.self], inMemory: true)
}
