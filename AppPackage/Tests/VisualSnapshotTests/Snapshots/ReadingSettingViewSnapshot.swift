import CoreGraphics
import ReadingSettingFeature
@testable import SettingFeature

/// The snapshot states of `ReadingSettingView` (19-18).
enum ReadingSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let pages = GalleryScenarios.prepareReaderPages
        return [
            SnapshotState(
                id: "reader-settings-sheet",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 918, large: 960, accessibility5: 3277),
                        landscape: .init(xSmall: 797, large: 835, accessibility5: 2052)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2735),
                        landscape: .init(xSmall: 856, large: 898, accessibility5: 2735)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.reader(.settings) }, prepare: pages)
            ),
            SnapshotState(
                id: "settings-pages-reading",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 920, accessibility5: 3237),
                        landscape: .init(xSmall: 777, large: 815, accessibility5: 2032)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2086),
                        landscape: .init(xSmall: 834, large: 845, accessibility5: 1905)
                    )
                ),
                factory: .init(make: { SettingsScenarios.settings([.reading(.init())]) })
            )
        ]
    }
}
