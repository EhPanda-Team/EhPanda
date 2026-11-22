@testable import SettingFeature

/// The snapshot states of `LaboratorySettingView` (19-18).
enum LaboratorySettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-laboratory",
                heights: .screen,
                factory: .init(
                    make: { SettingsScenarios.settings([.laboratory(.init())]) },
                    still: SettingsScenarios.waitForGlassShadow
                )
            )
        ]
    }
}
