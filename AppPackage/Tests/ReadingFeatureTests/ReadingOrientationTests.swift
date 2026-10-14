import AppModels
import ComposableArchitecture
import Foundation
@testable import ReadingFeature
import Sharing
import Testing

struct ReadingOrientationTests {
    @MainActor
    @Test(arguments: [true, false])
    func entryAppliesTheCurrentOrientation(isLandscape: Bool) async {
        let store = makeStore(setting: Setting(readingDirection: .leftToRight, enableDualPageMode: true))
        await store.send(.layoutChanged(isLandscape: isLandscape, supportsAutomaticLayout: true)) {
            $0.layoutIsLandscape = isLandscape
            $0.supportsAutomaticLayout = true
            $0.$setting.withLock {
                $0.readingDirection = isLandscape ? .rightToLeft : .vertical
                $0.enableDualPageMode = isLandscape
            }
        }
        await store.finish()
    }

    @MainActor
    @Test(arguments: HorizontalReadingDirection.allCases, ReadingDirection.allCases)
    func rotationUsesBothConfiguredDirections(
        landscape: HorizontalReadingDirection, portrait: ReadingDirection
    ) async {
        let setting = Setting(
            readingOrientation: .init(landscapeDirection: landscape, portraitDirection: portrait),
            exceptCover: true
        )
        let store = makeStore(setting: setting)
        await store.send(.layoutChanged(isLandscape: true, supportsAutomaticLayout: true)) {
            $0.layoutIsLandscape = true
            $0.supportsAutomaticLayout = true
            $0.$setting.withLock {
                $0.readingDirection = landscape.readingDirection
                $0.enableDualPageMode = true
            }
        }
        await store.send(.layoutChanged(isLandscape: false, supportsAutomaticLayout: true)) {
            $0.layoutIsLandscape = false
            $0.$setting.withLock {
                $0.readingDirection = portrait
                $0.enableDualPageMode = false
            }
        }
        #expect(store.state.setting.exceptCover)
        await store.finish()
    }

    @MainActor
    @Test(arguments: [true, false])
    func ordinaryPhoneNeverChangesManualPreferences(isLandscape: Bool) async {
        let setting = Setting(readingDirection: .leftToRight, enableDualPageMode: true)
        let store = makeStore(setting: setting)
        await store.send(.layoutChanged(isLandscape: isLandscape, supportsAutomaticLayout: false)) {
            $0.layoutIsLandscape = isLandscape
        }
        await store.send(.readingOrientationPreferencesChanged)
        #expect(store.state.setting == setting)
        await store.finish()
    }

    @MainActor
    @Test
    func disablingAutomationPreservesManualPreferencesAcrossRotation() async {
        let setting = Setting(
            readingDirection: .leftToRight, readingOrientation: .init(isEnabled: false), enableDualPageMode: true
        )
        let store = makeStore(setting: setting)
        await store.send(.layoutChanged(isLandscape: true, supportsAutomaticLayout: true)) {
            $0.layoutIsLandscape = true
            $0.supportsAutomaticLayout = true
        }
        await store.send(.layoutChanged(isLandscape: false, supportsAutomaticLayout: true)) {
            $0.layoutIsLandscape = false
        }
        await store.send(.readingOrientationPreferencesChanged)
        #expect(store.state.setting == setting)
        await store.finish()
    }

    @MainActor
    @Test
    func aLateHingeReportAppliesTheAlreadyMeasuredOrientation() async {
        let store = makeStore()
        await store.send(.layoutChanged(isLandscape: true, supportsAutomaticLayout: false)) {
            $0.layoutIsLandscape = true
        }
        await store.send(.layoutChanged(isLandscape: true, supportsAutomaticLayout: true)) {
            $0.supportsAutomaticLayout = true
            $0.$setting.withLock {
                $0.readingDirection = .rightToLeft
                $0.enableDualPageMode = true
            }
        }
        await store.finish()
    }

    @MainActor
    @Test
    func sameOrientationResizePreservesAManualOverride() async {
        let setting = Setting(readingDirection: .vertical, enableDualPageMode: false)
        let store = makeStore(setting: setting, isLandscape: true, supportsAutomaticLayout: true)
        await store.send(.layoutChanged(isLandscape: true, supportsAutomaticLayout: true))
        #expect(store.state.setting == setting)
        await store.send(.layoutChanged(isLandscape: false, supportsAutomaticLayout: true)) {
            $0.layoutIsLandscape = false
        }
        await store.send(.layoutChanged(isLandscape: true, supportsAutomaticLayout: true)) {
            $0.layoutIsLandscape = true
            $0.$setting.withLock {
                $0.readingDirection = .rightToLeft
                $0.enableDualPageMode = true
            }
        }
        await store.finish()
    }

    @MainActor
    @Test
    func changingAutomationPreferencesAppliesWithoutAnotherRotation() async {
        let setting = Setting(readingOrientation: .init(landscapeDirection: .leftToRight))
        let store = makeStore(setting: setting, isLandscape: true, supportsAutomaticLayout: true)
        await store.send(.readingOrientationPreferencesChanged) {
            $0.$setting.withLock {
                $0.readingDirection = .leftToRight
                $0.enableDualPageMode = true
            }
        }
        await store.finish()
    }

    @MainActor
    private func makeStore(
        setting: Setting = .init(), isLandscape: Bool? = nil, supportsAutomaticLayout: Bool = false
    ) -> TestStoreOf<ReadingReducer> {
        withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            var state = ReadingReducer.State(gallery: .preview)
            state.$setting.withLock({ $0 = setting })
            state.layoutIsLandscape = isLandscape
            state.supportsAutomaticLayout = supportsAutomaticLayout
            return TestStore(initialState: state, reducer: ReadingReducer.init)
        }
    }
}
