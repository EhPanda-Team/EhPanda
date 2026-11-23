import AppModels
import ComposableArchitecture
import Foundation
import HapticsClient
import QuickSearchFeature
@testable import SearchFeature
import Sharing
import Testing
import TestingSupport

// Save Search on the Search tab's results page (261123-1ep). Each case owns its app storage,
// so the suite runs in parallel.
@Suite(.isolatedAppStorage)
struct SaveSearchTests {
    private static let keyword = "language:english"

    @MainActor
    @Test
    func saveSearchOpensTheEditorPrefilledWithTheShownKeyword() async {
        let store = makeStore(keyword: Self.keyword)
        #expect(store.state.canSaveSearch)

        await store.send(.saveSearchButtonTapped) {
            $0.destination = .newSavedSearch(NewSavedSearchFeature.State(id: UUID(0), keyword: Self.keyword))
        }
    }

    @MainActor
    @Test
    func saveSearchDoesNothingWithoutAKeyword() async {
        let store = makeStore(keyword: "")
        #expect(!store.state.canSaveSearch)

        await store.send(.saveSearchButtonTapped)
    }

    @MainActor
    @Test
    func saveSearchDoesNothingWhenTheKeywordIsAlreadySaved() async {
        let store = makeStore(keyword: Self.keyword, existing: [SavedSearch(name: "English", content: Self.keyword)])
        #expect(!store.state.canSaveSearch)

        await store.send(.saveSearchButtonTapped)
    }

    @MainActor
    @Test
    func confirmingSavesTheKeywordAndReturnsToTheResults() async {
        let store = makeStore(keyword: Self.keyword)
        await store.send(.saveSearchButtonTapped) {
            $0.destination = .newSavedSearch(NewSavedSearchFeature.State(id: UUID(0), keyword: Self.keyword))
        }
        await store.send(.destination(.presented(.newSavedSearch(.confirmButtonTapped)))) {
            $0.destination?.newSavedSearch?.$savedSearches.withLock({
                $0 = [SavedSearch(id: UUID(0), name: "", content: Self.keyword)]
            })
        }
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
        #expect(!store.state.canSaveSearch)
    }

    @MainActor
    private func makeStore(keyword: String, existing: [SavedSearch] = []) -> TestStoreOf<SearchReducer> {
        @Shared(.savedSearches) var savedSearches
        $savedSearches.withLock({ $0 = existing })
        return TestStore(initialState: SearchReducer.State(keyword: keyword), reducer: SearchReducer.init) {
            $0.hapticsClient = .noop
            $0.uuid = .incrementing
        }
    }
}
