import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The per-file non-answer, pinned across the SEED COPY rather than inside one folder scan.
///
/// D-G13-01 is stated absolutely — a probe's non-answer is never authority to destroy a recorded
/// hash — but round 12 enforced it only where the scan and the destructive consumer read the SAME
/// folder. `materializeRepairSeed` reads a different one: it selects the pages to copy from the
/// SOURCE folder's scan and hands the destination a folder whose contents were decided by that
/// scan, while copying the manifest whole. A source page the probe could not answer for is
/// therefore simply not copied, the destination listing honestly reports it absent
/// (`scanSucceeded` true, `unprobedPages` empty), and both lines of the round-12 defence pass it
/// through to be blanked. A non-answer in one folder is laundered into a positive absence in
/// another (G-15-19).
///
/// The invariant these two cases pin is over the SIGNAL and its whole route: a page the SOURCE
/// probe could not answer for must never become a positive absence at the DESTINATION, and a page
/// that is genuinely absent at the source must still be blankable there.
///
/// A new file rather than more cases in `DownloadContinuedSessionBasisTests.swift`: that file sits
/// at 996 lines against a `file_length` limit of 1000 at error severity, and these cases cross its
/// staging with `DownloadCoordinatorRepairSeedTests`' rather than extending either. The shared
/// fixture and pushed-pair vocabulary lives in `DownloadFeatureTestHelpers.swift`, so this suite
/// asserts with the same helpers as both.
///
/// **Choreography discipline.** Record state comes only from the fixture manifest, `writePageFiles`
/// and the production announcing preparation. Neither case issues a push of its own: every update
/// the spy records is production-issued, by `testingEnsureContinuedSession` and by
/// `prepareWorkingSeedAnnouncingProgress`'s own announcement.
@Suite
struct DownloadRepairSeedSignalPropagationTests: DownloadFeatureTestCase {
    /// The crossed regression: a per-file probe failure at the SOURCE, on the branch that copies.
    ///
    /// Neither existing suite reaches this. The mass-partial case stages its repair against the
    /// same folder the fixture wrote — `makeRepairPayload` keeps the title, so
    /// `shouldReuseWorkingFolder` returns true and the materialization branch is never taken — and
    /// `DownloadCoordinatorRepairSeedTests.testRepairSeedReusesCompletedFilesWhenPageCountMatches`
    /// does take that branch, but with every source file fully probeable.
    ///
    /// So both stagings are crossed here. The probe failure is the reachability class G-15-13 was
    /// narrowed to: `PartialProbeFailureFileManager` throws `attributesOfItem` for three of the
    /// four claimed pages, and real `0o000` modes on those same three files make the probe's
    /// `FileHandle` fallback throw `EACCES` for real, so the classification is reached the way
    /// production reaches it. The re-slot is the upstream title change: the payload is built from a
    /// second gallery with the SAME gid and a DIFFERENT title, its destination is computed through
    /// the production `folderRelativePath(for:parentFolderName:)`, and that folder does not exist —
    /// which is exactly the conjunction `setupWorkingFolder` answers with the repair seed.
    ///
    /// What must hold afterwards: the three unanswered pages keep their recorded hashes at the
    /// destination, the record is not republished at the laundered count, and the D-G7-01 bracket
    /// withdraws nothing, because a refusal moves no index record for its delta to measure.
    @Test
    func testAnUnprobeableSourcePageIsNeverBlankedAcrossTheSeedCopy() async throws {
        let laundered = SessionGallery(
            gid: "210382",
            title: "Laundered",
            pageCount: 6,
            completedPageCount: 4
        )
        // Three of the four claimed pages: the N-1 shape the all-or-nothing residual lets through.
        let unprobedPages = [2, 3, 4]
        // `makePageRelativePath`'s shape — the identity prefix, the page number, a dot — which no
        // other file in either folder carries. Pinned against the production API below.
        let pathFragments = unprobedPages.map({ "\(laundered.gid)_token_\($0)." })
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [laundered],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            fileManager: PartialProbeFailureFileManager(
                pathFragments: pathFragments,
                error: NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
            )
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        let sourceFolderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(laundered.gid)_token] \(laundered.title)"
        )

        try writePageFiles(for: laundered, in: fixture, indices: [1, 2, 3, 4])
        let unprobedFileURLs = unprobedPages.map { page in
            sourceFolderURL.appendingPathComponent(
                fixture.storage.makePageRelativePath(
                    gid: laundered.gid,
                    token: "token",
                    index: page,
                    fileExtension: "jpg"
                )
            )
        }
        // The double's fragments and the real page-file names are built by different routes, so the
        // staging is pinned rather than assumed: a naming change fails here rather than silently
        // disarming the double and leaving the case green against an unexercised probe.
        for (fileURL, fragment) in zip(unprobedFileURLs, pathFragments) {
            #expect(fileURL.lastPathComponent.contains(fragment))
        }

        await manager.reloadDownloadIndex()
        let stagedDownload = try #require(await manager.fetchDownload(gid: laundered.gid))
        #expect(stagedDownload.completedPageCount == 4)
        // Ground truth, captured while every file is still readable: the nothing-blanked assertion
        // below compares hash for hash against this rather than against a re-read the dropped modes
        // could distort.
        let stagedManifest = try fixture.storage.readManifest(folderURL: sourceFolderURL)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "4 / 6 pages · 1 gallery")

        // The cross: same gid, new title. The computed destination is a folder that does not exist,
        // which is what routes `setupWorkingFolder` into the repair-seed materialization instead of
        // the folder reuse every existing per-file case takes.
        let reslotted = SessionGallery(
            gid: laundered.gid,
            title: "Laundered Elsewhere",
            pageCount: laundered.pageCount,
            completedPageCount: laundered.completedPageCount
        )
        let payload = makeRepairPayload(for: reslotted)
        let destinationFolderURL = fixture.storage.folderURL(
            relativePath: await manager.folderRelativePath(
                for: payload,
                parentFolderName: stagedDownload.folderName
            )
        )
        #expect(destinationFolderURL != sourceFolderURL)
        #expect(FileManager.default.fileExists(atPath: destinationFolderURL.path) == false)

        let originalPermissions = try unprobedFileURLs.map { fileURL in
            try #require(
                FileManager.default.attributesOfItem(atPath: fileURL.path)[.posixPermissions]
                    as? NSNumber
            )
        }
        defer {
            // Declared after the tree removal so it runs BEFORE it, leaving a leaked temporary tree
            // inspectable. No assertion needs the modes back: the three unreadable files are SOURCE
            // page files, and every manifest this case reads is a different file.
            restoreOriginalModes(of: unprobedFileURLs, to: originalPermissions)
        }
        // No owner bits at all on the three files: the double throws the metadata read, the
        // content-read fallback then throws EACCES against the real filesystem, and the folder
        // itself is untouched so the enumeration keeps succeeding.
        for fileURL in unprobedFileURLs {
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o000)],
                ofItemAtPath: fileURL.path
            )
        }

        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: stagedDownload,
            folderURL: destinationFolderURL
        ).workingSeed

        // Nothing re-indexed: the record the card sums from is where the fixture left it.
        #expect(await manager.fetchDownload(gid: laundered.gid)?.completedPageCount == 4)
        // Page 1 is the only one the source probe answered for, so it is the only one copied. The
        // other three are re-fetched by the run, which is the harmless pre-D-G5-01 arc.
        #expect(seed.existingPages.keys.sorted() == [1])
        // Nothing blanked ACROSS the copy: the manifest that landed at the destination still claims
        // every page the source manifest claimed, hash for hash.
        let destinationManifest = try fixture.storage.readManifest(folderURL: destinationFolderURL)
        #expect(destinationManifest.pages == stagedManifest.pages)
        #expect(destinationManifest.completedPageCount == 4)
        #expect(
            destinationManifest.pages.filter({ !$0.value.isEmpty }).keys.sorted() == [1, 2, 3, 4]
        )
        // The announcement's own push, and the only push recorded: no withdrawal was taken, because
        // the refusal moved no record for the bracket's delta to measure.
        #expect(spy.progressUpdates.count == 1)
        let refusalPair = try lastPushedPair(spy.progressUpdates)
        #expect(refusalPair.completedUnitCount == 4)
        #expect(refusalPair.totalUnitCount == 6)
        #expect(refusalPair.subtitle == "4 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The companion that stops the carried set from being bought by disabling blanking after a
    /// seed.
    ///
    /// Same re-slot, same materialization branch, over the REAL file manager, with two of the four
    /// claimed page files deleted outright from the SOURCE folder — the route a user emptying the
    /// folder in the Files app takes. The source listing succeeds and simply does not yield them,
    /// which is a POSITIVE absence rather than an unanswered question, so those two pages must
    /// still be blanked at the destination: the record republishes at its honest lowered count and
    /// D-G7-01's bracket withdraws exactly the counted movement.
    ///
    /// Green both before and after the fix, deliberately. It pins the side the fix must NOT move,
    /// so a fix that buys the crossed case by carrying every uncopied page — or by refusing to
    /// reconcile at all after a seed — fails here in the same run.
    @Test
    func testAGenuinelyAbsentSourcePageIsStillBlankedAcrossTheSeedCopy() async throws {
        let lost = SessionGallery(
            gid: "210383",
            title: "Lost",
            pageCount: 6,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [lost],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        let sourceFolderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(lost.gid)_token] \(lost.title)"
        )

        try writePageFiles(for: lost, in: fixture, indices: [1, 2, 3, 4])
        await manager.reloadDownloadIndex()
        let stagedDownload = try #require(await manager.fetchDownload(gid: lost.gid))
        #expect(stagedDownload.completedPageCount == 4)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "4 / 6 pages · 1 gallery")

        for page in [3, 4] {
            let relativePath = fixture.storage.makePageRelativePath(
                gid: lost.gid,
                token: "token",
                index: page,
                fileExtension: "jpg"
            )
            try FileManager.default.removeItem(
                at: sourceFolderURL.appendingPathComponent(relativePath)
            )
        }

        let reslotted = SessionGallery(
            gid: lost.gid,
            title: "Lost Elsewhere",
            pageCount: lost.pageCount,
            completedPageCount: lost.completedPageCount
        )
        let payload = makeRepairPayload(for: reslotted)
        let destinationFolderURL = fixture.storage.folderURL(
            relativePath: await manager.folderRelativePath(
                for: payload,
                parentFolderName: stagedDownload.folderName
            )
        )
        #expect(destinationFolderURL != sourceFolderURL)
        #expect(FileManager.default.fileExists(atPath: destinationFolderURL.path) == false)

        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: stagedDownload,
            folderURL: destinationFolderURL
        ).workingSeed

        // Exactly the two lost pages, and only them: the record the card sums from moved by two.
        #expect(await manager.fetchDownload(gid: lost.gid)?.completedPageCount == 2)
        #expect(seed.existingPages.keys.sorted() == [1, 2])
        let destinationManifest = try fixture.storage.readManifest(folderURL: destinationFolderURL)
        #expect(destinationManifest.completedPageCount == 2)
        #expect(destinationManifest.pages.filter({ !$0.value.isEmpty }).keys.sorted() == [1, 2])
        // One push, at the corrected basis: the record really moved, so the bracket withdrew the
        // counted two rather than nothing.
        #expect(spy.progressUpdates.count == 1)
        let correctedPair = try lastPushedPair(spy.progressUpdates)
        #expect(correctedPair.completedUnitCount == 2)
        #expect(correctedPair.totalUnitCount == 6)
        #expect(correctedPair.subtitle == "2 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }
}

// MARK: - Helpers

private extension DownloadRepairSeedSignalPropagationTests {
    /// Puts the page files this suite staged unreadable back to their original modes, so the
    /// fixture tree can be enumerated and removed.
    ///
    /// Local and batched rather than promoted from the basis suite's single-URL restorer: that
    /// helper is file-private to a file this plan must leave byte-unchanged, and one call site
    /// restoring a whole staged set is smaller than either duplicating a named helper or widening
    /// that suite's private seam.
    ///
    /// A failure here strands the temporary tree rather than affecting any assertion, so it is
    /// recorded as an issue instead of thrown from a deferred block.
    func restoreOriginalModes(of fileURLs: [URL], to permissions: [NSNumber]) {
        for (fileURL, mode) in zip(fileURLs, permissions) {
            do {
                try FileManager.default.setAttributes(
                    [.posixPermissions: mode],
                    ofItemAtPath: fileURL.path
                )
            } catch {
                Issue.record("Restoring a staged page file's permissions failed: \(error)")
            }
        }
    }
}
