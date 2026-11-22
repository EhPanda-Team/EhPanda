/// The snapshot states of `DateSeekPickerView` (19-18).
enum DateSeekPickerViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "quick-search-date-seek",
                heights: .screen,
                factory: .init(make: { LibraryScenarios.dateSeek() }, prepare: TracerScenarios.cacheHomeArtwork)
            )
        ]
    }
}
