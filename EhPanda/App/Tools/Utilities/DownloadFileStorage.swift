//
//  DownloadFileStorage.swift
//  EhPanda
//

import Foundation
import CryptoKit

enum DownloadValidationState: Equatable, Sendable {
    case valid
    case missingFiles(String)
}

struct DownloadFolderRecord: Equatable, Sendable {
    let relativePath: String
    let folderURL: URL
    let manifest: DownloadManifest
    let modifiedAt: Date?
}

struct DownloadFileStorage: Sendable {
    let rootURL: URL
    let fileManager: DownloadFileManager

    init(
        rootURL: URL = FileUtil.downloadsDirectoryURL,
        fileManager: sending FileManager = .default
    ) {
        self.rootURL = rootURL
        self.fileManager = DownloadFileManager(fileManager)
    }

    func ensureRootDirectory() throws {
        try fileManager.operate {
            try $0.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
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

    func queueURL() -> URL {
        rootURL.appendingPathComponent(".queue.json")
    }

    func failedPagesURL(folderURL: URL) -> URL {
        folderURL.appendingPathComponent(Defaults.FilePath.downloadFailedPages)
    }

    func writeFailedPages(_ snapshot: DownloadFailedPagesSnapshot, folderURL: URL) throws {
        try writeJSON(snapshot, to: failedPagesURL(folderURL: folderURL))
    }

    func readFailedPages(folderURL: URL) throws -> DownloadFailedPagesSnapshot {
        try readJSON(DownloadFailedPagesSnapshot.self, from: failedPagesURL(folderURL: folderURL))
    }

    func removeFailedPages(folderURL: URL) throws {
        let url = failedPagesURL(folderURL: folderURL)
        try fileManager.operate {
            guard $0.fileExists(atPath: url.path) else { return }
            try $0.removeItem(at: url)
        }
    }

    func existingPageRelativePaths(
        folderURL: URL,
        expectedPageCount: Int
    ) -> [Int: String] {
        var relativePaths = existingLegacyPageRelativePaths(
            folderURL: folderURL,
            expectedPageCount: expectedPageCount
        )
        guard let finalPageURLs = try? fileManager.operate({
            try $0.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil
            )
        }) else {
            return relativePaths
        }

        for pageURL in finalPageURLs {
            guard let index = finalPageIndex(from: pageURL),
                  index >= 1,
                  index <= expectedPageCount,
                  sanitizeAssetFileIfNeeded(at: pageURL)
            else {
                continue
            }
            relativePaths[index] = pageURL.lastPathComponent
        }
        return relativePaths
    }

    private func existingLegacyPageRelativePaths(
        folderURL: URL,
        expectedPageCount: Int
    ) -> [Int: String] {
        let pagesFolderURL = folderURL.appendingPathComponent(
            Defaults.FilePath.downloadPages,
            isDirectory: true
        )
        guard let pageURLs = try? fileManager.operate({
            try $0.contentsOfDirectory(
                at: pagesFolderURL,
                includingPropertiesForKeys: nil
            )
        }) else {
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

    private func finalPageIndex(from pageURL: URL) -> Int? {
        let filename = pageURL.deletingPathExtension().lastPathComponent
        guard let separatorIndex = filename.lastIndex(of: "_") else {
            return nil
        }
        let indexStart = filename.index(after: separatorIndex)
        return Int(filename[indexStart...])
    }

    func existingCoverRelativePath(folderURL: URL) -> String? {
        guard let fileURLs = try? fileManager.operate({
            try $0.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil
            )
        }) else {
            return nil
        }

        return fileURLs
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .first(where: {
                let filename = $0.deletingPathExtension().lastPathComponent
                return (filename == "cover" || filename.hasSuffix("_cover"))
                    && sanitizeAssetFileIfNeeded(at: $0)
            })?
            .lastPathComponent
    }

    func makeFolderRelativePath(gid: String, title: String) -> String {
        "\(gid) - \(normalizedFolderTitle(title))"
    }

    func makeFolderRelativePath(gid: String, token: String, title: String) -> String {
        "[\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))] \(normalizedFolderTitle(title))"
    }

    private func normalizedFolderTitle(_ title: String) -> String {
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
        return fallbackTitle
    }

    private func normalizedIdentityComponent(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\[]:")
            .union(.controlCharacters)
            .union(.whitespacesAndNewlines)
        let sanitized = value.unicodeScalars
            .map { invalidCharacters.contains($0) ? "_" : String($0) }
            .joined()
        return sanitized.isEmpty ? "unknown" : sanitized
    }

    func makePageRelativePath(index: Int, fileExtension: String) -> String {
        let ext = fileExtension.lowercased()
        let paddedIndex = String(format: "%04d", index)
        return Defaults.FilePath.downloadPages + "/\(paddedIndex).\(ext)"
    }

    func makeCoverRelativePath(fileExtension: String) -> String {
        "cover.\(fileExtension.lowercased())"
    }

    func makePageRelativePath(gid: String, token: String, index: Int, fileExtension: String) -> String {
        [
            normalizedIdentityComponent(gid),
            normalizedIdentityComponent(token),
            String(index)
        ].joined(separator: "_") + ".\(fileExtension.lowercased())"
    }

    func makeCoverRelativePath(gid: String, token: String, fileExtension: String) -> String {
        "\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))_cover.\(fileExtension.lowercased())"
    }

    func existingPageFileURL(folderURL: URL, gid: String, token: String, index: Int) -> URL? {
        existingAssetFileURL(
            folderURL: folderURL,
            prefix: "\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))_\(index)."
        )
    }

    func existingCoverFileURL(folderURL: URL, gid: String, token: String) -> URL? {
        existingAssetFileURL(
            folderURL: folderURL,
            prefix: "\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))_cover."
        )
    }

    private func existingAssetFileURL(folderURL: URL, prefix: String) -> URL? {
        guard let fileURLs = try? fileManager.operate({
            try $0.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
            )
        }) else {
            return nil
        }

        return fileURLs
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .first(where: {
                $0.lastPathComponent.hasPrefix(prefix)
                    && sanitizeAssetFileIfNeeded(at: $0)
            })
    }

    func writeManifest(_ manifest: DownloadManifest, folderURL: URL) throws {
        try writeJSON(manifest, to: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest))
    }

    func readManifest(folderURL: URL) throws -> DownloadManifest {
        try readJSON(DownloadManifest.self, from: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest))
    }

    func scanDownloadFolders() throws -> [DownloadFolderRecord] {
        guard fileManager.operate({ $0.fileExists(atPath: rootURL.path) }) else {
            return []
        }

        let folderURLs = try fileManager.operate {
            try $0.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        }

        return folderURLs.compactMap { folderURL in
            let resourceValues = try? folderURL.resourceValues(
                forKeys: [.isDirectoryKey, .contentModificationDateKey]
            )
            guard resourceValues?.isDirectory == true,
                  let manifest = try? readManifest(folderURL: folderURL)
            else {
                return nil
            }
            return DownloadFolderRecord(
                relativePath: folderURL.lastPathComponent,
                folderURL: folderURL,
                manifest: manifest,
                modifiedAt: resourceValues?.contentModificationDate
            )
        }
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
        guard fileManager.operate({ $0.fileExists(atPath: url.path) }) else { return false }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.operate { try $0.attributesOfItem(atPath: url.path) }
        } catch {
            return canReadNonEmptyFile(at: url)
        }

        let isRegularFile = (attributes[.type] as? FileAttributeType).map { $0 == .typeRegular } ?? true
        guard isRegularFile else {
            try? fileManager.operate { try $0.removeItem(at: url) }
            return false
        }
        guard let fileSize = (attributes[.size] as? NSNumber)?.intValue else { return false }
        guard fileSize > 0 else {
            try? fileManager.operate { try $0.removeItem(at: url) }
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
