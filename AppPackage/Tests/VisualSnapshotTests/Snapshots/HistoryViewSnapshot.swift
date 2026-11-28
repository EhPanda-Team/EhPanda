import AppModels
import CoreGraphics
import Foundation
import Resources

/// The snapshot states of `HistoryView` (19-18).
enum HistoryViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "history-list",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1238, large: 1252, accessibility5: 4632),
                        landscape: .init(xSmall: 1128, large: 1131, accessibility5: 2415)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2456),
                        landscape: .init(xSmall: 1193, large: 1196, accessibility5: 2132)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.history(.row) }, prepare: artwork)
            ),
            SnapshotState(
                id: "history-grid",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1344, large: 1362, accessibility5: 6001),
                        landscape: .init(xSmall: 835, large: 1026, accessibility5: 8428)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 9014),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 3678)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.history(.grid) }, prepare: artwork)
            ),
            SnapshotState(
                id: "history-empty",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 1133),
                        landscape: .init(xSmall: 430, large: 450, accessibility5: 606)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.history(nil) })
            ),
            SnapshotState(
                id: "history-clear-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { BrowsingScenarios.history(.row) }, prepare: artwork,
                    interact: { window in
                        try await BrowsingScenarios.activate(String(localized: .RLocalizable.clear), in: window)
                        try await RevealStep.awaitDialogPlatter()(window)
                    }
                )
            )
        ]
    }
}
