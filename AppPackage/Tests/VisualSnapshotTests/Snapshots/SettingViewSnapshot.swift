/// The snapshot states of `SettingView` (19-18).
enum SettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-root",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.settings([]) })
            )
        ]
    }
}
