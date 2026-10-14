import SwiftUI
import UIKit

/// Physical sides of Home's partially folded layout, independent of reading direction.
public enum HomePane: Equatable, Sendable {
    case left
    case right

    var opposite: Self { self == .left ? .right : .left }

    func placement(layoutDirection: LayoutDirection) -> UISheetPresentationController.Placement {
        switch (self, layoutDirection) {
        case (.left, .leftToRight), (.right, .rightToLeft):
            return .leading
        default:
            return .trailing
        }
    }
}

struct HomeHingeObservation: ViewModifier {
    let changed: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                changed(context.hinge?.status == .partiallyOpen)
            }
        } else {
            content
        }
    }
}
