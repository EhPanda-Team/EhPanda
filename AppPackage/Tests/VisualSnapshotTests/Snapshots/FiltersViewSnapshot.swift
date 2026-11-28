@testable import FiltersFeature
import Foundation

/// The snapshot states of `FiltersView` (19-18).
enum FiltersViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "quick-search-filters",
                heights: .screen,
                factory: .init(make: { LibraryScenarios.filters(confirmingReset: false) })
            ),
            SnapshotState(
                id: "quick-search-filters-reset-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { LibraryScenarios.filters(confirmingReset: true) },
                    interact: RevealStep.reveal(.label(String(localized: .resetFilters)))
                )
            )
        ]
    }
}
