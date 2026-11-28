import CoreGraphics

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
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1880),
                        landscape: .init(xSmall: 521, large: 531, accessibility5: 1667)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1836),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1836)
                    )
                ),
                factory: .init(
                    make: { try GalleryScenarios.archives(lowFunds: false) }, prepare: artwork,
                    interact: RevealStep.showLargeTitle()
                )
            ),
            // Where the balances are below the fold (accessibility5, run 43403534542), the sheet is scrolled to them,
            // once its large title is drawn.
            SnapshotState(
                id: "detail-pages-archives-insufficient-funds",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1818),
                        landscape: .init(xSmall: 521, large: 531, accessibility5: 1667)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1774),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1774)
                    )
                ),
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
