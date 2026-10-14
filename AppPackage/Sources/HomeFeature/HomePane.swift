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

/// The system can reserve an entire side for vertical bars. Split the enclosing width before
/// removing each side's own inset so that the divider stays on the fold as the bars minimize.
struct HomePaneWidths: Equatable {
    let contentWidth: CGFloat
    let leftInset: CGFloat
    let rightInset: CGFloat

    var left: CGFloat {
        min(contentWidth, max(0, (contentWidth + leftInset + rightInset) / 2 - leftInset))
    }
}
