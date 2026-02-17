import SwiftUI
import SwiftData

// MARK: - Tag Chip View

struct TagChipView: View {
    let tag: Tag
    var showRemoveButton: Bool = false
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)

            if showRemoveButton {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tag.color.opacity(0.2))
        .foregroundStyle(tag.color)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(tag.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Tag Flow Layout

struct TagFlowLayout: View {
    let tags: [Tag]
    var showRemoveButtons: Bool = false
    var onRemove: ((Tag) -> Void)? = nil

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags) { tag in
                TagChipView(
                    tag: tag,
                    showRemoveButton: showRemoveButtons
                ) {
                    onRemove?(tag)
                }
            }
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @Binding var selectedTags: [Tag]
    let title: String

    @State private var searchText = ""
    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var newTagColor: TagColor = .blue
    @State private var hasShownAssignHint = false

    var filteredTags: [Tag] {
        if searchText.isEmpty {
            return allTags
        }
        return allTags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var suggestedPresets: [PresetTag] {
        let existingNames = Set(allTags.map { $0.name.lowercased() })
        return PresetTag.allCases.filter { !existingNames.contains($0.rawValue.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Selected tags section
                if !selectedTags.isEmpty {
                    Section("Selected") {
                        TagFlowLayout(tags: selectedTags, showRemoveButtons: true) { tag in
                            withAnimation {
                                selectedTags.removeAll { $0.id == tag.id }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                // Existing tags section
                Section {
                    if filteredTags.isEmpty && searchText.isEmpty {
                        Text("No tags yet. Create one below!")
                            .foregroundStyle(.secondary)
                    } else {
                        if hasShownAssignHint && selectedTags.isEmpty {
                            Text(String(localized: "Tap a tag below to assign it"))
                                .font(.caption)
                                .foregroundStyle(AppColors.teal)
                        }
                        ForEach(filteredTags) { tag in
                            TagRowView(
                                tag: tag,
                                isSelected: selectedTags.contains { $0.id == tag.id }
                            ) {
                                toggleTag(tag)
                            }
                        }
                    }
                } header: {
                    Text("Available Tags")
                }

                // Quick create from search
                if !searchText.isEmpty && !allTags.contains(where: { $0.name.lowercased() == searchText.lowercased() }) {
                    Section {
                        Button {
                            createTagFromSearch()
                        } label: {
                            Label("Create \"\(searchText)\"", systemImage: "plus.circle.fill")
                        }
                    }
                }

                // Preset suggestions
                if !suggestedPresets.isEmpty && searchText.isEmpty {
                    Section("Suggested") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedPresets, id: \.rawValue) { preset in
                                    Button {
                                        createPresetTag(preset)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                                .font(.caption2)
                                            Text(preset.rawValue)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(preset.suggestedColor.color.opacity(0.2))
                                        .foregroundStyle(preset.suggestedColor.color)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
                }

                // Create new tag section
                Section {
                    Button {
                        showCreateTag = true
                    } label: {
                        Label("Create New Tag", systemImage: "plus.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search or create tags")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCreateTag) {
                CreateTagView(selectedTags: $selectedTags)
            }
        }
    }

    private func toggleTag(_ tag: Tag) {
        withAnimation {
            if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
                selectedTags.remove(at: index)
            } else {
                selectedTags.append(tag)
            }
        }
    }

    private func createTagFromSearch() {
        let tag = Tag(name: searchText, colorHex: TagColor.blue.hex)
        modelContext.insert(tag)
        selectedTags.append(tag)
        searchText = ""
    }

    private func createPresetTag(_ preset: PresetTag) {
        let tag = Tag(name: preset.rawValue, colorHex: preset.suggestedColor.hex)
        modelContext.insert(tag)
        if !hasShownAssignHint {
            hasShownAssignHint = true
        }
    }
}

// MARK: - Tag Row View

struct TagRowView: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Circle()
                    .fill(tag.color)
                    .frame(width: 12, height: 12)

                Text(tag.name)
                    .foregroundStyle(.primary)

                Spacer()

                if tag.usageCount > 0 {
                    Text("\(tag.usageCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Tag View

struct CreateTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTags: [Tag]

    @State private var name = ""
    @State private var selectedColor: TagColor = .blue

    private let columns = [
        GridItem(.adaptive(minimum: 44))
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Tag name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(TagColor.allCases) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 36, height: 36)

                                    if selectedColor == color {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2)
                                            .frame(width: 36, height: 36)

                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Preview") {
                    HStack {
                        Spacer()
                        previewChip
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTag()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var previewChip: some View {
        if name.isEmpty {
            Text("Enter a name")
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selectedColor.color.opacity(0.2))
            .foregroundStyle(selectedColor.color)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(selectedColor.color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func createTag() {
        let tag = Tag(name: name.trimmingCharacters(in: .whitespaces), colorHex: selectedColor.hex)
        modelContext.insert(tag)
        selectedTags.append(tag)
        dismiss()
    }
}

// MARK: - Tag Filter View

struct TagFilterView: View {
    let availableTags: [Tag]
    @Binding var selectedTags: Set<UUID>
    var onClear: () -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            // Clear filter button - more prominent when active
            if !selectedTags.isEmpty {
                Button {
                    onClear()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("Clear (\(selectedTags.count))")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.coral.opacity(0.15))
                    .foregroundStyle(AppColors.coral)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Tag filters
            ForEach(availableTags) { tag in
                let isSelected = selectedTags.contains(tag.id)
                Button {
                    withAnimation {
                        if isSelected {
                            selectedTags.remove(tag.id)
                        } else {
                            selectedTags.insert(tag.id)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tag.color)
                            .frame(width: 8, height: 8)

                        Text(tag.name)
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .regular)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isSelected ? tag.color.opacity(0.2) : Color(.secondarySystemFill))
                    .foregroundStyle(isSelected ? tag.color : .secondary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? tag.color.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Inline Tag Editor

struct InlineTagEditor: View {
    @Environment(\.modelContext) private var modelContext
    let tags: [Tag]
    var onAddTag: () -> Void
    var onRemoveTag: (Tag) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tags.isEmpty {
                Button {
                    onAddTag()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2)
                        Text("Add tags")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(tags) { tag in
                        TagChipView(tag: tag, showRemoveButton: true) {
                            onRemoveTag(tag)
                        }
                    }

                    Button {
                        onAddTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview("Tag Chip") {
    let tag = Tag(name: "Work", colorHex: TagColor.blue.hex)
    return TagChipView(tag: tag)
}

#Preview("Create Tag") {
    CreateTagView(selectedTags: .constant([]))
}
