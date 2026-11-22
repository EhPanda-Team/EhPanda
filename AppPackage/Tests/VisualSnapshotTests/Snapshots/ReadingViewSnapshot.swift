/// The snapshot states of `ReadingView` (19-18).
enum ReadingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let pages = GalleryScenarios.prepareReaderPages
        return [
            SnapshotState(
                id: "reader-vertical",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reader(.vertical) }, prepare: pages)
            ),
            SnapshotState(
                id: "reader-horizontal",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reader(.horizontal) }, prepare: pages)
            ),
            SnapshotState(
                id: "reader-two-page-spread",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reader(.spread) }, prepare: pages)
            ),
            SnapshotState(
                id: "reader-controls",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.reader(.controls) }, prepare: pages,
                    interact: SettingsScenarios.waitForGlassShadow
                )
            ),
            SnapshotState(
                id: "reader-slider-scrub",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.reader(.scrub) }, prepare: pages,
                    interact: SettingsScenarios.waitForGlassShadow
                )
            ),
            SnapshotState(
                id: "reader-page-failed",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reader(.pageFailed) }, prepare: pages)
            ),
            SnapshotState(
                id: "reader-loading",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.reader(.loading) }, prepare: pages,
                    interact: GalleryScenarios.holdStill
                )
            ),
            SnapshotState(
                id: "reader-live-text",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.reader(.liveText) }, prepare: GalleryScenarios.prepareLiveText
                )
            )
        ]
    }
}
