import CoreGraphics

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
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 940, accessibility5: 3582),
                        landscape: .init(xSmall: 682, large: 722, accessibility5: 2017)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2578),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 2578)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.reportForm(.ready) })
            ),
            SnapshotState(
                id: "report-form-filled",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 987, large: 1092, accessibility5: 4626),
                        landscape: .init(xSmall: 780, large: 842, accessibility5: 2649)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 3348),
                        landscape: .init(xSmall: 843, large: 953, accessibility5: 3348)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.reportForm(.filled) })
            ),
            SnapshotState(
                id: "report-form-sending",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 987, large: 1092, accessibility5: 4688),
                        landscape: .init(xSmall: 780, large: 842, accessibility5: 2649)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 3348),
                        landscape: .init(xSmall: 844, large: 953, accessibility5: 3348)
                    )
                ),
                factory: .init(
                    make: { try GalleryScenarios.reportForm(.sending) }, still: GalleryScenarios.holdStill
                )
            ),
            SnapshotState(
                id: "report-form-sent",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 912),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 502)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.reportForm(.sent) })
            ),
            SnapshotState(
                id: "report-form-unavailable",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1131),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 731)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 891)
                    )
                ),
                factory: .init(make: { try GalleryScenarios.reportForm(.unavailable) })
            ),
            SnapshotState(
                id: "report-form-error-alert",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { try GalleryScenarios.reportForm(.errorAlert) },
                    interact: GalleryScenarios.presentHeldReportFailure
                )
            )
        ]
    }
}
