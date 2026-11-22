@testable import SettingFeature

/// The snapshot states of `AboutView` (19-18).
enum AboutViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-about",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.settings([.about(.init())]) })
            )
        ]
    }
}
