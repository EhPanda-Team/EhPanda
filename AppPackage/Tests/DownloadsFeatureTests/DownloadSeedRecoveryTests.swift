import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Synchronization
import Testing

/// WR-03: what the REPAIR-SEED route owes after it has destroyed a page file — the same debt the
/// validate route has paid since CR-02, on the copy that inherited the ordering without the
/// compensation.
///
/// `prepareWorkingSeed`'s authorized removal mirrors `reconcileValidatedRecordAgainstPageFiles`'
/// classify → guard → remove → rescan → blank ordering, and that ordering is deliberate: reversing
/// it would leave a failed removal as a blank hash beside a surviving file, which is the D-SSOT-04
/// laundering shape. Its price is a window. Three exits fire AFTER the removal — a rescan that could
/// not enumerate, the post-removal loop's own refusal lines, and a thrown manifest write — and each
/// leaves the record claiming pages this pass deleted.
///
/// Two of those exits are staged here, both through the production preparation, and each pins a
/// different consequence of the same window:
///
/// - **Exit 3, the thrown write** (`testAThrownSeedManifestWriteRecoversTheRecordBeforeFailing`):
///   the run has to fail, but it must not settle a LYING record. The compensation is what separates
///   "this run could not finish" from "the app deleted files and went on claiming them".
/// - **Exit 1, the failed rescan** (`testASeedRescanFailureCannotAnnounceMoreThanTheHonestBasis`):
///   the record legitimately stands — a failed listing is a non-answer — but the ANNOUNCED basis may
///   not presume a page whose file this very pass removed. Its healthy-rescan twin
///   (`testAHealthySeedRescanAnnouncesTheSameHonestBasis`) pins the other side of that
///   discontinuity, so the fix is read from both regimes rather than from the failing one alone.
///
/// **Every observable is production-issued.** The seed preparation is driven through
/// `testingPrepareWorkingSeedAnnouncingProgress`, which forwards to the very function
/// `performDownload` calls; the session is started through `testingEnsureContinuedSession`; and the
/// pushed frames are the ones the preparation's own announcement issues. No case pushes, scans or
/// removes anything of its own — the fixtures stage record and disk state and then stand back.
///
/// The suite owns its two doubles rather than growing `DownloadFeatureTestHelpers.swift`, which sits
/// at 992 of its 1000-line ceiling. Both are count-gated and single-purpose, and both name in their
/// own docs the exact production call they key on and the invocation index they act at.
struct DownloadSeedRecoveryTests: DownloadFeatureTestCase {
    /// Exit 3 on the seed route: the blanking loop's manifest write throws with the refuted file
    /// already destroyed, and the record must not be left claiming it.
    ///
    /// The staging is the validate route's own (`testAnUnwritableManifestKeepsTheEntryAndTheNext
    /// ValidateConvergesTheRecord`): the store's `writeJSON` bottoms out in
    /// `Data.write(to:options:.atomic)`, which takes no injected collaborator, so the faithful way
    /// to make a manifest write throw is an immutable `manifest.json` inside a still-writable
    /// folder — the `rename` the atomic write performs fails with `EPERM` while the refuted page
    /// file is removed normally.
    ///
    /// The failure is staged TRANSIENT, which is the case the recover-once path exists for and the
    /// only staging that discriminates. A permanently unwritable manifest leaves record and disk
    /// diverged whether or not the compensation runs, and the "next converging pass" heals it in
    /// both regimes — the removed page is positively absent, so an ordinary later pass blanks it
    /// with nothing special-cased. So the double lifts the immutable flag at the recovery's OWN
    /// fresh scan, modelling a folder that was busy for an instant, and the difference between the
    /// regimes becomes the thing that is asserted: pre-fix nothing retries, the flag is never
    /// lifted, and the record goes on claiming a page whose file this preparation deleted.
    ///
    /// The `#expect(throws:)` is the staging premise as well as the exit's disposition. If an atomic
    /// write over an immutable target did not throw on this filesystem, the preparation would return
    /// normally and this case would fail here rather than somewhere confusing.
    @Test
    func testAThrownSeedManifestWriteRecoversTheRecordBeforeFailing() async throws {
        let gallery = SessionGallery(
            gid: "215620",
            title: "SeedWriteFailure",
            pageCount: 2,
            completedPageCount: 2
        )
        let control = SeedManifestWriteRecoveryControl()
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            fileManager: SeedManifestWriteRecoveryFileManager(
                // Derived through the production naming API rather than spelled out, so a naming
                // change moves the injection with the file it is about.
                removedPathFragment: DownloadStore().makePageRelativePath(
                    gid: gallery.gid,
                    token: "token",
                    index: 2,
                    fileExtension: "jpg"
                ),
                listedPathFragment: "[\(gallery.gid)_token]",
                control: control
            )
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        // Written through the production namer and then TRUNCATED, so the listing really yields the
        // entry and only the size question refutes it. A file never written would stage the ABSENCE
        // family, which nothing on this route removes.
        try writePageFiles(for: gallery, in: fixture, indices: [1, 2])
        let pageTwoURL = pageFileURL(for: gallery, in: fixture, index: 2)
        try Data().write(to: pageTwoURL, options: .atomic)
        await fixture.manager.reloadDownloadIndex()

        let staged = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(staged.completedPageCount == 2)
        let manifestURL = staged.manifestURL
        try setImmutableFlag(true, at: manifestURL)
        defer {
            // Declared after the tree removal so it runs BEFORE it: a leftover immutable flag would
            // defeat the temporary tree's own removal and leak the fixture.
            clearImmutableFlag(at: manifestURL)
        }
        control.stageTransientFailure(at: manifestURL)

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        // The comment doubles as the STAGING PREMISE: if an atomic write over an immutable target
        // did not throw on this filesystem, the preparation would return normally and nothing below
        // would be about the recovery at all.
        await #expect(
            throws: (any Error).self,
            "a thrown manifest write after an authorized removal must still fail the run"
        ) {
            _ = try await fixture.manager.testingPrepareWorkingSeedAnnouncingProgress(
                payload: makeRepairPayload(for: gallery),
                folderURL: folderURL
            )
        }

        // Anti-vacuity, in order: the authorized removal really happened, and the recovery's own
        // fresh scan really ran. Without the second, every assertion below would be about a path
        // this case never entered.
        #expect(
            FileManager.default.fileExists(atPath: pageTwoURL.path) == false,
            "the authorized removal did not destroy the refuted page file"
        )
        #expect(
            control.postRemovalListingCount >= 2,
            "the recovery's own fresh scan never ran after the thrown write"
        )
        // The precise pin is the RELEASE, not the listing tally: the transient lifts once, at the
        // second post-removal listing. The tally itself runs past two once the recovery's write
        // succeeds, because its index rebuild resolves the folder's rendering resources.
        #expect(control.releasedTransientCount == 1)

        // THE PROPERTY: record and disk agree over the pages this pass destroyed. Read from the
        // persisted manifest, which is the basis a relaunch meets, rather than from session state.
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[2] == "")
        #expect(diskManifest.pages[1]?.isEmpty == false)
        #expect(diskManifest.completedPageCount == 1)

        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.completedPageCount == 1)
        #expect(reread.displayStatus == .inactive)
    }

    /// Exit 1 on the seed route: the post-removal rescan cannot enumerate, so the loop hands the
    /// manifest back verbatim — and the ANNOUNCED basis must not therefore presume the page this
    /// preparation itself deleted.
    ///
    /// The record is INCOMPLETE on purpose (2 of 3 claimed). `inheritedPages`' complete-reading
    /// branch subtracts the run's pending pages and would mask the defect; the incomplete branch
    /// returns the presumed-done set raw, which on a failed scan is every claimed page — including
    /// the one whose file this pass just removed. That is over-reporting, the direction the
    /// announcement's own doc calls "the defect", and it reaches the system card as a stalled-looking
    /// fraction that D-11's expiration policy punishes by pausing every schedulable download.
    ///
    /// The record itself is NOT the complaint here: a failed listing is a non-answer, and non-answers
    /// leave recorded claims standing. The disposition is asserted as such below — the manifest still
    /// claims page 2 after the run, because the recovery's own scan could not answer either, and the
    /// run route is self-healing through `pendingPageIndices`, which re-fetches all three pages.
    @Test
    func testASeedRescanFailureCannotAnnounceMoreThanTheHonestBasis() async throws {
        let gallery = SessionGallery(
            gid: "215621",
            title: "SeedRescanFailure",
            pageCount: 3,
            completedPageCount: 2
        )
        let control = SeedRescanFailureControl()
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [gallery.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            fileManager: SeedRescanFailingFileManager(
                removedPathFragment: DownloadStore().makePageRelativePath(
                    gid: gallery.gid,
                    token: "token",
                    index: 2,
                    fileExtension: "jpg"
                ),
                listedPathFragment: "[\(gallery.gid)_token]",
                error: CocoaError(.fileReadNoPermission),
                control: control
            )
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        let announced = try await announcedFrameForAZeroBytePageRepair(
            gallery: gallery,
            fixture: fixture,
            spy: spy
        ) { prepared, pageTwoURL in
            #expect(
                control.consumedFailureCount >= 1,
                "the injected post-removal listing failure was never consumed"
            )
            #expect(prepared.workingSeed.scanSucceeded == false)
            #expect(FileManager.default.fileExists(atPath: pageTwoURL.path) == false)
            // Self-healing on the run route, which is what makes the standing claim survivable: the
            // seed inherits no existing page, so every page is re-fetched.
            #expect(prepared.pendingPageIndices == [1, 2, 3])
        }

        // THE PROPERTY: the honest basis is the claimed pages MINUS the pages this pass removed —
        // {1, 2} \ {2} — so the announcement may never push more than one.
        #expect(announced.completedUnitCount == 1)
        #expect(announced.totalUnitCount == 3)
        #expect(announced.subtitle == "1 / 3 pages · 1 gallery")

        // The dispositioned residual, stated rather than implied: the retry could not enumerate
        // either, so the record legitimately still claims the removed page and the divergence is
        // what the `error` log exists for.
        let diskManifest = try fixture.storage.readManifest(
            folderURL: galleryFolderURL(for: gallery, in: fixture)
        )
        #expect(diskManifest.pages[2]?.isEmpty == false)
    }

    /// The other side of the discontinuity: the identical staging with a HEALTHY post-removal
    /// rescan announces the same honest basis, and its record is corrected on disk.
    ///
    /// Pinning it is what keeps the fix a correction rather than a constant. Both regimes announce
    /// one page, but they reach it by different routes — here the loop blanks the removed page and
    /// the record itself becomes honest, while its failing twin leaves the claim standing and relies
    /// on the removal being subtracted. A case pinned to one regime alone cannot tell those apart,
    /// and this regime's reading is unchanged by the fix.
    @Test
    func testAHealthySeedRescanAnnouncesTheSameHonestBasis() async throws {
        let gallery = SessionGallery(
            gid: "215622",
            title: "SeedRescanHealthy",
            pageCount: 3,
            completedPageCount: 2
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [gallery.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        let announced = try await announcedFrameForAZeroBytePageRepair(
            gallery: gallery,
            fixture: fixture,
            spy: spy
        ) { prepared, pageTwoURL in
            #expect(prepared.workingSeed.scanSucceeded)
            #expect(FileManager.default.fileExists(atPath: pageTwoURL.path) == false)
            #expect(prepared.pendingPageIndices == [2, 3])
        }

        #expect(announced.completedUnitCount == 1)
        #expect(announced.totalUnitCount == 3)
        #expect(announced.subtitle == "1 / 3 pages · 1 gallery")

        let diskManifest = try fixture.storage.readManifest(
            folderURL: galleryFolderURL(for: gallery, in: fixture)
        )
        #expect(diskManifest.pages[2] == "")
        #expect(diskManifest.completedPageCount == 1)
    }
}

// MARK: - Shared Staging

private extension DownloadSeedRecoveryTests {
    /// Stages the removal-authorizing repair shape both announcement cases share, drives the
    /// production preparation under a live session, and answers with the frame that preparation's
    /// own announcement pushed.
    ///
    /// The shape: three pages, two claimed, page 1 present and usable, page 2 present and zero-byte
    /// — a positively refuted claim — and page 3 unclaimed and absent. The combined prospective set
    /// is that one page against a completed count of two, so the wholesale guard AUTHORIZES the
    /// removal, which is the precondition every post-removal exit needs.
    ///
    /// `inspect` runs between the preparation and the frame assertions so each case can pin its own
    /// regime's anti-vacuity conditions while the shared arithmetic stays in one place.
    func announcedFrameForAZeroBytePageRepair(
        gallery: SessionGallery,
        fixture: SessionFixture,
        spy: BackgroundProcessingClientSpy,
        inspect: (DownloadCoordinator.PreparedWorkingRun, URL) throws -> Void
    ) async throws -> BackgroundProcessingClientSpy.ProgressUpdate {
        try writePageFiles(for: gallery, in: fixture, indices: [1, 2])
        let pageTwoURL = pageFileURL(for: gallery, in: fixture, index: 2)
        try Data().write(to: pageTwoURL, options: .atomic)
        await fixture.manager.reloadDownloadIndex()

        let staged = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(staged.completedPageCount == 2)

        await fixture.manager.testingEnsureContinuedSession()
        // The card's honest opening, read off the record because no run has measured anything yet.
        #expect(spy.startCount == 1)
        #expect(spy.startCompletedUnitCounts.last == 2)
        #expect(spy.startTotalUnitCounts.last == 3)

        let baselinePushCount = spy.progressUpdates.count
        let prepared = try await fixture.manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: gallery),
            folderURL: galleryFolderURL(for: gallery, in: fixture)
        )
        try inspect(prepared, pageTwoURL)

        #expect(
            spy.progressUpdates.count > baselinePushCount,
            "the preparation issued no announcement, so no frame is under assertion"
        )
        return try #require(spy.progressUpdates.last)
    }
}

// MARK: - Exit 3 Double

/// The observable half of `SeedManifestWriteRecoveryFileManager`, and the owner of the transient it
/// releases.
///
/// Counting is what keeps the case honest: an injection that is never consumed leaves every
/// assertion about the recovery passing over a path the case never entered.
final class SeedManifestWriteRecoveryControl: Sendable {
    private struct State {
        var manifestURL: URL?
        var isArmed = false
        var postRemovalListingCount = 0
        var releasedTransientCount = 0
    }

    private let state = Mutex(State())

    /// Names the manifest whose immutable flag models the transient write failure. Called after the
    /// fixture exists, since the store owns the temporary root the URL is built from.
    func stageTransientFailure(at manifestURL: URL) {
        state.withLock({ $0.manifestURL = manifestURL })
    }

    /// Arms the counting. Called when the double observes the removal it keys on.
    func arm() {
        state.withLock({ $0.isArmed = true })
    }

    /// Counts one post-removal listing and answers with the manifest whose flag this listing must
    /// lift — non-nil for the SECOND one only, which is the recovery's own fresh scan.
    func manifestURLToRelease() -> URL? {
        state.withLock { state in
            guard state.isArmed else { return nil }
            state.postRemovalListingCount += 1
            guard state.postRemovalListingCount == 2, let manifestURL = state.manifestURL else {
                return nil
            }
            state.releasedTransientCount += 1
            return manifestURL
        }
    }

    var postRemovalListingCount: Int {
        state.withLock({ $0.postRemovalListingCount })
    }

    var releasedTransientCount: Int {
        state.withLock({ $0.releasedTransientCount })
    }
}

/// Lifts an immutable `manifest.json` at the SECOND gallery-folder listing that follows a refuted
/// page file's removal, then forwards every filesystem operation to `FileManager` unchanged.
///
/// **The call it keys on and the invocation index, because keying on an ordinal alone would
/// silently re-target itself the moment a call is added.** The double intercepts
/// `contentsOfDirectory(at:includingPropertiesForKeys:options:)` — the overload `DownloadStore`'s
/// `existingAssetFileURLs` reaches through `DownloadFileManager.operate`, and therefore the one
/// every `pageFileScan` of this folder bottoms out in. Inside one `prepareWorkingSeed` the gallery
/// folder is enumerated by the CLASSIFICATION scan, then — after `removeRefutedPageFiles` has
/// deleted the refuted file — by the blanking pass's rescan, and then once more only if the pass
/// RETRIES. So "the second listing after the removal" names the recovery's own fresh scan
/// positionally-independently, and it is the only window in which a transient write failure could
/// plausibly have cleared: the removal, the failing write and the retry are one synchronous stretch
/// inside a single preparation, so nothing external can land between them.
///
/// Listings CONTINUE past the release, and the count is deliberately not pinned to an exact total: a
/// recovery whose write succeeds re-indexes the folder, and `galleryFolderRecord`'s two rendering
/// resolutions (`localCoverURL` and `imageURLs`) list it again. Those follow the release rather than
/// gating it, so they cannot move which listing lifts the transient.
///
/// It MUTATES rather than fails, which is the opposite of its sibling below and is deliberate. Exit
/// 3's defect is not that a write fails — it is that a pass which destroyed files gives up without
/// re-attempting. Staging a PERMANENT failure cannot see that: the record and the disk end up
/// diverged either way, and the ordinary next pass heals both regimes identically because the
/// removed page is positively absent by then. A transient is the case `recoveredBlanking`'s own doc
/// names, and modelling it here is what makes the retry observable at all.
///
/// The removal itself is performed for real before arming — the page file really is gone, which is
/// what makes the recovery's fresh scan see it as the positive absence it now is.
final class SeedManifestWriteRecoveryFileManager: FileManager {
    private let removedPathFragment: String
    private let listedPathFragment: String
    private let control: SeedManifestWriteRecoveryControl

    init(
        removedPathFragment: String,
        listedPathFragment: String,
        control: SeedManifestWriteRecoveryControl
    ) {
        self.removedPathFragment = removedPathFragment
        self.listedPathFragment = listedPathFragment
        self.control = control
        super.init()
    }

    override func removeItem(at url: URL) throws {
        try super.removeItem(at: url)
        guard url.path.contains(removedPathFragment) else { return }
        control.arm()
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        if url.path.contains(listedPathFragment),
           let manifestURL = control.manifestURLToRelease() {
            clearImmutableFlag(at: manifestURL)
        }
        return try super.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: mask
        )
    }
}

// MARK: - Exit 1 Double

/// The observable half of `SeedRescanFailingFileManager`.
final class SeedRescanFailureControl: Sendable {
    private struct State {
        var isArmed = false
        var consumedFailureCount = 0
    }

    private let state = Mutex(State())

    func arm() {
        state.withLock({ $0.isArmed = true })
    }

    /// Answers whether this listing falls inside the armed window, counting it if so. The arming is
    /// NOT consumed, so the recovery's own rescan meets the same failure the first one did.
    func shouldFailListing() -> Bool {
        state.withLock { state in
            guard state.isArmed else { return false }
            state.consumedFailureCount += 1
            return true
        }
    }

    var consumedFailureCount: Int {
        state.withLock({ $0.consumedFailureCount })
    }
}

/// Fails EVERY gallery-folder listing that follows a refuted page file's removal, then forwards
/// every other filesystem operation to `FileManager` unchanged.
///
/// **The call and the window.** Like its sibling above it intercepts
/// `contentsOfDirectory(at:includingPropertiesForKeys:options:)`, the overload every
/// `pageFileScan` of this folder reaches, and it arms on the removal rather than on an ordinal. The
/// classification scan precedes the removal and therefore succeeds — which it must, since a failed
/// classification returns before authorizing anything and no removal would happen at all — while
/// the post-removal rescan and everything after it fail.
///
/// **It stays armed, unlike the validate route's single-shot double, and that is the point.** A
/// one-shot failure lets the recovery's own rescan answer, which blanks the removed page and makes
/// the record honest by itself; the announced basis would then be honest for a reason that has
/// nothing to do with the subtraction under test. Staying armed keeps the record's claim standing —
/// the legitimate outcome of a non-answer — so what the announcement does with a page this pass
/// removed is the only thing left to observe.
final class SeedRescanFailingFileManager: FileManager {
    private let removedPathFragment: String
    private let listedPathFragment: String
    private let error: any Error & Sendable
    private let control: SeedRescanFailureControl

    init(
        removedPathFragment: String,
        listedPathFragment: String,
        error: any Error & Sendable,
        control: SeedRescanFailureControl
    ) {
        self.removedPathFragment = removedPathFragment
        self.listedPathFragment = listedPathFragment
        self.error = error
        self.control = control
        super.init()
    }

    override func removeItem(at url: URL) throws {
        try super.removeItem(at: url)
        guard url.path.contains(removedPathFragment) else { return }
        control.arm()
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        guard url.path.contains(listedPathFragment), control.shouldFailListing() else {
            return try super.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: mask
            )
        }
        throw error
    }
}
