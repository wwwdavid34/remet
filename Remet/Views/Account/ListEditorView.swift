import SwiftUI
import SwiftData

enum PersonField {
    case relationship
    case context
}

struct IdentifiableItem: Identifiable {
    let id = UUID()
    var value: String
}

struct ListEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]

    let title: String
    let field: PersonField
    let defaults: [String]
    let onSave: ([String]) -> Void

    @State private var items: [IdentifiableItem]
    @State private var newItemText = ""
    @State private var showAddAlert = false
    @State private var renameItem: IdentifiableItem?
    @State private var renameText = ""
    @State private var showResetConfirmation = false

    init(title: String, field: PersonField, items: [String], defaults: [String], onSave: @escaping ([String]) -> Void) {
        self.title = title
        self.field = field
        self.defaults = defaults
        self.onSave = onSave
        self._items = State(initialValue: items.map { IdentifiableItem(value: $0) })
    }

    private func usageCount(for value: String) -> Int {
        people.filter { personValue(for: $0) == value }.count
    }

    private func personValue(for person: Person) -> String? {
        switch field {
        case .relationship: return person.relationship
        case .context: return person.contextTag
        }
    }

    private func renameInPeople(from oldValue: String, to newValue: String) {
        for person in people {
            switch field {
            case .relationship:
                if person.relationship == oldValue {
                    person.relationship = newValue
                }
            case .context:
                if person.contextTag == oldValue {
                    person.contextTag = newValue
                }
            }
        }
    }

    /// Items currently in use that are NOT in the default list
    private var inUseNonDefaults: [String] {
        let currentValues = items.map(\.value)
        return currentValues.filter { value in
            !defaults.contains(value) && usageCount(for: value) > 0
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    let count = usageCount(for: item.value)
                    HStack {
                        Text(item.value)
                        Spacer()
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.secondary))
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if count == 0 {
                            Button(role: .destructive) {
                                withAnimation {
                                    items.removeAll { $0.id == item.id }
                                    save()
                                }
                            } label: {
                                Label(String(localized: "Delete"), systemImage: "trash")
                            }
                        }
                        Button {
                            renameItem = item
                            renameText = item.value
                        } label: {
                            Label(String(localized: "Rename"), systemImage: "pencil")
                        }
                        .tint(AppColors.teal)
                    }
                }
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                    save()
                }
            } footer: {
                Text(String(localized: "Swipe left to rename or delete. Drag to reorder. Items assigned to people cannot be deleted."))
            }

            Section {
                Button {
                    showAddAlert = true
                } label: {
                    Label(String(localized: "Add New"), systemImage: "plus.circle.fill")
                        .foregroundStyle(AppColors.teal)
                }

                Button {
                    showResetConfirmation = true
                } label: {
                    Label(String(localized: "Reset to Defaults"), systemImage: "arrow.counterclockwise")
                        .foregroundStyle(AppColors.coral)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .alert(String(localized: "Add New"), isPresented: $showAddAlert) {
            TextField(String(localized: "Name"), text: $newItemText)
            Button(String(localized: "Add")) {
                let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !items.contains(where: { $0.value == trimmed }) {
                    withAnimation {
                        items.append(IdentifiableItem(value: trimmed))
                        save()
                    }
                }
                newItemText = ""
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                newItemText = ""
            }
        }
        .alert(String(localized: "Rename"), isPresented: Binding(
            get: { renameItem != nil },
            set: { if !$0 { renameItem = nil } }
        )) {
            TextField(String(localized: "Name"), text: $renameText)
            Button(String(localized: "Save")) {
                guard let item = renameItem else { return }
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                let oldValue = item.value
                if !trimmed.isEmpty && trimmed != oldValue && !items.contains(where: { $0.value == trimmed }) {
                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                        items[index].value = trimmed
                        renameInPeople(from: oldValue, to: trimmed)
                        save()
                    }
                }
                renameItem = nil
                renameText = ""
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                renameItem = nil
                renameText = ""
            }
        } message: {
            if let item = renameItem {
                let count = usageCount(for: item.value)
                if count > 0 {
                    Text(String(localized: "This will update \(count) people."))
                }
            }
        }
        .confirmationDialog(String(localized: "Reset to Defaults"), isPresented: $showResetConfirmation) {
            Button(String(localized: "Reset"), role: .destructive) {
                resetToDefaults()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            let orphans = inUseNonDefaults
            if orphans.isEmpty {
                Text(String(localized: "Restore the original list of options."))
            } else {
                Text(String(localized: "Custom items in use (\(orphans.joined(separator: ", "))) will be kept."))
            }
        }
    }

    private func resetToDefaults() {
        // Keep in-use items that aren't in defaults
        let kept = inUseNonDefaults
        var newItems = defaults.map { IdentifiableItem(value: $0) }
        for value in kept {
            if !defaults.contains(value) {
                newItems.append(IdentifiableItem(value: value))
            }
        }
        withAnimation {
            items = newItems
            save()
        }
    }

    private func save() {
        onSave(items.map(\.value))
    }
}
