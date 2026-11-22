@testable import SettingFeature

/// The snapshot states of `DownloadSettingView` (19-18).
enum DownloadSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-download",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.settings([.download(.init())]) })
            )
        ]
    }
}
