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
///
/// **The last two cases are what the amended placement rule asks for (DEF-15-11).** That rule keeps
/// the dialog on the row — the correct anchor for a per-row destructive action — and judges
/// stability against changes UNRELATED to the dialog's own action: a row removed by its own
/// confirmed deletion is the intended terminal state, not instability, which is why the confirm
/// case above is not an instance of the hazard. The hazard is a snapshot moving the row for a reason
/// the dialog knows nothing about, and it has exactly two shapes. A tick that REORDERS keeps the
/// armed row's dialog on that row (identity is the gid, not the position) and its confirmed action
/// still deletes that gid — it neither strands the dialog nor misdirects it at whichever row slid
/// into the old slot. A tick that DROPS the row takes the dialog with it, structurally, because the
/// rows ARE the storage; what has to be pinned there is the other half — that no deletion fires, and
/// that a record returning in a later tick comes back DISARMED, so the user confirms again rather
/// than inheriting a decision they made about a row that had gone.
///
/// Filter and gate flips were examined as a third shape and are deliberately NOT pinned. Narrowing
/// `keyword` or `folderFilter` while a row dialog is up is unreachable: the iPhone presentation is
/// modal, and the iPad popover dismisses (sending `.dismiss`) before a filter control can be
/// touched. The one programmatic filter write — `fetchFoldersDone` resetting a vanished folder to
/// `.all` — WIDENS the visible set, so it cannot remove a row either. A speculative case there would
/// pin a path no user can take.
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

    /// A gallery that leaves the snapshot takes its row, and so its dialog, with it — and fires no
    /// deletion on the way out.
    ///
    /// The removal is structural: the rows are the storage, so a dialog cannot be left behind
    /// pointing at a record that is gone. What needs saying is what does NOT happen. Full
    /// exhaustivity from the removal onwards is the proof — no `.deleteDownload` was sent, and the
    /// recorder confirms the client was never called — because the user's confirmation never
    /// happened; the snapshot moved, not their finger.
    ///
    /// The returning tick is the other half. A record that comes back (a failed delete elsewhere, a
    /// refresh that re-reads the folder) arrives DISARMED: the decision the user was mid-way through
    /// belonged to a row that had left, and inheriting it would fire a deletion behind a dialog
    /// nobody is looking at any more.
    @MainActor
    @Test
    func testARowLeavingTheSnapshotDropsItsDialogAndFiresNoDeletion() async {
        let staying = sampleDownload(gid: "555", title: "Staying", status: .completed)
        let leaving = sampleDownload(gid: "666", title: "Leaving", status: .completed)
        var initialState = DownloadsReducer.State()
        initialState.loadingState = .idle
        initialState.downloads = [staying, leaving]

        let deleted = LockIsolated<[String]>([])
        let store = TestStore(initialState: initialState, reducer: DownloadsReducer.init) {
            $0.analyticsClient = .noop
            $0.downloadClient.delete = { gid in deleted.withValue({ $0.append(gid) }) }
        }
        // Off for the arming send alone; everything the hazard is about is asserted exhaustively.
        store.exhaustivity = .off
        await store.send(.rows(.element(id: leaving.gid, action: .deleteButtonTapped)))
        #expect(store.state.rows[id: leaving.gid]?.confirmationDialog != nil)
        store.exhaustivity = .on

        await store.send(.observeDownloadsDone([staying])) {
            $0.rows.remove(id: leaving.gid)
        }

        #expect(store.state.downloads.map(\.gid) == [staying.gid])

        await store.send(.observeDownloadsDone([staying, leaving])) {
            $0.rows.append(.init(download: leaving))
        }

        #expect(store.state.rows[id: leaving.gid]?.confirmationDialog == nil)
        await store.finish()
        #expect(deleted.value.isEmpty)
    }

    /// A reordering tick keeps the armed row's dialog on THAT row, and its action still finds it.
    ///
    /// The index publishes by modification date, so any download that finishes a page can reorder
    /// the list under a presented dialog. Identity is the gid rather than the position, so the
    /// dialog must travel with its record — and the confirmed action must still delete that record
    /// rather than whichever row slid into the slot the user was pointing at.
    @MainActor
    @Test
    func testAReorderingSnapshotKeepsTheArmedRowsDialogAndItsAction() async {
        let first = sampleDownload(gid: "777", title: "First", status: .completed)
        let second = sampleDownload(gid: "888", title: "Second", status: .completed)
        var initialState = DownloadsReducer.State()
        initialState.loadingState = .idle
        initialState.downloads = [first, second]

        let deleted = LockIsolated<[String]>([])
        let store = TestStore(initialState: initialState, reducer: DownloadsReducer.init) {
            $0.analyticsClient = .noop
            $0.downloadClient.delete = { gid in deleted.withValue({ $0.append(gid) }) }
        }
        store.exhaustivity = .off

        await store.send(.rows(.element(id: second.gid, action: .deleteButtonTapped)))
        await store.send(.observeDownloadsDone([second, first]))

        #expect(Array(store.state.rows.ids) == [second.gid, first.gid])
        #expect(store.state.rows[id: second.gid]?.confirmationDialog != nil)
        #expect(store.state.rows[id: first.gid]?.confirmationDialog == nil)

        await store.send(
            .rows(.element(id: second.gid, action: .confirmationDialog(.presented(.confirmDelete))))
        )
        await store.receive(\.rows)
        await store.receive(\.deleteDownload)
        await store.receive(\.deleteDownloadDone)

        #expect(deleted.value == [second.gid])
    }
}
