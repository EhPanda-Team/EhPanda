import SwiftUI
import UIKit

/// Physical sides of Home's two-pane layout, independent of reading direction.
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
