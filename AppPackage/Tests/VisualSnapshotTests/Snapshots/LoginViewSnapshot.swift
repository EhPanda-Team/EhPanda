/// The snapshot states of `LoginView` (19-18).
enum LoginViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-login-empty",
                heights: .screen,
                factory: .init(signedIn: false, make: { SettingsScenarios.login(.empty) })
            ),
            SnapshotState(
                id: "settings-login-filled",
                heights: .screen,
                factory: .init(
                    signedIn: false, make: { SettingsScenarios.login(.filled) }, still: LibraryScenarios.holdCaret
                )
            ),
            SnapshotState(
                id: "settings-login-error",
                heights: .screen,
                factory: .init(signedIn: false, make: { SettingsScenarios.login(.error) })
            )
        ]
    }
}
