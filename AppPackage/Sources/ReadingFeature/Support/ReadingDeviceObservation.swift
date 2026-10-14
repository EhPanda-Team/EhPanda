import SwiftUI
import UIKit

/// Reads the reader's own hierarchy; a wide ordinary iPhone does not gain orientation automation.
struct ReadingDeviceObservation: UIViewRepresentable {
    let changed: (Bool) -> Void

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
        var changed: ((Bool) -> Void)?
        private var hasHinge = false
        private var reportedSupport: Bool?

        init(changed: @escaping (Bool) -> Void) {
            self.changed = changed
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            registerForTraitChanges([UITraitUserInterfaceIdiom.self]) { (view: DeviceView, _: UITraitCollection) in
                view.reportSupport()
            }
            if #available(iOS 27.1, *) {
                addInteraction(UIHingeInteraction { [weak self] _, update in
                    // A nil hinge also marks removal from the observing hierarchy, not a different device.
                    guard let self, update.hinge != nil else { return }
                    hasHinge = true
                    reportSupport()
                })
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportSupport()
        }

        private func reportSupport() {
            guard window != nil else { return }
            let supports = traitCollection.userInterfaceIdiom == .pad || hasHinge
            guard reportedSupport != supports else { return }
            reportedSupport = supports
            changed?(supports)
        }
    }
}
