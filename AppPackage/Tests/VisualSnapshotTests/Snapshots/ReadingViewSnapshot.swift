/// The snapshot states of `ReadingView` (19-18).
enum ReadingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let pages = GalleryScenarios.prepareReaderPages
        return [
            SnapshotState(
                id: "reader-vertical",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」"
                ),
                factory: .init(make: { try GalleryScenarios.reader(.vertical) }, prepare: pages)
            ),
            SnapshotState(
                id: "reader-horizontal",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」"
                ),
                factory: .init(make: { try GalleryScenarios.reader(.horizontal) }, prepare: pages)
            ),
            SnapshotState(
                id: "reader-two-page-spread",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」"
                ),
                factory: .init(make: { try GalleryScenarios.reader(.spread) }, prepare: pages)
            ),
            SnapshotState(
                id: "reader-controls",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」"
                ),
                factory: .init(
                    make: { try GalleryScenarios.reader(.controls) }, prepare: pages,
                    still: SettingsScenarios.waitForGlassShadow
                )
            ),
            SnapshotState(
                id: "reader-slider-scrub",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」"
                ),
                factory: .init(
                    make: { try GalleryScenarios.reader(.scrub) }, prepare: pages,
                    still: SettingsScenarios.waitForGlassShadow
                )
            ),
            SnapshotState(
                id: "reader-page-failed",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」"
                ),
                factory: .init(make: { try GalleryScenarios.reader(.pageFailed) }, prepare: pages)
            ),
            SnapshotState(
                id: "reader-loading",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」"
                ),
                factory: .init(
                    make: { try GalleryScenarios.reader(.loading) }, prepare: pages,
                    still: GalleryScenarios.holdStill
                )
            ),
            SnapshotState(
                id: "reader-live-text",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「對於閱讀器這種一個螢幕高就可以測量完 UI 的頁面，可以維持螢幕高」"
                ),
                factory: .init(
                    make: { try GalleryScenarios.reader(.liveText) }, prepare: GalleryScenarios.prepareLiveText
                )
            )
        ]
    }
}
