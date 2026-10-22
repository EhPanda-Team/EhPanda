import AppModels
import ComposableArchitecture
import Foundation
@testable import SearchFeature
import Testing

@Suite
struct SearchHistoryRemovalTests {
    @MainActor
    @Test
    func removingRecentSearchesPreservesSavedSearchesAndBrowsingHistory() async {
        let storage = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = storage
        } operation: {
            let state = populatedState()
            let savedSearches = state.quickSearchWords
            let browsingHistory = state.galleryHistory
            let store = TestStore(initialState: state, reducer: SearchRootReducer.init)

            await store.send(.removeAllHistoryKeywords) {
                $0.$historyKeywords.withLock({ $0.removeAll() })
            }
            let reopened = SearchRootReducer.State()
            #expect(reopened.historyKeywords.isEmpty)
            #expect(reopened.quickSearchWords == savedSearches)
            #expect(reopened.galleryHistory == browsingHistory)
            await store.finish()
        }
    }

    @MainActor
    @Test
    func removingRecentlySeenClearsAllPersistedHistoryAndResumePositions() async {
        let storage = UserDefaults.inMemory
        await withDependencies {
            $0.defaultAppStorage = storage
        } operation: {
            let state = populatedState()
            let searches = state.historyKeywords
            let savedSearches = state.quickSearchWords
            let store = TestStore(initialState: state, reducer: SearchRootReducer.init)

            await store.send(.removeAllHistoryGalleries) {
                $0.$galleryHistory.withLock({ $0.removeAll() })
                $0.historyGalleries = []
            }
            let reopened = SearchRootReducer.State()
            #expect(reopened.galleryHistory.isEmpty)
            #expect(reopened.historyKeywords == searches)
            #expect(reopened.quickSearchWords == savedSearches)
            await store.send(.onPresented)
            await store.receive(\.fetchHistoryGalleries)
            await store.finish()
        }
    }

    @MainActor
    @Test
    func queuedMetadataCannotRestoreClearedHistory() async {
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let state = populatedState()
            let oldMetadata = state.historyGalleries
            let store = TestStore(initialState: state, reducer: SearchRootReducer.init)

            await store.send(.removeAllHistoryGalleries) {
                $0.$galleryHistory.withLock({ $0.removeAll() })
                $0.historyGalleries = []
            }
            await store.send(.fetchHistoryGalleriesDone(.success(oldMetadata)))
            await store.finish()
        }
    }

    @MainActor
    @Test
    func metadataStillLoadsForCurrentHistory() async {
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            var state = populatedState()
            let metadata = state.historyGalleries
            state.historyGalleries = []
            let store = TestStore(initialState: state, reducer: SearchRootReducer.init)

            await store.send(.fetchHistoryGalleriesDone(.success(metadata))) {
                $0.historyGalleries = metadata
            }
            await store.finish()
        }
    }

    private func populatedState() -> SearchRootReducer.State {
        var state = SearchRootReducer.State()
        state.$historyKeywords.withLock({ $0 = ["watercolor", "artbook"] })
        state.$quickSearchWords.withLock({ $0 = [.init(name: "Artbooks", content: "artbook")] })
        state.$galleryHistory.withLock { entries in
            // Recently Seen displays ten, but Remove All must also remove older persisted entries.
            entries = (1...12).map {
                .init(gid: String($0), token: "fixture", lastOpenDate: .distantPast, readingProgress: 5)
            }
        }
        state.historyGalleries = state.galleryHistory.prefix(10).map {
            Gallery(
                gid: $0.gid, token: $0.token, title: "Artbook", rating: 4,
                tags: [], category: .nonH, uploader: "Studio", pageCount: 48,
                postedDate: .distantPast, coverURL: nil, galleryURL: nil
            )
        }
        return state
    }
}
