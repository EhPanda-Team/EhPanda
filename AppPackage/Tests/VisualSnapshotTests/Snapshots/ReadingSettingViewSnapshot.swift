import ReadingSettingFeature
@testable import SettingFeature

/// The snapshot states of `ReadingSettingView` (19-18).
enum ReadingSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let pages = GalleryScenarios.prepareReaderPages
        return [
            SnapshotState(
                id: "reader-settings-sheet",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reader(.settings) }, prepare: pages)
            ),
            SnapshotState(
                id: "settings-pages-reading",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.settings([.reading(.init())]) })
            )
        ]
    }
}
