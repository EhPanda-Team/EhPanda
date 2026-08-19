import AnalyticsClient
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing

/// A refused Pause/Resume tap in the downloads LIST is not a no-op, and the screen has to say so
/// (DEF-15-05).
///
/// The list-side sibling of `DownloadInspectorPauseFailureTests`, case for case. The list offers
/// Pause/Resume from a swipe action and a context menu, both gated by the rendered snapshot's
/// `canTogglePause`, so the boundary refuses exactly as it does in the inspector: `.notFound` when
/// the record is gone, `.unknown` when the status left the toggleable set between the render and
/// the tap. Pre-fix both arms returned `.none` with nowhere to put the answer — the reducer owned
/// no toast surface at all — so a refused toggle moved nothing and said nothing.
///
/// **The list reports without reloading, and that is the one difference from the inspector.** The
/// inspector's `inspection` is a separate load it must resettle, so it reports AND reloads. Here the
/// rows come straight from the live `observeDownloads` stream, so both refusal arms are already
/// reflected in what is on screen — `.notFound` means the row is gone or going, `.unknown` means the
/// newer status is already delivered or arriving. The accepted-toggle case below pins that from the
/// other side under full exhaustivity.
///
/// `@MainActor` here is compiler-required, not stylistic: every case below builds a TCA `TestStore`,
/// whose `init` and `state` accessor are main-actor-isolated. It is applied per member rather than
/// to the suite so the type's `DownloadFeatureTestCase` conformance stays nonisolated — a
/// main-actor conformance cannot be used from the `@Sendable` dependency closures these stores
/// install.
struct DownloadsPauseFailureTests: DownloadFeatureTestCase {
    /// The gallery was deleted underneath the row, and the user is owed that word.
    @MainActor
    @Test
    func testDownloadsListReportsAPauseRefusedBecauseTheGalleryVanished() async {
        let store = makePauseTestStore(
            download: sampleDownload(
                gid: "113250", title: "Vanished List Pause Gallery",
                status: .downloading, completedPageCount: 1
            )
        )

        await store.send(.toggleDownloadPauseDone(.failure(.notFound))) {
            $0.toast = .error(caption: AppError.notFound.alertText)
        }
    }

    /// The status moved out of the toggleable set between the render and the tap.
    @MainActor
    @Test
    func testDownloadsListReportsAPauseRefusedBecauseTheStatusMovedOn() async {
        let store = makePauseTestStore(
            download: sampleDownload(
                gid: "113251", title: "Moved On List Pause Gallery",
                status: .downloading, completedPageCount: 1
            )
        )

        await store.send(.toggleDownloadPauseDone(.failure(.unknown))) {
            $0.toast = .error(caption: AppError.unknown.alertText)
        }
    }

    /// The mapping's payload arm, pinned through THIS branch too.
    ///
    /// `.fileOperationFailed` is not a kind `togglePause` answers — its only exits are `.notFound`
    /// and `.unknown`. The case is here because the list now shares the module's one
    /// `actionFailureToast` mapping with the inspector's two branches, and that mapping has two
    /// arms: a payload-only rendering for `.fileOperationFailed` (whose payload already names which
    /// refusal happened, and which `alertText` would bury under its own generic "local file
    /// operation failed" line) and an `alertText` fallback for everything else. A third consumer is
    /// a third chance to drop an arm in a rename, so both are asserted from the list side too.
    @MainActor
    @Test
    func testDownloadsListRendersAPauseFailurePayloadWithoutTheGenericPrefix() async {
        let refusalMessage = "The download folder for this gallery is no longer readable."
        let store = makePauseTestStore(
            download: sampleDownload(
                gid: "113252", title: "Payload List Pause Gallery",
                status: .downloading, completedPageCount: 1
            )
        )

        await store.send(.toggleDownloadPauseDone(.failure(.fileOperationFailed(refusalMessage)))) {
            $0.toast = .error(caption: refusalMessage)
        }
        // Keeps the case from being vacuous: the two arms really do render differently, so the
        // assertion above would fail if the payload arm were dropped in favour of the fallback.
        #expect(AppError.fileOperationFailed(refusalMessage).alertText != refusalMessage)
    }

    /// The whole tap path, not just the action: the effect's catch arm has to carry the kind.
    ///
    /// The cases above drive `toggleDownloadPauseDone` directly, which would still pass if the
    /// effect swallowed the client's error or flattened every refusal into one kind. Here the
    /// dependency throws the boundary's own `.unknown` and the assertion reads the message the user
    /// would see, so the client seam — `AppError(error)` inside the `catch:` of the
    /// `toggleDownloadPause` effect — is covered end to end from the list.
    @MainActor
    @Test
    func testDownloadsListReportsARefusalRaisedOnTheTapPath() async {
        let download = sampleDownload(
            gid: "113253", title: "Tap Path List Pause Gallery",
            status: .downloading, completedPageCount: 1
        )
        let store = makePauseTestStore(
            download: download,
            togglePause: { _ in throw AppError.unknown }
        )

        await store.send(.toggleDownloadPause(download.gid))
        await store.receive(\.toggleDownloadPauseDone) {
            $0.toast = .error(caption: AppError.unknown.alertText)
        }
    }

    /// The boundary from the other side: an accepted toggle is not an occasion for a toast.
    ///
    /// FULL exhaustivity on purpose. With it, this case pins BOTH halves of the accepted arm's
    /// disposition: no toast, and no reload either — an added `.send(.fetchDownloads)` would fail
    /// the case as an unreceived action. A success toast on a tap whose only effect is that the
    /// queue accepted the change would be noise the user has to dismiss, and the row's new status
    /// arrives through `observeDownloads` regardless.
    @MainActor
    @Test
    func testDownloadsListSetsNoToastWhenAPauseRequestIsAccepted() async {
        let store = makePauseTestStore(
            download: sampleDownload(
                gid: "113254", title: "Accepted List Pause Gallery",
                status: .downloading, completedPageCount: 1
            )
        )

        await store.send(.toggleDownloadPauseDone(.success(())))
        #expect(store.state.toast == nil)
    }
}

// MARK: - Fixture Helpers

private extension DownloadsPauseFailureTests {
    @MainActor
    func makePauseTestStore(
        download: DownloadedGallery,
        togglePause: @escaping @Sendable (String) async throws -> Void = { _ in }
    ) -> TestStoreOf<DownloadsReducer> {
        var initialState = DownloadsReducer.State()
        initialState.loadingState = .idle
        initialState.downloads = [download]

        return TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in continuation.finish() }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = togglePause
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.retryPages = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
            }
        )
    }
}
