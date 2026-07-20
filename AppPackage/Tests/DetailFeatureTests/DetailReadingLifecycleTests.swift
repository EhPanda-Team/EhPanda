import Foundation
import Testing
import AppModels
import DownloadClient
import ComposableArchitecture
@testable import DetailFeature
@testable import ReadingFeature

// The reader's load used to be kicked off by `ReadingView.onAppear`. It is now sent by whoever
// presents the reader, in the same transition that sets the destination. Both of Detail's
// presentation paths must carry that send — an unpaired one is a reader that never resolves its
// local pages and never observes its download, i.e. a silently broken primary read flow.
@Suite
@MainActor
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

    private func makeStore() -> TestStore<DetailReducer.State, DetailReducer.Action> {
        let store = TestStore(initialState: makeState(), reducer: DetailReducer.init) {
            $0.downloadClient = .noop
        }
        store.exhaustivity = .off
        return store
    }

    @Test
    func presentingTheReaderStartsItsLoad() async {
        let store = makeStore()

        await store.send(.presentReading)
        await store.receive(\.destination.presented.reading.onPresented)
        await store.receive(\.destination.presented.reading.observeDownloads)
        await store.receive(\.destination.presented.reading.loadLocalPageURLs)

        await store.finish()
    }

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
