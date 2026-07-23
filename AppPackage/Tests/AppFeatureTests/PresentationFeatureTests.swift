@testable import AppFeature
import AppModels
import AppTools
@testable import ClipboardClient
import ComposableArchitecture
import CustomDump
import DownloadClient
import Foundation
import HapticsClient
import Testing
@testable import UserDefaultsClient

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct PresentationFeatureTests {
    @MainActor
    @Test
    func unsupportedExplicitDeepLinkSurfacesErrorToast() async throws {
        let url = try #require(URL(string: "ehpanda://evil.example/g/123/token?secret=value"))
        let errorInfo = ErrorInfo(error: .unsupportedDeepLink, context: .unsupportedLink(url: url))
        let store = TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init
        )

        await store.send(.handleDeepLink(url)) {
            $0.toast = .error(errorInfo)
        }
    }

    @MainActor
    @Test
    func unsupportedClipboardURLStaysSilentAfterPersistingChangeCount() async throws {
        let recordedWrites = LockIsolated<[Int]>([])
        let url = try #require(URL(string: "https://example.com/not-a-gallery"))
        let changeCount = 42
        let store = TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init,
            withDependencies: {
                $0.clipboardClient = .fixed(url: url, changeCount: changeCount)
                $0.userDefaultsClient = .recording(read: 7, writes: recordedWrites)
            }
        )

        await store.send(.detectClipboardURL)
        await store.finish()

        expectNoDifference(recordedWrites.value, [changeCount])
        #expect(store.state.toast == nil)
    }

    @MainActor
    @Test
    func recognizedClipboardURLForwardsToDeepLinkHandler() async throws {
        let recordedWrites = LockIsolated<[Int]>([])
        let url = try #require(URL(string: "https://e-hentai.org/g/123/abcdef0123/"))
        let changeCount = 42
        let store = TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init,
            withDependencies: {
                $0.clipboardClient = .fixed(url: url, changeCount: changeCount)
                $0.userDefaultsClient = .recording(read: 7, writes: recordedWrites)
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.detectClipboardURL)
        await store.receive(\.handleDeepLink)

        expectNoDifference(recordedWrites.value, [changeCount])
    }

    @MainActor
    @Test
    func fetchedReplacementWaitsForDetailDismissalCompletion() async throws {
        let currentGallery = gallery(id: "111")
        let fetchedGallery = gallery(id: "222")
        let url = try #require(URL(string: "https://e-hentai.org/g/222/abcdef0123/"))
        var initialState = PresentationFeature.State()
        initialState.detail = .init(gallery: currentGallery)
        let fetchStore = presentationStore(initialState: initialState)

        await fetchStore.send(.handleDeepLink(url)) {
            $0.detail = nil
            $0.isAwaitingDetailDismissal = true
        }
        await fetchStore.receive(\.fetchGallery) {
            $0.toast = .loading()
        }
        let stateWhileFetching = fetchStore.state
        fetchStore.exhaustivity = .off(showSkippedAssertions: false)
        await fetchStore.skipInFlightEffects(strict: false)
        await fetchStore.skipReceivedActions(strict: false)

        let store = presentationStore(initialState: stateWhileFetching)
        await store.send(.fetchGalleryDone(url: url, result: .success(fetchedGallery))) {
            $0.pendingGalleryLink = .init(url: url, gallery: fetchedGallery)
            $0.toast = nil
        }
        await store.send(.detailDismissalCompleted) {
            $0.isAwaitingDetailDismissal = false
            $0.pendingGalleryLink = nil
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.handleGalleryLink)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.detail?.gallery == fetchedGallery)
    }

    @MainActor
    @Test
    func dismissalCompletingBeforeFetchPresentsWhenFetchFinishes() async throws {
        let fetchedGallery = gallery(id: "222")
        let url = try #require(URL(string: "https://e-hentai.org/g/222/abcdef0123/"))
        var initialState = PresentationFeature.State()
        initialState.isAwaitingDetailDismissal = true
        let store = presentationStore(initialState: initialState)

        await store.send(.detailDismissalCompleted) {
            $0.isAwaitingDetailDismissal = false
        }
        await store.send(.fetchGalleryDone(url: url, result: .success(fetchedGallery)))

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.handleGalleryLink)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.detail?.gallery == fetchedGallery)
        #expect(store.state.pendingGalleryLink == nil)
    }

    @MainActor
    @Test
    func userDismissalWithoutPendingLinkIsSilent() async {
        let store = presentationStore()

        await store.send(.detailDismissalCompleted)
        await store.finish()
    }

    @MainActor
    @Test
    func deepLinkWithoutPresentedDetailFlowsStraightToPresentation() async throws {
        let fetchedGallery = gallery(id: "222")
        let url = try #require(URL(string: "https://e-hentai.org/g/222/abcdef0123/"))
        let fetchStore = presentationStore()

        await fetchStore.send(.handleDeepLink(url))
        await fetchStore.receive(\.fetchGallery) {
            $0.toast = .loading()
        }
        let stateWhileFetching = fetchStore.state
        fetchStore.exhaustivity = .off(showSkippedAssertions: false)
        await fetchStore.skipInFlightEffects(strict: false)
        await fetchStore.skipReceivedActions(strict: false)

        let store = presentationStore(initialState: stateWhileFetching)
        await store.send(.fetchGalleryDone(url: url, result: .success(fetchedGallery))) {
            $0.toast = nil
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.handleGalleryLink)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.detail?.gallery == fetchedGallery)
        #expect(store.state.isAwaitingDetailDismissal == false)
        #expect(store.state.pendingGalleryLink == nil)
    }

    @MainActor
    @Test
    func repeatedFetchWhileDismissingKeepsLatestFetchedGallery() async throws {
        let firstGallery = gallery(id: "222")
        let latestGallery = gallery(id: "333")
        let firstURL = try #require(URL(string: "https://e-hentai.org/g/222/abcdef0123/"))
        let latestURL = try #require(URL(string: "https://e-hentai.org/g/333/fedcba3210/"))
        var initialState = PresentationFeature.State()
        initialState.isAwaitingDetailDismissal = true
        let store = presentationStore(initialState: initialState)

        await store.send(.fetchGalleryDone(url: firstURL, result: .success(firstGallery))) {
            $0.pendingGalleryLink = .init(url: firstURL, gallery: firstGallery)
        }
        await store.send(.fetchGalleryDone(url: latestURL, result: .success(latestGallery))) {
            $0.pendingGalleryLink = .init(url: latestURL, gallery: latestGallery)
        }
        await store.send(.detailDismissalCompleted) {
            $0.isAwaitingDetailDismissal = false
            $0.pendingGalleryLink = nil
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.receive(\.handleGalleryLink)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.detail?.gallery == latestGallery)
    }

    @Test(arguments: [
        GalleryFailureRouteFixture(
            url: "https://e-hentai.org/g/123/secret-token?next=private",
            secret: "secret-token"
        ),
        GalleryFailureRouteFixture(
            url: "https://exhentai.org/s/secret-key/456-7?next=private",
            secret: "secret-key"
        )
    ])
    @MainActor
    private func galleryFailureToastUsesSanitizedContext(fixture: GalleryFailureRouteFixture) async throws {
        let url = try #require(URL(string: fixture.url))
        let context = Context.galleryFailure(
            url: url,
            action: "Fetch gallery",
            reason: AppError.networkingFailed.localizedDescription
        )
        let errorInfo = ErrorInfo(error: .networkingFailed, context: context)
        var initialState = PresentationFeature.State()
        initialState.toast = .loading()
        let store = TestStore(
            initialState: initialState,
            reducer: PresentationFeature.init
        )

        await store.send(.fetchGalleryDone(url: url, result: .failure(.networkingFailed))) {
            $0.toast = .error(errorInfo)
        }
        await store.finish()

        let values = context.values.map(\.displayValue)
        #expect(values.contains(where: { $0.contains(fixture.secret) }) == false)
        #expect(values.contains(where: { $0.contains(url.path) }) == false)
        #expect(values.contains(where: { $0.contains("next=private") }) == false)
        #expect(values.contains(where: { $0.contains(url.absoluteString) }) == false)
    }

    @MainActor
    @Test
    func presentErrorInfoRoutesToErrorInfoDestination() async {
        let errorInfo = ErrorInfo(
            error: .parseFailed,
            context: [.action: "test"]
        )
        let store = TestStore(
            initialState: PresentationFeature.State(),
            reducer: PresentationFeature.init
        )

        await store.send(.presentErrorInfo(errorInfo)) {
            $0.destination = .errorInfo(errorInfo)
        }
    }

    // Proves the read routes through the injected UserDefaultsClient, not UserDefaults.standard:
    // the injected read equals the clipboard change count, so the guard short-circuits and no write
    // occurs — even though the process-global holds a conflicting value that would force a write if
    // it were consulted.
    @MainActor
    @Test
    func injectedReadSuppressesWriteDespiteConflictingProcessGlobal() async {
        let recordedWrites = LockIsolated<[Int]>([])
        let matchingChangeCount = 42

        await withSeededProcessGlobal(conflicting: 999) {
            let store = TestStore(
                initialState: PresentationFeature.State(),
                reducer: PresentationFeature.init,
                withDependencies: {
                    $0.clipboardClient = .fixed(changeCount: matchingChangeCount)
                    $0.userDefaultsClient = .recording(read: matchingChangeCount, writes: recordedWrites)
                }
            )

            await store.send(.detectClipboardURL)
            await store.finish()
        }

        expectNoDifference(recordedWrites.value, [])
    }

    // Proves the write routes through the injected UserDefaultsClient: the injected read differs from
    // the clipboard change count, so the reducer records the new count through the injected setValue.
    @MainActor
    @Test
    func injectedReadMismatchWritesThroughInjectedSetValue() async {
        let recordedWrites = LockIsolated<[Int]>([])
        let clipboardChangeCount = 42
        let injectedReadValue = 7

        await withSeededProcessGlobal(conflicting: 999) {
            let store = TestStore(
                initialState: PresentationFeature.State(),
                reducer: PresentationFeature.init,
                withDependencies: {
                    $0.clipboardClient = .fixed(changeCount: clipboardChangeCount)
                    $0.userDefaultsClient = .recording(read: injectedReadValue, writes: recordedWrites)
                }
            )

            await store.send(.detectClipboardURL)
            await store.finish()
        }

        expectNoDifference(recordedWrites.value, [clipboardChangeCount])
    }
}

private struct GalleryFailureRouteFixture: CustomTestStringConvertible, Sendable {
    let url: String
    let secret: String

    var testDescription: String { url }
}

private extension PresentationFeatureTests {
    func gallery(id: String) -> Gallery {
        Gallery(
            gid: id,
            token: "token-\(id)",
            title: "Gallery \(id)",
            rating: 4,
            tags: [],
            category: .doujinshi,
            uploader: "Uploader",
            pageCount: 10,
            postedDate: Date(timeIntervalSince1970: 0),
            coverURL: nil,
            galleryURL: nil
        )
    }

    @MainActor
    func presentationStore(
        initialState: PresentationFeature.State = .init()
    ) -> TestStoreOf<PresentationFeature> {
        TestStore(
            initialState: initialState,
            reducer: PresentationFeature.init,
            withDependencies: {
                $0.date = .constant(Date(timeIntervalSince1970: 0))
                $0.downloadClient = .noop
                $0.hapticsClient = .noop
            }
        )
    }

    // Seeds a conflicting value into the process-global store for the change-count key, runs the body,
    // then restores the store so the test does not pollute others.
    func withSeededProcessGlobal(conflicting value: Int, _ body: () async -> Void) async {
        let key = AppUserDefaults.clipboardChangeCount.rawValue
        let original = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(value, forKey: key)
        await body()
        if let original {
            UserDefaults.standard.set(original, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

private extension ClipboardClient {
    static func fixed(url: URL? = nil, changeCount: Int) -> Self {
        .init(
            url: { url },
            changeCount: { changeCount },
            saveText: { _ in },
            saveImage: { _, _ in },
            saveImageData: { _ in false }
        )
    }
}

private extension UserDefaultsClient {
    static func recording(read: Int?, writes: LockIsolated<[Int]>) -> Self {
        .init(
            getValue: { _ in read },
            setValue: { value, _ in
                if let intValue = value as? Int {
                    writes.withValue({ $0.append(intValue) })
                }
            }
        )
    }
}
