import AppComponents
import ComposableArchitecture
import Foundation
import SwiftUI
import SystemNotification
import Testing
import UIKit

// T-1 of quick 261126-iq9: the toast stands on its host's bottom safe-area edge with a small gap, with no fixed
// bottom constant. A page inside a tab then clears the tab bar exactly once, because the tab bar is already part of
// its safe area. A host whose bottom chrome lies outside that safe area (the reader's control panel overlay, a bar
// applied inside the host's own content) passes the chrome's height as `bottomInset`, and the toast stands that much
// higher. Both are layout facts, so they are read from a hosted window (``HostedView``).
@MainActor
struct ToastPlacementTests {
    private static let windowSize = CGSize(width: 420, height: 912)

    @Test
    func theToastStandsOnTheSafeAreaEdgeWithASmallGap() throws {
        let safeAreaEdge = Self.windowSize.height - (try Self.bottomSafeAreaInset())
        let gap = safeAreaEdge - (try Self.toastBottomEdge(bottomInset: 0))

        #expect((8...24).contains(gap), "The toast stands \(gap) points above the safe-area edge.")
    }

    @Test
    func aHostsBottomInsetLiftsTheToastByThatMuch() throws {
        let plain = try Self.toastBottomEdge(bottomInset: 0)
        let lifted = try Self.toastBottomEdge(bottomInset: 100)

        #expect(abs((plain - lifted) - 100) <= 0.5, "The toast moved \(plain - lifted) points.")
    }

    /// The bottom safe-area inset of a window of ``windowSize``.
    private static func bottomSafeAreaInset() throws -> CGFloat {
        try HostedView.withRoot(of: Color.clear, size: windowSize) { root in
            root.safeAreaInsets.bottom
        }
    }

    /// Where the presented toast's bottom edge stands in a window of ``windowSize``, hosted on a clear view, with
    /// `bottomInset` given by the host.
    private static func toastBottomEdge(bottomInset: CGFloat) throws -> CGFloat {
        let store = Store<AppAlertState<Never>, Never>(
            initialState: .success(caption: "Placement probe"), reducer: EmptyReducer<AppAlertState<Never>, Never>.init
        )
        let host = Color.clear
            .toast(.constant(store), bottomInset: bottomInset)
            .environment(\.locale, Locale(identifier: "en_US"))
        return try AccessibilityElements.read(of: host, size: windowSize) { elements in
            let toast = try #require(elements.first(where: {
                $0.accessibilityLabel?.contains("Placement probe") == true
            }))
            return toast.accessibilityFrame.maxY
        }
    }
}
