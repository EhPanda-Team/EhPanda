/// The snapshot states of `ArchivesView` (19-18).
enum ArchivesViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            // At accessibility5 the sheet's large title could be laid out in its hidden error view, and drawn in one
            // run and not in the next (run 43451019962): it is given back to the shown list.
            SnapshotState(
                id: "detail-pages-archives",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.archives(lowFunds: false) }, prepare: artwork,
                    interact: RevealStep.showLargeTitle()
                )
            ),
            // Where the balances are below the fold (accessibility5, run 43403534542), the sheet is scrolled to them,
            // once its large title is drawn.
            SnapshotState(
                id: "detail-pages-archives-insufficient-funds",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.archives(lowFunds: true) }, prepare: artwork,
                    interact: RevealStep.showLargeTitle(
                        then: RevealStep.reveal(.label(GalleryScenarios.lowGalleryPointsLabel))
                    )
                )
            )
        ]
    }
}
