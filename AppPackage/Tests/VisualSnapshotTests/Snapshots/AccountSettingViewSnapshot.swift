import AppTools
import CoreGraphics
import Foundation
@testable import SettingFeature

/// The snapshot states of `AccountSettingView` (19-18).
enum AccountSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-account-signed-in",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1005, large: 1048, accessibility5: 2856),
                        landscape: .init(xSmall: 930, large: 973, accessibility5: 2086)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2077),
                        landscape: .init(xSmall: 962, large: 1005, accessibility5: 1954)
                    )
                ),
                factory: .init(
                    cookies: SettingsScenarios.memberCookies,
                    make: { SettingsScenarios.account(confirmingLogout: false) }
                )
            ),
            // The cookies are the state: where they are below the fold, the page is scrolled to them. The page is
            // stepped through first: launches had built different rows below them and drew the page differently.
            SnapshotState(
                id: "settings-account-invalid-cookies",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1005, large: 1048, accessibility5: 2610),
                        landscape: .init(xSmall: 930, large: 973, accessibility5: 1964)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1954),
                        landscape: .init(xSmall: 962, large: 1005, accessibility5: 1954)
                    )
                ),
                factory: .init(
                    cookies: SettingsScenarios.withheldCookies,
                    make: { SettingsScenarios.account(confirmingLogout: false) },
                    interact: RevealStep.reveal(.label(Defaults.Cookie.ipbMemberId), measuringPage: true)
                )
            ),
            SnapshotState(
                id: "settings-account-signed-out",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 2144),
                        landscape: .init(xSmall: 796, large: 816, accessibility5: 1622)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1674),
                        landscape: .init(xSmall: 834, large: 848, accessibility5: 1674)
                    )
                ),
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
