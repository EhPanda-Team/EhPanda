import AnalyticsClient
@testable import AppFeature
import AppLaunchAutomationClient
import AppModels
import ClipboardClient
import ComposableArchitecture
import CookieClient
import DownloadClient
import FavoritesFeature
import Foundation
import HapticsClient
import HomeFeature
import LogsClient
import SettingFeature
import Sharing
import SwiftUI
import Testing
import UserDefaultsClient

struct TabBarSettingPresentationTests {
    @MainActor
    @Test
    func aRegularWindowKeepsTheCurrentTabAndPresentsSetting() async {
        let store = makeStore(initialTab: .library, window: .regular)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabBar(.setTabBarItemType(.setting)))
        await store.receive(\.tabBar.delegate.openSetting)
        await store.receive(\.presentation.presentSetting)
        #expect(store.state.tabBarState.tabBarItemType == .library)
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.finish()
    }

    @MainActor
    @Test(arguments: [WindowSizeClasses.compactWidth, .compactHeight])
    func aWindowCompactInEitherDimensionSelectsTheTab(_ window: WindowSizeClasses) async {
        let store = makeStore(initialTab: .library, window: window)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabBar(.setTabBarItemType(.setting)))
        await store.receive(\.tabBar.delegate.openSetting)
        await store.receive(\.tabBar.selectSettingInline) {
            $0.tabBarState.tabBarItemType = .setting
        }
        #expect(store.state.presentationState.destination == nil)
        await store.finish()
    }

    @MainActor
    @Test
    func aSettingTabLeftSelectedByANarrowerWindowStaysInline() async {
        let store = makeStore(initialTab: .setting, window: .compactWidth)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.windowSizeClassesChanged(.regular)) {
            $0.windowSizeClasses = .regular
        }
        await store.send(.tabBar(.setTabBarItemType(.setting)))
        await store.receive(\.tabBar.delegate.openSetting)
        await store.receive(\.tabBar.selectSettingInline)
        #expect(store.state.tabBarState.tabBarItemType == .setting)
        #expect(store.state.presentationState.destination == nil)
        await store.finish()
    }

    @MainActor
    @Test
    func loggedOutSettingRouteInARegularWindowPresentsWithoutSelectingTheTab() async {
        let clock = TestClock()
        let store = makeStore(initialTab: .library, window: .regular, clock: clock)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.favorites(.onNotLoginViewButtonTapped))
        await store.skipReceivedActions(strict: false)
        #expect(store.state.tabBarState.tabBarItemType == .library)
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test
    func ordinaryTabSelectionStillSelectsTheRequestedTab() async {
        let store = makeStore(initialTab: .library, window: .regular)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.tabBar(.setTabBarItemType(.home))) {
            $0.tabBarState.tabBarItemType = .home
        }
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test
    func repeatedSettingSelectionInARegularWindowNeverSelectsTheTab() async {
        let store = makeStore(initialTab: .library, window: .regular)
        store.exhaustivity = .off(showSkippedAssertions: false)

        for _ in 0..<2 {
            await store.send(.tabBar(.setTabBarItemType(.setting)))
            await store.receive(\.tabBar.delegate.openSetting)
            await store.receive(\.presentation.presentSetting)
            #expect(store.state.tabBarState.tabBarItemType == .library)
        }
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.finish()
    }

    @MainActor
    @Test
    func launchAutomationSettingRouteInARegularWindowPresentsWithoutSelectingTheTab() async {
        let store = makeStore(
            initialTab: .home,
            window: .regular,
            launchAutomation: AppLaunchAutomation(initialTab: .setting)
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.tabBar.setTabBarItemType)
        await store.receive(\.tabBar.delegate.openSetting)
        await store.receive(\.presentation.presentSetting)
        #expect(store.state.tabBarState.tabBarItemType == .home)
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.finish()
    }

    /// A launch automation opens screens the way taps do, and the root routes those by the window, so
    /// a launch whose settings load before the root view first reports the window waits for it.
    @MainActor
    @Test
    func launchAutomationWaitsForTheWindowsFirstReport() async {
        let store = makeStore(
            initialTab: .home,
            window: nil,
            launchAutomation: AppLaunchAutomation(initialTab: .setting)
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.runLaunchAutomation)
        #expect(store.state.didRunLaunchAutomation == false)

        await store.send(.windowSizeClassesChanged(.regular)) {
            $0.windowSizeClasses = .regular
        }
        await store.receive(\.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.presentation.presentSetting)
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        await store.finish()
    }
}

private extension TabBarSettingPresentationTests {
    @MainActor
    func makeStore(
        initialTab: TabBarItemType,
        window: WindowSizeClasses?,
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
            initialState.windowSizeClasses = window
            initialState.settingState.hasLoadedInitialSetting = true
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
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                    $0.homeClient = .noop
                    $0.logsClient = .noop
                    $0.userDefaultsClient = .noop
                }
            )
        }
    }
}
