import AnalyticsClient
import AppModels
import ComposableArchitecture
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing

/// The delete confirmation belongs to one row, and these assertions are only possible because it
/// does.
///
/// A single `@Presents` on ``DownloadsReducer`` could not be asked "is exactly one row
/// presenting?" — there would be one optional for the whole list, and the answer would be the same
/// for every row by construction. Per-row state turns that into an observable: the tapped row's
/// dialog is non-nil and every other row's is nil, checked here rather than inferred from a
/// screenshot.
///
/// The presented-and-preserved case is the one with teeth. `observeDownloads` re-emits the whole
/// snapshot on every page that lands, which is constant traffic while a download runs, and the
/// snapshot arrives as a plain array assigned to `state.downloads`. If that assignment rebuilt the
/// rows, the dialog would be torn out from under a user who is mid-decision on an active download —
/// exactly the row most likely to be receiving ticks.
struct DownloadRowConfirmationTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testTappingDeleteArmsOnlyTheTappedRow() async {
        let first = sampleDownload(gid: "111", title: "First", status: .completed)
        let second = sampleDownload(gid: "222", title: "Second", status: .completed)
        var initialState = DownloadsReducer.State()
        initialState.downloads = [first, second]

        let store = TestStore(initialState: initialState, reducer: DownloadsReducer.init) {
            $0.analyticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.rows(.element(id: first.gid, action: .deleteButtonTapped)))

        #expect(store.state.rows[id: first.gid]?.confirmationDialog != nil)
        #expect(store.state.rows[id: second.gid]?.confirmationDialog == nil)
    }

    @MainActor
    @Test
    func testConfirmingTheRowDialogDeletesThatGallery() async {
        let download = sampleDownload(gid: "333", title: "Doomed", status: .completed)
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let deleted = LockIsolated<[String]>([])
        let store = TestStore(initialState: initialState, reducer: DownloadsReducer.init) {
            $0.analyticsClient = .noop
            $0.downloadClient.delete = { gid in deleted.withValue({ $0.append(gid) }) }
        }
        store.exhaustivity = .off

        await store.send(.rows(.element(id: download.gid, action: .deleteButtonTapped)))
        await store.send(
            .rows(.element(id: download.gid, action: .confirmationDialog(.presented(.confirmDelete))))
        )
        await store.receive(\.rows)
        await store.receive(\.deleteDownload)
        await store.receive(\.deleteDownloadDone)

        #expect(deleted.value == [download.gid])
    }

    /// A snapshot tick must not dismiss a dialog the user is still looking at.
    @MainActor
    @Test
    func testAnObservationTickPreservesAPresentedDialog() async {
        let download = sampleDownload(
            gid: "444", title: "Running", status: .downloading, completedPageCount: 3
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState, reducer: DownloadsReducer.init) {
            $0.analyticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.rows(.element(id: download.gid, action: .deleteButtonTapped)))
        #expect(store.state.rows[id: download.gid]?.confirmationDialog != nil)

        // The same gallery, one page further along — the shape every observation tick arrives in,
        // and a genuinely different value so the reducer's no-change guard does not short-circuit.
        let advanced = sampleDownload(
            gid: "444", title: "Running", status: .downloading, completedPageCount: 4
        )
        await store.send(.observeDownloadsDone([advanced]))

        #expect(store.state.downloads.first?.completedPageCount == 4)

        #expect(store.state.rows[id: download.gid]?.confirmationDialog != nil)
    }

    /// A gallery that leaves the snapshot takes its row, and so its dialog, with it.
    @MainActor
    @Test
    func testARowLeavingTheSnapshotDropsItsDialog() async {
        let staying = sampleDownload(gid: "555", title: "Staying", status: .completed)
        let leaving = sampleDownload(gid: "666", title: "Leaving", status: .completed)
        var initialState = DownloadsReducer.State()
        initialState.downloads = [staying, leaving]

        let store = TestStore(initialState: initialState, reducer: DownloadsReducer.init) {
            $0.analyticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.rows(.element(id: leaving.gid, action: .deleteButtonTapped)))
        await store.send(.observeDownloadsDone([staying]))

        #expect(store.state.rows[id: leaving.gid] == nil)
        #expect(store.state.downloads.map(\.gid) == [staying.gid])
    }
}
