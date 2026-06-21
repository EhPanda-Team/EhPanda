//
//  DownloadBadgeSortTests.swift
//  EhPandaTests
//

import SwiftUI
import Foundation
import SFSafeSymbols
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
        #expect(badge.symbol == .playFill)
        #expect(badge.color == .green)

        let completedBadge = sampleDownload(
            gid: "481",
            title: "Done Archive",
            status: .completed,
            pageCount: 26
        ).badge

        #expect(completedBadge.symbol == .checkmarkCircleFill)
        #expect(completedBadge.color == .gray)
        #expect(completedBadge.progress.fraction == 1)
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
        #expect(partialDownload.badge.symbol == .exclamationmarkTriangleFill)
        #expect(partialDownload.badge.color == .yellow)
        #expect(
            partialDownload.badge.progress
                == DownloadProgress(completedPageCount: 5, pageCount: 12)
        )
    }

    @Test
    func testQueuedRepairKeepsQueuedStatusWhileMissingFilesStaysError() {
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

        #expect(queuedRepair.displayStatus == .queued)
        #expect(missingFilesWithoutQueuedWork.displayStatus == .error)
        #expect(missingFilesWithoutQueuedWork.lastError?.code == .fileOperationFailed)
    }

    @Test
    func testQueuedRedownloadKeepsQueuedSortPriority() {
        let completedDownload = sampleDownload(
            gid: "707",
            title: "Completed Archive",
            status: .completed,
            lastDownloadedDate: .distantFuture
        )

        let queuedRedownload = sampleDownload(
            gid: "808",
            title: "Queued Archive",
            status: .queued,
            completedPageCount: 12,
            lastDownloadedDate: .distantPast
        )

        let sortedDownloads = [completedDownload, queuedRedownload].sorted { lhs, rhs in
            if lhs.displayStatus != rhs.displayStatus {
                return lhs.displayStatus.sortPriority < rhs.displayStatus.sortPriority
            }
            return (lhs.lastDownloadedDate ?? .distantPast) > (rhs.lastDownloadedDate ?? .distantPast)
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
