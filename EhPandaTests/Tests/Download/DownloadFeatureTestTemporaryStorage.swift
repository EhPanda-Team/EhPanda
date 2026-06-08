//
//  DownloadFeatureTestTemporaryStorage.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

// MARK: - Temporary Storage Helpers

extension DownloadFeatureTestCase {
    func writeTemporaryManifestAndPages(
        storage: DownloadFileStorage, gid: String,
        manifest: DownloadManifest, pageCount: Int,
        omittingPage pageToOmit: Int? = nil,
        versionSignature _: String,
        mode _: DownloadStartMode = .redownload,
        pageSelection _: [Int]? = nil
    ) throws {
        let folderURL = storage.temporaryFolderURL(gid: gid)
        try? FileManager.default.removeItem(at: folderURL)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(
                Defaults.FilePath.downloadPages, isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(manifest).write(
            to: folderURL.appendingPathComponent(
                Defaults.FilePath.downloadManifest
            ),
            options: .atomic
        )
        try Data([0x00]).write(
            to: folderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        for index in 1...max(1, pageCount) where index != pageToOmit && pageCount > 0 {
            try Data([UInt8(index % 255)]).write(
                to: folderURL.appendingPathComponent(
                    "pages/\(String(format: "%04d", index)).jpg"
                ),
                options: .atomic
            )
        }
    }
}
