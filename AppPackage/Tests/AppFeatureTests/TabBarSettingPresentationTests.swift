import AnalyticsClient
@testable import AppFeature
import AppLaunchAutomationClient
import AppModels
import AppTools
import ClipboardClient
import ComposableArchitecture
import CookieClient
import DeviceClient
import DownloadClient
import Foundation
import HapticsClient
import LogsClient
import Sharing
import Testing
import UserDefaultsClient

struct TabBarSettingPresentationTests {
    @MainActor
    @Test
    func padSettingSelectionKeepsTheCurrentTabAndPresentsSetting() async {
        let store = makeStore(initialTab: .favorites, deviceType: .pad)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabBar(.setTabBarItemType(.setting)))
        await store.receive(\.tabBar.delegate.presentSetting)
        await store.receive(\.presentation.presentSetting)
        #expect(store.state.tabBarState.tabBarItemType == .favorites)
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.finish()
    }

    @MainActor
    @Test
    func phoneSettingSelectionSelectsTheTabWithoutPresentingSetting() async {
        let store = makeStore(initialTab: .favorites, deviceType: .phone)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabBar(.setTabBarItemType(.setting)))
        await store.receive(\.tabBar.selectSettingInline) {
            $0.tabBarState.tabBarItemType = .setting
        }
        #expect(store.state.presentationState.destination == nil)
        await store.finish()
    }

    @MainActor
    @Test
    func loggedOutSettingRouteOnPadPresentsWithoutSelectingTheTab() async {
        let clock = TestClock()
        let store = makeStore(initialTab: .favorites, deviceType: .pad, clock: clock)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.favorites(.onNotLoginViewButtonTapped))
        await store.skipReceivedActions(strict: false)
        #expect(store.state.tabBarState.tabBarItemType == .favorites)
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test
    func ordinaryTabSelectionStillSelectsTheRequestedTab() async {
        let store = makeStore(initialTab: .favorites, deviceType: .pad)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabBar(.setTabBarItemType(.home))) {
            $0.tabBarState.tabBarItemType = .home
        }
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test
    func repeatedPadSettingSelectionNeverSelectsTheTab() async {
        let store = makeStore(initialTab: .downloads, deviceType: .pad)
        store.exhaustivity = .off(showSkippedAssertions: false)

        for _ in 0..<2 {
            await store.send(.tabBar(.setTabBarItemType(.setting)))
            await store.receive(\.tabBar.delegate.presentSetting)
            await store.receive(\.presentation.presentSetting)
            #expect(store.state.tabBarState.tabBarItemType == .downloads)
        }
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.finish()
    }

    @MainActor
    @Test
    func launchAutomationSettingRouteOnPadPresentsWithoutSelectingTheTab() async {
        let store = makeStore(
            initialTab: .home,
            deviceType: .pad,
            launchAutomation: AppLaunchAutomation(initialTab: .setting)
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.tabBar.setTabBarItemType)
        await store.receive(\.tabBar.delegate.presentSetting)
        await store.receive(\.presentation.presentSetting)
        #expect(store.state.tabBarState.tabBarItemType == .home)
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.finish()
    }
}

private extension TabBarSettingPresentationTests {
    @MainActor
    func makeStore(
        initialTab: TabBarItemType,
        deviceType: DeviceType,
        clock: TestClock<Duration> = TestClock(),
        launchAutomation: AppLaunchAutomation? = nil
    ) -> TestStoreOf<AppReducer> {
        let appStorage = UserDefaults.inMemory
        let inMemoryStorage = InMemoryStorage()

        return withDependencies {
            $0.defaultAppStorage = appStorage
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            var initialState = AppReducer.State()
            initialState.tabBarState.tabBarItemType = initialTab
            initialState.$privacyMaskBlur.withLock({ $0 = 0 })

            return TestStore(
                initialState: initialState,
                reducer: AppReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.appLaunchAutomationClient = AppLaunchAutomationClient(
                        current: { launchAutomation }
                    )
                    $0.clipboardClient = .noop
                    $0.continuousClock = clock
                    $0.cookieClient = .noop
                    $0.defaultAppStorage = appStorage
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.deviceClient = DeviceClient(
                        deviceType: { deviceType },
                        isLandscape: { false },
                        interfaceOrientation: { .portrait }
                    )
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                    $0.logsClient = .noop
                    $0.userDefaultsClient = .noop
                }
            )
        }
    }
}
