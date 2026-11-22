/// The snapshot states of `ToastMessageView` (19-18).
enum ToastMessageViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "app-wide-toast-success",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.app(.successToast) })
            ),
            SnapshotState(
                id: "app-wide-toast-failure",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.app(.failureToast) })
            )
        ]
    }
}
