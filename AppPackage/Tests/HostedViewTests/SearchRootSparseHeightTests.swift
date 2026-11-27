import ComposableArchitecture
import Foundation
@testable import SearchFeature
import SwiftUI
import Testing
import UIKit

/// The Search page with little to show is exactly as tall as the room its scroll view gives it, so it does not scroll.
///
/// The suggestions panel takes the scroll view's height as its floor (16-25, W-22), which keeps a sparse page from
/// collapsing. Its vertical padding sat outside that floor, so the content was always the room plus 32 pt: an empty
/// Search page scrolled 32 pt, and the snapshot measuring read a need that followed every window it was given (19-26,
/// owner decision 2026-11-27). The padding now counts within the floor.
@MainActor
struct SearchRootSparseHeightTests {
    nonisolated private static let iPhonePortrait = CGSize(width: 420, height: 912)
    nonisolated private static let taller = CGSize(width: 420, height: 1412)

    /// With no history and no saved searches, the content fills the room exactly, in any window.
    @Test(arguments: [iPhonePortrait, taller])
    func anEmptySearchPageDoesNotScroll(size: CGSize) throws {
        let page = try Self.emptySearchRoot()
        try HostedView.withRoot(of: page, size: size) { root in
            let scrollView = try #require(Self.scrollViews(in: root).first, "The Search page has no scroll view.")
            let room = Self.visibleHeight(of: scrollView)
            #expect(
                abs(scrollView.contentSize.height - room) <= 1,
                "The content is \(scrollView.contentSize.height) pt tall in \(room) pt of room."
            )
        }
    }

    /// The Search root with nothing in its history, its saved searches or its viewed galleries, from defaults of its
    /// own, so neither the host app's records nor another test's reach it.
    private static func emptySearchRoot() throws -> some View {
        let defaults = try #require(UserDefaults(suiteName: "SearchRootSparseHeightTests-\(UUID().uuidString)"))
        let store = withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            Store(initialState: SearchRootReducer.State(), reducer: SearchRootReducer.init)
        }
        return SearchRootView(store: store)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "en_US"))
    }

    /// The room a scroll view gives its content: its bounds less the insets that keep content clear of the bars.
    private static func visibleHeight(of scrollView: UIScrollView) -> CGFloat {
        scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map({ [$0] }) ?? []) + view.subviews.flatMap(scrollViews(in:))
    }
}
