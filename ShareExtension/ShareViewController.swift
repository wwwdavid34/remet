import UIKit
import UniformTypeIdentifiers

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
                        // File URL from Photos — load and copy to shared container
                        savedURL = self.saveImageToSharedContainer(image)
                    } else if let image = item as? UIImage {
                        savedURL = self.saveImageToSharedContainer(image)
                    } else if let data = item as? Data, let image = UIImage(data: data) {
                        savedURL = self.saveImageToSharedContainer(image)
                    }

                    if let savedURL {
                        self.flagPendingImport(savedURL)
                    }
                    self.openContainingAppAndComplete()
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

    /// Store the shared image path in shared UserDefaults so the main app picks it up on foreground.
    private func flagPendingImport(_ imageURL: URL) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var pending = defaults.stringArray(forKey: "pendingSharedImages") ?? []
        pending.append(imageURL.path)
        defaults.set(pending, forKey: "pendingSharedImages")
    }

    private func openContainingAppAndComplete() {
        guard let url = URL(string: "remet://import") else {
            completeRequest()
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.openURL(url)

            // Give the system a moment to process the URL open before tearing down
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.completeRequest()
            }
        }
    }

    /// Open a URL via the ObjC runtime, bypassing Swift's extension availability restrictions.
    private func openURL(_ url: URL) {
        guard let appClass = NSClassFromString("UIApplication") else { return }

        // Cast to AnyObject to use ObjC dynamic dispatch for class methods
        let cls: AnyObject = appClass
        guard let shared = cls.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() else { return }

        let openSel = NSSelectorFromString("openURL:")
        guard (shared as AnyObject).responds(to: openSel) else { return }
        _ = (shared as AnyObject).perform(openSel, with: url)
    }

    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
