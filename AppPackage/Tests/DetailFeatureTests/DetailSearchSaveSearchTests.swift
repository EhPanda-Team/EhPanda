import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import HapticsClient
import QuickSearchFeature
import Sharing
import Testing

// Save Search on the tag search results page reached from a gallery's details (261123-1ep). Each
// case owns its in-memory defaults, so the suite runs in parallel.
@Suite
struct DetailSearchSaveSearchTests {
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
    private func makeStore(keyword: String, existing: [SavedSearch] = []) -> TestStoreOf<DetailSearchReducer> {
        let appStorage = UserDefaults.inMemory
        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            @Shared(.savedSearches) var savedSearches
            $savedSearches.withLock({ $0 = existing })
            return TestStore(
                initialState: DetailSearchReducer.State(keyword: keyword),
                reducer: DetailSearchReducer.init
            ) {
                $0.defaultAppStorage = appStorage
                $0.hapticsClient = .noop
                $0.uuid = .incrementing
            }
        }
    }
}
