import CoreGraphics

/// The snapshot states of `ToastMessageView` (19-18).
enum ToastMessageViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "app-wide-toast-success",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1400),
                        landscape: .init(xSmall: 734, large: 740, accessibility5: 1166)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1179)
                    )
                ),
                factory: .init(make: { SettingsScenarios.app(.successToast) })
            ),
            SnapshotState(
                id: "app-wide-toast-failure",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1400),
                        landscape: .init(xSmall: 734, large: 740, accessibility5: 1166)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1179)
                    )
                ),
                factory: .init(make: { SettingsScenarios.app(.failureToast) })
            )
        ]
    }
}
