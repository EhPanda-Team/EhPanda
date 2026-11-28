import AppTools
import Foundation
@testable import SettingFeature

/// The snapshot states of `AccountSettingView` (19-18).
enum AccountSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-account-signed-in",
                heights: .screen,
                factory: .init(
                    cookies: SettingsScenarios.memberCookies,
                    make: { SettingsScenarios.account(confirmingLogout: false) }
                )
            ),
            // The cookies are the state: where they are below the fold, the page is scrolled to them. The page is
            // stepped through first: launches had built different rows below them and drew the page differently.
            SnapshotState(
                id: "settings-account-invalid-cookies",
                heights: .screen,
                factory: .init(
                    cookies: SettingsScenarios.withheldCookies,
                    make: { SettingsScenarios.account(confirmingLogout: false) },
                    interact: RevealStep.reveal(.label(Defaults.Cookie.ipbMemberId), measuringPage: true)
                )
            ),
            SnapshotState(
                id: "settings-account-signed-out",
                heights: .screen,
                factory: .init(signedIn: false, make: { SettingsScenarios.account(confirmingLogout: false) })
            ),
            SnapshotState(
                id: "settings-account-logout-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    cookies: SettingsScenarios.memberCookies,
                    make: { SettingsScenarios.account(confirmingLogout: true) },
                    interact: { window in
                        try await RevealStep.reveal(.label(String(localized: .logout)))(window)
                        try await RevealStep.awaitDialogPlatter()(window)
                    }
                )
            )
        ]
    }
}
