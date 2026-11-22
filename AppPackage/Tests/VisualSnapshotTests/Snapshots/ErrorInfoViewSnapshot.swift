/// The snapshot states of `ErrorInfoView` (19-18).
enum ErrorInfoViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "app-wide-error-info",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.app(.errorInfo) })
            )
        ]
    }
}
