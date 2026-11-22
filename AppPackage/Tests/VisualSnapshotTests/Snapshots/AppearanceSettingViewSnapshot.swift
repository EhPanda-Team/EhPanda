@testable import SettingFeature

/// The snapshot states of `AppearanceSettingView` (19-18).
enum AppearanceSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-appearance",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.settings([.appearance(.init())]) })
            )
        ]
    }
}
