/// The snapshot states of `AppActivityLogsView` (19-18).
enum AppActivityLogsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-activity-logs",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.activityLogs(filled: true) })
            ),
            SnapshotState(
                id: "settings-pages-activity-logs-empty",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.activityLogs(filled: false) })
            ),
            SnapshotState(
                id: "settings-pages-activity-logs-run-picker",
                heights: .screen,
                factory: .init(
                    make: { SettingsScenarios.activityLogs(filled: true) }, interact: SettingsScenarios.openRunsMenu
                )
            )
        ]
    }
}
