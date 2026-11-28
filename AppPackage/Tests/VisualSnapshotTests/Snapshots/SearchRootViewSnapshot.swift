import CoreGraphics

/// The snapshot states of `SearchRootView` (19-18).
enum SearchRootViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "search-root-empty",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1351),
                        landscape: .init(xSmall: 690, large: 696, accessibility5: 1122)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1115)
                    )
                ),
                factory: .init(make: { LibraryScenarios.searchRoot(history: false) })
            ),
            SnapshotState(
                id: "search-root-history",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1896),
                        landscape: .init(xSmall: 697, large: 703, accessibility5: 1395)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1410),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1286)
                    )
                ),
                factory: .init(make: { LibraryScenarios.searchRoot(history: true) }, prepare: artwork)
            ),
            SnapshotState(
                id: "search-clear-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { LibraryScenarios.searchRoot(history: true) }, prepare: artwork,
                    interact: { window in
                        try await BrowsingScenarios.activate(LibraryScenarios.removeAllLabel, in: window)
                        try await RevealStep.awaitDialogPlatter()(window)
                    }
                )
            )
        ]
    }
}
