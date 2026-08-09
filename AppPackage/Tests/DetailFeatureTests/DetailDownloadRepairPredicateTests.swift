import AppModels
@testable import DetailFeature
import Foundation
import Testing

/// D-G5D-01: which of Detail's two error-button destinations a record earns.
///
/// `DetailView` sends `.retryDownloadButtonTapped(store.downloadNeedsRepair ? .repair : .redownload)`,
/// so this one predicate decides between resuming in place and deleting the working folder to fetch
/// every page again. The boundary it must draw is the record's own HONESTY: a record that says it is
/// incomplete beside a file-shaped failure has landed pages worth keeping, and a presence-based
/// repair is exactly the medicine for it; a record that still claims every page has either claims
/// nothing can verify (the refusal family) or files that exist and are wrong (corrupt-in-place), and
/// a repair that only fetches absent pages fixes neither of those.
///
/// The suite is a truth table rather than a pair of happy cases because the predicate is a
/// conjunction of three independent facts, and the two rows that matter most sit on either side of
/// one of them: 26-of-36 must offer the repair, 36-of-36 must not. A test of only the extremes would
/// pass against the predicate this plan replaces, whose completed-count conjunct was `== 0` — a
/// condition that held only AFTER a repair run's blanking loop had already emptied the record, never
/// at the moment a user faced the button.
@Suite
struct DetailDownloadRepairPredicateTests {
    /// The old predicate's only true row, kept: a zero-completed record satisfies the widened
    /// conjunct trivially, so the swept case is a strict superset rather than a replacement.
    @Test
    func testAZeroCompletedFileFailureOffersTheRepair() {
        let state = makeState(
            status: .error,
            completedPageCount: 0,
            failureCode: .fileOperationFailed
        )

        #expect(state.downloadNeedsRepair)
    }

    /// The swept row, and the defect's whole substance: a mid-run file failure that left 26 pages on
    /// disk used to route to the destructive redownload as its ONLY option.
    @Test
    func testAPartiallyCompletedFileFailureOffersTheRepair() {
        let state = makeState(
            status: .error,
            completedPageCount: 26,
            failureCode: .fileOperationFailed
        )

        #expect(state.downloadNeedsRepair)
    }

    /// D-G5D-01's boundary, pinned rather than blurred: a complete-claiming record keeps the
    /// destructive offer, because a presence-based repair would find nothing absent to fetch and
    /// would leave a wholesale-unverifiable or corrupt-in-place gallery exactly as it was. The
    /// surgical alternative for that shape is the inspector's D-G5C-01 retry, not this button.
    @Test
    func testACompleteClaimingFileFailureKeepsTheDestructiveRedownload() {
        let state = makeState(
            status: .error,
            completedPageCount: 36,
            failureCode: .fileOperationFailed
        )

        #expect(state.downloadNeedsRepair == false)
    }

    /// Incompleteness alone does not earn the repair. A networking-shaped failure says nothing about
    /// the files on disk, so the failure code stays a required conjunct.
    @Test
    func testAnIncompleteRecordUnderANonFileFailureKeepsTheDestructiveRedownload() {
        let state = makeState(
            status: .error,
            completedPageCount: 26,
            failureCode: .networkingFailed
        )

        #expect(state.downloadNeedsRepair == false)
    }

    /// The status guard: a record that is not erroring is not choosing between these two
    /// destinations at all, whatever its counts and its last recorded failure say.
    @Test
    func testANonErrorRecordNeverOffersTheRepair() {
        let state = makeState(
            status: .inactive,
            completedPageCount: 26,
            failureCode: .fileOperationFailed
        )

        #expect(state.downloadNeedsRepair == false)
    }
}

// MARK: - Setup Helpers

private extension DetailDownloadRepairPredicateTests {
    /// A Detail state carrying only the three facts the predicate reads.
    ///
    /// Built directly rather than driven through a store: `downloadNeedsRepair` is a pure function
    /// of `downloadBadge` and `downloadFailureCode`, so a round trip would only add ways for the
    /// staging to disagree with the thing under test.
    func makeState(
        status: DownloadDisplayStatus,
        completedPageCount: Int,
        pageCount: Int = 36,
        failureCode: DownloadFailureCode?
    ) -> DetailReducer.State {
        var state = DetailReducer.State(
            gallery: Gallery(
                gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                category: .doujinshi, pageCount: pageCount,
                postedDate: .init(timeIntervalSince1970: 0),
                coverURL: nil, galleryURL: URL(string: "https://example.com/g/42/abc123/")
            )
        )
        state.downloadBadge = DownloadBadge(
            status: status,
            progress: DownloadProgress(
                completedPageCount: completedPageCount,
                pageCount: pageCount
            )
        )
        state.downloadFailureCode = failureCode
        return state
    }
}
