import AppModels
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
@testable import ReadingFeature
import Testing

// REV-1/REV-4/REV-10: pushing the reader from Detail must seed the reader's `gallery` (so remote
// reading isn't blank and history upserts carry the real gid/token), plus the threaded `previewConfig`
// (page math) and `language` (Live Text). A regression here silently bricks the primary read flow.
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct DetailReadingSeedTests {
    private func makeGallery() -> Gallery {
        Gallery(
            gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
            category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
            coverURL: nil, galleryURL: URL(string: "https://example.com/g/42/abc123/")
        )
    }

    private func makeSeededState() -> DetailReducer.State {
        var state = DetailReducer.State(gallery: makeGallery())
        state.galleryDetail = .preview
        state.previewConfig = .large(rows: 3)
        return state
    }

    @MainActor
    @Test
    func openReadingRemoteSeedsGalleryPreviewConfigAndLanguage() async {
        // Presenting the reader now starts its load in the same transition, so the reader's
        // download observation runs inside this store.
        let store = TestStore(initialState: makeSeededState(), reducer: DetailReducer.init) {
            $0.downloadClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.openReadingDone(.failure(.notFound)))

        guard case let .reading(readingState)? = store.state.destination else {
            Issue.record("expected a reading destination")
            return
        }
        #expect(readingState.gallery.gid == "42")
        #expect(readingState.gallery.token == "abc123")
        #expect(readingState.gallery.galleryURL != nil)
        #expect(readingState.previewConfig == .large(rows: 3))
        #expect(readingState.language == GalleryDetail.preview.language)
    }

    @MainActor
    @Test
    func presentReadingSeedsGalleryPreviewConfigAndLanguage() async {
        // Presenting the reader now starts its load in the same transition, so the reader's
        // download observation runs inside this store.
        let store = TestStore(initialState: makeSeededState(), reducer: DetailReducer.init) {
            $0.downloadClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.presentReading)

        guard case let .reading(readingState)? = store.state.destination else {
            Issue.record("expected a reading destination")
            return
        }
        #expect(readingState.gallery.gid == "42")
        #expect(readingState.previewConfig == .large(rows: 3))
        #expect(readingState.language == GalleryDetail.preview.language)
    }
}
