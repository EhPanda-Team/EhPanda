import AppModels
import AppTools
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Resources
import Testing

/// CR-03: an ordinary READ of a downloaded gallery may not destroy one of its files.
///
/// The rule this suite pins is not about which pages a pass may CORRECT — that is settled by
/// D-SSOT-01/02/03 and pinned next door — but about whether merely LOOKING is allowed to act at all.
/// A probe that deletes what it refuses performs a mutation as part of forming an answer, so every
/// caller that never named the mutation flag was a mutator by default: opening a downloaded gallery
/// (`loadManifest`), resolving repair-versus-redownload (`resumeMode`) and the coordinator's own
/// folder sweep all reached `probeAssetFile` on the discarding default and deleted a zero-byte or
/// non-regular page or cover file while the manifest went on claiming it.
///
/// That is the record/disk divergence AGENTS.md forbids, manufactured by the app itself: nothing on
/// these routes writes the manifest, so the page keeps a non-empty hash, the gallery keeps deriving
/// `.completed` under D-SSOT-07, and the divergence outlives the process — not even a session-scoped
/// signal marks it. The remedy is by construction rather than by caller list: the flag now defaults
/// to the non-mutating value, so a deleting caller has to write it down.
///
/// **Every case asserts from BOTH sides.** The file must survive AND the record must still claim it.
/// A file-only assertion would be satisfied by a read that deleted nothing and blanked the hash
/// anyway; a manifest-only assertion passes verbatim against the defect, because the manifest is
/// exactly what these routes never touched. The record side is stated twice over — the manifest
/// bytes on disk, and the reading a FRESH coordinator derives from them — so "the record still
/// claims it" means the persisted basis rather than this session's memory of it.
struct DownloadReadPathNonMutationTests: DownloadFeatureTestCase {
    /// Opening a downloaded gallery whose only page file has been truncated behind the app's back.
    ///
    /// This is the reported sequence in miniature. `loadManifest` runs the coordinator's folder
    /// sweep and then `storage.validate`, and before the flip BOTH of them probed on the discarding
    /// default — the sweep discarding its results outright, since it existed for the deletion and
    /// nothing else. The verdict is the same either way (a zero-byte file is missing content whether
    /// or not it is deleted), which is the whole point: the answer never needed the deletion, so the
    /// deletion was never anything but damage.
    @Test
    func testLoadManifestOverAZeroBytePageLeavesTheFileAndTheRecordUntouched() async throws {
        let gallery = SessionGallery(
            gid: "215661",
            title: "ReadOnlyPage",
            pageCount: 1,
            completedPageCount: 1
        )
        let fixture = try await makeReadPathFixture(for: gallery)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        // Written through the production namer and then TRUNCATED, so the directory entry is one the
        // listing really yields and only the size question rejects it. A file that was never written
        // would stage the absence family, which is a different evidence class entirely.
        try writePageFiles(for: gallery, in: fixture, indices: [1])
        let pageOneURL = pageFileURL(for: gallery, in: fixture, index: 1)
        try Data().write(to: pageOneURL, options: .atomic)
        await fixture.manager.reloadDownloadIndex()

        let manifestBefore = try manifestBytes(for: gallery, in: fixture)
        let readingBefore = try await freshDisplayReading(for: gallery, in: fixture)

        let result = await fixture.manager.loadManifest(gid: gallery.gid)

        guard case .failure(let error) = result else {
            Issue.record("loadManifest must refuse a gallery whose only page file holds no content")
            return
        }
        let expectedMessage = String(localized: .RLocalizable.downloadStorePageMissing(page: 1))
        #expect(error == .fileOperationFailed(expectedMessage))

        try await expectTheReadChangedNothing(
            for: gallery,
            in: fixture,
            manifestBefore: manifestBefore,
            readingBefore: readingBefore,
            survivingURL: pageOneURL
        )
    }

    /// The second discarding read route, reached without opening anything: deciding how to resume.
    ///
    /// `resumeMode` asks `storage.validate` whether a record that reads COMPLETE is contradicted by
    /// its files, and routes a contradiction to `.repair` rather than to `.redownload` so the pages
    /// already on disk are kept. Answering that question by deleting the very file that answers it
    /// is self-defeating, and it converges only if the user then starts the download — until then the
    /// record lies about a page this call destroyed.
    ///
    /// The record is staged COMPLETE deliberately: an incomplete record short-circuits two branches
    /// earlier and never reaches the validate, so `isIncomplete` is asserted false before the call
    /// rather than assumed, or the case would prove nothing about the branch it is named for.
    @Test
    func testResumeModeOverAZeroBytePageResolvesRepairWithoutDeletingIt() async throws {
        let gallery = SessionGallery(
            gid: "215662",
            title: "ReadOnlyResume",
            pageCount: 1,
            completedPageCount: 1
        )
        let fixture = try await makeReadPathFixture(for: gallery)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1])
        let pageOneURL = pageFileURL(for: gallery, in: fixture, index: 1)
        try Data().write(to: pageOneURL, options: .atomic)
        await fixture.manager.reloadDownloadIndex()

        let manifestBefore = try manifestBytes(for: gallery, in: fixture)
        let readingBefore = try await freshDisplayReading(for: gallery, in: fixture)

        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.isIncomplete == false)
        #expect(download.hasUpdate == false)

        let mode = await fixture.manager.resumeMode(for: download)

        #expect(mode == .repair)
        try await expectTheReadChangedNothing(
            for: gallery,
            in: fixture,
            manifestBefore: manifestBefore,
            readingBefore: readingBefore,
            survivingURL: pageOneURL
        )
    }

    /// The cover half of the same boundary, on the same reader-open route.
    ///
    /// A cover carries no recorded hash, so its deletion creates no arithmetic divergence — which is
    /// exactly why it needs its own case. The property is about the READ rather than about what the
    /// read happens to be looking at: the sweep resolved the cover purely to delete a refused one,
    /// and a rule stated only over pages would leave that half of the sweep licensed.
    ///
    /// The page is left intact here so the route runs to SUCCESS. A failing `loadManifest` would
    /// leave it open whether the cover survived because reads no longer delete or because the run
    /// stopped before reaching it.
    @Test
    func testLoadManifestOverAZeroByteCoverLeavesTheCoverOnDisk() async throws {
        let gallery = SessionGallery(
            gid: "215663",
            title: "ReadOnlyCover",
            pageCount: 1,
            completedPageCount: 1
        )
        let fixture = try await makeReadPathFixture(for: gallery)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1])
        let coverURL = try writeZeroByteCover(for: gallery, in: fixture)
        await fixture.manager.reloadDownloadIndex()

        let manifestBefore = try manifestBytes(for: gallery, in: fixture)
        let readingBefore = try await freshDisplayReading(for: gallery, in: fixture)

        let result = await fixture.manager.loadManifest(gid: gallery.gid)

        guard case .success(let loaded) = result else {
            Issue.record("loadManifest must succeed while every claimed page file is intact")
            return
        }
        #expect(loaded.manifest.pages[1]?.isEmpty == false)

        try await expectTheReadChangedNothing(
            for: gallery,
            in: fixture,
            manifestBefore: manifestBefore,
            readingBefore: readingBefore,
            survivingURL: coverURL
        )
    }
}

// MARK: - Fixtures

/// The persisted reading of one gallery, derived by a coordinator that holds none of the session's
/// memory. A named value rather than a tuple so both members read as what they are at the call site.
private struct PersistedDisplayReading: Equatable {
    let displayStatus: DownloadDisplayStatus
    let completedPageCount: Int
}

private extension DownloadReadPathNonMutationTests {
    /// One gallery on disk, nothing queued and nothing runnable.
    ///
    /// The injected runner is what keeps the case about the read: with the default runner a
    /// schedulable gallery could start downloading underneath the assertions and write the very
    /// files they are measuring.
    func makeReadPathFixture(for gallery: SessionGallery) async throws -> SessionFixture {
        try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: BackgroundProcessingClientSpy().client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
    }

    /// Stages a cover file through the production namer and truncates it, matching how the page
    /// cases stage theirs — same rejection exit, different asset class.
    func writeZeroByteCover(
        for gallery: SessionGallery,
        in fixture: SessionFixture
    ) throws -> URL {
        let coverURL = galleryFolderURL(for: gallery, in: fixture)
            .appendingPathComponent(
                fixture.storage.makeCoverRelativePath(
                    gid: gallery.gid,
                    token: "token",
                    fileExtension: "jpg"
                )
            )
        try Data().write(to: coverURL, options: .atomic)
        return coverURL
    }

    /// The manifest exactly as it sits on disk.
    ///
    /// Read as BYTES rather than as a decoded value: the claim under test is that the read wrote
    /// nothing at all, and a decoded comparison would accept a rewrite that happened to round-trip.
    func manifestBytes(for gallery: SessionGallery, in fixture: SessionFixture) throws -> Data {
        try Data(
            contentsOf: galleryFolderURL(for: gallery, in: fixture)
                .appendingPathComponent(Defaults.FilePath.downloadManifest)
        )
    }

    /// What a relaunch would show: a second coordinator over the same storage root, which holds none
    /// of this session's in-memory state and can therefore only answer from the persisted record.
    func freshDisplayReading(
        for gallery: SessionGallery,
        in fixture: SessionFixture
    ) async throws -> PersistedDisplayReading {
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let download = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        return PersistedDisplayReading(
            displayStatus: download.displayStatus,
            completedPageCount: download.completedPageCount
        )
    }

    /// The non-mutation contract itself, stated once so the three routes cannot drift into asserting
    /// different amounts of preservation — which is how one route ends up green over a weaker promise
    /// than its siblings.
    ///
    /// Both sides are here on purpose. The file assertion is the one the defect fails; the record
    /// assertions are what stop a "fix" that stopped deleting by starting to blank instead, which
    /// would trade this divergence for its mirror image.
    func expectTheReadChangedNothing(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        manifestBefore: Data,
        readingBefore: PersistedDisplayReading,
        survivingURL: URL
    ) async throws {
        #expect(
            FileManager.default.fileExists(atPath: survivingURL.path),
            "an ordinary read must leave the file it refused on disk"
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: survivingURL.path)
        #expect((attributes[.type] as? FileAttributeType) == .typeRegular)
        #expect((attributes[.size] as? NSNumber)?.intValue == 0)

        let manifestAfter = try manifestBytes(for: gallery, in: fixture)
        #expect(manifestAfter == manifestBefore)
        let readingAfter = try await freshDisplayReading(for: gallery, in: fixture)
        #expect(readingAfter == readingBefore)
    }
}
