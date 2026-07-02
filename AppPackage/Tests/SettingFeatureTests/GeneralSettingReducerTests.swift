import Testing
import Foundation
@testable import SettingFeature
import ComposableArchitecture

// Covers the tag-translation file-import flow: the button drives a native `.fileImporter` through a
// `@Presents` destination, so present/dismiss are exhaustively assertable in the reducer.
@Suite
@MainActor
struct GeneralSettingReducerTests {
    @Test
    func importButtonPresentsFileImporter() async {
        let store = TestStore(initialState: .init(), reducer: GeneralSettingReducer.init)

        await store.send(.importCustomTranslationsButtonTapped) {
            $0.destination = .importTranslations
        }

        // Cancelling or picking flips the `isPresented` binding back to false → dismiss.
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
    }

    @Test
    func filePickedCausesNoLocalStateChange() async {
        let store = TestStore(initialState: .init(), reducer: GeneralSettingReducer.init)

        // The child only relays the URL and mutates no local state; the import itself is handled by
        // `SettingReducer` (covered by `generalFilePickedImportsAndStoresTagTranslator`).
        await store.send(.onTranslationsFilePicked(URL(filePath: "/tmp/tags.json")))
    }
}
