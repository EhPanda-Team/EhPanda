//
//  DownloadManagerStorageTests.swift
//  EhPandaTests
//

import CoreData
import Kingfisher
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadManagerStorageTests: DownloadFeatureTestCase {
    @Test
    func testDownloadManagerLoadInspectionUsesTemporaryFailedPagesSnapshot() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: .shared,
            persistenceContainer: container
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .failed,
            completedPageCount: 1,
            pageCount: 2
        )

        let temporaryFolderURL = rootURL.appendingPathComponent(".tmp-\(gid)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try JSONEncoder().encode(
            DownloadFailedPagesSnapshot(
                pages: [
                    .init(
                        index: 2,
                        relativePath: "pages/0002.jpg",
                        failure: .init(code: .networkingFailed, message: "Network Error")
                    )
                ]
            )
        )
        .write(
            to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadFailedPages),
            options: .atomic
        )

        let result = await manager.loadInspection(gid: gid)
        let inspection = try result.get()

        #expect(inspection.pages[0].status == .downloaded)
        #expect(inspection.pages[1].status == .failed)
        #expect(inspection.pages[1].failure?.code == .networkingFailed)
    }

    @Test
    func testDownloadManagerLoadLocalPageURLsPrefersCompletedFolderForCompletedDownload() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 11)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            persistenceContainer: container
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .completed,
            completedPageCount: 2,
            pageCount: 2
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
        let completedPageURL = completedFolderURL.appendingPathComponent("pages/0001.jpg")
        try Data([0x01]).write(to: completedPageURL, options: .atomic)
        try Data([0x02]).write(
            to: completedFolderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let temporaryPageURL = temporaryFolderURL.appendingPathComponent("pages/0001.jpg")
        try Data([0x02]).write(to: temporaryPageURL, options: .atomic)

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == completedPageURL)
        #expect(pageURLs[1] != temporaryPageURL)
        #expect(pageURLs[3] == nil)
    }

    @Test
    func testDownloadManagerLoadLocalPageURLsMergesReadableCompletedPagesWithTemporaryPages() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 12)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            persistenceContainer: container
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .downloading,
            completedPageCount: 2,
            pageCount: 2
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

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let temporaryPageURL = temporaryFolderURL.appendingPathComponent("pages/0002.jpg")
        try Data([0x02]).write(to: temporaryPageURL, options: .atomic)

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == completedFolderURL.appendingPathComponent("pages/0001.jpg"))
        #expect(pageURLs[2] == temporaryPageURL)
    }

}
