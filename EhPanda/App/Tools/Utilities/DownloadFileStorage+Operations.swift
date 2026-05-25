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

    func addingCurrentFileHashes(
        to manifest: DownloadManifest,
        folderURL: URL
    ) throws -> DownloadManifest {
        let coverFileHash: String?
        if let coverRelativePath = manifest.coverRelativePath,
           coverRelativePath.notEmpty {
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
        let manifest = try readManifest(folderURL: folderURL)
        var didUpdate = false
        let pages = try manifest.pages.map { page in
            guard page.index == pageIndex else { return page }
            didUpdate = true
            let refreshedRelativePath = relativePath ?? page.relativePath
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
              coverRelativePath.notEmpty
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
            pageCount: pageCount,
            coverRelativePath: coverRelativePath,
            coverFileHash: coverFileHash,
            galleryURL: galleryURL,
            rating: rating,
            downloadOptions: downloadOptions,
            versionSignature: versionSignature,
            downloadedAt: downloadedAt,
            pages: pages
        )
    }
}
