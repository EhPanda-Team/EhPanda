import AppComponents
import ComposableArchitecture
import DetailFeature
import SwiftUI
import UIKit

/// Owns a native trailing sheet independently of its content's navigation and nested presentations.
struct FloatingDownloadPanel: UIViewControllerRepresentable {
    let item: UIBinding<StoreOf<DownloadsReducer.FloatingPanelFeature>?>
    let viewport: CGSize
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller(presentation: self, layoutDirection: context.environment.layoutDirection)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.presentation = self
        controller.layoutDirection = context.environment.layoutDirection
        controller.updatePresentation()
    }

    final class Controller: UIViewController {
        var presentation: FloatingDownloadPanel
        var layoutDirection: LayoutDirection
        private weak var hostingController: UIHostingController<FloatingDownloadPanelContent>?

        init(presentation: FloatingDownloadPanel, layoutDirection: LayoutDirection) {
            self.presentation = presentation
            self.layoutDirection = layoutDirection
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            present(item: presentation.item, onDismiss: { [weak self] in
                self?.hostingController = nil
                self?.presentation.onDismiss()
            }) { [weak self] store in
                let controller = UIHostingController(rootView: FloatingDownloadPanelContent(store: store))
                controller.modalPresentationStyle = .formSheet
                self?.hostingController = controller
                self?.configure(controller)
                return controller
            }
        }

        func updatePresentation() {
            guard let hostingController else { return }
            configure(hostingController)
        }

        private func configure(_ controller: UIHostingController<FloatingDownloadPanelContent>) {
            controller.preferredContentSize = CGSize(
                width: min(480, max(320, presentation.viewport.width - 32)),
                height: max(320, presentation.viewport.height - 32)
            )
            guard let sheet = controller.sheetPresentationController else { return }
            sheet.preferredPlacement = layoutDirection == .rightToLeft ? .leading : .trailing
            sheet.largestUndimmedDetentIdentifier = .large
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }
    }
}

private struct FloatingDownloadPanelContent: View {
    let store: StoreOf<DownloadsReducer.FloatingPanelFeature>

    var body: some View {
        Group {
            switch store.case {
            case .details(let detailStore):
                GallerySheetView(store: detailStore, showsCloseButton: true)
            case .pages(let pagesStore):
                NavigationStack {
                    DownloadInspectorView(store: pagesStore)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .privacyMask()
        .accessibilityIdentifier("download-floating-panel")
    }
}
