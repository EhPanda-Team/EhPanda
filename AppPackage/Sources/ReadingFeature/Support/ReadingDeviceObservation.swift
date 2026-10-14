import SwiftUI
import UIKit

struct ReadingDeviceState: Equatable {
    var supportsAutomaticLayout: Bool
    var isPartiallyOpen: Bool
}

/// Reads the reader's own hierarchy; a wide ordinary iPhone does not gain orientation automation.
struct ReadingDeviceObservation: UIViewRepresentable {
    let changed: (ReadingDeviceState) -> Void

    func makeUIView(context: Context) -> DeviceView {
        DeviceView(changed: changed)
    }

    func updateUIView(_ view: DeviceView, context: Context) {
        view.changed = changed
    }

    static func dismantleUIView(_ view: DeviceView, coordinator: ()) {
        view.changed = nil
    }

    final class DeviceView: UIView {
        var changed: ((ReadingDeviceState) -> Void)?
        private var hasHinge = false
        private var isPartiallyOpen = false
        private var reportedState: ReadingDeviceState?

        init(changed: @escaping (ReadingDeviceState) -> Void) {
            self.changed = changed
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            registerForTraitChanges([UITraitUserInterfaceIdiom.self]) { (view: DeviceView, _: UITraitCollection) in
                view.reportState()
            }
            if #available(iOS 27.1, *) {
                addInteraction(UIHingeInteraction { [weak self] _, update in
                    // A nil hinge also marks removal from the observing hierarchy, not a different device.
                    guard let self, let hinge = update.hinge else { return }
                    hasHinge = true
                    isPartiallyOpen = hinge.status == .partiallyOpen
                    reportState()
                })
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportState()
        }

        private func reportState() {
            guard window != nil else { return }
            let state = ReadingDeviceState(
                supportsAutomaticLayout: traitCollection.userInterfaceIdiom == .pad || hasHinge,
                isPartiallyOpen: isPartiallyOpen
            )
            guard reportedState != state else { return }
            reportedState = state
            changed?(state)
        }
    }
}
