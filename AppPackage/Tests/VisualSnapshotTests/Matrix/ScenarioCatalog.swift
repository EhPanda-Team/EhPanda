import AppModels
import CookieClient
import Foundation
import SwiftUI
import UIKit
import VisualSnapshotSupport

/// One scenario's real view: how to build it, whether it is signed in, what it loads before hosting (synthetic
/// artwork into the image cache), and the steps, if any, that bring the hosted view to its state.
///
/// The steps are of two kinds, marked by their argument label in the state's `*ViewSnapshot.swift` file (owner
/// decision 2026-11-23, 「把步驟拆成兩種」, split the steps into two kinds; 19-30):
/// - `still` is a stillness step. All it does is let what `make` built finish and hold it still, so the page can
///   settle at screen size: it stops a spinner or a caret's blink, or waits for a keyboard, an alert or a glass
///   shadow the state itself brought up, and re-focuses only a field the state itself focused.
/// - `interact` is an operating step: a user's action (a tap or activation, a held tap, opening a menu or a dialog,
///   scrolling, typing, focusing a field the state did not focus), or a check or correction the page does not need in
///   order to settle, together with everything the same step does after its action: a hold of what the action
///   brought up belongs to that step, in its order.
///
/// Order. On the screen-sized path `still` and `interact` run back to back, still first, after hosting. On the tall
/// path `still` runs at screen size right after hosting; the page then settles and is frozen at native size, the
/// window grows, and `interact` runs in the grown window, so an operating step (a popover's anchor, a scroll
/// position) sees the page it operates. A step moves between kinds by its argument label only.
struct ScenarioFactory {
    typealias Make = @MainActor () throws -> AnyView
    typealias Prepare = @MainActor () async throws -> Void
    typealias Interact = @MainActor (UIWindow) async throws -> Void

    let signedIn: Bool
    /// The cookie jar the scenario reads, when its cookies are themselves on screen; otherwise a signed-in scenario
    /// reads the preview client and a signed-out one an empty jar.
    let cookies: CookieClient?
    let make: Make
    let prepare: Prepare?
    let still: Interact?
    let interact: Interact?
    /// The fewest identical reads its pictures settle on (``HostedWindowCapture/settle(_:minimumReads:)``).
    let minimumReads: Int

    init(
        signedIn: Bool = true, cookies: CookieClient? = nil, make: @escaping Make, prepare: Prepare? = nil,
        still: Interact? = nil, interact: Interact? = nil, minimumReads: Int = HostedWindowCapture.minimumReads
    ) {
        self.signedIn = signedIn
        self.cookies = cookies
        self.make = make
        self.prepare = prepare
        self.still = still
        self.interact = interact
        self.minimumReads = minimumReads
    }
}

/// Scenario ID → state. Every registered ID must be in `scenarios.json` (`ScenarioInventoryTests`).
enum ScenarioCatalog {
    /// Every view's snapshot provider (19-18), one line each. Swift has no type discovery, so a new provider is
    /// listed here; `ScenarioInventoryTests` fails until the inventory and the list agree.
    static var providers: [any SnapshotProvider.Type] {
        [
            AgeWallViewSnapshot.self,
            AnalyticsChoiceViewSnapshot.self,
            LibraryViewSnapshot.self,
            HomeViewSnapshot.self,
            FrontPageViewSnapshot.self,
            PopularViewSnapshot.self,
            WatchedViewSnapshot.self,
            ToplistsViewSnapshot.self,
            HistoryViewSnapshot.self,
            SearchRootViewSnapshot.self,
            SearchViewSnapshot.self,
            QuickSearchViewSnapshot.self,
            FiltersViewSnapshot.self,
            DateSeekPickerViewSnapshot.self,
            FavoritesViewSnapshot.self,
            DownloadsViewSnapshot.self,
            DownloadInspectorViewSnapshot.self,
            DetailViewSnapshot.self,
            GallerySheetViewSnapshot.self,
            SettingViewSnapshot.self,
            CommentsViewSnapshot.self,
            PostCommentViewSnapshot.self,
            ReportFormViewSnapshot.self,
            PreviewsViewSnapshot.self,
            GalleryInfoViewSnapshot.self,
            DetailSearchViewSnapshot.self,
            ArchivesViewSnapshot.self,
            TorrentsViewSnapshot.self,
            TagDetailViewSnapshot.self,
            NewDawnViewSnapshot.self,
            FolderManagerViewSnapshot.self,
            ReadingViewSnapshot.self,
            ReadingSettingViewSnapshot.self,
            AccountSettingViewSnapshot.self,
            BlockedUsersViewSnapshot.self,
            LoginViewSnapshot.self,
            GeneralSettingViewSnapshot.self,
            AppActivityLogsViewSnapshot.self,
            AppearanceSettingViewSnapshot.self,
            AppIconViewSnapshot.self,
            DownloadSettingViewSnapshot.self,
            LaboratorySettingViewSnapshot.self,
            AboutViewSnapshot.self,
            EhSettingViewSnapshot.self,
            ErrorInfoViewSnapshot.self,
            ToastMessageViewSnapshot.self
        ]
    }

    /// Every provider's states. An ID declared twice appears twice: ``state(_:)`` keeps the first, and
    /// `ScenarioInventoryTests` fails.
    @MainActor
    static var states: [SnapshotState] {
        providers.flatMap({ $0.states })
    }

    @MainActor
    static var registeredIDs: Set<String> {
        Set(states.map(\.id))
    }

    @MainActor
    static func state(_ id: String) throws -> SnapshotState {
        guard let state = states.first(where: { $0.id == id }) else { throw ScenarioCatalogError.unregistered(id) }
        return state
    }
}

enum ScenarioCatalogError: Error, Equatable {
    case unregistered(String)
    case missingFixture(String)
}

extension SnapshotMatrixCase {
    /// Captures the catalog's scenario `id`.
    @MainActor
    func capture(scenario id: String) async throws {
        let state = try ScenarioCatalog.state(id)
        try await state.factory.prepare?()
        try await capture(scenario: id, factory: state.factory, heights: state.heights)
    }
}
