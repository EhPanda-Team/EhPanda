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
            status: .completed,
            completedPageCount: 12,
            pendingOperation: .redownload
        )

        #expect(queuedRedownload.matches(filter: .completed) == false)
        #expect(queuedRedownload.matches(filter: .update) == false)
    }

    @Test
    func testQueuedRepairDoesNotLeakIntoFailedFilter() {
        let queuedRepair = sampleDownload(
            gid: "606",
            title: "Repair Archive",
            status: .missingFiles,
            completedPageCount: 3,
            pendingOperation: .repair
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
        #expect(missingFilesWithoutQueuedWork.badge == .missingFiles)
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
            status: .completed,
            completedPageCount: 12,
            lastDownloadedAt: .distantPast,
            pendingOperation: .redownload
        )

        let sortedDownloads = [completedDownload, queuedRedownload].sorted { lhs, rhs in
            if lhs.sortPriority != rhs.sortPriority {
                return lhs.sortPriority < rhs.sortPriority
            }
            return (lhs.lastDownloadedAt ?? .distantPast) > (rhs.lastDownloadedAt ?? .distantPast)
        }

        #expect(queuedRedownload.sortPriority == 1)
        #expect(completedDownload.sortPriority == 7)
        #expect(sortedDownloads.map(\.gid) == [queuedRedownload.gid, completedDownload.gid])
    }

    @Test
    func testInProgressDownloadUsesFinalCoverURL() throws {
        let gid = "811"
        let download = sampleDownload(
            gid: gid,
            title: "Local Cover Archive",
            status: .downloading,
            completedPageCount: 3
        )

        let rootURL = FileUtil.downloadsDirectoryURL
        let folderURL = rootURL.appendingPathComponent(
            "\(gid) - Local Cover Archive",
            isDirectory: true
        )
        try? FileManager.default.removeItem(at: folderURL)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let coverURL = folderURL.appendingPathComponent("cover.jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: coverURL, options: .atomic)

        #expect(download.resolvedCoverURL(rootURL: rootURL) == coverURL)
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
