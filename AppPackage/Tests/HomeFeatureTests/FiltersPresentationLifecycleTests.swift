import AnalyticsClient
import AppModels
import ComposableArchitecture
import FiltersFeature
import Foundation
import HapticsClient
@testable import HomeFeature
import Sharing
import Testing
import TestingSupport

// `FiltersView`'s former `onAppear` loaded the persisted filters into the sheet's working copies.
// Six screens present that sheet; each now sends the load itself. Front Page stands in for all of
// them here — the shape is identical at every site.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite(.isolatedAppStorage)
struct FiltersPresentationLifecycleTests {
    @MainActor
    @Test
    func presentingFiltersLoadsThePersistedFilters() async {
        var stored = Filter()
        stored.doujinshi = false
        stored.manga = false

        @Shared(.searchFilter) var searchFilter
        $searchFilter.withLock({ $0 = stored })

        let store = TestStore(initialState: .init(), reducer: FrontPageReducer.init) {
            $0.analyticsClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.filtersButtonTapped)
        // A sheet presented with the defaults still in its working copies would silently discard
        // the user's saved filters on the first edit.
        await store.receive(\.destination.presented.filters.fetchFilters)
        #expect(store.state.destination?.filters?.searchFilter == stored)
        await store.finish()
    }
}
