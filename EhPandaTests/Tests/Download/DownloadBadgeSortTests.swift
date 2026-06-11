//
//  DownloadBadgeSortTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

struct DownloadBadgeSortTests: DownloadFeatureTestCase {
    @Test
    func testBadgeSeparatesDisplayStatusFromProgress() {
        let activeDownload = sampleDownload(
            gid: "479",
            title: "Active Archive",
            status: .downloading,
            pageCount: 26,
            completedPageCount: 7
        )
        let badge = activeDownload.badge

        #expect(badge.status == activeDownload.displayStatus)
        #expect(badge.progress == DownloadProgress(completedPageCount: 7, pageCount: 26))
        #expect(badge.failure == nil)
        #expect(badge.statusText == "Downloading")
        #expect(badge.progressText == "7/26")
        #expect(badge.text == "Downloading 7/26")

        let completedBadge = sampleDownload(
            gid: "481",
            title: "Done Archive",
            status: .completed,
            pageCount: 26
        ).badge

        #expect(completedBadge.progressText == nil)
        #expect(completedBadge.text == completedBadge.statusText)
    }

    @Test
    func testPartialDownloadBadgeUsesNeedsAttentionCopy() {
        let partialDownload = sampleDownload(
            gid: "480",
            title: "Incomplete Archive",
            status: .partial,
            pageCount: 12,
            completedPageCount: 5
        )
        #expect(partialDownload.badge.text == "Needs Attention 5/12")
        #expect(DownloadListFilter.failed.title == "Needs Attention")
    }

    @Test
    func testQueuedRedownloadDoesNotLeakIntoCompletedFilter() {
        let queuedRedownload = sampleDownload(
            gid: "505",
            title: "Delta Archive",
            status: .queued,
            completedPageCount: 12
        )

        #expect(queuedRedownload.matches(filter: .completed) == false)
        #expect(queuedRedownload.matches(filter: .update) == false)
    }

    @Test
    func testQueuedRepairDoesNotLeakIntoFailedFilter() {
        let queuedRepair = sampleDownload(
            gid: "606",
            title: "Repair Archive",
            status: .queued,
            completedPageCount: 3
        )
        let missingFilesWithoutQueuedWork = sampleDownload(
            gid: "607",
            title: "Actually Missing",
            status: .missingFiles,
            pageCount: 4,
            completedPageCount: 0
        )

        #expect(queuedRepair.matches(filter: .failed) == false)
        #expect(queuedRepair.matches(filter: .update) == false)
        #expect(missingFilesWithoutQueuedWork.badge.failure == .missingFiles)
        #expect(missingFilesWithoutQueuedWork.matches(filter: .failed))
    }

    @Test
    func testQueuedRedownloadKeepsQueuedSortPriority() {
        let completedDownload = sampleDownload(
            gid: "707",
            title: "Completed Archive",
            status: .completed,
            lastDownloadedAt: .distantFuture
        )

        let queuedRedownload = sampleDownload(
            gid: "808",
            title: "Queued Archive",
            status: .queued,
            completedPageCount: 12,
            lastDownloadedAt: .distantPast
        )

        let sortedDownloads = [completedDownload, queuedRedownload].sorted { lhs, rhs in
            if lhs.displayStatus != rhs.displayStatus {
                return lhs.displayStatus.sortPriority < rhs.displayStatus.sortPriority
            }
            return (lhs.lastDownloadedAt ?? .distantPast) > (rhs.lastDownloadedAt ?? .distantPast)
        }

        #expect(queuedRedownload.displayStatus == .queued)
        #expect(completedDownload.displayStatus == .completed)
        #expect(sortedDownloads.map(\.gid) == [queuedRedownload.gid, completedDownload.gid])
    }

    @Test
    func testInProgressDownloadUsesFinalCoverURL() throws {
        let gid = "811"
        let folderURL = FileUtil.downloadsDirectoryURL
            .appendingPathComponent("[\(gid)_token] Local Cover Archive", isDirectory: true)
        let coverURL = folderURL.appendingPathComponent("\(gid)_token_cover.jpg")
        let download = sampleDownload(
            gid: gid,
            title: "Local Cover Archive",
            status: .downloading,
            completedPageCount: 3,
            folderURL: folderURL,
            localCoverURL: coverURL
        )

        try? FileManager.default.removeItem(at: folderURL)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([0xFF, 0xD8, 0xFF]).write(to: coverURL, options: .atomic)

        #expect(download.coverURL == coverURL)
    }

    @Test
    func testActiveDownloadDoesNotNormalizeWhileTaskIsStillRunning() {
        let activeDownload = sampleDownload(
            gid: "810",
            title: "Running Archive",
            status: .downloading,
            completedPageCount: 3
        )

        #expect(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: activeDownload.gid,
                hasActiveTask: true
            ) == false
        )
        #expect(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: nil,
                hasActiveTask: false
            )
        )
        #expect(
            activeDownload.needsInterruptedDownloadNormalization(
                activeGalleryID: "another-gid",
                hasActiveTask: true
            )
        )
    }
}
