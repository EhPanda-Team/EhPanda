//
//  DownloadFilterAndBadgeTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

struct DownloadFilterAndBadgeTests: DownloadFeatureTestCase {
    @Test
    func testDownloadsFilterMatchesKeywordAndStatus() {
        let activeDownload = sampleDownload(
            gid: "101",
            title: "Alpha Archive",
            status: .downloading,
            completedPageCount: 2
        )
        let completedDownload = sampleDownload(
            gid: "202",
            title: "Beta Collection",
            status: .completed
        )

        var state = DownloadsReducer.State()
        state.downloads = [activeDownload, completedDownload]
        state.filter = .active
        state.keyword = "alpha"

        #expect(state.filteredDownloads == [activeDownload])
    }

    @Test
    func testSearchableTextDropsNilAndBlankFields() {
        let download = DownloadedGallery(
            gid: "111",
            host: .ehentai,
            token: "token",
            title: "Solo Title",
            jpnTitle: nil,
            uploader: nil,
            category: .doujinshi,
            tags: [],
            pageCount: 1,
            postedDate: .now,
            rating: 4,
            onlineCoverURL: nil,
            folderRelativePath: "111 - Solo Title",
            coverRelativePath: nil,
            status: .completed,
            completedPageCount: 1,
            lastDownloadedAt: .now,
            lastError: nil,
            downloadOptionsSnapshot: DownloadOptionsSnapshot(),
            remoteVersionSignature: "hash:v1",
            latestRemoteVersionSignature: "hash:v1"
        )

        #expect(download.searchableText == ["Solo Title", Category.doujinshi.value].joined(separator: " "))
        #expect(!download.searchableText.contains("  "))
        #expect(download.searchableText == download.searchableText.trimmingCharacters(in: .whitespaces))
    }

    @Test
    func testQueuedRetryWorkAppearsAsActiveDownloadBadge() {
        let queuedRedownload = sampleDownload(
            gid: "303",
            title: "Gamma Archive",
            status: .completed,
            completedPageCount: 12,
            pendingOperation: .redownload
        )

        #expect(queuedRedownload.pendingOperation == .redownload)
        #expect(queuedRedownload.badge == .queued)
        #expect(queuedRedownload.matches(filter: .active))
    }

    @Test
    func testQueuedRepairWorkAppearsAsActiveDownloadBadge() {
        let queuedRepair = sampleDownload(
            gid: "404",
            title: "Broken Archive",
            status: .missingFiles,
            completedPageCount: 3,
            pendingOperation: .repair
        )

        #expect(queuedRepair.pendingOperation == .repair)
        #expect(queuedRepair.badge == .queued)
        #expect(queuedRepair.matches(filter: .active))
    }

    @Test
    func testQueuedUpdateWorkAppearsAsActiveDownloadBadge() {
        let queuedUpdate = sampleDownload(
            gid: "414",
            title: "Updated Archive",
            status: .updateAvailable,
            completedPageCount: 12,
            latestRemoteVersionSignature: "hash:v2",
            pendingOperation: .update
        )

        #expect(queuedUpdate.pendingOperation == .update)
        #expect(queuedUpdate.badge == .queued)
        #expect(queuedUpdate.matches(filter: .active))
        #expect(queuedUpdate.matches(filter: .update) == false)
    }

    @Test
    func testQueuedResumedUpdateDoesNotPretendToBeInitialWork() {
        let resumedUpdate = sampleDownload(
            gid: "415",
            title: "Resumed Update",
            status: .queued,
            pageCount: 26,
            completedPageCount: 7,
            latestRemoteVersionSignature: "hash:v2"
        )

        #expect(resumedUpdate.pendingOperation == nil)
        #expect(resumedUpdate.isQueuedWorkItem)
        #expect(resumedUpdate.badge == .queued)
        #expect(resumedUpdate.matches(filter: .active))
    }

    @Test
    func testPausedDownloadAppearsAsActiveBadge() {
        let pausedDownload = sampleDownload(
            gid: "455",
            title: "Paused Archive",
            status: .paused,
            pageCount: 12,
            completedPageCount: 4
        )

        #expect(pausedDownload.badge == .paused(4, 12))
        #expect(pausedDownload.matches(filter: .active))
    }

    @Test
    func testActiveDownloadsDoNotExposeUpdateActions() {
        let downloadingUpdate = sampleDownload(
            gid: "456",
            title: "Downloading Update",
            status: .downloading,
            completedPageCount: 5,
            latestRemoteVersionSignature: "hash:v2"
        )
        let pausedUpdate = sampleDownload(
            gid: "457",
            title: "Paused Update",
            status: .paused,
            completedPageCount: 5,
            latestRemoteVersionSignature: "hash:v2"
        )
        let completedUpdate = sampleDownload(
            gid: "458",
            title: "Completed Update",
            status: .completed,
            latestRemoteVersionSignature: "hash:v2"
        )

        #expect(downloadingUpdate.canTriggerUpdate == false)
        #expect(pausedUpdate.canTriggerUpdate == false)
        #expect(completedUpdate.canTriggerUpdate)
    }

    @Test
    func testSearchPageRangeFilterOmitsInvertedBounds() {
        var filter = Filter()
        filter.advanced = true
        filter.pageRangeActivated = true
        filter.pageLowerBound = "50"
        filter.pageUpperBound = "10"

        let queryItems = queryItems(for: URLUtil.frontpageList(filter: filter))

        #expect(queryItems["f_sp"] == "on")
        #expect(queryItems["f_spf"] == nil)
        #expect(queryItems["f_spt"] == nil)
    }

    @Test
    func testSearchPageRangeFilterKeepsValidBounds() {
        var filter = Filter()
        filter.advanced = true
        filter.pageRangeActivated = true
        filter.pageLowerBound = "10"
        filter.pageUpperBound = "50"

        let queryItems = queryItems(for: URLUtil.frontpageList(filter: filter))

        #expect(queryItems["f_sp"] == "on")
        #expect(queryItems["f_spf"] == "10")
        #expect(queryItems["f_spt"] == "50")
    }

    @Test
    func testSearchPageRangeFilterKeepsSingleBounds() {
        var lowerOnlyFilter = Filter()
        lowerOnlyFilter.advanced = true
        lowerOnlyFilter.pageRangeActivated = true
        lowerOnlyFilter.pageLowerBound = "10"

        var upperOnlyFilter = Filter()
        upperOnlyFilter.advanced = true
        upperOnlyFilter.pageRangeActivated = true
        upperOnlyFilter.pageUpperBound = "50"

        let lowerOnlyQueryItems = queryItems(for: URLUtil.frontpageList(filter: lowerOnlyFilter))
        let upperOnlyQueryItems = queryItems(for: URLUtil.frontpageList(filter: upperOnlyFilter))

        #expect(lowerOnlyQueryItems["f_sp"] == "on")
        #expect(lowerOnlyQueryItems["f_spf"] == "10")
        #expect(lowerOnlyQueryItems["f_spt"] == nil)
        #expect(upperOnlyQueryItems["f_sp"] == "on")
        #expect(upperOnlyQueryItems["f_spf"] == nil)
        #expect(upperOnlyQueryItems["f_spt"] == "50")
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

    private func queryItems(for url: URL) -> [String: String] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value
            } ?? [:]
    }
}
