import AnalyticsClient
import ComposableArchitecture
import Foundation
@testable import SettingFeature
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
