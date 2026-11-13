import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
import HapticsClient
@testable import ReadingFeature
import Sharing
import Testing

/// The Read button shows where the reader will resume. The number is the browsing history's saved page, read
/// when the screen is presented and again when the reader closes, so it is never older than the last read.
@Suite
struct DetailReadingProgressTests {
    @MainActor
    private func makeStore() -> TestStoreOf<DetailReducer> {
        var state = DetailReducer.State(
            gallery: Gallery(
                gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
                coverURL: nil, galleryURL: nil
            )
        )
        state.galleryDetail = .preview
        let store = TestStore(initialState: state, reducer: DetailReducer.init) {
            $0.analyticsClient = .noop
            $0.appLaunchAutomationClient = .none
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.downloadClient = .noop
            // Closing the reader plays a haptic.
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off
        return store
    }

    @MainActor
    @Test
    func aNeverReadGalleryHasNoProgress() async {
        let store = makeStore()
        await store.send(.onPresented)
        #expect(store.state.readingProgress == 0)
    }

    @MainActor
    @Test
    func presentingTheScreenReadsTheSavedPage() async {
        @Shared(.galleryHistory) var galleryHistory
        $galleryHistory.withLock {
            $0.updateReadingProgress(gid: "42", token: "abc123", progress: 12, date: Date(timeIntervalSince1970: 1))
        }
        let store = makeStore()
        await store.send(.onPresented)
        #expect(store.state.readingProgress == 12)
    }

    @MainActor
    @Test
    func closingTheReaderRefreshesTheProgress() async {
        @Shared(.galleryHistory) var galleryHistory
        let store = makeStore()
        await store.send(.onPresented)
        #expect(store.state.readingProgress == 0)

        // The reader writes the page it ends on into the history before the screen learns it closed.
        $galleryHistory.withLock {
            $0.updateReadingProgress(gid: "42", token: "abc123", progress: 9, date: Date(timeIntervalSince1970: 2))
        }
        await store.send(.presentReading)
        await store.send(.destination(.presented(.reading(.onPerformDismiss))))
        await store.receive(\.destination.dismiss)
        #expect(store.state.readingProgress == 9)
    }
}
