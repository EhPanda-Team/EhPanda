//
//  DownloadClient+ExecutionSupport.swift
//  EhPanda
//

import Foundation

// MARK: - Execution Support
extension DownloadManager {
    func downloadCoverImage(
        payload: DownloadRequestPayload,
        temporaryFolderURL: URL,
        existingCoverRelativePath: String?
    ) async throws -> String? {
        if let coverRelativePath = existingCoverRelativePath,
           !coverRelativePath.isEmpty {
            let localCoverURL = temporaryFolderURL
                .appendingPathComponent(coverRelativePath)
            if fileManager.operate({ $0.fileExists(atPath: localCoverURL.path) }) {
                return coverRelativePath
            }
        }
        guard let coverURL =
                payload.galleryDetail.coverURL
                ?? payload.gallery.coverURL
        else {
            return nil
        }
        if let cachedData = await validatedCachedAssetData(
            for: [coverURL]
        ) {
            return try saveCoverFromCache(
                cachedData: cachedData,
                coverURL: coverURL,
                payload: payload,
                temporaryFolderURL: temporaryFolderURL
            )
        }
        return try await downloadCoverFromNetwork(
            coverURL: coverURL,
            payload: payload,
            temporaryFolderURL: temporaryFolderURL,
            allowsCellular: payload.options.allowCellular
        )
    }

    private func saveCoverFromCache(
        cachedData: Data,
        coverURL: URL,
        payload: DownloadRequestPayload,
        temporaryFolderURL: URL
    ) throws -> String {
        let ext = fileExtension(
            for: coverURL,
            response: nil,
            prefixData: cachedData
        )
        let relativePath = storage
            .makeCoverRelativePath(
                gid: payload.gallery.gid,
                token: payload.gallery.token,
                fileExtension: ext
            )
        let fileURL = temporaryFolderURL
            .appendingPathComponent(relativePath)
        try write(data: cachedData, to: fileURL)
        return relativePath
    }

    private func downloadCoverFromNetwork(
        coverURL: URL,
        payload: DownloadRequestPayload,
        temporaryFolderURL: URL,
        allowsCellular: Bool
    ) async throws -> String {
        let (downloadedFileURL, response) =
            try await downloadResponse(
                url: coverURL,
                allowsCellular: allowsCellular
            )
        let prefixData = try readResponsePrefixData(
            at: downloadedFileURL
        )
        let ext = fileExtension(
            for: coverURL,
            response: response,
            prefixData: prefixData
        )
        let relativePath = storage
            .makeCoverRelativePath(
                gid: payload.gallery.gid,
                token: payload.gallery.token,
                fileExtension: ext
            )
        let fileURL = temporaryFolderURL
            .appendingPathComponent(relativePath)
        try moveDownloadedFile(
            from: downloadedFileURL,
            to: fileURL
        )
        return relativePath
    }

    func cleanupCachedRemoteAssetsAfterSuccessfulDownload(
        payload: DownloadRequestPayload,
        storedGalleryImageState: CachedGalleryImageState?,
        pages: [PageResult],
        existingDownload: DownloadedGallery
    ) async {
        let previewURLs = (
            Array(payload.previewURLs.values)
                + (storedGalleryImageState.map {
                    Array($0.previewURLs.values)
                } ?? [])
        )
        .flatMap { $0.previewCacheCleanupURLs() }
        let pageURLs = pages.compactMap(\.imageURL)
            + (storedGalleryImageState.map {
                Array($0.imageURLs.values)
            } ?? [])
        let coverURLs = [
            payload.galleryDetail.coverURL,
            payload.gallery.coverURL,
            existingDownload.onlineCoverURL
        ]
        .compactMap(\.self)

        let urls = Array(Set(previewURLs + pageURLs + coverURLs))
            .map(Optional.some)
        await removeCachedImages(for: urls, includeStableAlias: true)
    }

    func resolveSource(
        payload: DownloadRequestPayload,
        requiredPageIndices: [Int]
    ) async throws -> ResolvedSource {
        let requiredPageNumbers = Array(
            Set(requiredPageIndices.map {
                payload.previewConfig.pageNumber(index: $0)
            })
        )
        .sorted()
        var thumbnailURLs = [Int: URL]()
        for pageNumber in requiredPageNumbers {
            let pageURLs = try await ThumbnailURLsRequest(
                galleryURL: payload.gallery.galleryURL.forceUnwrapped,
                pageNum: pageNumber,
                urlSession: urlSession,
                allowsCellular: payload.options.allowCellular
            )
            .response()
            .get()
            thumbnailURLs
                .merge(pageURLs, uniquingKeysWith: { _, new in new })
        }
        guard let firstURL = requiredPageIndices.lazy
                .compactMap({ thumbnailURLs[$0] }).first
                ?? thumbnailURLs.values.first
        else {
            throw AppError.notFound
        }
        if firstURL.pathComponents.count > 1,
           firstURL.pathComponents[1] == "mpv" {
            let (mpvKey, imageKeys) = try await MPVKeysRequest(
                mpvURL: firstURL,
                urlSession: urlSession,
                allowsCellular: payload.options.allowCellular
            )
            .response()
            .get()
            return .mpv(mpvKey, imageKeys)
        } else {
            return .normal(thumbnailURLs)
        }
    }

    func prepareWorkingSeed(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        temporaryFolderURL: URL,
        versionSignature: String
    ) throws -> WorkingSeed {
        let resumeState = try? storage
            .readResumeState(folderURL: temporaryFolderURL)
        let shouldReuseTemporaryFolder = resumeState?.matches(
            mode: payload.mode,
            versionSignature: versionSignature,
            pageCount: payload.galleryDetail.pageCount,
            downloadOptions: payload.options
        ) == true
        && fileManager.operate {
            $0.fileExists(atPath: temporaryFolderURL.path)
        }

        let seedContext = RepairSeedContext(
            existingDownload: existingDownload,
            payload: payload,
            versionSignature: versionSignature
        )
        try setupTemporaryFolder(
            temporaryFolderURL: temporaryFolderURL,
            shouldReuse: shouldReuseTemporaryFolder,
            seedContext: seedContext
        )

        let manifest = validatedManifest(
            at: temporaryFolderURL,
            gid: payload.gallery.gid,
            pageCount: payload.galleryDetail.pageCount,
            versionSignature: versionSignature,
            downloadOptions: payload.options
        )
        let existingPages = storage.existingPageRelativePaths(
            folderURL: temporaryFolderURL,
            expectedPageCount: payload.galleryDetail.pageCount
        )
        let coverRelativePath = manifest?.coverRelativePath
            ?? storage.existingCoverRelativePath(
                folderURL: temporaryFolderURL
            )
        return .init(
            folderURL: temporaryFolderURL,
            manifest: manifest,
            existingPages: existingPages,
            coverRelativePath: coverRelativePath
        )
    }

    private struct RepairSeedContext {
        let existingDownload: DownloadedGallery
        let payload: DownloadRequestPayload
        let versionSignature: String
    }

    private func setupTemporaryFolder(
        temporaryFolderURL: URL,
        shouldReuse: Bool,
        seedContext: RepairSeedContext
    ) throws {
        if !shouldReuse {
            try? fileManager.operate {
                try $0.removeItem(at: temporaryFolderURL)
            }
        }
        if !fileManager.operate({ $0.fileExists(atPath: temporaryFolderURL.path) }) {
            if let seed = repairSeed(
                for: seedContext.existingDownload,
                payload: seedContext.payload,
                versionSignature: seedContext.versionSignature
            ) {
                try storage.materializeRepairSeed(
                    from: seed.folderURL,
                    manifest: seed.manifest,
                    to: temporaryFolderURL
                )
            } else {
                try createDirectory(at: temporaryFolderURL)
            }
        }
        let pagesFolderURL = temporaryFolderURL
            .appendingPathComponent(
                Defaults.FilePath.downloadPages,
                isDirectory: true
            )
        try createDirectory(at: pagesFolderURL)
    }

    func resolvedImageSource(
        index: Int,
        payload: DownloadRequestPayload,
        source: ResolvedSource
    ) async throws -> ResolvedImageSource {
        switch source {
        case .normal(let thumbnailURLs):
            guard let thumbnailURL = thumbnailURLs[index] else {
                throw AppError.notFound
            }
            let (imageURLs, _) = try await GalleryNormalImageURLsRequest(
                thumbnailURLs: [index: thumbnailURL],
                urlSession: urlSession,
                allowsCellular: payload.options.allowCellular
            )
            .response()
            .get()
            guard let imageURL = imageURLs[index] else {
                throw AppError.notFound
            }
            return .init(imageURL: imageURL)

        case .mpv(let mpvKey, let imageKeys):
            guard let gid = Int(payload.gallery.gid) else {
                throw AppError.notFound
            }
            guard let imageKey = imageKeys[index] else {
                throw AppError.notFound
            }
            let response = try await GalleryMPVImageURLRequest(
                gid: gid,
                index: index,
                mpvKey: mpvKey,
                mpvImageKey: imageKey,
                skipServerIdentifier: nil,
                apiURL: payload.host.url.appendingPathComponent("api.php"),
                urlSession: urlSession,
                allowsCellular: payload.options.allowCellular,
                requiresSkipServerIdentifier: false
            )
            .response()
            .get()
            return .init(imageURL: response.imageURL)
        }
    }

    func repairSeed(
        for download: DownloadedGallery,
        payload: DownloadRequestPayload,
        versionSignature: String
    ) -> RepairSeed? {
        let folderURL = download
            .resolvedFolderURL(rootURL: storage.rootURL)
        guard payload.mode == .repair,
              fileManager.operate({
                  $0.fileExists(atPath: folderURL.path)
              }),
              let manifest = try? storage
                .readManifest(folderURL: folderURL),
              manifest.gid == download.gid,
              manifest.pageCount ==
                payload.galleryDetail.pageCount,
              manifest.pages.count == manifest.pageCount,
              manifest.versionSignature == versionSignature
        else {
            return nil
        }
        return .init(folderURL: folderURL, manifest: manifest)
    }

    func pendingPageIndices(
        payload: DownloadRequestPayload,
        folderURL: URL,
        existingPageRelativePaths: [Int: String]
    ) -> [Int] {
        let selectedIndices = payload.pageSelection.map(Set.init)
        return (1...payload.galleryDetail.pageCount).filter { index in
            if let selectedIndices,
               !selectedIndices.contains(index) {
                return false
            }
            guard let relativePath =
                    existingPageRelativePaths[index] else {
                return true
            }
            let fileURL = folderURL
                .appendingPathComponent(relativePath)
            return !fileManager.operate {
                $0.fileExists(atPath: fileURL.path)
            }
        }
    }
}
