/// The snapshot states of `BlockedUsersView` (19-18).
enum BlockedUsersViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "blocked-users-filled",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.blockedUsers(filled: true) })
            ),
            SnapshotState(
                id: "blocked-users-empty",
                heights: .screen,
                factory: .init(make: { SettingsScenarios.blockedUsers(filled: false) })
            )
        ]
    }
}
