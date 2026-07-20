import Foundation
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CustomDump
import CookieClient
import DownloadClient
import LogsClient
import Sharing
import Testing
import UserDefaultsClient
@testable import ClipboardClient
@testable import AppFeature

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct AppReducerScenePhaseTests {
    @MainActor
    @Test
    func scenePhaseWritesPrivacyMaskAndStartsForegroundEffectsOnce() async {
        let clipboardInvocationCount = LockIsolated(0)
        let intensity = 40.0
        let store = makeStore(
            clipboardDetectionCount: clipboardInvocationCount,
            detectLinksFromClipboard: true,
            privacyMaskIntensity: intensity
        )

        await store.send(.onScenePhaseChange(.inactive)) {
            $0.scenePhase = .inactive
            $0.$privacyMaskBlur.withLock { $0 = intensity }
        }

        await store.send(.onScenePhaseChange(.active)) {
            $0.scenePhase = .active
            $0.$privacyMaskBlur.withLock { $0 = 0 }
        }
        await store.receive(\.setting.fetchGreeting)
        await store.receive(\.appLogsPump.startPump)
        await store.receive(\.presentation.detectClipboardURL)
        await store.send(.appLogsPump(.pausePump))
        await store.finish()
        expectNoDifference(clipboardInvocationCount.value, 1)
    }

    @MainActor
    @Test
    func activeSceneSkipsClipboardDetectionWhenDisabled() async {
        let clipboardInvocationCount = LockIsolated(0)
        let store = makeStore(
            clipboardDetectionCount: clipboardInvocationCount,
            detectLinksFromClipboard: false,
            privacyMaskIntensity: 40
        )

        await store.send(.onScenePhaseChange(.active))
        await store.receive(\.setting.fetchGreeting)
        await store.receive(\.appLogsPump.startPump)
        await store.send(.appLogsPump(.pausePump))
        await store.finish()
        expectNoDifference(clipboardInvocationCount.value, 0)
    }

    @MainActor
    @Test
    func maskAndLatchAreWrittenBeforeSettingsLoad() async {
        let store = makeStore(
            detectLinksFromClipboard: true,
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
    @MainActor
    func makeStore(
        clipboardDetectionCount: LockIsolated<Int>? = nil,
        detectLinksFromClipboard: Bool,
        privacyMaskIntensity: Double,
        hasLoadedInitialSetting: Bool = true
    ) -> TestStoreOf<AppReducer> {
        let appStorage = UserDefaults.inMemory
        let inMemoryStorage = InMemoryStorage()

        return withDependencies {
            $0.defaultAppStorage = appStorage
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            var initialState = AppReducer.State()
            initialState.settingState.hasLoadedInitialSetting = hasLoadedInitialSetting
            initialState.settingState.$setting.withLock {
                $0 = Setting(
                    detectLinksFromClipboard: detectLinksFromClipboard,
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
                    $0.clipboardClient = clipboardDetectionCount.map(ClipboardClient.countingDetections) ?? .noop
                    $0.continuousClock = TestClock()
                    $0.cookieClient = .noop
                    $0.defaultAppStorage = appStorage
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.downloadClient = .noop
                    $0.logsClient = .noop
                    $0.userDefaultsClient = .noop
                }
            )
        }
    }
}

private extension ClipboardClient {
    static func countingDetections(_ count: LockIsolated<Int>) -> Self {
        .init(
            url: { nil },
            changeCount: {
                count.withValue { $0 += 1 }
                return .min
            },
            saveText: { _ in },
            saveImage: { _, _ in },
            saveImageData: { _ in false }
        )
    }
}
