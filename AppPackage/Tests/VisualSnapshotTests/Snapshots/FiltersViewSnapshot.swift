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
                heights: .screen,
                factory: .init(
                    make: { LibraryScenarios.filters(confirmingReset: true) },
                    interact: RevealStep.reveal(.label(String(localized: .resetFilters)))
                )
            )
        ]
    }
}
