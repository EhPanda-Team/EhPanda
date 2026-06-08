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

        guard let source = context.source else {
            throw AppError.notFound
        }
        let resolved = try await resolvedImageSource(
            index: index,
            payload: payload,
            source: source
        )
        if let result = try await attemptResolvedCacheRestore(
            index: index,
            resolvedImageSource: resolved,
            context: context,
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

    private func attemptResolvedCacheRestore(
        index: Int,
        resolvedImageSource: ResolvedImageSource,
        context: PageDownloadContext,
        preferredRelativePath: String?
    ) async throws -> PageResult? {
        let payload = context.payload
        let resolvedCacheURLs = pageImageCacheURLs(
            imageURL: resolvedImageSource.imageURL
        )
        let resolvedSource = CacheRestoreSource(
            gid: payload.gallery.gid,
            token: payload.gallery.token,
            cacheURLs: resolvedCacheURLs,
            referenceURL: preferredPageReferenceURL(
                resolvedImageSource: resolvedImageSource
            ),
            imageURL: resolvedImageSource.imageURL
        )
        return try await restorePageFromCache(
            index: index,
            source: resolvedSource,
            folderURL: context.temporaryFolderURL,
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
                gid: payload.gallery.gid,
                token: payload.gallery.token,
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
