/// The snapshot states of `ReportFormView` (19-18).
enum ReportFormViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "report-form-loading",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.reportForm(.loading) }, still: GalleryScenarios.holdStill
                )
            ),
            SnapshotState(
                id: "report-form-ready",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reportForm(.ready) })
            ),
            SnapshotState(
                id: "report-form-filled",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reportForm(.filled) })
            ),
            SnapshotState(
                id: "report-form-sending",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.reportForm(.sending) }, still: GalleryScenarios.holdStill
                )
            ),
            SnapshotState(
                id: "report-form-sent",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reportForm(.sent) })
            ),
            SnapshotState(
                id: "report-form-unavailable",
                heights: .screen,
                factory: .init(make: { try GalleryScenarios.reportForm(.unavailable) })
            ),
            SnapshotState(
                id: "report-form-error-alert",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.reportForm(.errorAlert) },
                    interact: GalleryScenarios.presentHeldReportFailure
                )
            )
        ]
    }
}
