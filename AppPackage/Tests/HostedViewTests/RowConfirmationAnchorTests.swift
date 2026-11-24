import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
@testable import QuickSearchFeature
import SwiftUI
import Testing
import UIKit

/// A delete confirmation comes from the row it deletes.
///
/// On the iPad a confirmation dialog is a popover anchored to the view its modifier is attached to. Folder Manager and
/// Quick Search attached theirs to the whole list, so the popover's arrow pointed at the list's top and not at the row
/// whose Delete was tapped (the owner's C7 item, 19-13; AGENTS.md "Confirmation dialog / alert placement"). At compact
/// width the dialog is an action sheet with no anchor, so the test only requires that one is presented.
///
/// The tests ask for the dialog of the second row and read the presented alert controller's popover source: its centre
/// must lie inside the second row's frame and outside the first's.
@MainActor
struct RowConfirmationAnchorTests {
    @Test
    func theFolderDeleteConfirmationIsAnchoredOnItsRow() throws {
        let store = withDependencies {
            $0.context = .preview
        } operation: {
            var state = FolderManagerReducer.State()
            state.folders = ["Alpha", "Beta"]
            return Store(initialState: state, reducer: FolderManagerReducer.init)
        }
        try HostedView.withRoot(of: FolderManagerView(store: store), size: HostedView.sceneSize()) { root in
            store.send(.deleteButtonTapped("Beta"))
            try Self.expectConfirmationOnLastRow(in: root)
        }
    }

    @Test
    func theSavedSearchDeleteConfirmationIsAnchoredOnItsRow() throws {
        let searches = [
            SavedSearch(name: "Reading list", content: "language:english"),
            SavedSearch(name: "Favourites", content: "rating:5")
        ]
        let store = withDependencies {
            $0.context = .preview
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let state = QuickSearchReducer.State()
            state.$savedSearches.withLock({ $0 = searches })
            return Store(initialState: state, reducer: QuickSearchReducer.init)
        }
        let view = QuickSearchView(store: store, searchAction: { _ in })
        try HostedView.withRoot(of: view, size: HostedView.sceneSize()) { root in
            store.send(.deleteSavedSearchButtonTapped(searches[1]))
            try Self.expectConfirmationOnLastRow(in: root)
        }
    }

    // MARK: Reading the popover

    /// The dialog is presented, and, where it is a popover, its source is inside the page's last row and outside the
    /// row before it.
    private static func expectConfirmationOnLastRow(in root: UIView) throws {
        let alert = try presentedAlert(from: root)
        guard root.traitCollection.horizontalSizeClass == .regular else { return }
        let popover = try #require(alert.popoverPresentationController, "The dialog is not a popover at regular width.")
        let source = try #require(popover.sourceView, "The popover has no source view.")
        let sourceRect = popover.sourceRect.isEmpty ? source.bounds : popover.sourceRect
        let anchor = source.convert(sourceRect, to: nil)
        let point = CGPoint(x: anchor.midX, y: anchor.midY)
        let rows = cells(in: root)
            .map({ $0.convert($0.bounds, to: nil) })
            .sorted(by: { $0.minY < $1.minY })
        let target = try #require(rows.last, "The page has no rows.")
        let other = try #require(rows.dropLast().last, "The page has fewer than two rows.")
        #expect(
            target.contains(point),
            "The popover points at \(point), outside the row it belongs to, \(target)."
        )
        #expect(
            !other.contains(point),
            "The popover points at \(point), inside the row before it, \(other)."
        )
    }

    /// The alert controller the page presents, waiting up to five seconds for SwiftUI to present it.
    private static func presentedAlert(from root: UIView) throws -> UIAlertController {
        let deadline = Date(timeIntervalSinceNow: 5)
        while alert(presentedOver: root) == nil, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return try #require(alert(presentedOver: root), "No alert controller was presented within 5 seconds.")
    }

    private static func alert(presentedOver root: UIView) -> UIAlertController? {
        var controller = root.window?.rootViewController
        while let presented = controller?.presentedViewController {
            if let alert = presented as? UIAlertController { return alert }
            controller = presented
        }
        return nil
    }

    private static func cells(in view: UIView) -> [UICollectionViewCell] {
        ((view as? UICollectionViewCell).map({ [$0] }) ?? []) + view.subviews.flatMap(cells(in:))
    }
}
