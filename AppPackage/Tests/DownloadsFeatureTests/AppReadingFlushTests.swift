import Foundation
import ComposableArchitecture
import Testing
import Sharing
import AppModels
import DownloadClient
import CookieClient
import AppLaunchAutomationClient
import ReadingFeature
import DownloadsFeature
@testable import AppFeature

// #8: ReadingView no longer observes scene phase itself. On `.background`, AppReducer routes
// `.flushReadingProgress` to whichever reading session is on top of a navigation host (located from
// navigation state), so a force-quit from the background still persists the reader's last debounced
// page. When no reader is presented it is a no-op.
@Suite(.serialized)
struct AppReadingFlushTests: DownloadFeatureTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    private func persistedProgress(_ defaults: UserDefaults, gid: String) -> Int {
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.galleryHistory) var history
            return history.readingProgress(gid: gid)
        }
    }

    @MainActor
    @Test
    func backgroundFlushesTheActiveReaderProgressIntoHistory() async throws {
        let suiteName = "app-reading-flush-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gallery = sampleGallery()

        var reader = ReadingReducer.State(gallery: gallery, contentSource: .remote)
        reader.pendingReadingProgress = 7

        var initialState = AppReducer.State()
        initialState.settingState.hasLoadedInitialSetting = true
        initialState.downloadsState.destination = .reading(reader)

        let store = TestStore(
            initialState: initialState,
            reducer: AppReducer.init,
            withDependencies: {
                $0.defaultAppStorage = defaults
                $0.date = .constant(now)
                $0.appLaunchAutomationClient = .none
                $0.cookieClient = .noop
                $0.downloadClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.onScenePhaseChange(.background))
        await store.finish()

        #expect(persistedProgress(defaults, gid: gallery.id) == 7)
    }

    @MainActor
    @Test
    func backgroundWithoutAReaderLeavesHistoryUntouched() async throws {
        let suiteName = "app-reading-flush-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gallery = sampleGallery()

        // Pre-seed a saved progress of 3; with no reader presented the flush must not touch it.
        withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            @Shared(.galleryHistory) var history
            $history.withLock {
                $0.recordGalleryOpen(gid: gallery.id, token: gallery.token, date: now)
                $0.updateReadingProgress(gid: gallery.id, token: gallery.token, progress: 3, date: now)
            }
        }

        var initialState = AppReducer.State()
        initialState.settingState.hasLoadedInitialSetting = true

        let store = TestStore(
            initialState: initialState,
            reducer: AppReducer.init,
            withDependencies: {
                $0.defaultAppStorage = defaults
                $0.date = .constant(now)
                $0.appLaunchAutomationClient = .none
                $0.cookieClient = .noop
                $0.downloadClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.onScenePhaseChange(.background))
        await store.finish()

        #expect(persistedProgress(defaults, gid: gallery.id) == 3)
    }
}
