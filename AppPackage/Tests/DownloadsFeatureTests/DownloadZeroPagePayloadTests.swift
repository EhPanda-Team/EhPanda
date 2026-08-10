@testable import AppFeature
import AppModels
import AppTools
import ComposableArchitecture
import DownloadClient
import Foundation
import Testing
import UIKit

/// Zero-page payload coverage for G-15-14.
///
/// A freshly fetched gallery detail can parse with no page count — an expunged gallery, a partially
/// rendered detail page, or an upstream HTML change — and every `1...pageCount` built from that
/// value is an invalid `ClosedRange` that traps the process. Phase 15 deleted the discretionary
/// background tier, so a trap now loses a continued-processing session with nothing left to resume
/// it. These cases pin the module's page-count range sites at zero and the two entrance
/// dispositions that keep a zero-page gallery out of a run at all.
///
/// **Recorded RED-first deviation.** The usual failing-test-first step is deliberately NOT staged
/// here. Pre-fix, every case below would TRAP rather than fail: an invalid-`ClosedRange`
/// precondition kills the test runner process, and on this machine a killed or wedged `xcodebuild
/// test` invocation wedges `testmanagerd` and costs a host reboot (recorded project memory: never
/// overlap or kill test runs). The falsifiability evidence is therefore static rather than staged —
/// the pre-fix expressions were `(1...payload.galleryDetail.pageCount).filter { … }`
/// (`DownloadClient+ExecutionSupport.swift`) and
/// `Array(1...context.payload.galleryDetail.pageCount)` (`DownloadClient+PageDownload.swift`),
/// against the same module's own zero-page branches in `makeInitialManifest`
/// (`pageCount > 0 ? … : [:]`) and `reusableExistingManifest` (`pageCount > 0 ? Set(1...) : Set()`),
/// which establish that zero is a modeled input rather than an impossible one — plus post-fix GREEN
/// below.
struct DownloadZeroPagePayloadTests: DownloadFeatureTestCase {
    // MARK: - Fixtures

    /// A well-formed gallery whose freshly parsed detail reports `pageCount` pages.
    private func makePayload(
        pageCount: Int,
        mode: DownloadStartMode = .initial,
        pageSelection: Set<Int>? = nil
    ) -> DownloadRequestPayload {
        var gallery = sampleGallery()
        gallery.pageCount = pageCount
        var detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        detail.pageCount = pageCount
        return DownloadRequestPayload(
            gallery: gallery,
            galleryDetail: detail,
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Folder",
            mode: mode,
            pageSelection: pageSelection
        )
    }

    /// The degenerate payload: a well-formed gallery whose freshly parsed detail carries no pages.
    private func makeZeroPagePayload(
        pageSelection: Set<Int>? = nil
    ) -> DownloadRequestPayload {
        makePayload(pageCount: 0, pageSelection: pageSelection)
    }

    // MARK: - Range Sites

    @Test
    func testPendingPageIndicesOfAZeroPagePayloadIsEmpty() async throws {
        let manager = makeTestingDownloadCoordinator()
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let pending = await manager.pendingPageIndices(
            payload: makeZeroPagePayload(),
            folderURL: folderURL,
            existingPageRelativePaths: [:]
        )
        #expect(pending.isEmpty)

        // The selection branch runs inside the same range, so the guard has to sit ahead of both
        // rather than inside the filter — a selected page cannot rescue a range that never formed.
        let selectedPending = await manager.pendingPageIndices(
            payload: makeZeroPagePayload(pageSelection: [1]),
            folderURL: folderURL,
            existingPageRelativePaths: [:]
        )
        #expect(selectedPending.isEmpty)
    }

    @Test
    func testDownloadPagesWithAZeroPagePayloadCompletesWithoutTrapping() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        let payload = makeZeroPagePayload()
        let folderRelativePath = "Folder/" + storage.makeFolderRelativePath(
            gid: payload.gallery.gid,
            token: payload.gallery.token,
            title: payload.galleryDetail.trimmedTitle
        )
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        // The manifest is built by the production helper that already handles zero, so the case
        // reaches `downloadPages` through the shape a real zero-page run would carry.
        let manifest = await manager.makeInitialManifest(payload: payload)
        #expect(manifest.pages.isEmpty)

        let pendingPageIndices = await manager.pendingPageIndices(
            payload: payload,
            folderURL: folderURL,
            existingPageRelativePaths: [:]
        )
        let batchResult = try await manager.downloadPages(
            context: .init(
                payload: payload,
                options: DownloadRequestOptions(),
                source: .normal([:]),
                folderURL: folderURL
            ),
            pendingPageIndices: pendingPageIndices,
            existingManifest: manifest,
            existingPageRelativePaths: [:]
        )

        #expect(batchResult.pages.isEmpty)
        #expect(batchResult.failedPages.isEmpty)
        let record = await manager.fetchDownload(gid: payload.gallery.gid)
        #expect(record == nil)
    }

    @Test
    func testTheModulesOtherPageCountRangeSitesAnswerEmptyForAZeroPagePayload() async throws {
        let manager = makeTestingDownloadCoordinator()

        // `normalizeFetchedPayload` validates a raw page selection against the detail's page count.
        // The answer is a PRESENT empty set, not nil (CR-04): the caller named pages, and at zero
        // pages none of them is admissible. Nil is reserved for "no selection was ever made", which
        // `pendingPageIndices` reads as unrestricted work over the whole gallery — so collapsing
        // this case to nil would answer a request for two pages with a request for all of them.
        let normalized = await manager.normalizeFetchedPayload(
            makeZeroPagePayload(),
            mode: .initial,
            rawPageSelection: [1, 2]
        )
        #expect(normalized.pageSelection != nil)
        #expect(normalized.pageSelection == Set<Int>())

        // `buildInspectionPages` enumerates a record's pages for the inspector.
        let zeroPageDownload = sampleDownload(
            gid: "123456",
            title: "Sample Gallery",
            status: .queued,
            pageCount: 0
        )
        let inspectionPages = await manager.buildInspectionPages(
            download: zeroPageDownload,
            activeFolderURL: nil,
            existingRelativePaths: [:],
            failedPages: [:]
        )
        #expect(inspectionPages.isEmpty)
    }

    // MARK: - Selection Presence (CR-04)

    /// The three selection states, and the distinction between two of them is the whole finding.
    ///
    /// `rawPageSelection` is the coordinator's queue-intent entry for the run. `nil` means no
    /// selection was ever made; a non-nil value means the caller named pages. Pre-fix, an explicit
    /// selection that filtered down to nothing came out as `nil` — the same value as "no selection"
    /// — and every downstream reader takes nil as permission to work over the whole gallery.
    ///
    /// Every assertion here tests OPTIONAL PRESENCE before it tests contents. Comparing only the
    /// contained set is what makes this collapse invisible: `nil` and `.some([])` both hold no
    /// pages, and they mean opposite things.
    @Test
    func testNormalizationKeepsNilUnrestrictedAndAnExplicitSelectionPresent() async throws {
        let manager = makeTestingDownloadCoordinator()
        let payload = makePayload(pageCount: 3, mode: .repair)

        let unrestricted = await manager.normalizeFetchedPayload(
            payload,
            mode: .repair,
            rawPageSelection: nil
        )
        #expect(unrestricted.pageSelection == nil)

        let explicitlyEmpty = await manager.normalizeFetchedPayload(
            payload,
            mode: .repair,
            rawPageSelection: []
        )
        #expect(explicitlyEmpty.pageSelection != nil)
        #expect(explicitlyEmpty.pageSelection == Set<Int>())

        let allInvalid = await manager.normalizeFetchedPayload(
            payload,
            mode: .repair,
            rawPageSelection: [0, 999]
        )
        #expect(allInvalid.pageSelection != nil)
        #expect(allInvalid.pageSelection == Set<Int>())

        let mixed = await manager.normalizeFetchedPayload(
            payload,
            mode: .repair,
            rawPageSelection: [0, 2, 2, 999]
        )
        #expect(mixed.pageSelection == Set([2]))

        // The one mode that legitimately discards a selection: an update refreshes the gallery as
        // a unit, against a page count the old selection was never drawn against.
        let update = await manager.normalizeFetchedPayload(
            makePayload(pageCount: 3, mode: .update),
            mode: .update,
            rawPageSelection: [2]
        )
        #expect(update.pageSelection == nil)
    }

    /// The downstream half of the same contract, read at the filter that decides real work.
    ///
    /// This is the reason presence matters: `pendingPageIndices` treats nil as "no restriction" and
    /// answers with every page the record still owes. A present empty set answers with nothing.
    /// Both readings are correct — they are simply readings of different requests.
    @Test
    func testPendingPagesReadNilAsUnrestrictedAndAPresentEmptySetAsNoPages() async throws {
        let manager = makeTestingDownloadCoordinator()
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let unrestricted = await manager.pendingPageIndices(
            payload: makePayload(pageCount: 3, mode: .repair),
            folderURL: folderURL,
            existingPageRelativePaths: [:]
        )
        #expect(unrestricted == [1, 2, 3])

        let none = await manager.pendingPageIndices(
            payload: makePayload(pageCount: 3, mode: .repair, pageSelection: []),
            folderURL: folderURL,
            existingPageRelativePaths: [:]
        )
        #expect(none.isEmpty)

        let narrow = await manager.pendingPageIndices(
            payload: makePayload(pageCount: 3, mode: .repair, pageSelection: [2]),
            folderURL: folderURL,
            existingPageRelativePaths: [:]
        )
        #expect(narrow == [2])
    }

    /// CR-04 as one composed expression: the two steps that produce the widening, run together.
    ///
    /// Neither step is wrong alone. Normalization dropping out-of-domain values is right, and
    /// `pendingPageIndices` reading nil as unrestricted is right. The defect lives in the seam,
    /// where "everything you asked for is invalid" was encoded with the same value as "you asked
    /// for no restriction". Composing them here is what states the size of the consequence: a
    /// two-index request answered with the whole gallery.
    @Test
    func testAnAllInvalidSelectionNeverNormalizesIntoWholeGalleryWork() async throws {
        let manager = makeTestingDownloadCoordinator()
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let normalized = await manager.normalizeFetchedPayload(
            makePayload(pageCount: 3, mode: .repair),
            mode: .repair,
            rawPageSelection: [0, 999]
        )
        let scheduled = await manager.pendingPageIndices(
            payload: normalized,
            folderURL: folderURL,
            existingPageRelativePaths: [:]
        )

        #expect(
            scheduled.isEmpty,
            "An all-invalid selection scheduled \(scheduled) instead of nothing."
        )
    }

    // MARK: - Bounded Sites

    /// `captureCachedPage` is the one page-count site the G-15-14 sweep WIDENED rather than
    /// guarded: its bound read `index <= max(download.pageCount, 1)`, which admitted index 1 for a
    /// record claiming no pages at all. The consequence is not a trap but an unclaimed write — a
    /// page file no manifest names, invisible to `pageFileScan` and skipped by
    /// `refreshManifestPageFileHashes`.
    ///
    /// The record is staged through `updateDownloadIndex(folderURL:manifest:)`, the same production
    /// index writer every capture and flush publishes through, fed by the manifest
    /// `makeInitialManifest` produces for a zero-page payload. No test-only seam exists for this
    /// site and none was added. A restorable cached page is staged deliberately: without one the
    /// capture would come back empty-handed for a reason unrelated to the bound, and this case
    /// could not fail.
    @Test
    func testCaptureCachedPageRefusesAZeroPageRecord() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        let payload = makeZeroPagePayload()
        let gid = payload.gallery.gid
        let folderURL = rootURL.appendingPathComponent(
            "Folder/\(gid) - Zero Page",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        // Warm the index the way launch does, then publish the zero-page record through the
        // production writer so `fetchDownload` answers with a record whose page count is zero.
        await manager.reloadDownloadIndex()
        let manifest = await manager.makeInitialManifest(payload: payload)
        #expect(manifest.pages.isEmpty)
        await manager.updateDownloadIndex(folderURL: folderURL, manifest: manifest)
        let staged = await manager.fetchDownload(gid: gid)
        #expect(staged?.pageCount == 0)

        let imageURL = try #require(
            URL(string: "https://ehgt.org/ab/cd/0001-\(UUID().uuidString).jpg")
        )
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemGreen.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.jpegData(compressionQuality: 1))
        let cacheKeys = imageURL.imageCacheKeys
        let dataCache = DataCache(
            configuration: .init(
                rootURL: rootURL.appendingPathComponent("DataCache", isDirectory: true)
            )
        )
        try await withDependencies {
            $0.dataCache = dataCache
        } operation: {
            try await dataCache.store(imageData, forKeys: cacheKeys)

            await manager.captureCachedPage(gid: gid, index: 1, imageURL: imageURL)

            let written = try FileManager.default.contentsOfDirectory(atPath: folderURL.path)
            #expect(written.isEmpty)
            let afterwards = await manager.fetchDownload(gid: gid)
            #expect(afterwards?.manifest.pages.isEmpty == true)
            try await dataCache.removeData(forKeys: cacheKeys)
        }
    }

    // MARK: - Entrance Dispositions (D-G14-01)

    @Test
    func testEnqueueRejectsAZeroPagePayload() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )
        // Warm the index the way launch does, so a missing record afterwards is a refusal to
        // commit rather than an index that was never loaded.
        await manager.reloadDownloadIndex()

        let payload = makeZeroPagePayload()
        let result = await manager.enqueue(payload: payload)

        guard case .failure(let error) = result else {
            Issue.record("Expected enqueue to reject a zero-page payload, got \(result).")
            return
        }
        #expect(error == .notFound)
        let record = await manager.fetchDownload(gid: payload.gallery.gid)
        #expect(record == nil)
        #expect(queueStore.gids.isEmpty)
    }
}
