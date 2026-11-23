import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
import HapticsClient
@testable import ReadingFeature
import Sharing
import Testing
import TestingSupport

// V-1 regression guard. Closing the reader must persist the current page *synchronously* on
// `.onPerformDismiss` — that runs in this child reducer before the parent nils the presentation and
// cancels the pending debounce, so a deferred send (the old `onDisappear` approach) would be dropped.
// And a flush that fires before the first page turn must rewrite the *restored* resume position, never
// clobber it with a stale `.zero`.
// `@MainActor` here is compiler-required, not stylistic: every case below builds a TCA
// `TestStore`, whose `init` and `state` accessor are main-actor-isolated. It is applied
// per member rather than to the suite so the type's `DownloadFeatureTestCase` conformance
// stays nonisolated — a main-actor conformance cannot be used from the `@Sendable`
// dependency closures these stores install.
@Suite(.isolatedAppStorage)
struct ReadingReducerFlushTests: DownloadFeatureTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    /// Reads `@Shared(.galleryHistory)` from the case's suite from `.isolatedAppStorage`.
    private func persistedProgress(gid: String) -> Int? {
        @Shared(.galleryHistory) var history
        return history.first(where: { $0.gid == gid })?.readingProgress
    }

    @MainActor
    @Test
    func dismissFlushesTheLastSyncedPageBeforeTheDebounceFires() async {
        let gallery = sampleGallery()
        let clock = TestClock()

        let store = TestStore(
            initialState: ReadingReducer.State(gallery: gallery, contentSource: .remote),
            reducer: ReadingReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.continuousClock = clock
                $0.date = .constant(now)
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.syncReadingProgress(7)) // pending = 7, starts the 1s debounce (not yet fired)
        await store.send(.onPerformDismiss)        // must persist 7 inline, before the debounce fires

        #expect(persistedProgress(gid: gallery.id) == 7)

        await clock.advance(by: .seconds(1)) // drain the still-pending debounce so the store finishes
        await store.finish()
    }

    @MainActor
    @Test
    func dismissBeforeAnyPageTurnDoesNotClobberTheRestoredResumePosition() async {
        let gallery = sampleGallery()

        // Pre-seed a saved resume position of 5.
        @Shared(.galleryHistory) var history
        $history.withLock {
            $0.recordGalleryOpen(gid: gallery.id, token: gallery.token, date: now)
            $0.updateReadingProgress(gid: gallery.id, token: gallery.token, progress: 5, date: now)
        }

        // State.init reads the saved resume position (5) from history, so build it where the case's
        // suite holds the pre-seeded history.
        let initialState = ReadingReducer.State(gallery: gallery, contentSource: .remote)
        let store = TestStore(
            initialState: initialState,
            reducer: ReadingReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.continuousClock = TestClock()
                $0.date = .constant(now)
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.onPerformDismiss) // flushes the restored 5, must not overwrite with 0

        #expect(persistedProgress(gid: gallery.id) == 5)
        await store.finish()
    }
}
