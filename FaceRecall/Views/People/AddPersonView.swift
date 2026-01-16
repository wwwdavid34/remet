import SwiftUI
import SwiftData

struct AddPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]

    @State private var name = ""
    @State private var relationship = ""
    @State private var contextTag = ""
    @State private var showPaywall = false

    private let limitChecker = LimitChecker()
    private let relationships = ["", "Family", "Friend", "Coworker", "Acquaintance", "Other"]
    private let contexts = ["", "Work", "School", "Gym", "Church", "Neighborhood", "Other"]

    private var limitStatus: LimitChecker.LimitStatus {
        limitChecker.canAddPerson(currentCount: people.count)
    }

    var body: some View {
        NavigationStack {
            Group {
                if limitStatus.isBlocked {
                    // Show limit reached view
                    LimitReachedView {
                        showPaywall = true
                    }
                } else {
                    // Normal form
                    formContent
                }
            }
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if !limitStatus.isBlocked {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            savePerson()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            // Warning banner if approaching limit
            if case .approachingLimit = limitStatus {
                Section {
                    LimitWarningBanner(status: limitStatus) {
                        showPaywall = true
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Required") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }

            Section("Optional") {
                Picker("Relationship", selection: $relationship) {
                    ForEach(relationships, id: \.self) { relation in
                        Text(relation.isEmpty ? "None" : relation).tag(relation)
                    }
                }

                Picker("Context", selection: $contextTag) {
                    ForEach(contexts, id: \.self) { context in
                        Text(context.isEmpty ? "None" : context).tag(context)
                    }
                }
            }

            Section {
                Text("You can add face photos after creating this person.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func savePerson() {
        // Double-check limit before saving
        guard !limitStatus.isBlocked else {
            showPaywall = true
            return
        }

        let person = Person(
            name: name.trimmingCharacters(in: .whitespaces),
            relationship: relationship.isEmpty ? nil : relationship,
            contextTag: contextTag.isEmpty ? nil : contextTag
        )
        modelContext.insert(person)
        dismiss()
    }
}

#Preview {
    AddPersonView()
}
