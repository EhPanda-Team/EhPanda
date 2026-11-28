import AppModels
import CoreGraphics
import Foundation
@testable import SettingFeature

/// The snapshot states of `EhSettingView` (19-18).
enum EhSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-site-settings",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 6594, large: 7571, accessibility5: 44243),
                        landscape: .init(xSmall: 5630, large: 6229, accessibility5: 27167)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 5633, large: 6140, accessibility5: 26602),
                        landscape: .init(xSmall: 5519, large: 5922, accessibility5: 23075)
                    )
                ),
                factory: .init(make: { SettingsScenarios.siteSettings(.loaded) })
            ),
            SnapshotState(
                id: "settings-pages-site-settings-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { SettingsScenarios.siteSettings(.deleteConfirmation) },
                    interact: RevealStep.reveal(.label(String(localized: .deleteProfile)))
                )
            ),
            SnapshotState(
                id: "settings-pages-site-settings-error",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 912),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 460)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: .init(make: { SettingsScenarios.siteSettings(.failed) })
            )
        ]
    }
}
