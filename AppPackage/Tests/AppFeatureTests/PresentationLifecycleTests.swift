import AnalyticsClient
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadClient
import Foundation
import HapticsClient
import Testing

// Presentation-driven lifecycle for the two routes that install a gallery detail *modally* rather
// than by pushing it: the iPad tap route (`presentGalleryDetail`) and the deep-link / clipboard /
// URL route (`handleGalleryLink`). Both used to rely on the detail view's `onAppear`, so both must
// now carry the load send themselves — a miss here is a permanently blank detail screen (T-11-10).
//
// `Gallery.preview` has no `galleryURL`, so the detail fetch short-circuits and these tests make no
// network request. The remaining presentation effects are non-exhaustively skipped: the request
// types take no injectable session, so they cannot be asserted end to end (see 11-07-SUMMARY.md).
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct PresentationLifecycleTests {
    @MainActor
    @Test
    func presentingGalleryDetailStartsItsLoad() async {
        let store = makePresentationStore()

        await store.send(.presentGalleryDetail(gallery: .preview, downloaded: nil))
        await store.receive(\.detail.presented.onPresented)
        await store.skipReceivedActions(strict: false)

        #expect(store.state.detail != nil)
    }

    @MainActor
    @Test
    func deepLinkedGalleryDetailStartsItsLoad() async throws {
        let url = try #require(URL(string: "https://e-hentai.org/g/123/abcdef0123/"))
        let store = makePresentationStore()

        await store.send(.handleGalleryLink(url: url, gallery: .preview))
        await store.receive(\.detail.presented.onPresented)
        await store.skipReceivedActions(strict: false)

        #expect(store.state.detail != nil)
    }
}

private extension PresentationLifecycleTests {
    @MainActor
    func makePresentationStore() -> TestStoreOf<PresentationFeature> {
        let store = TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = .noop
                $0.hapticsClient = .noop
                $0.date = .constant(.init(timeIntervalSince1970: 0))
            }
        )
        store.exhaustivity = .off
        return store
    }
}
