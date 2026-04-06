//
//  DownloadVersionSignatureTests.swift
//  EhPandaTests
//

import CoreData
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadVersionSignatureTests: DownloadFeatureTestCase {
    @Test
    func testDownloadManagerReconcileNormalizesFailedDownloadBeforeTempCleanup() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 31)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared, persistenceContainer: container)
        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .failed,
            completedPageCount: 0,
            pageCount: 2,
            lastError: .init(code: .networkingFailed, message: "Network Error")
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        let localPages = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(stored?.status == .partial)
        #expect(stored?.completedPageCount == 1)
        #expect(FileManager.default.fileExists(atPath: temporaryFolderURL.path))
        #expect(localPages[1] == temporaryFolderURL.appendingPathComponent("pages/0001.jpg"))
    }

    @MainActor
    @Test
    func testUpdateRemoteSignatureSkipsUpdateWhenStoredChainAndLatestHashDiffer() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 101)
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
            status: .completed,
            completedPageCount: 26,
            token: "token",
            remoteVersionSignature: "chain:\(gid):token"
        )

        let badge = await manager.updateRemoteSignature(gid: gid, latestSignature: "hash:new")
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(badge == .downloaded)
        #expect(stored?.status == .completed)
        #expect(stored?.remoteVersionSignature == "chain:\(gid):token")
        #expect(stored?.latestRemoteVersionSignature == "hash:new")
    }

    @MainActor
    @Test
    func testUpdateRemoteSignatureSkipsUpdateWhenStoredHashAndLatestNonOriginalChainDiffer() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 102)
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
            status: .completed,
            completedPageCount: 26,
            token: "token",
            remoteVersionSignature: "hash:old"
        )

        let badge = await manager.updateRemoteSignature(
            gid: gid,
            latestSignature: "chain:othergid:othertoken"
        )
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(badge == .downloaded)
        #expect(stored?.status == .completed)
        #expect(stored?.remoteVersionSignature == "hash:old")
        #expect(stored?.latestRemoteVersionSignature == "chain:othergid:othertoken")
    }

    @MainActor
    @Test
    func testUpdateRemoteSignatureCanonicalizesStoredHashToOriginalChainWithoutMarkingUpdate() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 103)
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
            status: .completed,
            completedPageCount: 26,
            token: "token",
            remoteVersionSignature: "hash:old"
        )

        let badge = await manager.updateRemoteSignature(
            gid: gid,
            latestSignature: "chain:\(gid):token"
        )
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(badge == .downloaded)
        #expect(stored?.status == .completed)
        #expect(stored?.remoteVersionSignature == "chain:\(gid):token")
        #expect(stored?.latestRemoteVersionSignature == "chain:\(gid):token")
    }

}
