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
    func aListThatHasNotFailedHoldsNoScrollViewButItsOwn(loadingState: LoadingState) {
        #expect(Self.scrollViews(loadingState: loadingState).count == 1)
    }

    /// The premise of the test above: at this height the error view scrolls once the list shows it.
    @Test
    func aFailedListScrollsAnErrorViewThatDoesNotFit() {
        #expect(Self.scrollViews(loadingState: .failed(.unknown)).count == 2)
    }

    /// Every scroll view of a list hosted in a window `shortHeight` tall, hidden ones included.
    ///
    /// The list builds its scroll views only inside a window, and the test process has no window scene to make one
    /// in, so the window comes from `init(frame:)`, as in the other hosted layout tests.
    private static func scrollViews(loadingState: LoadingState) -> [UIScrollView] {
        let list = GalleryList(
            displayMode: .row, galleries: [], pageNumber: nil, loadingState: loadingState, footerLoadingState: .idle
        )
        let controller = UIHostingController(rootView: list
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "en_US"))
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: shortHeight))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: .now.addingTimeInterval(0.2))
        return scrollViews(in: controller.view)
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map({ [$0] }) ?? []) + view.subviews.flatMap(scrollViews(in:))
    }
}
