//
//  DownloadClient+PageDownloadHelpers.swift
//  EhPanda
//

import Foundation

// MARK: - Download Single Page
extension DownloadManager {
    func downloadPage(
        index: Int,
        context: PageDownloadContext,
        preferredRelativePath: String?
    ) async throws -> PageResult {
        let payload = context.payload
        let attempts = payload.options.autoRetryFailedPages ? 2 : 1
        var capturedError: AppError = .unknown

        for _ in 0..<attempts {
            do {
                return try await performSingleDownloadAttempt(
                    index: index,
                    context: context,
                    preferredRelativePath: preferredRelativePath
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as AppError {
                capturedError = error
                guard error.isRetryable else { throw error }
            } catch {
                if Self.isCancellationLikeError(error) {
                    throw CancellationError()
                }
                throw error
            }
        }

        throw capturedError
    }

    private func performSingleDownloadAttempt(
        index: Int,
        context: PageDownloadContext,
        preferredRelativePath: String?
    ) async throws -> PageResult {
        let payload = context.payload
        let temporaryFolderURL = context.temporaryFolderURL
        let storedGalleryImageState = context.storedGalleryImageState

        if let result = try await attemptCacheRestore(
            index: index,
            storedGalleryImageState: storedGalleryImageState,
            temporaryFolderURL: temporaryFolderURL,
            preferredRelativePath: preferredRelativePath
        ) {
            return result
        }
        guard let source = context.source else {
            throw AppError.notFound
        }
        let resolved = try await resolvedImageSource(
            index: index,
            payload: payload,
            source: source,
            retriesRequest: false
        )
        if let result = try await attemptResolvedCacheRestore(
            index: index,
            resolvedImageSource: resolved,
            storedGalleryImageState: storedGalleryImageState,
            temporaryFolderURL: temporaryFolderURL,
            preferredRelativePath: preferredRelativePath
        ) {
            return result
        }
        return try await downloadAndSavePage(
            index: index,
            resolvedImageSource: resolved,
            payload: payload,
            temporaryFolderURL: temporaryFolderURL,
            preferredRelativePath: preferredRelativePath
        )
    }

    private func attemptCacheRestore(
        index: Int,
        storedGalleryImageState: CachedGalleryImageState?,
        temporaryFolderURL: URL,
        preferredRelativePath: String?
    ) async throws -> PageResult? {
        let storedCacheURLs = pageImageCacheURLs(
            resolvedImageSource: nil,
            index: index,
            storedGalleryImageState: storedGalleryImageState
        )
        let storedSource = CacheRestoreSource(
            cacheURLs: storedCacheURLs,
            referenceURL: storedCacheURLs
                .compactMap(\.self).first,
            imageURL: storedGalleryImageState?
                .imageURLs[index]
        )
        return try await restorePageFromCache(
            index: index,
            source: storedSource,
            folderURL: temporaryFolderURL,
            preferredRelativePath: preferredRelativePath
        )
    }

    private func attemptResolvedCacheRestore(
        index: Int,
        resolvedImageSource: ResolvedImageSource,
        storedGalleryImageState: CachedGalleryImageState?,
        temporaryFolderURL: URL,
        preferredRelativePath: String?
    ) async throws -> PageResult? {
        let resolvedCacheURLs = pageImageCacheURLs(
            resolvedImageSource: resolvedImageSource,
            index: index,
            storedGalleryImageState: storedGalleryImageState
        )
        let resolvedSource = CacheRestoreSource(
            cacheURLs: resolvedCacheURLs,
            referenceURL: preferredPageReferenceURL(
                resolvedImageSource: resolvedImageSource
            ),
            imageURL: resolvedImageSource.imageURL
        )
        return try await restorePageFromCache(
            index: index,
            source: resolvedSource,
            folderURL: temporaryFolderURL,
            preferredRelativePath: preferredRelativePath
        )
    }

    private func downloadAndSavePage(
        index: Int,
        resolvedImageSource: ResolvedImageSource,
        payload: DownloadRequestPayload,
        temporaryFolderURL: URL,
        preferredRelativePath: String?
    ) async throws -> PageResult {
        let targetURL = resolvedImageSource.imageURL
        let (downloadedFileURL, response) =
            try await downloadResponse(
                url: targetURL,
                allowsCellular: payload.options.allowCellular,
                retriesRequest: false
            )
        let relativePath: String
        if let preferredRelativePath {
            relativePath = preferredRelativePath
        } else {
            let prefixData = try readResponsePrefixData(
                at: downloadedFileURL
            )
            let ext = fileExtension(
                for: targetURL,
                response: response,
                prefixData: prefixData
            )
            relativePath = storage.makePageRelativePath(
                index: index,
                fileExtension: ext
            )
        }
        let fileURL = temporaryFolderURL
            .appendingPathComponent(relativePath)
        try moveDownloadedFile(
            from: downloadedFileURL,
            to: fileURL
        )
        return .init(
            index: index,
            relativePath: relativePath,
            imageURL: resolvedImageSource.imageURL
        )
    }
}
