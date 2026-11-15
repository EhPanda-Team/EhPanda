import AppModels
import Foundation
import GalleryListComponents
import SwiftUI
import Testing
import UIKit

/// `GalleryList` holds its error view only while the list has failed.
///
/// The error view is a `ContentUnavailableView`, which becomes a scroll view when it gets less height than it needs.
/// The list used to keep it on the page at all times, hidden with opacity 0. Wherever the keyboard left less room
/// than the view needs (iPhone in landscape, the largest text sizes), a second, invisible scroll view then lay over
/// the list, and a list whose search field became active while it was there did not get the 35 points of top spacing
/// the system gives a list under an active search bar. Whether the keyboard or the search bar came first varied from
/// launch to launch, so the visual check captured `front-page-search` in two positions (16 of 162 hosted pictures).
@MainActor
struct GalleryListErrorViewTests {
    /// Less height than the error view needs at any text size.
    private static let shortHeight: CGFloat = 100

    @Test(arguments: [LoadingState.idle, .loading])
    func aListThatHasNotFailedHoldsNoScrollViewButItsOwn(loadingState: LoadingState) throws {
        #expect(try Self.scrollViewCount(loadingState: loadingState) == 1)
    }

    /// The premise of the test above: at this height the error view scrolls once the list shows it.
    @Test
    func aFailedListScrollsAnErrorViewThatDoesNotFit() throws {
        #expect(try Self.scrollViewCount(loadingState: .failed(.unknown)) == 2)
    }

    /// How many scroll views a list holds in a window `shortHeight` tall, hidden ones included. The list builds its
    /// scroll views only inside a window (``HostedView``).
    private static func scrollViewCount(loadingState: LoadingState) throws -> Int {
        let list = GalleryList(
            displayMode: .row, galleries: [], pageNumber: nil, loadingState: loadingState, footerLoadingState: .idle
        )
        .environment(\.dynamicTypeSize, .large)
        .environment(\.locale, Locale(identifier: "en_US"))
        return try HostedView.withRoot(of: list, size: CGSize(width: 390, height: shortHeight)) { root in
            scrollViews(in: root).count
        }
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map({ [$0] }) ?? []) + view.subviews.flatMap(scrollViews(in:))
    }
}
