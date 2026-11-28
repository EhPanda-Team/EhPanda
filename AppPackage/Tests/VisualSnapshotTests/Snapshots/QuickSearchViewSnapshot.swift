import AppModels
import CoreGraphics

/// The snapshot states of `QuickSearchView` (19-18).
enum QuickSearchViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "quick-search-list",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1211),
                        landscape: .init(xSmall: 422, large: 444, accessibility5: 732)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { LibraryScenarios.quickSearch(.list) })
            ),
            SnapshotState(
                id: "quick-search-empty",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 947),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 627)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { LibraryScenarios.quickSearch(.empty) })
            ),
            SnapshotState(
                id: "quick-search-delete-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { LibraryScenarios.quickSearch(.deleteConfirmation) },
                    interact: RevealStep.reveal(.label((LibraryScenarios.savedSearches.first ?? .empty).name))
                )
            ),
            SnapshotState(
                id: "quick-search-word-editor",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 912),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 615)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(
                    make: { LibraryScenarios.quickSearch(.wordEditor) }, still: LibraryScenarios.holdCaret
                )
            )
        ]
    }
}
