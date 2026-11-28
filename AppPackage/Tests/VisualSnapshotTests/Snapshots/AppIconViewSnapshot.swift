import CoreGraphics
@testable import SettingFeature

/// The snapshot states of `AppIconView` (19-18).
enum AppIconViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-app-icon",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1440),
                        landscape: .init(xSmall: 683, large: 683, accessibility5: 774)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { SettingsScenarios.settings([.appearance(.init()), .appIcon(.init())]) })
            )
        ]
    }
}
