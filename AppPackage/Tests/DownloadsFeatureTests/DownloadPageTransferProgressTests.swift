import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Synchronization
import Testing

/// Sub-page credit for transfers still in flight (G-15-2D): what it counts, when it may move, and
/// how it hands over to whole-page credit.
///
/// **The `now` seam is frozen throughout.** The push throttle compares against it, so a real clock
/// would make "no push inside one second" a measurement of machine load rather than of the rule.
/// Every case that needs time to pass moves the frozen date explicitly.
@Suite
struct DownloadPageTransferProgressTests: DownloadFeatureTestCase {
    private static let pageCount = 6
    private static let completedPageCount = 2

    @Test
    func inFlightBytesRideBesideTheWholePagePairAndAreThrottledToOnePushPerSecond() async throws {
        let gallery = Self.makeGallery(gid: "240010")
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeFrozenFixture(gallery: gallery, client: spy.client)
        defer { removeTemporaryItem(at: fixture.context.rootURL) }

        await fixture.context.manager.testingEnsureContinuedSession()
        await fixture.context.manager.testingBeginPageTransfer(gid: gallery.gid, pageIndex: 3)

        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 3,
            bytesWritten: 500,
            bytesExpected: 1000
        )
        let firstPush = try #require(spy.progressUpdates.last)
        #expect(firstPush.inFlightSubunitCount == 500)
        // The pushed pair is still whole pages, which is the whole point of PD-1: the sub-page term
        // travels beside it and is folded by the client.
        #expect(firstPush.completedUnitCount == Int64(Self.completedPageCount))
        #expect(firstPush.totalUnitCount == Int64(Self.pageCount))

        // Inside the throttle window: the credit moves, the card does not.
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 3,
            bytesWritten: 750,
            bytesExpected: 1000
        )
        #expect(spy.progressUpdates.count == 1)
        #expect(await fixture.context.manager.testingInFlightSubunitCount(gid: gallery.gid) == 750)

        fixture.advance(by: 1)
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 3,
            bytesWritten: 750,
            bytesExpected: 1000
        )
        #expect(spy.progressUpdates.count == 2)
        #expect(spy.progressUpdates.last?.inFlightSubunitCount == 750)

        _ = await fixture.context.manager.pause(gid: gallery.gid)
    }

    /// A retry restarts the byte count at zero, and the page's credit does not follow it down: the
    /// page is the unit the card reports on, and a retry is that page continuing.
    @Test
    func perPageCreditIsMonotoneAcrossARetryAndIgnoresAnUnknownSize() async throws {
        let gallery = Self.makeGallery(gid: "240020")
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeFrozenFixture(gallery: gallery, client: spy.client)
        defer { removeTemporaryItem(at: fixture.context.rootURL) }

        await fixture.context.manager.testingEnsureContinuedSession()
        await fixture.context.manager.testingBeginPageTransfer(gid: gallery.gid, pageIndex: 3)
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 3,
            bytesWritten: 750,
            bytesExpected: 1000
        )

        // The retry re-opens the attempt and reports from the start again.
        await fixture.context.manager.testingBeginPageTransfer(gid: gallery.gid, pageIndex: 3)
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 3,
            bytesWritten: 200,
            bytesExpected: 1000
        )
        #expect(await fixture.context.manager.testingInFlightSubunitCount(gid: gallery.gid) == 750)

        // An unknown expected size credits nothing: there is no fraction to compute from it.
        await fixture.context.manager.testingBeginPageTransfer(gid: gallery.gid, pageIndex: 4)
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 4,
            bytesWritten: 900,
            bytesExpected: -1
        )
        #expect(await fixture.context.manager.testingInFlightSubunitCount(gid: gallery.gid) == 750)

        // A second page with a known size sums with the first.
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 4,
            bytesWritten: 100,
            bytesExpected: 1000
        )
        #expect(await fixture.context.manager.testingInFlightSubunitCount(gid: gallery.gid) == 850)

        _ = await fixture.context.manager.pause(gid: gallery.gid)
    }

    /// The trade: the flush that RECORDS a page removes its in-flight entry in the same synchronous
    /// stretch, so whole-page credit rises by exactly what sub-page credit gives up and no push can
    /// observe a value between the two.
    @Test
    func theFlushTradesSubPageCreditForWholePageCreditAtomically() async throws {
        let gallery = Self.makeGallery(gid: "240030")
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeFrozenFixture(gallery: gallery, client: spy.client)
        defer { removeTemporaryItem(at: fixture.context.rootURL) }

        await fixture.context.manager.testingEnsureContinuedSession()
        await fixture.context.manager.testingBeginPageTransfer(gid: gallery.gid, pageIndex: 3)
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 3,
            bytesWritten: 900,
            bytesExpected: 1000
        )
        #expect(spy.progressUpdates.last?.inFlightSubunitCount == 900)

        let relativePath = try writeStagedPageFile(gallery: gallery, in: fixture.context, index: 3)
        try await fixture.context.manager.flushManifestPageProgress(
            folderURL: galleryFolderURL(for: gallery, in: fixture.context),
            pages: [.init(index: 3, relativePath: relativePath, imageURL: nil)]
        )
        #expect(await fixture.context.manager.testingInFlightSubunitCount(gid: gallery.gid) == 0)

        let sessionID = try #require(await fixture.context.manager.testingContinuedSessionID())
        await fixture.context.manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let afterFlush = try #require(spy.progressUpdates.last)
        #expect(afterFlush.completedUnitCount == Int64(Self.completedPageCount + 1))
        #expect(afterFlush.inFlightSubunitCount == 0)

        _ = await fixture.context.manager.pause(gid: gallery.gid)
    }

    /// The one deliberate downward mover: a page that will not land in this run gives its sub-page
    /// credit back. The whole-page numerator is untouched, so the drop is smaller than one page.
    @Test
    func aFailedPageWithdrawsOnlyItsSubPageCredit() async throws {
        let gallery = Self.makeGallery(gid: "240040")
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeFrozenFixture(gallery: gallery, client: spy.client)
        defer { removeTemporaryItem(at: fixture.context.rootURL) }

        await fixture.context.manager.testingEnsureContinuedSession()
        await fixture.context.manager.testingBeginPageTransfer(gid: gallery.gid, pageIndex: 3)
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 3,
            bytesWritten: 600,
            bytesExpected: 1000
        )
        #expect(spy.progressUpdates.last?.inFlightSubunitCount == 600)

        await fixture.context.manager.testingWithdrawInFlightPageCredit(gid: gallery.gid, pageIndex: 3)
        #expect(await fixture.context.manager.testingInFlightSubunitCount(gid: gallery.gid) == 0)

        let sessionID = try #require(await fixture.context.manager.testingContinuedSessionID())
        await fixture.context.manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let afterWithdrawal = try #require(spy.progressUpdates.last)
        #expect(afterWithdrawal.inFlightSubunitCount == 0)
        #expect(afterWithdrawal.completedUnitCount == Int64(Self.completedPageCount))

        _ = await fixture.context.manager.pause(gid: gallery.gid)
    }

    /// The sum is taken over the galleries the pushed pair was computed from, so credit for a
    /// gallery outside that snapshot cannot reach the card whose denominator excludes it.
    @Test
    func creditForAGalleryOutsideTheSnapshotIsNotPushed() async throws {
        let gallery = Self.makeGallery(gid: "240050")
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeFrozenFixture(gallery: gallery, client: spy.client)
        defer { removeTemporaryItem(at: fixture.context.rootURL) }

        await fixture.context.manager.testingEnsureContinuedSession()
        // A gallery this coordinator holds no record of, and which no snapshot can contain.
        await fixture.context.manager.testingBeginPageTransfer(gid: "999999", pageIndex: 1)
        await fixture.context.manager.testingRecordPageTransferBytes(
            gid: "999999",
            pageIndex: 1,
            bytesWritten: 800,
            bytesExpected: 1000
        )
        #expect(await fixture.context.manager.testingInFlightSubunitCount(gid: "999999") == 800)

        let sessionID = try #require(await fixture.context.manager.testingContinuedSessionID())
        await fixture.context.manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let pushed = try #require(spy.progressUpdates.last)
        #expect(pushed.inFlightSubunitCount == 0)

        _ = await fixture.context.manager.pause(gid: gallery.gid)
    }

    /// BINDING (G-15-2I, owner decision 2026-08-19): an attempt that has produced no bytes for
    /// `pageTransferAbandonThreshold` is abandoned by the sweep and surfaces out of the REAL
    /// transfer path as the retryable `.networkingFailed`, so the page rides its existing retry
    /// path instead of holding the worker.
    ///
    /// The sweep one second short of the threshold is the boundary's other side: without it the
    /// case would pass against any threshold at or below sixty seconds.
    @Test
    func aTransferWithoutBytesIsAbandonedAtTheThresholdAsARetryableNetworkingFailure() async throws {
        let gallery = Self.makeGallery(gid: "240060")
        let fixture = try await makeFrozenFixture(
            gallery: gallery,
            client: BackgroundProcessingClientSpy().client,
            pageDownloader: Self.hangingPageDownloader
        )
        defer { removeTemporaryItem(at: fixture.context.rootURL) }
        let manager = fixture.context.manager
        let attempt = try await startTransfer(gid: gallery.gid, pageIndex: 3, on: manager)

        fixture.advance(by: DownloadCoordinator.pageTransferAbandonThreshold - 1)
        await manager.testingSweepStarvedPageTransfers()
        #expect(await manager.testingIsPageTransferring(gid: gallery.gid, pageIndex: 3))

        fixture.advance(by: 1)
        await manager.testingSweepStarvedPageTransfers()

        let error = try #require(await transferError(of: attempt) as? AppError)
        #expect(error == .networkingFailed)
        #expect(error.isRetryable)
    }

    /// The discriminating control: idle time is measured from the LAST BYTE, never from the
    /// attempt's start once a byte has arrived, so a transfer that is slow but MOVING is never
    /// abandoned however long it has been running.
    ///
    /// The sweep at seventy seconds is the case's whole point — seventy seconds since the attempt
    /// started, twenty since its last byte — and a rule measuring from the start would abandon it
    /// there.
    @Test
    func aSlowButMovingTransferIsNeverAbandonedUntilItsOwnBytesStop() async throws {
        let gallery = Self.makeGallery(gid: "240070")
        let fixture = try await makeFrozenFixture(
            gallery: gallery,
            client: BackgroundProcessingClientSpy().client,
            pageDownloader: Self.hangingPageDownloader
        )
        defer { removeTemporaryItem(at: fixture.context.rootURL) }
        let manager = fixture.context.manager
        let attempt = try await startTransfer(gid: gallery.gid, pageIndex: 2, on: manager)

        fixture.advance(by: 50)
        await manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 2,
            bytesWritten: 100,
            bytesExpected: 1000
        )
        fixture.advance(by: 20)
        await manager.testingSweepStarvedPageTransfers()
        #expect(await manager.testingIsPageTransferring(gid: gallery.gid, pageIndex: 2))

        fixture.advance(by: 30)
        await manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 2,
            bytesWritten: 300,
            bytesExpected: 1000
        )
        fixture.advance(by: 10)
        await manager.testingSweepStarvedPageTransfers()
        #expect(await manager.testingIsPageTransferring(gid: gallery.gid, pageIndex: 2))

        // Sixty-one seconds since the last byte, and only now.
        fixture.advance(by: 51)
        await manager.testingSweepStarvedPageTransfers()

        let error = try #require(await transferError(of: attempt) as? AppError)
        #expect(error == .networkingFailed)
    }

    /// Every attempt measures its own idle time from its own start, because `beginPageTransfer`
    /// resets the attempt-scoped fields — while the page's earned credit deliberately survives the
    /// re-open, which is what makes a retry the same page continuing.
    @Test
    func eachAttemptMeasuresItsOwnIdleTimeAndKeepsThePagesEarnedCredit() async throws {
        let gallery = Self.makeGallery(gid: "240080")
        let fixture = try await makeFrozenFixture(
            gallery: gallery,
            client: BackgroundProcessingClientSpy().client,
            pageDownloader: Self.hangingPageDownloader
        )
        defer { removeTemporaryItem(at: fixture.context.rootURL) }
        let manager = fixture.context.manager
        let first = try await startTransfer(gid: gallery.gid, pageIndex: 1, on: manager)

        await manager.testingRecordPageTransferBytes(
            gid: gallery.gid,
            pageIndex: 1,
            bytesWritten: 250,
            bytesExpected: 1000
        )
        fixture.advance(by: DownloadCoordinator.pageTransferAbandonThreshold)
        await manager.testingSweepStarvedPageTransfers()
        #expect(try #require(await transferError(of: first) as? AppError) == .networkingFailed)

        // The retry re-opens the entry: a fresh attempt, the same page's credit.
        let second = try await startTransfer(gid: gallery.gid, pageIndex: 1, on: manager)
        #expect(await manager.testingInFlightSubunitCount(gid: gallery.gid) == 250)

        fixture.advance(by: 10)
        await manager.testingSweepStarvedPageTransfers()
        #expect(await manager.testingIsPageTransferring(gid: gallery.gid, pageIndex: 1))

        fixture.advance(by: 51)
        await manager.testingSweepStarvedPageTransfers()
        #expect(try #require(await transferError(of: second) as? AppError) == .networkingFailed)
        #expect(await manager.testingInFlightSubunitCount(gid: gallery.gid) == 250)
    }

    /// A caller's cancellation — a pause, the expiry's sweep, a group cancel — still surfaces as
    /// `CancellationError`. Abandonment is the ONLY path that converts a cancelled attempt into a
    /// retryable failure, and no sweep is involved here at all.
    @Test
    func aCallerCancelledTransferStillSurfacesAsCancellation() async throws {
        let gallery = Self.makeGallery(gid: "240090")
        let fixture = try await makeFrozenFixture(
            gallery: gallery,
            client: BackgroundProcessingClientSpy().client,
            pageDownloader: Self.hangingPageDownloader
        )
        defer { removeTemporaryItem(at: fixture.context.rootURL) }
        let manager = fixture.context.manager
        let attempt = try await startTransfer(gid: gallery.gid, pageIndex: 4, on: manager)

        attempt.cancel()

        let error = await transferError(of: attempt)
        #expect(error is CancellationError)
        #expect(!(error is AppError))
    }

    /// Below the abandon threshold the sweep still only REPORTS: the ten-second rule stays a log
    /// rule, and the transfer it names is left running.
    @Test
    func theSweepBelowTheAbandonThresholdLeavesTheTransferRunning() async throws {
        let gallery = Self.makeGallery(gid: "240100")
        let fixture = try await makeFrozenFixture(
            gallery: gallery,
            client: BackgroundProcessingClientSpy().client,
            pageDownloader: Self.hangingPageDownloader
        )
        defer { removeTemporaryItem(at: fixture.context.rootURL) }
        let manager = fixture.context.manager
        let attempt = try await startTransfer(gid: gallery.gid, pageIndex: 5, on: manager)

        fixture.advance(by: 15)
        await manager.testingSweepStarvedPageTransfers()

        #expect(await manager.testingIsPageTransferring(gid: gallery.gid, pageIndex: 5))
        #expect(!attempt.isCancelled)

        attempt.cancel()
        _ = await transferError(of: attempt)
    }
}

// MARK: - Fixture

/// A movable stand-in for the wall clock the flush and push throttles read.
///
/// A final class rather than a value, because `Mutex` is non-copyable and the coordinator's `now`
/// closure and the case both have to see the same date.
private final class FrozenDate: Sendable {
    private let value: Mutex<Date>

    init(_ date: Date) {
        value = Mutex(date)
    }

    var current: Date {
        value.withLock({ $0 })
    }

    func advance(by seconds: TimeInterval) {
        value.withLock({ $0 = $0.addingTimeInterval(seconds) })
    }
}

/// A queued-gallery fixture whose `now` is frozen and movable by the case.
private struct FrozenFixture {
    let context: SessionFixture
    private let currentDate: FrozenDate

    init(context: SessionFixture, currentDate: FrozenDate) {
        self.context = context
        self.currentDate = currentDate
    }

    func advance(by seconds: TimeInterval) {
        currentDate.advance(by: seconds)
    }
}

private extension DownloadPageTransferProgressTests {
    /// A downloader that never answers.
    ///
    /// The sleep is what a starved transfer IS from the coordinator's side — a request that has
    /// produced nothing — and it throws `CancellationError` the moment the attempt is cancelled,
    /// which is the very signal the abandon path has to classify. The thirty-second bound is the
    /// safety net: a case that fails to abandon fails rather than hangs.
    static var hangingPageDownloader: DownloadPageDownloader {
        DownloadPageDownloader { _, _, _ in
            try await Task.sleep(for: .seconds(30))
            throw AppError.unknown
        }
    }

    /// Starts one real transfer through `rawPageDownloadResponse` and returns only once the entry
    /// the sweep reads is actually transferring.
    ///
    /// Waiting on that seam rather than on a bare yield is what keeps the frozen clock meaningful:
    /// moving the date before the entry exists would measure an attempt that had not started.
    func startTransfer(
        gid: String,
        pageIndex: Int,
        on manager: DownloadCoordinator
    ) async throws -> Task<DownloadPageTransfer, any Error> {
        let url = try #require(URL(string: "https://example.com/\(gid)-\(pageIndex).jpg"))
        let request = URLRequest(url: url)
        let attempt = Task {
            try await manager.rawPageDownloadResponse(
                for: request,
                context: .init(gid: gid, pageIndex: pageIndex)
            )
        }
        try await waitUntil({ await manager.testingIsPageTransferring(gid: gid, pageIndex: pageIndex) })
        return attempt
    }

    /// Awaits an attempt expected to fail and hands back the error it threw, so a case can assert
    /// over the error's identity rather than only over its type.
    func transferError(of attempt: Task<DownloadPageTransfer, any Error>) async -> (any Error)? {
        do {
            _ = try await attempt.value
            return nil
        } catch {
            return error
        }
    }

    static func makeGallery(gid: String) -> SessionGallery {
        SessionGallery(
            gid: gid,
            title: "Transfer",
            pageCount: pageCount,
            completedPageCount: completedPageCount
        )
    }

    /// One queued gallery on disk, over a frozen `now` and a constant environment probe.
    ///
    /// Built here rather than through the shared queued-coordinator helper because the shared
    /// helpers file sits against its `file_length` gate; the layout is that helper's, so the folder
    /// naming stays in one shape across the target.
    func makeFrozenFixture(
        gallery: SessionGallery,
        client: BackgroundProcessingClient,
        pageDownloader: DownloadPageDownloader? = nil
    ) async throws -> FrozenFixture {
        let currentDate = FrozenDate(Date(timeIntervalSince1970: 1_700_000_000))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            pageDownloader: pageDownloader,
            backgroundProcessingClient: client,
            now: { currentDate.current },
            environmentProbe: .constant(
                DownloadEnvironmentSnapshot(
                    network: .wifi,
                    isLowPowerModeEnabled: false,
                    thermalState: .nominal
                )
            )
        )

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try storage.writeManifest(manifest(for: gallery), folderURL: folderURL)
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gallery.gid])
        return FrozenFixture(
            context: SessionFixture(manager: manager, storage: storage, rootURL: rootURL),
            currentDate: currentDate
        )
    }

    /// Writes a real page file through the production path-naming API, so the flush under test can
    /// hash it, and returns its relative path.
    func writeStagedPageFile(
        gallery: SessionGallery,
        in fixture: SessionFixture,
        index: Int
    ) throws -> String {
        let relativePath = fixture.storage.makePageRelativePath(
            gid: gallery.gid,
            token: "token",
            index: index,
            fileExtension: "jpg"
        )
        try Data("page-\(index)".utf8).write(
            to: galleryFolderURL(for: gallery, in: fixture).appendingPathComponent(relativePath),
            options: .atomic
        )
        return relativePath
    }
}
