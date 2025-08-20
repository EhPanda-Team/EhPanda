//
//  ShareViewController.swift
//  ShareExtension
//

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

        itemProvider.loadItem(forTypeIdentifier: "public.url") { (item, _) in
            if let shareURL = item as? URL, let scheme = shareURL.scheme,
               let replacedURL = URL(string: shareURL.absoluteString
                .replacingOccurrences(of: scheme, with: "ehpanda"))
            {
                self.openMainApp(url: replacedURL)
            }
        }
    }

    private func openMainApp(url: URL) {
        extensionContext?.completeRequest(
            returningItems: nil,
            completionHandler: { [weak self] _ in
                self?.openURL(url)
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
