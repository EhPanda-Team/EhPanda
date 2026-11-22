@testable import SettingFeature

/// The snapshot states of `AppIconView` (19-18).
enum AppIconViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-app-icon",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.settings([.appearance(.init()), .appIcon(.init())]) })
            )
        ]
    }
}
