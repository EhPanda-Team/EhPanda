import AppModels
import CoreGraphics

/// The snapshot states of `AnalyticsChoiceView` (19-18).
enum AnalyticsChoiceViewSnapshot: SnapshotProvider {
    /// The analytics choice with `level` picked. At accessibility5 the levels sit below the fold, and the three
    /// pictures were their base page's (run 43403534542), so there the page is scrolled to the picked level.
    private static func analyticsChoice(_ level: AnalyticsLevel) -> ScenarioFactory {
        ScenarioFactory(
            signedIn: false, make: { BrowsingScenarios.analyticsChoice(level) },
            interact: RevealStep.reveal(.identifier("first_launch_level_\(level.rawValue)")),
            minimumReads: BrowsingScenarios.firstLaunchMinimumReads
        )
    }

    @MainActor
    static var states: [SnapshotState] {
        let reads = BrowsingScenarios.firstLaunchMinimumReads
        return [
            SnapshotState(
                id: "analytics-choice-none",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 3631),
                        landscape: .init(xSmall: 650, large: 747, accessibility5: 2766)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2806),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 2806)
                    )
                ),
                factory: .init(
                    signedIn: false, make: { BrowsingScenarios.analyticsChoice(nil) }, minimumReads: reads
                )
            ),
            SnapshotState(
                id: "analytics-choice-minimal",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 3631),
                        landscape: .init(xSmall: 650, large: 747, accessibility5: 2766)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2806),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 2806)
                    )
                ),
                factory: analyticsChoice(.minimal)
            ),
            SnapshotState(
                id: "analytics-choice-basic",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 3631),
                        landscape: .init(xSmall: 650, large: 747, accessibility5: 2766)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2806),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 2806)
                    )
                ),
                factory: analyticsChoice(.basic)
            ),
            SnapshotState(
                id: "analytics-choice-full",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 3631),
                        landscape: .init(xSmall: 650, large: 747, accessibility5: 2766)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2806),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 2806)
                    )
                ),
                factory: analyticsChoice(.full)
            )
        ]
    }
}
