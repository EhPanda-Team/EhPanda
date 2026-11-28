import CoreGraphics

/// The snapshot states of `DateSeekPickerView` (19-18).
enum DateSeekPickerViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "quick-search-date-seek",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1037),
                        landscape: .init(xSmall: 649, large: 658, accessibility5: 783)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 940)
                    )
                ),
                factory: .init(make: { LibraryScenarios.dateSeek() }, prepare: TracerScenarios.cacheHomeArtwork)
            )
        ]
    }
}
