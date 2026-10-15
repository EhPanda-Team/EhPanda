public import SwiftUI
public import UIKit

/// Reads local device capabilities without mistaking a wide ordinary phone for a foldable.
public struct WindowDeviceObservation: UIViewRepresentable {
    let changed: (WindowDevice) -> Void

    public init(changed: @escaping (WindowDevice) -> Void) {
        self.changed = changed
    }

    public func makeUIView(context: Context) -> DeviceView {
        DeviceView(changed: changed)
    }

    public func updateUIView(_ view: DeviceView, context: Context) {
        view.changed = changed
    }

    public static func dismantleUIView(_ view: DeviceView, coordinator: ()) {
        view.changed = nil
    }

    public final class DeviceView: UIView {
        var changed: ((WindowDevice) -> Void)?
        private var hingeState: WindowDevice.HingeState?
        private var reportedState: WindowDevice?

        init(changed: @escaping (WindowDevice) -> Void) {
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
                    switch hinge.status {
                    case .closed, .unknown: hingeState = .closed
                    case .partiallyOpen: hingeState = .partiallyOpen
                    case .fullyOpen: hingeState = .fullyOpen
                    @unknown default: hingeState = .closed
                    }
                    reportState()
                })
            }
        }

        @available(*, unavailable)
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        public override func didMoveToWindow() {
            super.didMoveToWindow()
            reportState()
        }

        private func reportState() {
            guard window != nil else { return }
            let state = hingeState.map(WindowDevice.duo) ?? (traitCollection.userInterfaceIdiom == .pad ? .pad : .other)
            guard reportedState != state else { return }
            reportedState = state
            changed?(state)
        }
    }
}
