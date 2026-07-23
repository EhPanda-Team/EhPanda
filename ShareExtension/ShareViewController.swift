import AppIntents
import UIKit

class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let extensionItem = extensionContext?
                .inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first,
              itemProvider.hasItemConformingToTypeIdentifier("public.url")
        else {
            extensionContext?.completeRequest(
                returningItems: nil,
                completionHandler: nil
            )
            return
        }

        itemProvider.loadItem(forTypeIdentifier: "public.url") { [weak self] (item, _) in
            guard let shareURL = item as? URL,
                  var components = URLComponents(url: shareURL, resolvingAgainstBaseURL: false)
            else {
                Task { @MainActor in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
                return
            }
            components.scheme = "ehpanda"
            guard let replacedURL = components.url else {
                Task { @MainActor in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                }
                return
            }
            Task { @MainActor in
                self?.openMainApp(url: replacedURL)
            }
        }
    }

    @MainActor
    private func openMainApp(url: URL) {
        extensionContext?.completeRequest(
            returningItems: nil,
            completionHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.openURL(url)
                }
            }
        )
    }

    @discardableResult
    @objc private func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                return application.perform(
                    #selector(openURL(_:)), with: url
                ) != nil
            }
            responder = responder?.next
        }
        return false
    }
}
