import CoreGraphics

/// The snapshot states of `BlockedUsersView` (19-18).
enum BlockedUsersViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "blocked-users-filled",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 962),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 580)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
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
