import Foundation
import Sharing
import AppModels
import ComposableArchitecture
import Testing
import HapticsClient
@testable import ReadingFeature

// V-1 regression guard. Closing the reader must persist the current page *synchronously* on
// `.onPerformDismiss` — that runs in this child reducer before the parent nils the presentation and
// cancels the pending debounce, so a deferred send (the old `onDisappear` approach) would be dropped.
// And a flush that fires before the first page turn must rewrite the *restored* resume position, never
// clobber it with a stale `.zero`.
@Suite(.serialized)
struct ReadingReducerFlushTests: DownloadFeatureTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    /// Reads `@Shared(.galleryHistory)` from an isolated `UserDefaults` so the test never touches (or
    /// depends on) the real app defaults.
    private func persistedProgress(_ defaults: UserDefaults, gid: String) -> Int? {
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.galleryHistory) var history
            return history.first { $0.gid == gid }?.readingProgress
        }
    }

    @MainActor
    @Test
    func dismissFlushesTheLastSyncedPageBeforeTheDebounceFires() async throws {
        let suiteName = "reading-flush-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gallery = sampleGallery()
        let clock = TestClock()

        let store = TestStore(
            initialState: ReadingReducer.State(gallery: gallery, contentSource: .remote),
            reducer: ReadingReducer.init,
            withDependencies: {
                $0.defaultAppStorage = defaults
                $0.continuousClock = clock
                $0.date = .constant(now)
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.syncReadingProgress(7)) // pending = 7, starts the 1s debounce (not yet fired)
        await store.send(.onPerformDismiss)        // must persist 7 inline, before the debounce fires

        #expect(persistedProgress(defaults, gid: gallery.id) == 7)

        await clock.advance(by: .seconds(1)) // drain the still-pending debounce so the store finishes
        await store.finish()
    }

    @MainActor
    @Test
    func dismissBeforeAnyPageTurnDoesNotClobberTheRestoredResumePosition() async throws {
        let suiteName = "reading-flush-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gallery = sampleGallery()

        // Pre-seed a saved resume position of 5.
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.galleryHistory) var history
            $history.withLock {
                $0.recordGalleryOpen(gid: gallery.id, token: gallery.token, date: now)
                $0.updateReadingProgress(gid: gallery.id, token: gallery.token, progress: 5, date: now)
            }
        }

        let store = TestStore(
            initialState: ReadingReducer.State(gallery: gallery, contentSource: .remote),
            reducer: ReadingReducer.init,
            withDependencies: {
                $0.defaultAppStorage = defaults
                $0.continuousClock = TestClock()
                $0.date = .constant(now)
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.restoreSession(gallery.id)) // seeds pendingReadingProgress from the stored 5
        await store.send(.onPerformDismiss)            // flushes 5, must not overwrite with 0

        #expect(persistedProgress(defaults, gid: gallery.id) == 5)
        await store.finish()
    }
}
