//
//  DownloadFileStorage+Operations.swift
//  EhPanda
//

import Foundation

extension DownloadFileStorage {
    func replaceFolder(relativePath: String, with temporaryFolderURL: URL) throws {
        let targetURL = folderURL(relativePath: relativePath)
        if fileManager.fileExists(atPath: targetURL.path) {
            _ = try fileManager.replaceItemAt(
                targetURL,
                withItemAt: temporaryFolderURL
            )
        } else {
            try fileManager.moveItem(at: temporaryFolderURL, to: targetURL)
        }
    }

    func linkOrCopyReadableAsset(at sourceURL: URL, to destinationURL: URL) throws {
        guard sanitizeAssetFileIfNeeded(at: sourceURL) else {
            throw AppError.fileOperationFailed(
                L10n.Localizable.DownloadFileStorage.Error.assetUnreadable(sourceURL.lastPathComponent)
            )
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.linkItem(at: sourceURL, to: destinationURL)
        } catch {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    func materializeRepairSeed(
        from sourceFolderURL: URL,
        manifest: DownloadManifest,
        to temporaryFolderURL: URL
    ) throws {
        try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(
                Defaults.FilePath.downloadPages,
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )

        try linkOrCopyReadableAsset(
            at: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
        )

        if let coverRelativePath = manifest.coverRelativePath,
           coverRelativePath.notEmpty,
           let sourceCoverURL = validatedChildURL(root: sourceFolderURL, relativePath: coverRelativePath),
           let destCoverURL = validatedChildURL(root: temporaryFolderURL, relativePath: coverRelativePath) {
            if sanitizeAssetFileIfNeeded(at: sourceCoverURL) {
                try linkOrCopyReadableAsset(at: sourceCoverURL, to: destCoverURL)
            }
        }

        for page in manifest.pages {
            guard let sourcePageURL = validatedChildURL(root: sourceFolderURL, relativePath: page.relativePath),
                  let destPageURL = validatedChildURL(root: temporaryFolderURL, relativePath: page.relativePath)
            else { continue }
            guard sanitizeAssetFileIfNeeded(at: sourcePageURL) else { continue }
            try linkOrCopyReadableAsset(at: sourcePageURL, to: destPageURL)
        }
    }

    func removeFolder(relativePath: String) throws {
        let targetURL = folderURL(relativePath: relativePath)
        guard fileManager.fileExists(atPath: targetURL.path) else { return }
        try fileManager.removeItem(at: targetURL)
    }

    func cleanupTemporaryFolders(preservingGIDs: Set<String> = []) throws {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }
        let urls = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil
        )
        for url in urls where url.lastPathComponent.hasPrefix(".tmp-") {
            let gid = String(url.lastPathComponent.dropFirst(".tmp-".count))
            if preservingGIDs.contains(gid) {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }

    func validate(download: DownloadedGallery) -> DownloadValidationState {
        guard let folderURL = download.resolvedFolderURL(rootURL: rootURL) else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.downloadFolderUnresolved)
        }
        guard fileManager.fileExists(atPath: folderURL.path) else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.downloadFolderMissing)
        }
        guard let manifestURL = download.resolvedManifestURL(rootURL: rootURL),
              fileManager.fileExists(atPath: manifestURL.path)
        else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.manifestMissing)
        }
        guard let manifest = try? readManifest(folderURL: folderURL) else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.manifestCorrupted)
        }
        guard manifest.pageCount == manifest.pages.count else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.downloadedPagesIncomplete)
        }
        if let coverRelativePath = manifest.coverRelativePath,
           !coverRelativePath.isEmpty {
            guard let coverURL = validatedChildURL(root: folderURL, relativePath: coverRelativePath),
                  sanitizeAssetFileIfNeeded(at: coverURL)
            else {
                return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.coverImageMissing)
            }
        }
        for page in manifest.pages {
            guard let pageURL = validatedChildURL(root: folderURL, relativePath: page.relativePath),
                  sanitizeAssetFileIfNeeded(at: pageURL)
            else {
                return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.pageMissing(page.index))
            }
        }
        return .valid
    }

    func validPageCount(folderURL: URL, manifest: DownloadManifest) -> Int {
        manifest.pages.reduce(into: 0) { count, page in
            guard let pageURL = validatedChildURL(root: folderURL, relativePath: page.relativePath) else { return }
            if sanitizeAssetFileIfNeeded(at: pageURL) {
                count += 1
            }
        }
    }

    func isReadableAssetFile(at url: URL) -> Bool {
        sanitizeAssetFileIfNeeded(at: url)
    }
}
