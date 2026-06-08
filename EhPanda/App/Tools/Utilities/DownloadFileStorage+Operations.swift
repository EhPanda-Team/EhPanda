//
//  DownloadFileStorage+Operations.swift
//  EhPanda
//

import Foundation

extension DownloadFileStorage {
    func replaceFolder(relativePath: String, with temporaryFolderURL: URL) throws {
        let targetURL = folderURL(relativePath: relativePath)
        try fileManager.operate {
            if $0.fileExists(atPath: targetURL.path) {
                _ = try $0.replaceItemAt(
                    targetURL,
                    withItemAt: temporaryFolderURL
                )
            } else {
                try $0.moveItem(at: temporaryFolderURL, to: targetURL)
            }
        }
    }

    func linkOrCopyReadableAsset(at sourceURL: URL, to destinationURL: URL) throws {
        guard sanitizeAssetFileIfNeeded(at: sourceURL) else {
            throw AppError.fileOperationFailed(
                L10n.Localizable.DownloadFileStorage.Error.assetUnreadable(sourceURL.lastPathComponent)
            )
        }

        try fileManager.operate {
            try $0.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if $0.fileExists(atPath: destinationURL.path) {
                try $0.removeItem(at: destinationURL)
            }
        }

        do {
            try fileManager.operate {
                try $0.linkItem(at: sourceURL, to: destinationURL)
            }
        } catch {
            try fileManager.operate {
                try $0.copyItem(at: sourceURL, to: destinationURL)
            }
        }
    }

    func materializeRepairSeed(
        from sourceFolderURL: URL,
        manifest: DownloadManifest,
        to temporaryFolderURL: URL
    ) throws {
        try fileManager.operate {
            try $0.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)
            try $0.createDirectory(
                at: temporaryFolderURL.appendingPathComponent(
                    Defaults.FilePath.downloadPages,
                    isDirectory: true
                ),
                withIntermediateDirectories: true
            )
        }

        try linkOrCopyReadableAsset(
            at: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            to: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
        )

        if let coverRelativePath = manifest.coverRelativePath,
           !coverRelativePath.isEmpty,
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

    func addingCurrentFileHashes(
        to manifest: DownloadManifest,
        folderURL: URL
    ) throws -> DownloadManifest {
        let coverFileHash: String?
        if let coverRelativePath = manifest.coverRelativePath,
           !coverRelativePath.isEmpty {
            coverFileHash = try hashReadableAsset(
                folderURL: folderURL,
                relativePath: coverRelativePath,
                missingMessage: L10n.Localizable.DownloadFileStorage.Validation.coverImageMissing
            )
        } else {
            coverFileHash = nil
        }

        let pages = try manifest.pages.map { page in
            DownloadManifest.Page(
                index: page.index,
                relativePath: page.relativePath,
                fileHash: try hashReadableAsset(
                    folderURL: folderURL,
                    relativePath: page.relativePath,
                    missingMessage: L10n.Localizable.DownloadFileStorage.Validation.pageMissing(page.index)
                )
            )
        }

        return manifest.replacing(
            coverFileHash: coverFileHash,
            pages: pages
        )
    }

    @discardableResult
    func refreshManifestFileHashes(folderURL: URL) throws -> DownloadManifest {
        let manifest = try readManifest(folderURL: folderURL)
        let hashedManifest = try addingCurrentFileHashes(
            to: manifest,
            folderURL: folderURL
        )
        if hashedManifest != manifest {
            try writeManifest(hashedManifest, folderURL: folderURL)
        }
        return hashedManifest
    }

    @discardableResult
    func refreshManifestPageFileHash(
        folderURL: URL,
        pageIndex: Int,
        relativePath: String? = nil
    ) throws -> DownloadManifest {
        if let relativePath {
            return try refreshManifestPageFileHashes(
                folderURL: folderURL,
                pageRelativePaths: [pageIndex: relativePath]
            )
        }
        let manifest = try readManifest(folderURL: folderURL)
        guard let page = manifest.pages.first(
            where: { $0.index == pageIndex }
        ) else {
            return manifest
        }
        return try refreshManifestPageFileHashes(
            folderURL: folderURL,
            pageRelativePaths: [pageIndex: page.relativePath]
        )
    }

    @discardableResult
    func refreshManifestPageFileHashes(
        folderURL: URL,
        pageRelativePaths: [Int: String]
    ) throws -> DownloadManifest {
        let manifest = try readManifest(folderURL: folderURL)
        guard !pageRelativePaths.isEmpty else { return manifest }
        var didUpdate = false
        let pages = try manifest.pages.map { page in
            guard let refreshedRelativePath =
                    pageRelativePaths[page.index] else {
                return page
            }
            didUpdate = true
            return DownloadManifest.Page(
                index: page.index,
                relativePath: refreshedRelativePath,
                fileHash: try hashReadableAsset(
                    folderURL: folderURL,
                    relativePath: refreshedRelativePath,
                    missingMessage: L10n.Localizable.DownloadFileStorage.Validation.pageMissing(page.index)
                )
            )
        }

        guard didUpdate else { return manifest }

        let refreshedManifest = manifest.replacing(
            coverFileHash: manifest.coverFileHash,
            pages: pages
        )
        if refreshedManifest != manifest {
            try writeManifest(refreshedManifest, folderURL: folderURL)
        }
        return refreshedManifest
    }

    func removeFolder(relativePath: String) throws {
        let targetURL = folderURL(relativePath: relativePath)
        try fileManager.operate {
            guard $0.fileExists(atPath: targetURL.path) else { return }
            try $0.removeItem(at: targetURL)
        }
    }

    func cleanupTemporaryFolders(preservingGIDs: Set<String> = []) throws {
        let urls = try fileManager.operate {
            guard $0.fileExists(atPath: rootURL.path) else { return [URL]() }
            return try $0.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: nil
            )
        }
        for url in urls where url.lastPathComponent.hasPrefix(".tmp-") {
            let gid = String(url.lastPathComponent.dropFirst(".tmp-".count))
            if preservingGIDs.contains(gid) {
                continue
            }
            try? fileManager.operate {
                try $0.removeItem(at: url)
            }
        }
    }

    func validate(download: DownloadedGallery) -> DownloadValidationState {
        let folderURL = download.resolvedFolderURL(rootURL: rootURL)
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.downloadFolderMissing)
        }
        let manifestURL = download.resolvedManifestURL(rootURL: rootURL)
        guard fileManager.operate({ $0.fileExists(atPath: manifestURL.path) }) else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.manifestMissing)
        }
        guard let manifest = try? readManifest(folderURL: folderURL) else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.manifestCorrupted)
        }
        if let coverValidationFailure = validateCover(
            folderURL: folderURL,
            manifest: manifest
        ) {
            return coverValidationFailure
        }
        if let pageValidationFailure = validatePages(
            folderURL: folderURL,
            pages: manifest.pages
        ) {
            return pageValidationFailure
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

    private func hashReadableAsset(
        folderURL: URL,
        relativePath: String,
        missingMessage: String
    ) throws -> String {
        guard let fileURL = validatedChildURL(root: folderURL, relativePath: relativePath),
              sanitizeAssetFileIfNeeded(at: fileURL)
        else {
            throw AppError.fileOperationFailed(missingMessage)
        }
        return try fileHash(at: fileURL)
    }

    private func validateCover(
        folderURL: URL,
        manifest: DownloadManifest
    ) -> DownloadValidationState? {
        guard let coverRelativePath = manifest.coverRelativePath,
              !coverRelativePath.isEmpty
        else { return nil }

        guard let coverURL = validatedChildURL(root: folderURL, relativePath: coverRelativePath),
              sanitizeAssetFileIfNeeded(at: coverURL)
        else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.coverImageMissing)
        }

        if let expectedHash = manifest.coverFileHash,
           (try? fileHash(at: coverURL)) != expectedHash {
            return .missingFiles(
                L10n.Localizable.DownloadFileStorage.Validation.coverImageCorrupted
            )
        }

        return nil
    }

    private func validatePages(
        folderURL: URL,
        pages: [DownloadManifest.Page]
    ) -> DownloadValidationState? {
        for page in pages {
            if let validationFailure = validatePage(folderURL: folderURL, page: page) {
                return validationFailure
            }
        }
        return nil
    }

    private func validatePage(
        folderURL: URL,
        page: DownloadManifest.Page
    ) -> DownloadValidationState? {
        guard let pageURL = validatedChildURL(root: folderURL, relativePath: page.relativePath),
              sanitizeAssetFileIfNeeded(at: pageURL)
        else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.pageMissing(page.index))
        }

        if let expectedHash = page.fileHash,
           (try? fileHash(at: pageURL)) != expectedHash {
            return .missingFiles(
                L10n.Localizable.DownloadFileStorage.Validation.pageImageCorrupted(page.index)
            )
        }

        return nil
    }
}

private extension DownloadManifest {
    func replacing(
        coverFileHash: String?,
        pages: [Page]
    ) -> DownloadManifest {
        DownloadManifest(
            gid: gid,
            host: host,
            token: token,
            title: title,
            jpnTitle: jpnTitle,
            category: category,
            language: language,
            uploader: uploader,
            tags: tags,
            postedDate: postedDate,
            coverRelativePath: coverRelativePath,
            coverFileHash: coverFileHash,
            rating: rating,
            downloadOptions: downloadOptions,
            downloadedAt: downloadedAt,
            pages: pages
        )
    }
}
