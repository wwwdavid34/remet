import SwiftUI
import Contacts
import ContactsUI

/// Section for linking a Person to an iOS Contact (Premium feature)
struct ContactLinkSection: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var modelContext

    private let contactsManager = ContactsManager.shared
    private let subscriptionManager = SubscriptionManager.shared

    @State private var linkedContact: LinkedContactInfo?
    @State private var showContactPicker = false
    @State private var showPaywall = false
    @State private var showUnlinkConfirmation = false
    @State private var showPhotoExportConfirmation = false
    @State private var showPhotoExportSuccess = false
    @State private var exportError: String?

    /// Whether the contact photo differs from the current Remet profile
    private var shouldShowExportButton: Bool {
        guard person.profileEmbedding != nil else { return false }
        return person.contactPhotoSourceEmbeddingId != person.profileEmbedding?.id
    }

    var body: some View {
        Group {
            if let contact = linkedContact {
                linkedContactView(contact)

                if shouldShowExportButton {
                    Button {
                        showPhotoExportConfirmation = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.badge.arrow.down")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.teal)

                            Text("Set as Contact Photo")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppColors.textMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                notLinkedView
            }
        }
        .onAppear {
            loadLinkedContact()
        }
        .onChange(of: person.contactIdentifier) { _, _ in
            loadLinkedContact()
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView(
                onContactSelected: { contact in
                    linkContact(contact)
                },
                onDismiss: {
                    showContactPicker = false
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Unlink Contact", isPresented: $showUnlinkConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Unlink", role: .destructive) {
                unlinkContact()
            }
        } message: {
            Text("This will remove the link to this contact. Your contact's data won't be affected.")
        }
        .alert("Update Contact Photo", isPresented: $showPhotoExportConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Update") {
                exportPhotoToContact()
            }
        } message: {
            Text("This will replace \(linkedContact?.fullName ?? "the contact")'s photo with the face from Remet.")
        }
        .alert("Photo Updated", isPresented: $showPhotoExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Contact photo has been updated successfully.")
        }
        .alert("Error", isPresented: .constant(exportError != nil)) {
            Button("OK") {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "An error occurred")
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var notLinkedView: some View {
        Button {
            handleLinkTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.teal)

                Text("Link to Contact")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if !subscriptionManager.isPremium {
                    PremiumBadge()
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func linkedContactView(_ contact: LinkedContactInfo) -> some View {
        Button {
            openContactInContacts(identifier: contact.identifier)
        } label: {
            HStack(spacing: 10) {
                // Contact thumbnail
                if let thumbnailData = contact.thumbnailData,
                   let image = UIImage(data: thumbnailData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColors.teal.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "person.crop.rectangle.stack")
                                .font(.caption)
                                .foregroundStyle(AppColors.teal)
                        }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Text("Linked Contact")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.cardBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button {
                syncFromContact()
            } label: {
                Label("Sync from Contact", systemImage: "arrow.triangle.2.circlepath")
            }

            if shouldShowExportButton {
                Button {
                    showPhotoExportConfirmation = true
                } label: {
                    Label("Set Contact Photo", systemImage: "photo.badge.arrow.down")
                }
            }

            Divider()

            Button(role: .destructive) {
                showUnlinkConfirmation = true
            } label: {
                Label("Unlink Contact", systemImage: "link.badge.minus")
            }
        }
    }

    private func openContactInContacts(identifier: String) {
        guard let contact = contactsManager.fetchContact(identifier: identifier) else { return }

        let contactVC = CNContactViewController(for: contact)
        contactVC.allowsEditing = false
        contactVC.allowsActions = true

        // Get the root view controller and present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            let navController = UINavigationController(rootViewController: contactVC)

            // Add Done button to dismiss
            contactVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: navController,
                action: #selector(UINavigationController.dismissSelf)
            )

            rootVC.present(navController, animated: true)
        }
    }

    // MARK: - Actions

    private func handleLinkTap() {
        if subscriptionManager.isPremium {
            requestContactsAccessAndShowPicker()
        } else {
            showPaywall = true
        }
    }

    private func requestContactsAccessAndShowPicker() {
        Task {
            let authorized = await contactsManager.requestAccess()
            if authorized {
                await MainActor.run {
                    showContactPicker = true
                }
            }
        }
    }

    private func loadLinkedContact() {
        guard let identifier = person.contactIdentifier, !identifier.isEmpty else {
            linkedContact = nil
            return
        }

        if let contact = contactsManager.fetchContact(identifier: identifier) {
            linkedContact = LinkedContactInfo(from: contact)
        } else {
            // Contact was deleted - clear the link
            person.contactIdentifier = nil
            linkedContact = nil
        }
    }

    private func linkContact(_ contact: CNContact) {
        let contactId = contact.identifier
        person.contactIdentifier = contactId

        // Fetch full contact with all keys since picker returns minimal data
        Task { @MainActor in
            if let fullContact = contactsManager.fetchContact(identifier: contactId) {
                linkedContact = LinkedContactInfo(from: fullContact)
                contactsManager.syncContactData(from: contactId, to: person)
            } else {
                loadLinkedContact()
            }
        }
    }

    private func unlinkContact() {
        person.contactIdentifier = nil
        person.contactPhotoSourceEmbeddingId = nil
        linkedContact = nil
    }

    private func syncFromContact() {
        guard let identifier = person.contactIdentifier else { return }
        contactsManager.syncContactData(from: identifier, to: person)
        loadLinkedContact()
    }

    private func exportPhotoToContact() {
        guard let identifier = person.contactIdentifier,
              let embedding = person.profileEmbedding else { return }

        Task {
            do {
                try await contactsManager.setContactPhoto(
                    contactIdentifier: identifier,
                    imageData: embedding.faceCropData
                )
                await MainActor.run {
                    person.contactPhotoSourceEmbeddingId = person.profileEmbedding?.id
                    showPhotoExportSuccess = true
                    loadLinkedContact() // Refresh to show new thumbnail
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                }
            }
        }
    }

}

// MARK: - Contact Picker View

struct ContactPickerView: UIViewControllerRepresentable {
    let onContactSelected: (CNContact) -> Void
    let onDismiss: () -> Void

    // Use a plain container so CNContactPickerViewController's self-dismissal
    // only removes itself from the container, not the entire navigation stack.
    func makeUIViewController(context: Context) -> UIViewController {
        let containerVC = UIViewController()
        containerVC.view.backgroundColor = .clear
        return containerVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Only present the picker once; guard prevents re-presentation on SwiftUI view updates.
        guard uiViewController.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        uiViewController.present(picker, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView

        init(_ parent: ContactPickerView) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onContactSelected(contact)
            DispatchQueue.main.async {
                self.parent.onDismiss()
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            DispatchQueue.main.async {
                self.parent.onDismiss()
            }
        }
    }
}

// MARK: - UINavigationController Extension

extension UINavigationController {
    @objc func dismissSelf() {
        dismiss(animated: true)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ContactLinkSection(person: Person(name: "John Doe"))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
