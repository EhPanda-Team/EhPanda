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
    let parentFolderName: String
}

struct DownloadScanResult: Equatable, Sendable {
    let records: [DownloadFolderRecord]
    let userFolders: [String]
}

struct DownloadFileStorage: Sendable {
    private static let maxFolderComponentByteCount = 255

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

    func userFolderURL(name: String) -> URL {
        rootURL.appendingPathComponent(name, isDirectory: true)
    }

    func rootRelativePath(forFolderURL url: URL) -> String? {
        let rootPath = rootURL.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return nil }
        return String(path.dropFirst(rootPath.count))
    }

    func parentFolderName(forFolderURL url: URL) -> String? {
        guard let relativePath = rootRelativePath(forFolderURL: url) else { return nil }
        let components = relativePath.split(separator: "/")
        guard components.count >= 2 else { return nil }
        return String(components[0])
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

    func existingPageRelativePaths(folderURL: URL, manifest: DownloadManifest) -> [Int: String] {
        let fileURLs = existingAssetFileURLs(folderURL: folderURL)
        return manifest.pages.keys.sorted().reduce(into: [:]) { result, index in
            guard let fileURL = existingAssetFileURL(
                in: fileURLs,
                prefix: pageFilePrefix(
                    gid: manifest.gid,
                    token: manifest.token,
                    index: index
                )
            ) else { return }
            result[index] = fileURL.lastPathComponent
        }
    }

    func imageURLs(folderURL: URL, manifest: DownloadManifest) -> [Int: URL] {
        existingPageRelativePaths(folderURL: folderURL, manifest: manifest)
            .reduce(into: [Int: URL]()) { result, entry in
                result[entry.key] = folderURL.appendingPathComponent(entry.value)
            }
    }

    func localCoverURL(folderURL: URL, manifest: DownloadManifest) -> URL? {
        existingCoverFileURL(
            folderURL: folderURL,
            gid: manifest.gid,
            token: manifest.token
        )
    }

    func existingCoverRelativePath(folderURL: URL, manifest: DownloadManifest) -> String? {
        localCoverURL(folderURL: folderURL, manifest: manifest)?
            .lastPathComponent
    }

    func makeFolderRelativePath(gid: String, token: String, title: String) -> String {
        let prefix = galleryFolderNamePrefix(gid: gid, token: token)
        let titleByteCount = max(Self.maxFolderComponentByteCount - prefix.utf8.count, 0)
        return "\(prefix)\(normalizedFolderTitle(title, maximumUTF8ByteCount: titleByteCount))"
    }

    func galleryFolderNamePrefix(gid: String, token: String) -> String {
        "[\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))] "
    }

    func galleryFolderURLs(gid: String, token: String) -> [URL] {
        guard fileManager.operate({ $0.fileExists(atPath: rootURL.path) }) else {
            return []
        }
        let prefix = galleryFolderNamePrefix(gid: gid, token: token)
        return directoryURLs(in: rootURL)
            .flatMap { directoryURLs(in: $0) }
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
    }

    static func isGalleryFolderLikeName(_ name: String) -> Bool {
        name.range(of: #"^\[[^\]]*_[^\]]*\] "#, options: .regularExpression) != nil
    }

    func isGalleryFolderLikeName(_ name: String) -> Bool {
        Self.isGalleryFolderLikeName(name)
    }

    static func normalizedUserFolderName(_ name: String) -> String? {
        guard let limitedName = normalizedFolderName(
            name,
            trimsLeadingDots: true,
            fallback: nil,
            maximumUTF8ByteCount: maxFolderComponentByteCount
        ) else {
            return nil
        }
        guard !limitedName.isEmpty, !isGalleryFolderLikeName(limitedName) else {
            return nil
        }
        return limitedName
    }

    func normalizedUserFolderName(_ name: String) -> String? {
        Self.normalizedUserFolderName(name)
    }

    private func normalizedFolderTitle(
        _ title: String,
        maximumUTF8ByteCount: Int
    ) -> String {
        Self.normalizedFolderName(
            title,
            trimsLeadingDots: false,
            fallback: "Gallery",
            maximumUTF8ByteCount: maximumUTF8ByteCount
        ) ?? "Gallery"
    }

    private static func normalizedFolderName(
        _ name: String,
        trimsLeadingDots: Bool,
        fallback: String?,
        maximumUTF8ByteCount: Int
    ) -> String? {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:")
            .union(.controlCharacters)
        let sanitizedScalars = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { invalidCharacters.contains($0) ? " " : String($0) }
            .joined()
        let collapsedWhitespace = sanitizedScalars.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        let trimPattern = trimsLeadingDots
            ? "^[\\s.]+|[\\s.]+$"
            : "^\\s+|[\\s.]+$"
        let trimmedName = collapsedWhitespace.replacingOccurrences(
            of: trimPattern,
            with: "",
            options: .regularExpression
        )
        let limitedName = trimmedName
            .truncatedToUTF8ByteCount(maximumUTF8ByteCount)
            .replacingOccurrences(
                of: "[\\s.]+$",
                with: "",
                options: .regularExpression
            )
        if limitedName.isEmpty {
            return fallback
        }
        return limitedName
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
            prefix: pageFilePrefix(gid: gid, token: token, index: index)
        )
    }

    func existingCoverFileURL(folderURL: URL, gid: String, token: String) -> URL? {
        existingAssetFileURL(
            folderURL: folderURL,
            prefix: coverFilePrefix(gid: gid, token: token)
        )
    }

    private func existingAssetFileURL(folderURL: URL, prefix: String) -> URL? {
        existingAssetFileURL(
            in: existingAssetFileURLs(folderURL: folderURL),
            prefix: prefix
        )
    }

    private func existingAssetFileURLs(folderURL: URL) -> [URL] {
        guard let fileURLs = try? fileManager.operate({
            try $0.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
            )
        }) else {
            return []
        }

        return fileURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    private func existingAssetFileURL(in fileURLs: [URL], prefix: String) -> URL? {
        fileURLs
            .first(where: {
                $0.lastPathComponent.hasPrefix(prefix)
                    && sanitizeAssetFileIfNeeded(at: $0)
            })
    }

    private func pageFilePrefix(gid: String, token: String, index: Int) -> String {
        "\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))_\(index)."
    }

    private func coverFilePrefix(gid: String, token: String) -> String {
        "\(normalizedIdentityComponent(gid))_\(normalizedIdentityComponent(token))_cover."
    }

    func writeManifest(_ manifest: DownloadManifest, folderURL: URL) throws {
        try writeJSON(manifest, to: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest))
    }

    func readManifest(folderURL: URL) throws -> DownloadManifest {
        let manifest = try readJSON(
            DownloadManifest.self,
            from: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
        )
        try validateDecodedManifest(manifest)
        return manifest
    }

    private func validateDecodedManifest(_ manifest: DownloadManifest) throws {
        guard manifest.pages.isEmpty == false else {
            throw manifestCorruptedError()
        }
        guard manifest.pages.keys.sorted() == Array(1...manifest.pages.count) else {
            throw manifestCorruptedError()
        }
    }

    private func manifestCorruptedError() -> AppError {
        .fileOperationFailed(L10n.Localizable.DownloadFileStorage.Validation.manifestCorrupted)
    }

    func scanDownloadFolders() throws -> [DownloadFolderRecord] {
        try scanDownloads().records
    }

    func scanDownloads() throws -> DownloadScanResult {
        guard fileManager.operate({ $0.fileExists(atPath: rootURL.path) }) else {
            return .init(records: [], userFolders: [])
        }

        var records = [DownloadFolderRecord]()
        var userFolders = [String]()
        for folderURL in directoryURLs(in: rootURL) {
            let folderName = folderURL.lastPathComponent
            // Gallery folders dropped directly under the root, including broken
            // manifest-less ones, are invisible to the app and never become
            // user folders.
            guard (try? readManifest(folderURL: folderURL)) == nil else { continue }
            guard !isGalleryFolderLikeName(folderName) else { continue }

            userFolders.append(folderName)
            for galleryFolderURL in directoryURLs(in: folderURL) {
                guard let manifest = try? readManifest(folderURL: galleryFolderURL) else {
                    continue
                }
                records.append(
                    galleryFolderRecord(
                        folderURL: galleryFolderURL,
                        manifest: manifest,
                        parentFolderName: folderName
                    )
                )
            }
        }
        return .init(
            records: records,
            userFolders: userFolders.sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
        )
    }

    private func directoryURLs(in parentURL: URL) -> [URL] {
        let contents = (try? fileManager.operate {
            try $0.contentsOfDirectory(
                at: parentURL,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        }) ?? []
        return contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        }
    }

    private func galleryFolderRecord(
        folderURL: URL,
        manifest: DownloadManifest,
        parentFolderName: String
    ) -> DownloadFolderRecord {
        let resourceValues = try? folderURL.resourceValues(
            forKeys: [.contentModificationDateKey]
        )
        return DownloadFolderRecord(
            relativePath: "\(parentFolderName)/\(folderURL.lastPathComponent)",
            folderURL: folderURL,
            manifest: manifest,
            modifiedAt: resourceValues?.contentModificationDate,
            parentFolderName: parentFolderName
        )
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

private extension String {
    func truncatedToUTF8ByteCount(_ maximumByteCount: Int) -> String {
        guard maximumByteCount > 0 else { return "" }
        var byteCount = 0
        var result = ""
        for character in self {
            let characterByteCount = String(character).utf8.count
            guard byteCount + characterByteCount <= maximumByteCount else {
                break
            }
            result.append(character)
            byteCount += characterByteCount
        }
        return result
    }
}
