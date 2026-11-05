import AnalyticsClient
import AppComponents
@testable import AppFeature
import AppLaunchAutomationClient
import ApplicationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DFClient
import DownloadClient
import Foundation
import HapticsClient
import LibraryClient
import LogsClient
import SettingFeature
import Sharing
import SwiftUI
import Testing
import UserDefaultsClient

// The first-launch gate (D-03, D-04, DD-06, DD-07): until the current age declaration is confirmed the
// app does only local work, and the network-opening launch work runs once, at the unlock.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it (see 11-22-SUMMARY.md).
struct FirstLaunchGateTests {
    // MARK: Locked launch

    // The download and analytics clients are left unimplemented: any call, including the first
    // download-client access that would build the live client and resume queued transfers, reports
    // an issue. The store is exhaustive, so a settings load would fail as an unexpected action.
    @MainActor
    @Test
    func aLockedLaunchRunsOnlyLocalWork() async {
        let store = Self.makeAppStore(ageDeclarationVersion: nil, dependencies: {
            $0.analyticsClient = .unimplemented
            $0.downloadClient = DownloadClient()
        })

        await store.send(.appDelegate(.onLaunchFinish))
        await store.receive(\.appLogsPump.startPump) {
            $0.appLogsPumpState.isPumpRunning = true
        }
        await store.receive(\.launchPreparationFinished) {
            $0.didFinishLaunchPreparation = true
        }
        await store.send(.onScenePhaseChange(.inactive)) {
            $0.scenePhase = .inactive
        }
        await store.send(.onScenePhaseChange(.active)) {
            $0.scenePhase = .active
            $0.recordedScenePhase = .active
        }
        await store.send(.appLogsPump(.pausePump)) {
            $0.appLogsPumpState.isPumpRunning = false
        }
        await store.finish()
    }

    @MainActor
    @Test
    func aLockedBackgroundTransitionIsRecordedNotReported() async {
        let store = Self.makeAppStore(ageDeclarationVersion: nil, dependencies: {
            $0.analyticsClient = .unimplemented
            $0.downloadClient = DownloadClient()
        })

        await store.send(.onScenePhaseChange(.background)) {
            $0.scenePhase = .background
            $0.hasEnteredBackground = true
            $0.recordedScenePhase = .background
        }
        await store.finish()
    }

    // A wording version other than the current one is not a confirmation (P-10).
    @MainActor
    @Test(arguments: [0, 2])
    func aStaleDeclarationVersionKeepsTheLaunchLocked(version: Int) async {
        let store = Self.makeAppStore(ageDeclarationVersion: version, dependencies: {
            $0.analyticsClient = .unimplemented
            $0.downloadClient = DownloadClient()
        })

        #expect(!store.state.isUnlocked)
        await store.send(.appDelegate(.onLaunchFinish))
        await store.receive(\.appLogsPump.startPump) {
            $0.appLogsPumpState.isPumpRunning = true
        }
        await store.receive(\.launchPreparationFinished) {
            $0.didFinishLaunchPreparation = true
        }
        await store.send(.appLogsPump(.pausePump)) {
            $0.appLogsPumpState.isPumpRunning = false
        }
        await store.finish()
    }

    // MARK: The deferred launch

    @MainActor
    @Test
    func confirmingTheAgeRunsTheDeferredLaunchOnce() async {
        let spy = DownloadClientSpy()
        let store = Self.makeAppStore(ageDeclarationVersion: nil, dependencies: {
            $0.downloadClient = spy.client
        })

        await store.send(.appDelegate(.onLaunchFinish))
        await store.receive(\.appLogsPump.startPump) {
            $0.appLogsPumpState.isPumpRunning = true
        }
        await store.receive(\.launchPreparationFinished) {
            $0.didFinishLaunchPreparation = true
        }
        await store.send(.onScenePhaseChange(.active)) {
            $0.recordedScenePhase = .active
        }
        #expect(spy.livenessObservations.value == 0)
        #expect(spy.phaseReports.value.isEmpty)

        await store.send(.firstLaunch(.binding(.set(\.isDeclarationTicked, true)))) {
            $0.firstLaunch.isDeclarationTicked = true
        }
        await store.send(.firstLaunch(.ageWallContinue)) {
            $0.firstLaunch.$setting.withLock({ $0.ageDeclarationVersion = AgeDeclaration.currentVersion })
        }
        await store.receive(\.firstLaunch.delegate.ageConfirmed) {
            $0.didRunDeferredLaunch = true
            $0.recordedScenePhase = nil
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.setting.loadUserSettings)

        // A second confirmation, however it arrives, runs nothing again.
        await store.send(.firstLaunch(.delegate(.ageConfirmed)))
        await store.send(.launchPreparationFinished)
        await store.send(.appLogsPump(.pausePump))
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(spy.livenessObservations.value == 1)
        #expect(spy.phaseReports.value == [false])
    }

    @MainActor
    @Test
    func aSecondConfirmationReceivesNothing() async {
        let store = Self.makeAppStore(
            ageDeclarationVersion: AgeDeclaration.currentVersion,
            state: {
                $0.didFinishLaunchPreparation = true
                $0.didRunDeferredLaunch = true
            },
            dependencies: {
                $0.analyticsClient = .unimplemented
                $0.downloadClient = DownloadClient()
            }
        )

        await store.send(.firstLaunch(.delegate(.ageConfirmed)))
        await store.send(.launchPreparationFinished)
        await store.finish()
    }

    // The confirmation can beat the cookie maintenance; settings must still load after it, so the
    // deferred launch waits for the preparation and runs from there.
    @MainActor
    @Test
    func aConfirmationBeforeThePreparationFinishesWaitsForIt() async {
        let spy = DownloadClientSpy()
        let store = Self.makeAppStore(ageDeclarationVersion: AgeDeclaration.currentVersion, dependencies: {
            $0.downloadClient = spy.client
        })

        await store.send(.firstLaunch(.delegate(.ageConfirmed)))
        #expect(spy.livenessObservations.value == 0)

        await store.send(.launchPreparationFinished) {
            $0.didFinishLaunchPreparation = true
            $0.didRunDeferredLaunch = true
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.setting.loadUserSettings)
        await store.skipReceivedActions(strict: false)
        await store.finish()
        #expect(spy.livenessObservations.value == 1)
        #expect(spy.phaseReports.value.isEmpty)
    }

    @MainActor
    @Test
    func anUnlockedLaunchRunsTheDeferredLaunchAtOnce() async {
        let spy = DownloadClientSpy()
        let store = Self.makeAppStore(ageDeclarationVersion: AgeDeclaration.currentVersion, dependencies: {
            $0.downloadClient = spy.client
        })

        await store.send(.appDelegate(.onLaunchFinish)) {
            $0.didRunDeferredLaunch = true
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.setting.loadUserSettings)
        await store.send(.firstLaunch(.delegate(.ageConfirmed)))
        await store.send(.appLogsPump(.pausePump))
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(!store.state.didFinishLaunchPreparation)
        #expect(spy.livenessObservations.value == 1)
        #expect(spy.phaseReports.value.isEmpty)
    }

    @MainActor
    @Test
    func anUnlockedScenePhaseReachesTheDownloadClientDirectly() async {
        let spy = DownloadClientSpy()
        let store = Self.makeAppStore(
            ageDeclarationVersion: AgeDeclaration.currentVersion,
            state: { $0.recordedScenePhase = .active },
            dependencies: { $0.downloadClient = spy.client }
        )

        await store.send(.onScenePhaseChange(.background)) {
            $0.scenePhase = .background
            $0.hasEnteredBackground = true
            $0.recordedScenePhase = nil
        }
        await store.finish()
        #expect(spy.phaseReports.value == [true])
    }

    // MARK: The analytics level

    @MainActor
    @Test(arguments: AnalyticsLevel.allCases)
    func anUnlockedLaunchWithAStoredLevelAppliesItOnce(level: AnalyticsLevel) async {
        let analytics = AnalyticsClientSpy()
        let store = Self.makeAppStore(
            ageDeclarationVersion: AgeDeclaration.currentVersion,
            analyticsLevel: level,
            dependencies: { $0.analyticsClient = analytics.client }
        )

        await store.send(.appDelegate(.onLaunchFinish)) {
            $0.didRunDeferredLaunch = true
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.setting.loadUserSettings)
        await store.send(.firstLaunch(.delegate(.ageConfirmed)))
        await store.send(.appLogsPump(.pausePump))
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(analytics.appliedLevels.value == [level])
    }

    @MainActor
    @Test(arguments: AnalyticsLevel.allCases)
    func anUnlockedLaunchWithNoLevelAppliesNothingUntilTheChoice(level: AnalyticsLevel) async {
        let analytics = AnalyticsClientSpy()
        let store = Self.makeAppStore(
            ageDeclarationVersion: AgeDeclaration.currentVersion,
            dependencies: { $0.analyticsClient = analytics.client }
        )

        await store.send(.appDelegate(.onLaunchFinish)) {
            $0.didRunDeferredLaunch = true
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.setting.loadUserSettings)
        await store.skipReceivedActions(strict: false)
        #expect(analytics.appliedLevels.value.isEmpty)

        await store.send(.firstLaunch(.analyticsContinue(level)))
        await store.receive(\.firstLaunch.delegate.levelChosen, level)
        await store.send(.appLogsPump(.pausePump))
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(analytics.appliedLevels.value == [level])
    }

    // The age wall and the choice in one first launch: confirming the age with no level applies
    // nothing, and the choice applies the level once.
    @MainActor
    @Test
    func aFirstLaunchAppliesTheLevelOnlyWhenItIsChosen() async {
        let analytics = AnalyticsClientSpy()
        let store = Self.makeAppStore(ageDeclarationVersion: nil, dependencies: {
            $0.analyticsClient = analytics.client
        })

        await store.send(.launchPreparationFinished) {
            $0.didFinishLaunchPreparation = true
        }
        await store.send(.firstLaunch(.binding(.set(\.isDeclarationTicked, true)))) {
            $0.firstLaunch.isDeclarationTicked = true
        }
        await store.send(.firstLaunch(.ageWallContinue)) {
            $0.firstLaunch.$setting.withLock({ $0.ageDeclarationVersion = AgeDeclaration.currentVersion })
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.firstLaunch.delegate.ageConfirmed)
        await store.receive(\.setting.loadUserSettings)
        await store.skipReceivedActions(strict: false)
        #expect(analytics.appliedLevels.value.isEmpty)

        await store.send(.firstLaunch(.analyticsContinue(.minimal)))
        await store.receive(\.firstLaunch.delegate.levelChosen, .minimal)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(analytics.appliedLevels.value == [.minimal])
    }

    // A choice reported before the deferred launch has run is applied by it, from storage, once.
    @MainActor
    @Test
    func aChoiceBeforeTheDeferredLaunchIsAppliedByItOnce() async {
        let analytics = AnalyticsClientSpy()
        let store = Self.makeAppStore(
            ageDeclarationVersion: AgeDeclaration.currentVersion,
            analyticsLevel: .basic,
            dependencies: { $0.analyticsClient = analytics.client }
        )

        await store.send(.firstLaunch(.delegate(.levelChosen(.basic))))
        #expect(analytics.appliedLevels.value.isEmpty)

        await store.send(.launchPreparationFinished) {
            $0.didFinishLaunchPreparation = true
            $0.didRunDeferredLaunch = true
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.setting.loadUserSettings)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(analytics.appliedLevels.value == [.basic])
    }

    // MARK: Links opened while locked

    @MainActor
    @Test
    func aLinkOpenedWhileLockedIsQueuedAndTheLatestWins() async throws {
        let first = try #require(URL(string: "https://e-hentai.org/g/1/first/"))
        let second = try #require(URL(string: "https://e-hentai.org/g/2/second/"))
        let store = Self.makeAppStore(ageDeclarationVersion: nil, dependencies: {
            $0.analyticsClient = .unimplemented
            $0.downloadClient = DownloadClient()
        })

        await store.send(.openURL(first)) {
            $0.pendingDeepLink = first
        }
        await store.send(.openURL(second)) {
            $0.pendingDeepLink = second
        }
        // Locked, the settings never load, so nothing routes it yet.
        await store.send(.runLaunchAutomation)
        await store.finish()
    }

    @MainActor
    @Test
    func aQueuedLinkWaitsForTheSettingsToLoad() async throws {
        let url = try #require(URL(string: "https://example.com/not-a-gallery"))
        let store = Self.makeAppStore(
            ageDeclarationVersion: AgeDeclaration.currentVersion,
            state: { $0.pendingDeepLink = url }
        )

        await store.send(.runLaunchAutomation)
        #expect(store.state.pendingDeepLink == url)
        await store.finish()
    }

    // An unsupported link keeps the routing observable without a gallery fetch: it lands as the
    // unsupported-link toast, which proves `handleDeepLink` ran.
    @MainActor
    @Test
    func aQueuedLinkIsRoutedOnceAfterTheSettingsLoad() async throws {
        let url = try #require(URL(string: "https://example.com/not-a-gallery"))
        let store = Self.makeAppStore(
            ageDeclarationVersion: AgeDeclaration.currentVersion,
            state: {
                $0.pendingDeepLink = url
                $0.settingState.hasLoadedInitialSetting = true
            }
        )

        await store.send(.runLaunchAutomation) {
            $0.pendingDeepLink = nil
        }
        await store.receive(\.presentation.handleDeepLink) {
            $0.presentationState.toast = .error(
                ErrorInfo(error: .unsupportedDeepLink, context: .unsupportedLink(url: url))
            )
        }
        await store.send(.runLaunchAutomation)
        await store.finish()
    }

    @MainActor
    @Test
    func anUnlockedLinkRoutesAtOnceAndReplacesAQueuedOne() async throws {
        let queued = try #require(URL(string: "https://example.com/older"))
        let url = try #require(URL(string: "https://example.com/not-a-gallery"))
        let store = Self.makeAppStore(
            ageDeclarationVersion: AgeDeclaration.currentVersion,
            state: { $0.pendingDeepLink = queued }
        )

        await store.send(.openURL(url)) {
            $0.pendingDeepLink = nil
        }
        await store.receive(\.presentation.handleDeepLink) {
            $0.presentationState.toast = .error(
                ErrorInfo(error: .unsupportedDeepLink, context: .unsupportedLink(url: url))
            )
        }
        await store.finish()
    }

    // MARK: FirstLaunchReducer

    @MainActor
    @Test(arguments: [
        StoredAnswers(version: nil, level: nil, step: .ageWall),
        StoredAnswers(version: nil, level: .full, step: .ageWall),
        StoredAnswers(version: 0, level: .minimal, step: .ageWall),
        StoredAnswers(version: 2, level: nil, step: .ageWall),
        StoredAnswers(version: 1, level: nil, step: .analyticsChoice),
        StoredAnswers(version: 1, level: .minimal, step: .complete),
        StoredAnswers(version: 1, level: .basic, step: .complete),
        StoredAnswers(version: 1, level: .full, step: .complete)
    ])
    func theStepIsDerivedFromTheStoredAnswers(answers: StoredAnswers) {
        let state = Self.makeFirstLaunchState(version: answers.version, level: answers.level)

        #expect(state.step == answers.step)
        #expect(!state.isDeclarationTicked)
        #expect(state.selectedLevel == nil)
    }

    @MainActor
    @Test
    func continueDoesNothingUntilTheDeclarationIsTicked() async {
        let store = Self.makeFirstLaunchStore(version: nil, level: nil)

        await store.send(.ageWallContinue)
        #expect(store.state.setting.ageDeclarationVersion == nil)
        #expect(store.state.step == .ageWall)
    }

    @MainActor
    @Test
    func continueWithTheTickStoresTheCurrentVersionAndReportsIt() async {
        let store = Self.makeFirstLaunchStore(version: nil, level: nil)

        await store.send(.binding(.set(\.isDeclarationTicked, true))) {
            $0.isDeclarationTicked = true
        }
        await store.send(.ageWallContinue) {
            $0.$setting.withLock({ $0.ageDeclarationVersion = AgeDeclaration.currentVersion })
        }
        await store.receive(\.delegate.ageConfirmed)
        #expect(store.state.step == .analyticsChoice)
    }

    @MainActor
    @Test
    func aStaleVersionIsReplacedByTheCurrentOne() async {
        let store = Self.makeFirstLaunchStore(version: 0, level: .basic)

        await store.send(.binding(.set(\.isDeclarationTicked, true))) {
            $0.isDeclarationTicked = true
        }
        await store.send(.ageWallContinue) {
            $0.$setting.withLock({ $0.ageDeclarationVersion = AgeDeclaration.currentVersion })
        }
        await store.receive(\.delegate.ageConfirmed)
        #expect(store.state.step == .complete)
    }

    @MainActor
    @Test(arguments: AnalyticsLevel.allCases)
    func choosingALevelStoresItAndReportsIt(level: AnalyticsLevel) async {
        let store = Self.makeFirstLaunchStore(version: AgeDeclaration.currentVersion, level: nil)

        await store.send(.analyticsContinue(level)) {
            $0.selectedLevel = level
            $0.$setting.withLock({ $0.analyticsLevel = level })
        }
        await store.receive(\.delegate.levelChosen, level)
        #expect(store.state.step == .complete)
    }

    @MainActor
    @Test
    func theChoiceIsUnreachableBeforeTheAgeWall() async {
        let store = Self.makeFirstLaunchStore(version: nil, level: nil)

        await store.send(.analyticsContinue(.full))
        #expect(store.state.setting.analyticsLevel == nil)
    }

    @MainActor
    @Test
    func aConfirmedWallIgnoresAnotherContinue() async {
        let store = Self.makeFirstLaunchStore(version: AgeDeclaration.currentVersion, level: nil)

        await store.send(.binding(.set(\.isDeclarationTicked, true))) {
            $0.isDeclarationTicked = true
        }
        await store.send(.ageWallContinue)
    }
}

// MARK: Helpers
private extension FirstLaunchGateTests {
    /// An `AppReducer` store over fresh storage, with the age and analytics answers stored as given. Every client the
    /// tested paths reach is a no-op unless `dependencies` replaces it; `state` edits the initial state.
    @MainActor
    static func makeAppStore(
        ageDeclarationVersion: Int?,
        analyticsLevel: AnalyticsLevel? = nil,
        state configure: (inout AppReducer.State) -> Void = { _ in },
        dependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<AppReducer> {
        let appStorage = UserDefaults.inMemory
        let inMemoryStorage = InMemoryStorage()

        return withDependencies {
            $0.defaultAppStorage = appStorage
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            var initialState = AppReducer.State()
            // The Setting tab presents nothing when the settings load, which keeps the tab fetches
            // out of the deferred-launch cases.
            initialState.tabBarState.tabBarItemType = .setting
            initialState.settingState.$setting.withLock {
                // No mask intensity, so an inactive phase leaves the blur where it starts.
                $0 = Setting(privacyMaskIntensity: 0)
                $0.ageDeclarationVersion = ageDeclarationVersion
                $0.analyticsLevel = analyticsLevel
            }
            initialState.$privacyMaskBlur.withLock({ $0 = 0 })
            initialState.appLogsPumpState.$currentRun.withLock {
                $0 = RunLogFile(
                    url: URL(filePath: "/tmp/app-feature-tests.jsonl"),
                    date: Date(timeIntervalSince1970: 0),
                    runCount: 1
                )
            }
            configure(&initialState)

            return TestStore(
                initialState: initialState,
                reducer: AppReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.appLaunchAutomationClient = .none
                    $0.applicationClient = .noop
                    $0.continuousClock = TestClock()
                    $0.cookieClient = .noop
                    $0.date = .constant(.distantPast)
                    $0.defaultAppStorage = appStorage
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.dfClient = .noop
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                    $0.libraryClient = .noop
                    $0.logsClient = .noop
                    $0.userDefaultsClient = .noop
                    dependencies(&$0)
                }
            )
        }
    }

    @MainActor
    static func makeFirstLaunchState(version: Int?, level: AnalyticsLevel?) -> FirstLaunchReducer.State {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let state = FirstLaunchReducer.State()
            state.$setting.withLock {
                $0.ageDeclarationVersion = version
                $0.analyticsLevel = level
            }
            return state
        }
    }

    @MainActor
    static func makeFirstLaunchStore(version: Int?, level: AnalyticsLevel?) -> TestStoreOf<FirstLaunchReducer> {
        let appStorage = UserDefaults.inMemory
        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            let state = FirstLaunchReducer.State()
            state.$setting.withLock {
                $0.ageDeclarationVersion = version
                $0.analyticsLevel = level
            }
            return TestStore(initialState: state, reducer: FirstLaunchReducer.init) {
                $0.defaultAppStorage = appStorage
            }
        }
    }
}

struct StoredAnswers: Sendable {
    let version: Int?
    let level: AnalyticsLevel?
    let step: FirstLaunchReducer.Step
}

/// Counts the deferred launch's download-client calls; every other endpoint stays a no-op.
private struct DownloadClientSpy {
    let livenessObservations = LockIsolated(0)
    let phaseReports = LockIsolated<[Bool]>([])

    var client: DownloadClient {
        var client = DownloadClient.noop
        client.observeContinuedSessionLiveness = { [livenessObservations] in
            livenessObservations.withValue({ $0 += 1 })
            return AsyncStream { $0.finish() }
        }
        client.setIsInBackground = { [phaseReports] isInBackground in
            phaseReports.withValue({ $0.append(isInBackground) })
        }
        return client
    }
}

/// Records every level the analytics client is asked to apply; `send` stays a no-op.
private struct AnalyticsClientSpy {
    let appliedLevels = LockIsolated<[AnalyticsLevel?]>([])

    var client: AnalyticsClient {
        var client = AnalyticsClient.noop
        client.apply = { [appliedLevels] level in
            appliedLevels.withValue({ $0.append(level) })
        }
        return client
    }
}
