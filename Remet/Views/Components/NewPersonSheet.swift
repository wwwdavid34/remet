import SwiftUI
import UIKit

/// Reusable sheet content for creating a new person.
/// Owns its own `@FocusState` so keyboard auto-focus works reliably in sheets.
struct NewPersonSheetContent: View {
    let faceCropImage: UIImage?
    @Binding var name: String
    let confirmLabel: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                if let image = faceCropImage {
                    Section {
                        HStack {
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .clipShape(Circle())
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .focused($isNameFocused)
                }
            }
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel) { onConfirm() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}
