import AppComponents
import ComposableArchitecture
import SwiftUI
import UIKit

/// Owns the native sheet configuration separately from the destination's nested presentations.
struct HomePaneSheet<Item: Identifiable, Sheet: View>: UIViewControllerRepresentable {
    let item: UIBinding<Item?>
    let viewport: CGSize
    let usesSplitLayout: Bool
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
        private weak var hostingController: HostingController?
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
                let controller = HostingController(rootView: hostedContent(for: item))
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

        private func configure(_ controller: HostingController, for item: Item) {
            guard let sheet = controller.sheetPresentationController else { return }
            if presentation.usesSplitLayout {
                let side = presentation.side(item)
                sheet.preferredPlacement = side.placement(layoutDirection: layoutDirection)
                controller.configure(side: side, viewport: presentation.viewport)
            } else {
                sheet.preferredPlacement = .automatic
                controller.configure(side: nil, viewport: presentation.viewport)
            }
        }
    }

    private final class HostingController: UIHostingController<HostedSheet> {
        private var side: HomePane?
        private var viewport: CGSize = .zero

        func configure(side: HomePane?, viewport: CGSize) {
            guard self.side != side || self.viewport != viewport else { return }
            self.side = side
            self.viewport = viewport
            preferredContentSize = side == nil ? .zero : CGSize(width: viewport.width / 2, height: viewport.height)
        }

        override func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()
            guard let side, let sheet = sheetPresentationController,
                  let container = sheet.containerView, container.bounds.width > 0 else { return }
            let frame = sheet.frameOfPresentedViewInContainerView
            guard frame.width > 0 else { return }
            // Native sheets inset their outer edge even on a flat display. Reserve that actual
            // margin within the target half instead of letting a half-width sheet cross the divider.
            let outerInset = side == .left
                ? frame.minX - container.bounds.minX
                : container.bounds.maxX - frame.maxX
            let width = max(0, container.bounds.width / 2 - max(0, outerInset))
            guard abs(preferredContentSize.width - width) > 1 / traitCollection.displayScale else { return }
            preferredContentSize.width = width
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
