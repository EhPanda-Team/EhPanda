import CoreGraphics

/// The snapshot states of `ErrorInfoView` (19-18).
enum ErrorInfoViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "app-wide-error-info",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1998),
                        landscape: .init(xSmall: 560, large: 588, accessibility5: 1222)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1518),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1518)
                    )
                ),
                factory: .init(make: { SettingsScenarios.app(.errorInfo) })
            )
        ]
    }
}
