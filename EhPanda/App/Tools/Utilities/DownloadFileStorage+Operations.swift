//
//  DownloadFileStorage+Operations.swift
//  EhPanda
//

import Foundation

extension DownloadFileStorage {
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
        to destinationFolderURL: URL
    ) throws {
        try fileManager.operate {
            try $0.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true)
            try $0.createDirectory(
                at: destinationFolderURL.appendingPathComponent(
                    Defaults.FilePath.downloadPages,
                    isDirectory: true
                ),
                withIntermediateDirectories: true
            )
        }

        try linkOrCopyReadableAsset(
            at: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            to: destinationFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
        )

        if let coverRelativePath = existingCoverRelativePath(folderURL: sourceFolderURL),
           let sourceCoverURL = validatedChildURL(root: sourceFolderURL, relativePath: coverRelativePath),
           let destCoverURL = validatedChildURL(root: destinationFolderURL, relativePath: coverRelativePath) {
            if sanitizeAssetFileIfNeeded(at: sourceCoverURL) {
                try linkOrCopyReadableAsset(at: sourceCoverURL, to: destCoverURL)
            }
        }

        for page in manifest.pages {
            guard let sourcePageURL = validatedChildURL(root: sourceFolderURL, relativePath: page.relativePath),
                  let destPageURL = validatedChildURL(root: destinationFolderURL, relativePath: page.relativePath)
            else { continue }
            guard sanitizeAssetFileIfNeeded(at: sourcePageURL) else { continue }
            try linkOrCopyReadableAsset(at: sourcePageURL, to: destPageURL)
        }
    }

    func addingCurrentFileHashes(
        to manifest: DownloadManifest,
        folderURL: URL
    ) throws -> DownloadManifest {
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
            rating: rating,
            pages: pages
        )
    }
}
