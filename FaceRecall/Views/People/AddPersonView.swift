import SwiftUI
import SwiftData

struct AddPersonView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var relationship = ""
    @State private var contextTag = ""

    private let relationships = ["", "Family", "Friend", "Coworker", "Acquaintance", "Other"]
    private let contexts = ["", "Work", "School", "Gym", "Church", "Neighborhood", "Other"]

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePerson()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func savePerson() {
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
