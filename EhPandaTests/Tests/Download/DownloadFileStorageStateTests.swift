//
//  DownloadFileStorageStateTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

struct DownloadFileStorageStateTests {
    @Test
    func testWriteReadAndRemoveFailedPagesSnapshot() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let snapshot = DownloadFailedPagesSnapshot(
            pages: [
                .init(
                    index: 3,
                    relativePath: "pages/0003.jpg",
                    failure: .init(code: .networkingFailed, message: "Network Error")
                )
            ]
        )

        try storage.writeFailedPages(snapshot, folderURL: folderURL)
        #expect(try storage.readFailedPages(folderURL: folderURL) == snapshot)

        try storage.removeFailedPages(folderURL: folderURL)
        do {
            _ = try storage.readFailedPages(folderURL: folderURL)
            Issue.record("Expected readFailedPages to throw after removing the snapshot.")
        } catch {
        }
    }
}

private extension DownloadFileStorageStateTests {
    func makeStorage() -> (DownloadFileStorage, URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (
            DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            rootURL
        )
    }
}
