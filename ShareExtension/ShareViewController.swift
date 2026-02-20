import UIKit
import UniformTypeIdentifiers
import UserNotifications

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.remet.shared"

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            completeRequest()
            return
        }

        for attachment in attachments {
            // Check for images first to avoid intercepting image file URLs
            // (image attachments from Photos also conform to UTType.url as file URLs)
            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
                    guard let self, error == nil else {
                        self?.completeRequest()
                        return
                    }

                    var savedURL: URL?

                    if let url = item as? URL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                        savedURL = self.saveImageToSharedContainer(image)
                    } else if let image = item as? UIImage {
                        savedURL = self.saveImageToSharedContainer(image)
                    } else if let data = item as? Data, let image = UIImage(data: data) {
                        savedURL = self.saveImageToSharedContainer(image)
                    }

                    if let savedURL {
                        self.flagPendingImport(savedURL)
                        self.scheduleNotification(
                            title: "Photo Ready to Import",
                            body: "Tap to open Remet and process the shared photo."
                        )
                    }
                    self.completeRequest()
                }
                return
            }

            // Handle shared web URLs (e.g. Facebook profile links)
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                    guard let self, error == nil, let sharedURL = item as? URL else {
                        self?.completeRequest()
                        return
                    }
                    // Only handle Facebook / Meta profile URLs
                    guard self.isFacebookURL(sharedURL) else {
                        self.completeRequest()
                        return
                    }
                    self.flagPendingFacebookURL(sharedURL)
                    self.scheduleNotification(
                        title: "Facebook Profile Received",
                        body: "Tap to open Remet and link this profile to a person."
                    )
                    self.completeRequest()
                }
                return
            }
        }

        completeRequest()
    }

    // MARK: - Facebook URL Validation

    private func isFacebookURL(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return ["www.facebook.com", "facebook.com", "www.fb.com", "fb.com", "m.facebook.com"].contains(host)
    }

    // MARK: - Image Handling

    private func saveImageToSharedContainer(_ image: UIImage) -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return nil
        }

        let fileName = "shared_image_\(UUID().uuidString).jpg"
        let fileURL = containerURL.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return nil
        }

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    private func flagPendingImport(_ imageURL: URL) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var pending = defaults.stringArray(forKey: "pendingSharedImages") ?? []
        pending.append(imageURL.path)
        defaults.set(pending, forKey: "pendingSharedImages")
    }

    // MARK: - Facebook URL Handling

    private func flagPendingFacebookURL(_ url: URL) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(url.absoluteString, forKey: "pendingFacebookURL")
    }

    // MARK: - Notification

    private func scheduleNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "com.remet.shared-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}

