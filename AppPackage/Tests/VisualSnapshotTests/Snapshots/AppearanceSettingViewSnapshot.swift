import CoreGraphics
@testable import SettingFeature

/// The snapshot states of `AppearanceSettingView` (19-18).
enum AppearanceSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-appearance",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1860),
                        landscape: .init(xSmall: 587, large: 615, accessibility5: 1223)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1275),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1144)
                    )
                ),
                factory: .init(make: { SettingsScenarios.settings([.appearance(.init())]) })
            )
        ]
    }
}
