import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import Sharing
import Testing

// Covers the tag-translation file-import flow: the button drives a native `.fileImporter` through a
// `@Presents` destination, so present/dismiss are exhaustively assertable in the reducer.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct GeneralSettingReducerTests {
    @MainActor
    @Test
    func importButtonPresentsFileImporter() async {
        let store = TestStore(initialState: .init(), reducer: GeneralSettingReducer.init) {
            $0.analyticsClient = .noop
        }

        await store.send(.importCustomTranslationsButtonTapped) {
            $0.destination = .importTranslations
        }

        // Cancelling or picking flips the `isPresented` binding back to false → dismiss.
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    @MainActor
    @Test
    func filePickedCausesNoLocalStateChange() async {
        let store = TestStore(initialState: .init(), reducer: GeneralSettingReducer.init) {
            $0.analyticsClient = .noop
        }

        // The child only relays the URL and mutates no local state; the import itself is handled by
        // `SettingReducer` (covered by `generalFilePickedImportsAndStoresTagTranslator`).
        await store.send(.onTranslationsFilePicked(URL(filePath: "/tmp/tags.json")))
    }
}

// Covers the analytics level picker (UI-SPEC C-9, D-07, DD-09a): a pick writes the level and applies it to the
// analytics client once, from the reducer, so lowering to Minimal stops the SDK at once (threat T-18-18).
@Suite
struct GeneralSettingAnalyticsLevelTests {
    /// The levels `apply` was called with, in order.
    private final class AppliedLevels: Sendable {
        let levels = LockIsolated<[AnalyticsLevel?]>([])

        var client: AnalyticsClient {
            var client = AnalyticsClient.noop
            client.apply = { [levels] level in levels.withValue({ $0.append(level) }) }
            return client
        }
    }

    @MainActor
    @Test(arguments: [
        (stored: AnalyticsLevel.full, picked: AnalyticsLevel.minimal),
        (stored: .basic, picked: .minimal),
        (stored: .minimal, picked: .basic),
        (stored: .minimal, picked: .full),
        (stored: .full, picked: .basic)
    ])
    func pickingALevelStoresItAndAppliesItOnce(stored: AnalyticsLevel, picked: AnalyticsLevel) async {
        let defaults = UserDefaults.inMemory
        let applied = AppliedLevels()
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = GeneralSettingReducer.State()
            state.$setting.withLock({ $0.analyticsLevel = stored })
            let store = TestStore(initialState: state, reducer: GeneralSettingReducer.init) {
                $0.analyticsClient = applied.client
                $0.defaultAppStorage = defaults
            }

            await store.send(.analyticsLevelPicked(picked)) {
                $0.$setting.withLock({ $0.analyticsLevel = picked })
            }
            await store.finish()

            #expect(applied.levels.value == [picked])
            @Shared(.setting) var persisted
            #expect(persisted.analyticsLevel == picked)
        }
    }

    @MainActor
    @Test(arguments: AnalyticsLevel.allCases)
    func pickingTheCurrentLevelAgainAppliesNothing(level: AnalyticsLevel) async {
        let defaults = UserDefaults.inMemory
        let applied = AppliedLevels()
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = GeneralSettingReducer.State()
            state.$setting.withLock({ $0.analyticsLevel = level })
            let store = TestStore(initialState: state, reducer: GeneralSettingReducer.init) {
                $0.analyticsClient = applied.client
                $0.defaultAppStorage = defaults
            }

            await store.send(.analyticsLevelPicked(level))
            await store.finish()

            #expect(applied.levels.value.isEmpty)
        }
    }

    @MainActor
    @Test
    func noOtherActionAppliesALevel() async {
        let defaults = UserDefaults.inMemory
        let applied = AppliedLevels()
        await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            let state = GeneralSettingReducer.State()
            state.$setting.withLock({ $0.analyticsLevel = .basic })
            let store = TestStore(initialState: state, reducer: GeneralSettingReducer.init) {
                $0.analyticsClient = applied.client
                $0.defaultAppStorage = defaults
            }
            store.exhaustivity = .off

            await store.send(.importCustomTranslationsButtonTapped)
            await store.send(.destination(.dismiss))
            await store.send(.onTranslationsFilePicked(URL(filePath: "/tmp/tags.json")))
            await store.send(.removeCustomTranslationsButtonTapped)
            await store.send(.clearImageCacheButtonTapped)
            await store.send(.calculateWebImageDiskCacheDone(2048))
            await store.send(.delegate(.enableTagsExtensionChanged))
            await store.finish()

            #expect(applied.levels.value.isEmpty)
        }
    }
}
