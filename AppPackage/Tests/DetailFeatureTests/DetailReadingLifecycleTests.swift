import AnalyticsClient
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
@testable import ReadingFeature
import Testing

// The reader's load used to be kicked off by `ReadingView.onAppear`. It is now sent by whoever
// presents the reader, in the same transition that sets the destination. Both of Detail's
// presentation paths must carry that send — an unpaired one is a reader that never resolves its
// local pages and never observes its download, i.e. a silently broken primary read flow.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct DetailReadingLifecycleTests {
    private func makeState() -> DetailReducer.State {
        var state = DetailReducer.State(
            gallery: Gallery(
                gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
                coverURL: nil, galleryURL: URL(string: "https://example.com/g/42/abc123/")
            )
        )
        state.galleryDetail = .preview
        return state
    }

    @MainActor
    private func makeStore() -> TestStore<DetailReducer.State, DetailReducer.Action> {
        let store = TestStore(initialState: makeState(), reducer: DetailReducer.init) {
            $0.analyticsClient = .noop
            $0.downloadClient = .noop
        }
        store.exhaustivity = .off
        return store
    }

    @MainActor
    @Test
    func presentingTheReaderStartsItsLoad() async {
        let store = makeStore()

        await store.send(.presentReading)
        await store.receive(\.destination.presented.reading.onPresented)
        await store.receive(\.destination.presented.reading.observeDownloads)
        await store.receive(\.destination.presented.reading.loadLocalPageURLs)

        await store.finish()
    }

    @MainActor
    @Test
    func openingTheReaderFromDownloadStartsItsLoad() async {
        let store = makeStore()

        await store.send(.openReadingDone(.failure(.notFound)))
        await store.receive(\.destination.presented.reading.onPresented)
        await store.receive(\.destination.presented.reading.observeDownloads)
        await store.receive(\.destination.presented.reading.loadLocalPageURLs)

        await store.finish()
    }
}
