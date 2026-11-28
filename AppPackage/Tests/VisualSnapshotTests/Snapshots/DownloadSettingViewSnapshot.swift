import CoreGraphics
@testable import SettingFeature

/// The snapshot states of `DownloadSettingView` (19-18).
enum DownloadSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-download",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1730),
                        landscape: .init(xSmall: 420, large: 434, accessibility5: 1018)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 846)
                    )
                ),
                factory: .init(make: { SettingsScenarios.settings([.download(.init())]) })
            )
        ]
    }
}
