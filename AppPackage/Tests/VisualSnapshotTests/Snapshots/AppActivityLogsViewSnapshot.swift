import CoreGraphics

/// The snapshot states of `AppActivityLogsView` (19-18).
enum AppActivityLogsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-activity-logs",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 2301),
                        landscape: .init(xSmall: 510, large: 526, accessibility5: 1507)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1596),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1063)
                    )
                ),
                factory: .init(make: { SettingsScenarios.activityLogs(filled: true) })
            ),
            SnapshotState(
                id: "settings-pages-activity-logs-empty",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.activityLogs(filled: false) })
            ),
            SnapshotState(
                id: "settings-pages-activity-logs-run-picker",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27, menus at the screen height: 「選單可以按你推薦處理」"
                ),
                factory: .init(
                    make: { SettingsScenarios.activityLogs(filled: true) }, interact: SettingsScenarios.openRunsMenu
                )
            )
        ]
    }
}
