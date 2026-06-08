//
//  DownloadManagerStorageTests.swift
//  EhPandaTests
//

import Kingfisher
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadManagerStorageTests: DownloadFeatureTestCase {
    @Test
    func testDownloadManagerReloadDownloadIndexScansManifestFolders() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[100_token] Complete",
            manifest: indexedManifest(
                gid: "100",
                title: "Complete",
                pageHashes: ["sha256:1", "sha256:2"],
                modifiedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[200_token] Queued",
            manifest: indexedManifest(
                gid: "200",
                title: "Queued",
                pageHashes: ["sha256:1", ""],
                modifiedAt: Date(timeIntervalSince1970: 200)
            )
        )
        try FileManager.default.createDirectory(
            at: rootURL.appendingPathComponent("No Manifest", isDirectory: true),
            withIntermediateDirectories: true
        )
        await manager.testingSetQueuedGalleryIDs(["200"])

        let downloads = await manager.reloadDownloadIndex()

        #expect(downloads.map(\.gid) == ["200", "100"])
        let queuedDownload = try #require(downloads.first { $0.gid == "200" })
        let completedDownload = try #require(downloads.first { $0.gid == "100" })
        #expect(queuedDownload.displayStatus == .queued)
        #expect(queuedDownload.completedPageCount == 1)
        #expect(completedDownload.displayStatus == .completed)
        #expect(completedDownload.completedPageCount == 2)
        #expect((await manager.indexedDownload(gid: "100")) == completedDownload)
        #expect(await manager.indexedDownload(gid: "missing") == nil)
    }

    @Test
    func testDownloadManagerReloadDownloadIndexKeepsNewestDuplicateFolder() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[500_token] Old",
            manifest: indexedManifest(
                gid: "500",
                title: "Old",
                pageHashes: ["sha256:old"],
                modifiedAt: olderDate
            )
        )
        try setFolderModificationDate(
            olderDate,
            storage: storage,
            relativePath: "[500_token] Old"
        )
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[500_token] New",
            manifest: indexedManifest(
                gid: "500",
                title: "New",
                pageHashes: ["sha256:new"],
                modifiedAt: newerDate
            )
        )
        try setFolderModificationDate(
            newerDate,
            storage: storage,
            relativePath: "[500_token] New"
        )

        let downloads = await manager.reloadDownloadIndex()

        #expect(downloads.map(\.gid) == ["500"])
        let download = try #require(downloads.first)
        #expect(download.title == "New")
        #expect(download.folderRelativePath == "[500_token] New")
        #expect(download.lastDownloadedAt == newerDate)
        #expect((await manager.indexedDownload(gid: "500")) == download)
    }

    @Test
    func testDownloadManagerFetchesDownloadsFromManifestIndex() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[600_token] Disk",
            manifest: indexedManifest(
                gid: "600",
                title: "Disk",
                pageHashes: [""]
            )
        )
        await manager.testingSetQueuedGalleryIDs(["600"])

        let downloads = await manager.fetchDownloads()
        let indexedDownload = try #require(await manager.fetchDownload(gid: "600"))
        let badges = await manager.badges(for: ["600", "601"])

        #expect(downloads.map(\.gid) == ["600"])
        #expect(indexedDownload.title == "Disk")
        #expect(indexedDownload.displayStatus == .queued)
        #expect(indexedDownload.status == .queued)
        #expect(await manager.fetchDownload(gid: "601") == nil)
        #expect(badges["600"] == .queued)
        #expect(badges["601"] == nil)
    }

    @Test
    func testDownloadManagerObserverInitialSnapshotUsesManifestIndex() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[700_token] Observed",
            manifest: indexedManifest(
                gid: "700",
                title: "Observed",
                pageHashes: ["sha256:1"]
            )
        )

        let stream = await manager.observeDownloads()
        let initialSnapshotTask = Task<[DownloadedGallery]?, Never> {
            var iterator = stream.makeAsyncIterator()
            return await iterator.next()
        }

        let snapshot = try await waitForTaskValue(
            initialSnapshotTask,
            timeout: .seconds(1),
            description: "initial download observer snapshot"
        )
        let downloads = try #require(snapshot)
        let download = try #require(downloads.first)

        #expect(downloads.map(\.gid) == ["700"])
        #expect(download.title == "Observed")
        #expect(download.displayStatus == .completed)
    }

    @Test
    func testDownloadManagerIndexAppliesSessionOnlyFlags() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[300_token] Updated",
            manifest: indexedManifest(
                gid: "300",
                title: "Updated",
                pageHashes: ["sha256:1"]
            )
        )
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[400_token] Failed",
            manifest: indexedManifest(
                gid: "400",
                title: "Failed",
                pageHashes: [""]
            )
        )
        await manager.testingSetUpdatedGalleryIDs(["300"])
        await manager.testingSetDownloadError(
            .init(code: .networkingFailed, message: "Network Error"),
            gid: "400"
        )

        let downloads = await manager.reloadDownloadIndex()

        let updatedDownload = try #require(downloads.first { $0.gid == "300" })
        let failedDownload = try #require(downloads.first { $0.gid == "400" })
        #expect(updatedDownload.displayStatus == .updateAvailable)
        #expect(failedDownload.displayStatus == .error)
        #expect(failedDownload.lastError?.code == .networkingFailed)
    }

    @Test
    func testDownloadManagerReconcileClearsIndexedCancellationError() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )
        let cancellationFailure = DownloadFailure(
            code: .fileOperationFailed,
            message: "The operation was cancelled."
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[410_token] Cancelled",
            manifest: indexedManifest(
                gid: "410",
                title: "Cancelled",
                pageHashes: [""]
            )
        )
        await manager.testingSetDownloadError(
            cancellationFailure,
            gid: "410"
        )

        await manager.reconcileDownloads()

        let download = try #require(await manager.fetchDownload(gid: "410"))
        #expect(download.displayStatus == .inactive)
        #expect(download.status == .paused)
        #expect(download.lastError == nil)
    }

    @Test
    func testDownloadManagerReconcileClearsIndexedInterruptedActiveFlag() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[420_token] Interrupted",
            manifest: indexedManifest(
                gid: "420",
                title: "Interrupted",
                pageHashes: [""]
            )
        )
        await manager.testingSetActiveGalleryID("420")

        await manager.reconcileDownloads()

        let download = try #require(await manager.fetchDownload(gid: "420"))
        #expect(download.displayStatus == .inactive)
        #expect(download.status == .paused)
        #expect(await manager.testingActiveGalleryID() == nil)
    }

    @Test
    func testDownloadManagerSanitizeClearsIndexedError() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )
        let failure = DownloadFailure(
            code: .fileOperationFailed,
            message: "Page 1 is missing."
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[430_token] Sanitize",
            manifest: indexedManifest(
                gid: "430",
                title: "Sanitize",
                pageHashes: [""]
            )
        )
        await manager.testingSetDownloadError(failure, gid: "430")

        let sanitizedDownload = await manager.testingSanitizeLocalFilesIfNeeded(
            gid: "430",
            clearingLastError: true
        )

        #expect(sanitizedDownload?.displayStatus == .inactive)
        #expect(sanitizedDownload?.status == .paused)
        #expect(sanitizedDownload?.lastError == nil)
    }

    @Test
    func testDownloadManagerValidateIndexedMissingFileUsesSessionError() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[440_token] Missing",
            manifest: indexedManifest(
                gid: "440",
                title: "Missing",
                pageHashes: ["sha256:missing"]
            )
        )

        let validation = await manager.validateImageData(gid: "440")

        #expect(validation == .missingFiles("Page 1 is missing."))
        let download = try #require(await manager.fetchDownload(gid: "440"))
        #expect(download.displayStatus == .error)
        #expect(download.status == .failed)
        #expect(download.lastError?.code == .fileOperationFailed)
        #expect(download.badge == .failed)
    }

    @Test
    func testDownloadManagerRetryIndexedDownloadUsesQueueIntent() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[450_token] Retry",
            manifest: indexedManifest(
                gid: "450",
                title: "Retry",
                pageHashes: ["sha256:done"]
            )
        )
        let blockingTask = Task<Void, Never> {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {}
        }
        defer { blockingTask.cancel() }
        await manager.testingInstallActiveTask(gid: "busy", task: blockingTask)

        let result = await manager.retry(gid: "450", mode: .redownload)

        guard case .success = result else {
            Issue.record("Retry should succeed, got \(result).")
            return
        }
        let download = try #require(await manager.fetchDownload(gid: "450"))
        #expect(queueStore.gids == ["450"])
        #expect(download.displayStatus == .queued)
        #expect(download.status == .queued)
        #expect(download.pendingOperation == nil)
    }

    @Test
    func testDownloadManagerRetryPagesIndexedDownloadUsesQueueIntent() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )

        try storage.ensureRootDirectory()
        let folderRelativePath = "[460_token] Retry Pages"
        try writeIndexedManifest(
            storage: storage,
            relativePath: folderRelativePath,
            manifest: indexedManifest(
                gid: "460",
                title: "Retry Pages",
                pageHashes: ["sha256:done", ""]
            )
        )
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try storage.writeFailedPages(
            .init(pages: [
                .init(
                    index: 2,
                    relativePath: "460_token_2.jpg",
                    failure: .init(
                        code: .networkingFailed,
                        message: "Network Error"
                    )
                )
            ]),
            folderURL: folderURL
        )
        let blockingTask = Task<Void, Never> {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {}
        }
        defer { blockingTask.cancel() }
        await manager.testingInstallActiveTask(gid: "busy", task: blockingTask)

        let result = await manager.retryPages(gid: "460", pageIndices: [2])

        guard case .success = result else {
            Issue.record("Retry pages should succeed, got \(result).")
            return
        }
        let download = try #require(await manager.fetchDownload(gid: "460"))
        #expect(queueStore.gids == ["460"])
        #expect(download.displayStatus == .queued)
        #expect(download.status == .queued)
        #expect(download.pendingOperation == nil)
        #expect(FileManager.default.fileExists(
            atPath: storage.failedPagesURL(folderURL: folderURL).path
        ) == false)
    }

    @Test
    func testDownloadManagerFailureSettlesQueueIntent() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[800_token] Failing",
            manifest: indexedManifest(
                gid: "800",
                title: "Failing",
                pageHashes: [""]
            )
        )
        await queueStore.enqueue("800")
        let download = try #require(await manager.fetchDownload(gid: "800"))

        await manager.persistFailure(
            error: .networkingFailed,
            context: .init(
                gid: "800",
                originalDownload: download,
                mode: .initial,
                hadReadableFiles: false
            )
        )

        let failedDownload = try #require(await manager.fetchDownload(gid: "800"))
        let badges = await manager.badges(for: ["800"])

        #expect(queueStore.gids == [])
        #expect(failedDownload.displayStatus == .error)
        #expect(failedDownload.status == .failed)
        #expect(failedDownload.lastError?.code == .networkingFailed)
        #expect(badges["800"] == .failed)
    }

    @Test
    func testDownloadManagerCompletionSettlesQueueIntent() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )

        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: "Complete")
        let folderRelativePath = storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detail.trimmedTitle
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: folderRelativePath,
            manifest: indexedManifest(
                gid: gallery.gid,
                title: "Complete",
                pageHashes: Array(
                    repeating: "sha256:done",
                    count: detail.pageCount
                )
            )
        )
        await queueStore.enqueue(gallery.gid)
        await manager.testingSetDownloadError(
            .init(code: .networkingFailed, message: "failed"),
            gid: gallery.gid
        )

        await manager.settleCompletedDownload(gid: gallery.gid)

        let completedDownload = try #require(
            await manager.fetchDownload(gid: gallery.gid)
        )

        #expect(queueStore.gids == [])
        #expect(completedDownload.displayStatus == .completed)
        #expect(completedDownload.lastError == nil)
    }

    @Test
    func testDownloadManagerPauseAndResumeMutateQueueIntent() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[820_token] Pausable",
            manifest: indexedManifest(
                gid: "820",
                title: "Pausable",
                pageHashes: ["sha256:1", ""]
            )
        )
        await queueStore.enqueue("820")
        await manager.testingSetDownloadError(
            .init(code: .networkingFailed, message: "failed"),
            gid: "820"
        )
        let activeTask = Task {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {}
        }
        await manager.testingInstallActiveTask(gid: "820", task: activeTask)

        let pauseResult = await manager.pause(gid: "820")

        guard case .success = pauseResult else {
            Issue.record("Pause should succeed, got \(pauseResult).")
            return
        }
        let pausedDownload = try #require(await manager.fetchDownload(gid: "820"))
        #expect(queueStore.gids == [])
        #expect(await manager.testingActiveGalleryID() == nil)
        #expect(pausedDownload.displayStatus == .inactive)
        #expect(pausedDownload.status == .paused)
        #expect(pausedDownload.lastError == nil)

        await manager.testingInstallActiveTask(gid: "busy", task: Task {})
        let resumeResult = await manager.resume(gid: "820")

        guard case .success = resumeResult else {
            Issue.record("Resume should succeed, got \(resumeResult).")
            return
        }
        let resumedDownload = try #require(await manager.fetchDownload(gid: "820"))
        #expect(queueStore.gids == ["820"])
        #expect(resumedDownload.displayStatus == .queued)
        #expect(resumedDownload.status == .queued)
        #expect(resumedDownload.lastError == nil)
    }

    @Test
    func testDownloadManagerSchedulesManifestQueueOrder() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )
        await manager.testingSetScheduledProcessHook { _ in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }

        try storage.ensureRootDirectory()
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[830_token] First",
            manifest: indexedManifest(
                gid: "830",
                title: "First",
                pageHashes: [""],
                modifiedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try writeIndexedManifest(
            storage: storage,
            relativePath: "[831_token] Newer",
            manifest: indexedManifest(
                gid: "831",
                title: "Newer",
                pageHashes: [""],
                modifiedAt: Date(timeIntervalSince1970: 200)
            )
        )
        await queueStore.enqueue("830")
        await queueStore.enqueue("831")

        await manager.testingScheduleNextIfNeeded()

        let scheduledGalleryIDs = await manager.testingScheduledGalleryIDs()
        #expect(scheduledGalleryIDs == ["830"])
        #expect(await manager.testingActiveGalleryID() == "830")

        guard case .success = await manager.pause(gid: "830") else {
            Issue.record("Pause should cancel the active queued test download.")
            return
        }
    }

    @Test
    func testDownloadManagerFlushProgressUpdatesManifestPageHash() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        let folderRelativePath = "[840_token] Progress"
        try writeIndexedManifest(
            storage: storage,
            relativePath: folderRelativePath,
            manifest: indexedManifest(
                gid: "840",
                title: "Progress",
                pageHashes: ["", ""]
            )
        )
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        let pageRelativePath = "840_token_1.jpg"
        try Data([0x01, 0x02, 0x03]).write(
            to: folderURL.appendingPathComponent(pageRelativePath),
            options: .atomic
        )
        var pendingResolvedPages = [
            DownloadManager.PageResult(
                index: 1,
                relativePath: pageRelativePath,
                imageURL: nil
            )
        ]
        var lastFlushDate = Date.distantPast

        try await manager.flushDownloadProgress(
            context: .init(gid: "840", folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )

        let manifest = try storage.readManifest(folderURL: folderURL)
        let download = try #require(await manager.fetchDownload(gid: "840"))

        #expect(pendingResolvedPages.isEmpty)
        #expect(manifest.pages[1]?.hasPrefix("sha256:") == true)
        #expect(manifest.pages[2] == "")
        #expect(download.completedPageCount == 1)
    }

    @Test
    func testDownloadManagerLoadInspectionUsesFinalFailedPagesSnapshot() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try storage.ensureRootDirectory()
        let folderRelativePath = "[\(gid)_token] Inspect"
        try writeIndexedManifest(
            storage: storage,
            relativePath: folderRelativePath,
            manifest: indexedManifest(
                gid: gid,
                title: "Inspect",
                pageHashes: ["sha256:done", ""]
            )
        )
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try storage.writeFailedPages(
            .init(
                pages: [
                    .init(
                        index: 2,
                        relativePath: "pages/0002.jpg",
                        failure: .init(code: .networkingFailed, message: "Network Error")
                    )
                ]
            ),
            folderURL: folderURL
        )

        let result = await manager.loadInspection(gid: gid)
        let inspection = try result.get()

        #expect(inspection.pages[0].status == .downloaded)
        #expect(inspection.pages[1].status == .failed)
        #expect(inspection.pages[1].failure?.code == .networkingFailed)
    }

    @Test
    func testDownloadManagerLoadLocalPageURLsPrefersCompletedFolderForCompletedDownload() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 11)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manifest = try indexedManifest(
            gid: gid,
            title: "Pause Race",
            pageHashes: ["sha256:1", "sha256:2"]
        )
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        let completedPageURL = completedFolderURL.appendingPathComponent("\(gid)_token_1.jpg")
        try Data([0x01]).write(to: completedPageURL, options: .atomic)
        try Data([0x02]).write(
            to: completedFolderURL.appendingPathComponent("\(gid)_token_2.jpg"),
            options: .atomic
        )

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == completedPageURL)
        #expect(pageURLs[3] == nil)
    }

    @Test
    func testDownloadManagerLoadLocalPageURLsUsesReadableCompletedPages() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 12)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(gid: gid, title: "Pause Race")
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: completedFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x09]).write(
            to: completedFolderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == completedFolderURL.appendingPathComponent("pages/0001.jpg"))
        #expect(pageURLs[2] == completedFolderURL.appendingPathComponent("pages/0002.jpg"))
    }

}

private extension DownloadManagerStorageTests {
    func writeIndexedManifest(
        storage: DownloadFileStorage,
        relativePath: String,
        manifest: DownloadManifest
    ) throws {
        let folderURL = storage.folderURL(relativePath: relativePath)
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(manifest, folderURL: folderURL)
        try FileManager.default.setAttributes(
            [.modificationDate: manifest.postedDate],
            ofItemAtPath: folderURL.path
        )
    }

    func indexedManifest(
        gid: String,
        title: String,
        pageHashes: [String],
        modifiedAt: Date = .now
    ) throws -> DownloadManifest {
        DownloadManifest(
            gid: gid,
            host: .ehentai,
            token: "token",
            title: title,
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            uploader: "Uploader",
            tags: [],
            postedDate: modifiedAt,
            rating: 4,
            pages: Dictionary(
                uniqueKeysWithValues:
                    pageHashes.enumerated().map { ($0.offset + 1, $0.element) }
            )
        )
    }

    func setFolderModificationDate(
        _ date: Date,
        storage: DownloadFileStorage,
        relativePath: String
    ) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: date],
            ofItemAtPath: storage.folderURL(relativePath: relativePath).path
        )
    }
}
