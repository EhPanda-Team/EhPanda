import Foundation
import AppLaunchAutomationClient
import AppModels
import ClipboardClient
import ComposableArchitecture
import CookieClient
import DownloadClient
import LogsClient
import Testing
import UserDefaultsClient
@testable import AppFeature

@Suite(.serialized)
@MainActor
struct AppReducerScenePhaseTests {
    @Test
    func scenePhaseWritesPrivacyMaskAndStartsForegroundEffectsOnce() async {
        let intensity = 40.0
        let store = makeStore(
            detectsLinksFromClipboard: true,
            privacyMaskIntensity: intensity
        )

        await store.send(.onScenePhaseChange(.inactive)) {
            $0.scenePhase = .inactive
            $0.$privacyMaskBlur.withLock { $0 = intensity }
        }

        await store.withExhaustivity(.off) {
            await store.send(.onScenePhaseChange(.active)) {
                $0.scenePhase = .active
                $0.$privacyMaskBlur.withLock { $0 = 0 }
            }
            await store.receive(\.setting.fetchGreeting)
            await store.receive(\.appLogsPump.startPump)
            await store.receive(\.appRoute.detectClipboardURL)
            await store.skipInFlightEffects()
        }
        await store.finish()
    }

    @Test
    func activeSceneSkipsClipboardDetectionWhenDisabled() async {
        let store = makeStore(
            detectsLinksFromClipboard: false,
            privacyMaskIntensity: 40
        )

        await store.withExhaustivity(.off) {
            await store.send(.onScenePhaseChange(.active))
            await store.receive(\.setting.fetchGreeting)
            await store.receive(\.appLogsPump.startPump)
            await store.skipInFlightEffects()
        }
        await store.finish()
    }

    @Test
    func maskAndLatchAreWrittenBeforeSettingsLoad() async {
        let store = makeStore(
            detectsLinksFromClipboard: true,
            privacyMaskIntensity: 40,
            hasLoadedInitialSetting: false
        )

        await store.send(.onScenePhaseChange(.inactive)) {
            $0.scenePhase = .inactive
            $0.$privacyMaskBlur.withLock { $0 = 40 }
        }
        await store.send(.onScenePhaseChange(.background)) {
            $0.scenePhase = .background
            $0.hasEnteredBackground = true
        }
        await store.finish()
    }
}

private extension AppReducerScenePhaseTests {
    func makeStore(
        detectsLinksFromClipboard: Bool,
        privacyMaskIntensity: Double,
        hasLoadedInitialSetting: Bool = true
    ) -> TestStoreOf<AppReducer> {
        var initialState = AppReducer.State()
        initialState.settingState.hasLoadedInitialSetting = hasLoadedInitialSetting
        initialState.settingState.$setting.withLock {
            $0 = Setting(
                detectsLinksFromClipboard: detectsLinksFromClipboard,
                privacyMaskIntensity: privacyMaskIntensity
            )
        }
        initialState.$privacyMaskBlur.withLock { $0 = 0 }
        initialState.appLogsPumpState.$currentRun.withLock {
            $0 = RunLogFile(
                url: URL(fileURLWithPath: "/tmp/app-feature-tests.jsonl"),
                date: Date(timeIntervalSince1970: 0),
                runCount: 1
            )
        }

        return TestStore(
            initialState: initialState,
            reducer: AppReducer.init,
            withDependencies: {
                $0.appLaunchAutomationClient = .none
                $0.clipboardClient = .noop
                $0.continuousClock = TestClock()
                $0.cookieClient = .noop
                $0.downloadClient = .noop
                $0.logsClient = .noop
                $0.userDefaultsClient = .noop
            }
        )
    }
}
