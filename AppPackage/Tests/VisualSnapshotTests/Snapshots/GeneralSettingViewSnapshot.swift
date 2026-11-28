import AppModels
import Foundation
@testable import SettingFeature

/// The snapshot states of `GeneralSettingView` (19-18).
enum GeneralSettingViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "settings-pages-general-minimal",
                heights: .screen,
                factory: .init(
                    make: { SettingsScenarios.general(level: .minimal) }, interact: SettingsScenarios.scrollToBottom
                )
            ),
            SnapshotState(
                id: "settings-pages-general-basic",
                heights: .screen,
                factory: .init(
                    make: { SettingsScenarios.general(level: .basic) }, interact: SettingsScenarios.scrollToBottom
                )
            ),
            SnapshotState(
                id: "settings-pages-general-full",
                heights: .screen,
                factory: .init(
                    make: { SettingsScenarios.general(level: .full) }, interact: SettingsScenarios.scrollToBottom
                )
            ),
            // At accessibility5 the rows above Clear Image Cache could still grow after it was placed, and the row
            // sat at three heights (run 43451019962): it is placed again until it stays.
            SnapshotState(
                id: "settings-pages-general-cache-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { SettingsScenarios.general(level: .basic, action: .clearImageCacheButtonTapped) },
                    interact: RevealStep.reveal(.label(String(localized: .clearImageCache)), holdingPlacement: true)
                )
            ),
            SnapshotState(
                id: "settings-pages-general-translations-confirmation",
                heights: .viewport(
                    reason: "19-26, owner, 2026-11-27: 「alert 組件不需要測量，所以只確認到存在 alert 就足夠」"
                ),
                factory: .init(
                    make: { SettingsScenarios.general(level: .basic, action: .removeCustomTranslationsButtonTapped) },
                    interact: RevealStep.reveal(
                        .label(String(localized: .removeCustomTranslations)), settlingSteps: true
                    )
                )
            )
        ]
    }
}
