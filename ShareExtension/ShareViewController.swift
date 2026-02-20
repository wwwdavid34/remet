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
                        self.scheduleNotification()
                    }
                    self.completeRequest()
                }
                return
            }
        }

        completeRequest()
    }

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

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()

        // Request permission if not yet granted (main app should also request during onboarding)
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Photo Ready to Import"
            content.body = "Tap to open Remet and process the shared photo."
            content.sound = .default

            // Deliver in 1 second (minimum for time-interval trigger)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "com.remet.shared-import-\(UUID().uuidString)",
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
