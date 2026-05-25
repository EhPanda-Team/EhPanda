//
//  DownloadFileStorage.swift
//  EhPanda
//

import Foundation
import CryptoKit
import Synchronization

enum DownloadValidationState: Equatable {
    case valid
    case missingFiles(String)
}

struct DownloadResumeState: Codable, Equatable {
    let mode: DownloadStartMode
    let versionSignature: String
    let pageCount: Int
    let downloadOptions: DownloadOptionsSnapshot
    let pageSelection: [Int]?

    init(
        mode: DownloadStartMode,
        versionSignature: String,
        pageCount: Int,
        downloadOptions: DownloadOptionsSnapshot,
        pageSelection: [Int]? = nil
    ) {
        self.mode = mode
        self.versionSignature = versionSignature
        self.pageCount = pageCount
        self.downloadOptions = downloadOptions
        self.pageSelection = pageSelection
    }

    func matches(
        mode: DownloadStartMode,
        versionSignature: String,
        pageCount: Int,
        downloadOptions: DownloadOptionsSnapshot
    ) -> Bool {
        self.mode == mode
            && self.versionSignature == versionSignature
            && self.pageCount == pageCount
            && self.downloadOptions == downloadOptions
    }
}

struct DownloadFileStorage: Sendable {
    let rootURL: URL
    let fileManager: DownloadFileManager

    init(
        rootURL: URL? = FileUtil.downloadsDirectoryURL,
        fileManager: sending FileManager = .default
    ) {
        self.rootURL = rootURL
            ?? FileUtil.temporaryDirectory.appendingPathComponent(
                Defaults.FilePath.downloads,
                isDirectory: true
            )
        self.fileManager = DownloadFileManager(fileManager)
    }

    func ensureRootDirectory() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableRootURL = rootURL
        try? mutableRootURL.setResourceValues(resourceValues)
    }

    func folderURL(relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath, isDirectory: true)
    }

    func validatedChildURL(
        root: URL, relativePath: String
    ) -> URL? {
        let resolved = root
            .appendingPathComponent(relativePath)
            .standardizedFileURL
        guard resolved.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            return nil
        }
        return resolved
    }

    func manifestURL(relativePath: String) -> URL {
        folderURL(relativePath: relativePath)
            .appendingPathComponent(Defaults.FilePath.downloadManifest)
    }

    func temporaryFolderURL(gid: String) -> URL {
        rootURL.appendingPathComponent(".tmp-\(gid)", isDirectory: true)
    }

    func temporaryFolderExists(gid: String) -> Bool {
        fileManager.fileExists(atPath: temporaryFolderURL(gid: gid).path)
    }

    func removeTemporaryFolder(gid: String) throws {
        let targetURL = temporaryFolderURL(gid: gid)
        guard fileManager.fileExists(atPath: targetURL.path) else { return }
        try fileManager.removeItem(at: targetURL)
    }

    func resumeStateURL(folderURL: URL) -> URL {
        folderURL.appendingPathComponent(Defaults.FilePath.downloadResumeState)
    }

    func failedPagesURL(folderURL: URL) -> URL {
        folderURL.appendingPathComponent(Defaults.FilePath.downloadFailedPages)
    }

    func writeResumeState(_ state: DownloadResumeState, folderURL: URL) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: resumeStateURL(folderURL: folderURL), options: .atomic)
    }

    func readResumeState(folderURL: URL) throws -> DownloadResumeState {
        let data = try Data(contentsOf: resumeStateURL(folderURL: folderURL))
        return try JSONDecoder().decode(DownloadResumeState.self, from: data)
    }

    func writeFailedPages(_ snapshot: DownloadFailedPagesSnapshot, folderURL: URL) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: failedPagesURL(folderURL: folderURL), options: .atomic)
    }

    func readFailedPages(folderURL: URL) throws -> DownloadFailedPagesSnapshot {
        let data = try Data(contentsOf: failedPagesURL(folderURL: folderURL))
        return try JSONDecoder().decode(DownloadFailedPagesSnapshot.self, from: data)
    }

    func removeFailedPages(folderURL: URL) throws {
        let url = failedPagesURL(folderURL: folderURL)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func existingPageRelativePaths(
        folderURL: URL,
        expectedPageCount: Int
    ) -> [Int: String] {
        let pagesFolderURL = folderURL.appendingPathComponent(
            Defaults.FilePath.downloadPages,
            isDirectory: true
        )
        guard let pageURLs = try? fileManager.contentsOfDirectory(
            at: pagesFolderURL,
            includingPropertiesForKeys: nil
        ) else {
            return [:]
        }

        var relativePaths = [Int: String]()
        for pageURL in pageURLs {
            guard sanitizeAssetFileIfNeeded(at: pageURL) else {
                continue
            }
            let filename = pageURL.deletingPathExtension().lastPathComponent
            guard let index = Int(filename),
                  index >= 1,
                  index <= expectedPageCount
            else {
                continue
            }
            relativePaths[index] = Defaults.FilePath.downloadPages + "/\(pageURL.lastPathComponent)"
        }
        return relativePaths
    }

    func existingCoverRelativePath(folderURL: URL) -> String? {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        return fileURLs
            .first(where: {
                $0.lastPathComponent.hasPrefix("cover.")
                    && sanitizeAssetFileIfNeeded(at: $0)
            })?
            .lastPathComponent
    }

    func makeFolderRelativePath(gid: String, title: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:")
            .union(.controlCharacters)
        let sanitizedScalars = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { invalidCharacters.contains($0) ? " " : String($0) }
            .joined()
        let collapsedWhitespace = sanitizedScalars.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        let trimmedSlug = collapsedWhitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: "[\\s.]+$",
                with: "",
                options: .regularExpression
            )
        let limitedSlug = String(trimmedSlug.prefix(96))
            .replacingOccurrences(
                of: "[\\s.]+$",
                with: "",
                options: .regularExpression
            )
        let fallbackTitle = limitedSlug.isEmpty ? "Gallery" : limitedSlug
        return "\(gid) - \(fallbackTitle)"
    }

    func makePageRelativePath(index: Int, fileExtension: String) -> String {
        let ext = fileExtension.lowercased()
        let paddedIndex = String(format: "%04d", index)
        return Defaults.FilePath.downloadPages + "/\(paddedIndex).\(ext)"
    }

    func makeCoverRelativePath(fileExtension: String) -> String {
        "cover.\(fileExtension.lowercased())"
    }

    func writeManifest(_ manifest: DownloadManifest, folderURL: URL) throws {
        let data = try JSONEncoder().encode(manifest)
        let fileURL = folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
        try data.write(to: fileURL, options: .atomic)
    }

    func readManifest(folderURL: URL) throws -> DownloadManifest {
        let manifestURL = folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(DownloadManifest.self, from: data)
    }

    func fileHash(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024)
            guard let data, !data.isEmpty else { break }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "sha256:\(hex)"
    }

    @discardableResult
    func sanitizeAssetFileIfNeeded(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            return canReadNonEmptyFile(at: url)
        }

        let isRegularFile = (attributes[.type] as? FileAttributeType).map { $0 == .typeRegular } ?? true
        guard isRegularFile else {
            try? fileManager.removeItem(at: url)
            return false
        }
        guard let fileSize = (attributes[.size] as? NSNumber)?.intValue else { return false }
        guard fileSize > 0 else {
            try? fileManager.removeItem(at: url)
            return false
        }

        return true
    }

    private func canReadNonEmptyFile(at url: URL) -> Bool {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            return try handle.read(upToCount: 1)?.isEmpty == false
        } catch {
            return false
        }
    }
}

final class DownloadFileManager: Sendable {
    private let fileManager: Mutex<FileManager>

    init(_ fileManager: sending FileManager) {
        self.fileManager = Mutex(fileManager)
    }

    func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool
    ) throws {
        try fileManager.withLock {
            try $0.createDirectory(
                at: url,
                withIntermediateDirectories: createIntermediates
            )
        }
    }

    func fileExists(atPath path: String) -> Bool {
        fileManager.withLock { $0.fileExists(atPath: path) }
    }

    func removeItem(at url: URL) throws {
        try fileManager.withLock {
            try $0.removeItem(at: url)
        }
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?
    ) throws -> [URL] {
        try fileManager.withLock {
            try $0.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys
            )
        }
    }

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try fileManager.withLock {
            try $0.attributesOfItem(atPath: path)
        }
    }

    func replaceItemAt(_ originalItemURL: URL, withItemAt newItemURL: URL) throws -> URL? {
        try fileManager.withLock {
            try $0.replaceItemAt(originalItemURL, withItemAt: newItemURL)
        }
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.withLock {
            try $0.moveItem(at: sourceURL, to: destinationURL)
        }
    }

    func linkItem(at sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.withLock {
            try $0.linkItem(at: sourceURL, to: destinationURL)
        }
    }

    func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.withLock {
            try $0.copyItem(at: sourceURL, to: destinationURL)
        }
    }
}
