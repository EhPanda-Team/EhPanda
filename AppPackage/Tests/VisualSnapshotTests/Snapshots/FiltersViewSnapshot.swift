import CoreGraphics
@testable import FiltersFeature
import Foundation

/// The snapshot states of `FiltersView` (19-18).
enum FiltersViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "quick-search-filters",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1154, large: 1244, accessibility5: 3777),
                        landscape: .init(xSmall: 1026, large: 1072, accessibility5: 2153)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2864),
                        landscape: .init(xSmall: 1074, large: 1121, accessibility5: 2864)
                    )
                ),
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
