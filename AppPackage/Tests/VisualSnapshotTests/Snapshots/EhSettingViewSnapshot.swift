import AppModels
import Foundation
@testable import SettingFeature

/// The snapshot states of `EhSettingView` (19-18).
enum EhSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-site-settings",
                heights: .screen,
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
                heights: .screen,
                factory: .init(make: { SettingsScenarios.siteSettings(.failed) })
            )
        ]
    }
}
