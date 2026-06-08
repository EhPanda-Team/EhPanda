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

        let existingPages = existingPageRelativePaths(
            folderURL: sourceFolderURL,
            expectedPageCount: manifest.pageCount
        )
        for index in manifest.pages.keys.sorted() {
            guard let relativePath = existingPages[index],
                  let sourcePageURL = validatedChildURL(root: sourceFolderURL, relativePath: relativePath),
                  let destPageURL = validatedChildURL(root: destinationFolderURL, relativePath: relativePath)
            else { continue }
            guard sanitizeAssetFileIfNeeded(at: sourcePageURL) else { continue }
            try linkOrCopyReadableAsset(at: sourcePageURL, to: destPageURL)
        }
    }

    func addingCurrentFileHashes(
        to manifest: DownloadManifest,
        folderURL: URL
    ) throws -> DownloadManifest {
        let existingPages = existingPageRelativePaths(
            folderURL: folderURL,
            expectedPageCount: manifest.pageCount
        )
        let pages = try manifest.pages.keys.sorted()
            .reduce(into: [Int: String]()) { result, index in
                guard let relativePath = existingPages[index] else {
                    throw AppError.fileOperationFailed(
                        L10n.Localizable.DownloadFileStorage.Validation.pageMissing(index)
                    )
                }
                result[index] = try hashReadableAsset(
                    folderURL: folderURL,
                    relativePath: relativePath,
                    missingMessage: L10n.Localizable.DownloadFileStorage.Validation.pageMissing(index)
                )
            }

        return manifest.replacing(pages: pages)
    }

    @discardableResult
    func refreshManifestPageFileHash(
        folderURL: URL,
        pageIndex: Int,
        relativePath: String? = nil
    ) throws -> DownloadManifest {
        let resolvedRelativePath: String?
        if let relativePath {
            resolvedRelativePath = relativePath
        } else {
            resolvedRelativePath = existingPageRelativePaths(
                folderURL: folderURL,
                expectedPageCount: (try? readManifest(folderURL: folderURL).pageCount) ?? pageIndex
            )[pageIndex]
        }
        guard let resolvedRelativePath else {
            return try readManifest(folderURL: folderURL)
        }
        return try refreshManifestPageFileHashes(
            folderURL: folderURL,
            pageRelativePaths: [pageIndex: resolvedRelativePath]
        )
    }

    @discardableResult
    func refreshManifestPageFileHashes(
        folderURL: URL,
        pageRelativePaths: [Int: String]
    ) throws -> DownloadManifest {
        let manifest = try readManifest(folderURL: folderURL)
        guard !pageRelativePaths.isEmpty else { return manifest }
        var pages = manifest.pages
        var didUpdate = false
        for index in pageRelativePaths.keys.sorted() {
            guard pages[index] != nil,
                  let refreshedRelativePath = pageRelativePaths[index]
            else {
                continue
            }
            pages[index] = try hashReadableAsset(
                folderURL: folderURL,
                relativePath: refreshedRelativePath,
                missingMessage: L10n.Localizable.DownloadFileStorage.Validation.pageMissing(index)
            )
            didUpdate = true
        }

        guard didUpdate else { return manifest }

        let refreshedManifest = manifest.replacing(pages: pages)
        if refreshedManifest != manifest {
            try writeManifest(refreshedManifest, folderURL: folderURL)
        }
        return refreshedManifest
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
            manifest: manifest
        ) {
            return pageValidationFailure
        }
        return .valid
    }

    func validPageCount(folderURL: URL, manifest: DownloadManifest) -> Int {
        let existingPages = existingPageRelativePaths(
            folderURL: folderURL,
            expectedPageCount: manifest.pageCount
        )
        return manifest.pages.keys.reduce(into: 0) { count, index in
            guard let relativePath = existingPages[index],
                  let pageURL = validatedChildURL(root: folderURL, relativePath: relativePath)
            else { return }
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
        manifest: DownloadManifest
    ) -> DownloadValidationState? {
        let existingPages = existingPageRelativePaths(
            folderURL: folderURL,
            expectedPageCount: manifest.pageCount
        )
        for index in manifest.pages.keys.sorted() {
            if let validationFailure = validatePage(
                folderURL: folderURL,
                index: index,
                expectedHash: manifest.pages[index] ?? "",
                existingPageRelativePaths: existingPages
            ) {
                return validationFailure
            }
        }
        return nil
    }

    private func validatePage(
        folderURL: URL,
        index: Int,
        expectedHash: String,
        existingPageRelativePaths: [Int: String]
    ) -> DownloadValidationState? {
        guard !expectedHash.isEmpty,
              let relativePath = existingPageRelativePaths[index],
              let pageURL = validatedChildURL(root: folderURL, relativePath: relativePath),
              sanitizeAssetFileIfNeeded(at: pageURL)
        else {
            return .missingFiles(L10n.Localizable.DownloadFileStorage.Validation.pageMissing(index))
        }

        if (try? fileHash(at: pageURL)) != expectedHash {
            return .missingFiles(
                L10n.Localizable.DownloadFileStorage.Validation.pageImageCorrupted(index)
            )
        }

        return nil
    }
}

private extension DownloadManifest {
    func replacing(
        pages: [Int: String]
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
