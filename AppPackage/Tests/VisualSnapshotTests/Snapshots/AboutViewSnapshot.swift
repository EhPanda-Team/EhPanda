import CoreGraphics
@testable import SettingFeature

/// The snapshot states of `AboutView` (19-18).
enum AboutViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-about",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1799, large: 1893, accessibility5: 4321),
                        landscape: .init(xSmall: 1683, large: 1778, accessibility5: 3181)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1759, large: 1854, accessibility5: 3227),
                        landscape: .init(xSmall: 1759, large: 1854, accessibility5: 3165)
                    )
                ),
                factory: .init(make: { SettingsScenarios.settings([.about(.init())]) })
            )
        ]
    }
}
