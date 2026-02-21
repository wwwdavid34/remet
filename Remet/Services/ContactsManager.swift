import Foundation
import Contacts
import ContactsUI

/// Manages integration with iOS Contacts
@Observable
@MainActor
final class ContactsManager {
    static let shared = ContactsManager()

    private let store = CNContactStore()

    // MARK: - Authorization

    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case limited
        case denied
        case restricted
    }

    var authorizationStatus: AuthorizationStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .limited:
            return .limited
        @unknown default:
            return .denied
        }
    }

    var isFullAccess: Bool {
        authorizationStatus == .authorized
    }

    /// Request access to contacts
    func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            print("Failed to request contacts access: \(error)")
            return false
        }
    }

    // MARK: - Fetch Contact

    /// Fetch a contact by identifier
    func fetchContact(identifier: String) -> CNContact? {
        // Note: CNContactNoteKey requires Apple approval, so we skip it
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactViewController.descriptorForRequiredKeys(),
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor
        ]

        do {
            let contact = try store.unifiedContact(withIdentifier: identifier, keysToFetch: keysToFetch)
            return contact
        } catch {
            print("Failed to fetch contact with identifier \(identifier): \(error)")
            return nil
        }
    }

    /// Search contacts by name
    func searchContacts(name: String) -> [CNContact] {
        guard !name.isEmpty else { return [] }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor
        ]

        do {
            let predicate = CNContact.predicateForContacts(matchingName: name)
            return try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        } catch {
            print("Failed to search contacts: \(error)")
            return []
        }
    }

    // MARK: - Update Contact Photo

    enum ContactPhotoError: LocalizedError {
        case contactNotFound
        case saveFailed(Error)
        case notAuthorized

        var errorDescription: String? {
            switch self {
            case .contactNotFound:
                return "Contact not found"
            case .saveFailed(let error):
                return "Failed to save: \(error.localizedDescription)"
            case .notAuthorized:
                return "Not authorized to modify contacts"
            }
        }
    }

    /// Set the contact's photo from image data
    func setContactPhoto(contactIdentifier: String, imageData: Data) async throws {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw ContactPhotoError.notAuthorized
        }

        // Fetch mutable contact
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactImageDataKey as CNKeyDescriptor
        ]

        guard let contact = try? store.unifiedContact(withIdentifier: contactIdentifier, keysToFetch: keysToFetch) else {
            throw ContactPhotoError.contactNotFound
        }

        guard let mutableContact = contact.mutableCopy() as? CNMutableContact else {
            throw ContactPhotoError.contactNotFound
        }

        // Set the photo
        mutableContact.imageData = imageData

        // Save
        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)

        do {
            try store.execute(saveRequest)
        } catch {
            throw ContactPhotoError.saveFailed(error)
        }
    }

    // MARK: - Sync Contact Data

    /// Sync data from linked contact to Person
    func syncContactData(from contactIdentifier: String, to person: Person) {
        guard let contact = fetchContact(identifier: contactIdentifier) else { return }

        // Only sync if Person fields are empty (don't overwrite user's data)
        if person.email == nil || person.email?.isEmpty == true,
           let email = contact.emailAddresses.first?.value as String? {
            person.email = email
        }

        if person.phone == nil || person.phone?.isEmpty == true,
           let phone = contact.phoneNumbers.first?.value.stringValue {
            person.phone = phone
        }

        if person.company == nil || person.company?.isEmpty == true,
           !contact.organizationName.isEmpty {
            person.company = contact.organizationName
        }

        if person.jobTitle == nil || person.jobTitle?.isEmpty == true,
           !contact.jobTitle.isEmpty {
            person.jobTitle = contact.jobTitle
        }

        if person.birthday == nil,
           let birthday = contact.birthday?.date {
            person.birthday = birthday
        }
    }

    private init() {}
}

// MARK: - Contact Display Helper

struct LinkedContactInfo {
    let identifier: String
    let fullName: String
    let phoneNumbers: [(label: String?, number: String)]
    let emailAddresses: [(label: String?, email: String)]
    let birthday: Date?
    let organization: String?
    let jobTitle: String?
    let thumbnailData: Data?

    /// Fallback initializer when the contact can't be fetched (limited access / deleted)
    init(identifier: String, fallbackName: String) {
        self.identifier = identifier
        self.fullName = fallbackName
        self.phoneNumbers = []
        self.emailAddresses = []
        self.birthday = nil
        self.organization = nil
        self.jobTitle = nil
        self.thumbnailData = nil
    }

    init(from contact: CNContact) {
        self.identifier = contact.identifier

        // Safely get full name - requires givenName/familyName keys
        if contact.isKeyAvailable(CNContactGivenNameKey) || contact.isKeyAvailable(CNContactFamilyNameKey) {
            self.fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        } else {
            self.fullName = "Unknown"
        }

        // Safely get phone numbers
        if contact.isKeyAvailable(CNContactPhoneNumbersKey) {
            self.phoneNumbers = contact.phoneNumbers.map { phone in
                (label: phone.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) },
                 number: phone.value.stringValue)
            }
        } else {
            self.phoneNumbers = []
        }

        // Safely get email addresses
        if contact.isKeyAvailable(CNContactEmailAddressesKey) {
            self.emailAddresses = contact.emailAddresses.map { email in
                (label: email.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) },
                 email: email.value as String)
            }
        } else {
            self.emailAddresses = []
        }

        // Safely get birthday
        if contact.isKeyAvailable(CNContactBirthdayKey) {
            self.birthday = contact.birthday?.date
        } else {
            self.birthday = nil
        }

        // Safely get organization
        if contact.isKeyAvailable(CNContactOrganizationNameKey) {
            self.organization = contact.organizationName.isEmpty ? nil : contact.organizationName
        } else {
            self.organization = nil
        }

        // Safely get job title
        if contact.isKeyAvailable(CNContactJobTitleKey) {
            self.jobTitle = contact.jobTitle.isEmpty ? nil : contact.jobTitle
        } else {
            self.jobTitle = nil
        }

        // Safely get thumbnail
        if contact.isKeyAvailable(CNContactThumbnailImageDataKey) {
            self.thumbnailData = contact.thumbnailImageData
        } else {
            self.thumbnailData = nil
        }
    }
}
