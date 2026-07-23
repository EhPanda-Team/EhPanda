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
        // Order matters: completing the request tears the extension down, so the
        // hand-off has to have been made before the request completes.
        openInHostApplication(url)
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// Asks the system to open `url`, which routes it to the containing app.
    ///
    /// No sanctioned route exists, and all three public candidates were measured
    /// as dead on iOS 26.5: `NSExtensionContext.open(_:)` is honoured only for the
    /// Today and iMessage extension points; UIKit force-fails the deprecated
    /// `openURL:` reached through the responder chain ("BUG IN CLIENT OF UIKIT
    /// ... Force returning false"); and the `_UIHostedWindowScene` that terminates
    /// an extension's responder chain accepts `openURL:options:completionHandler:`
    /// but never invokes the completion or opens anything.
    ///
    /// `LSApplicationWorkspace` is private API, used deliberately — this build does
    /// not ship to the App Store. `ShareSheetUITests` drives the real share sheet
    /// end to end, so it turns red the moment this route stops working.
    @MainActor
    @discardableResult
    private func openInHostApplication(_ url: URL) -> Bool {
        let defaultWorkspaceSelector = NSSelectorFromString("defaultWorkspace")
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              workspaceClass.responds(to: defaultWorkspaceSelector),
              let workspace = workspaceClass
                .perform(defaultWorkspaceSelector)?
                .takeUnretainedValue() as? NSObject
        else {
            return false
        }

        let openSelector = NSSelectorFromString("openURL:")
        guard workspace.responds(to: openSelector) else { return false }

        typealias OpenURL = @convention(c) (NSObject, Selector, NSURL) -> Bool
        let openImplementation = unsafeBitCast(
            workspace.method(for: openSelector),
            to: OpenURL.self
        )
        return openImplementation(workspace, openSelector, url as NSURL)
    }
}
