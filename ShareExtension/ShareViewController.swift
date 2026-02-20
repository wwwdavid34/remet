import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

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
            // Handle shared URLs (e.g. Facebook profile links)
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                    guard error == nil, let sharedURL = item as? URL else {
                        self?.completeRequest()
                        return
                    }
                    self?.openMainAppWithFacebookURL(sharedURL)
                }
                return
            }

            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
                    guard error == nil else {
                        self?.completeRequest()
                        return
                    }

                    var imageURL: URL?

                    if let url = item as? URL {
                        imageURL = url
                    } else if let image = item as? UIImage {
                        // Save image to shared container
                        imageURL = self?.saveImageToSharedContainer(image)
                    } else if let data = item as? Data, let image = UIImage(data: data) {
                        imageURL = self?.saveImageToSharedContainer(image)
                    }

                    if let url = imageURL {
                        self?.openMainApp(with: url)
                    } else {
                        self?.completeRequest()
                    }
                }
                return
            }
        }

        completeRequest()
    }

    private func openMainAppWithFacebookURL(_ facebookURL: URL) {
        guard let encoded = facebookURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "remet://facebook?url=\(encoded)") else {
            completeRequest()
            return
        }

        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.completeRequest()
                }
                return
            }
            responder = responder?.next
        }

        completeRequest()
    }

    private func saveImageToSharedContainer(_ image: UIImage) -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.remet.shared"
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
            print("Failed to save image: \(error)")
            return nil
        }
    }

    private func openMainApp(with imageURL: URL) {
        // Use URL scheme to open main app with the shared image
        let urlString = "remet://import?url=\(imageURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        guard let url = URL(string: urlString) else {
            completeRequest()
            return
        }

        // Open the main app
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] _ in
                    self?.completeRequest()
                }
                return
            }
            responder = responder?.next
        }

        // Fallback: use openURL selector
        let selector = sel_registerName("openURL:")
        responder = self
        while responder != nil {
            if responder?.responds(to: selector) == true {
                responder?.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }

        completeRequest()
    }

    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
