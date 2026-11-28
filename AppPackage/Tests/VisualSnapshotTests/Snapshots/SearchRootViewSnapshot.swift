import VisualSnapshotSupport

/// The snapshot states of `SearchRootView` (19-18).
enum SearchRootViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "search-root-empty",
                heights: .screen,
                factory: .init(make: { LibraryScenarios.searchRoot(history: false) })
            ),
            SnapshotState(
                id: "search-root-history",
                heights: .screen,
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
            ),
            SnapshotState(
                id: "search-typing-suggestions",
                heights: .screen,
                factory: .init(
                    make: { LibraryScenarios.searchRoot(history: true, suggestions: true) }, prepare: artwork,
                    interact: {
                        try await LibraryScenarios.type(
                            LibraryFixtures.typedTag, in: $0, until: LibraryScenarios.firstSuggestion
                        )
                    }
                )
            )
        ]
    }
}
