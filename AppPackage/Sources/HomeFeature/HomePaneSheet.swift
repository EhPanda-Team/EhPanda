import AppComponents
import ComposableArchitecture
import SwiftUI
import UIKit

/// Owns the native sheet configuration separately from the destination's nested presentations.
struct HomePaneSheet<Item: Identifiable, Sheet: View>: UIViewControllerRepresentable {
    let item: UIBinding<Item?>
    let viewport: CGSize
    let isPartiallyOpen: Bool
    let side: (Item) -> HomePane
    var onDismiss: (() -> Void)?
    @ViewBuilder let content: (Item) -> Sheet

    func makeUIViewController(context: Context) -> Controller {
        Controller(presentation: self, environment: context.environment)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.presentation = self
        controller.layoutDirection = context.environment.layoutDirection
        controller.viewportSampling = context.environment.visibleViewportSampling
        controller.updatePresentation()
    }

    final class Controller: UIViewController {
        var presentation: HomePaneSheet
        var layoutDirection: LayoutDirection
        var viewportSampling: VisibleViewportSampling?
        private weak var hostingController: UIHostingController<HostedSheet>?
        private var presentedItem: Item?

        init(presentation: HomePaneSheet, environment: EnvironmentValues) {
            self.presentation = presentation
            layoutDirection = environment.layoutDirection
            viewportSampling = environment.visibleViewportSampling
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            present(item: presentation.item, onDismiss: { [weak self] in
                self?.presentedItem = nil
                self?.hostingController = nil
                self?.presentation.onDismiss?()
            }) { [weak self] item in
                guard let self else { return UIViewController() }
                let controller = UIHostingController(rootView: hostedContent(for: item))
                controller.modalPresentationStyle = .formSheet
                hostingController = controller
                presentedItem = item
                configure(controller, for: item)
                return controller
            }
        }

        func updatePresentation() {
            guard let hostingController, let presentedItem else { return }
            hostingController.rootView = hostedContent(for: presentedItem)
            configure(hostingController, for: presentedItem)
        }

        private func hostedContent(for item: Item) -> HostedSheet {
            HostedSheet(
                content: presentation.content(item), layoutDirection: layoutDirection,
                viewportSampling: viewportSampling
            )
        }

        private func configure(_ controller: UIHostingController<HostedSheet>, for item: Item) {
            guard let sheet = controller.sheetPresentationController else { return }
            if presentation.isPartiallyOpen {
                sheet.preferredPlacement = presentation.side(item).placement(layoutDirection: layoutDirection)
                controller.preferredContentSize = CGSize(
                    width: presentation.viewport.width / 2, height: presentation.viewport.height
                )
            } else {
                sheet.preferredPlacement = .automatic
                controller.preferredContentSize = .zero
            }
        }
    }

    private struct HostedSheet: View {
        let content: Sheet
        let layoutDirection: LayoutDirection
        let viewportSampling: VisibleViewportSampling?

        var body: some View {
            content
                .environment(\.layoutDirection, layoutDirection)
                .environment(\.visibleViewportSampling, viewportSampling)
        }
    }
}
