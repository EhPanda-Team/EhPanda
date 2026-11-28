import AppModels
import CoreGraphics
import Foundation
@testable import HomeFeature
import Resources

/// The snapshot states of `ToplistsView` (19-18).
enum ToplistsViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "toplists-list",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 2347),
                        landscape: .init(xSmall: 598, large: 598, accessibility5: 1199)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 1127)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.toplists(.loaded(.row)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "toplists-grid",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 929, large: 940, accessibility5: 2987),
                        landscape: .init(xSmall: 435, large: 530, accessibility5: 4187)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 4523),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 2452)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.toplists(.loaded(.grid)) }, prepare: artwork)
            ),
            SnapshotState(
                id: "toplists-error",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 913),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 594)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.toplists(.failed(.networkingFailed)) })
            ),
            SnapshotState(
                id: "toplists-period-menu",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27, menus at the screen height: 「選單可以按你推薦處理」"
                ),
                factory: .init(
                    make: { BrowsingScenarios.toplists(.loaded(.row)) }, prepare: artwork,
                    interact: { try await BrowsingScenarios.activate(String(localized: .timeRange), in: $0) }
                )
            ),
            SnapshotState(
                id: "app-wide-app-alert",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「當 alert，維持螢幕高（建議）」"
                ),
                factory: .init(
                    make: { SettingsScenarios.jumpPageAlert() }, prepare: TracerScenarios.cacheHomeArtwork,
                    interact: { window in
                        try await RevealStep.reveal(.label(String(localized: .RLocalizable.jumpPage)))(window)
                        try await SettingsScenarios.holdAlertCaret(window)
                    }
                )
            )
        ]
    }
}
