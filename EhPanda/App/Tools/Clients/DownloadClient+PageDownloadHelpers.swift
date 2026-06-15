//
//  DownloadClient+PageDownloadHelpers.swift
//  EhPanda
//

import Foundation

// MARK: - Download Single Page
extension DownloadCoordinator {
    func downloadPage(
        index: Int,
        context: PageDownloadContext,
        preferredRelativePath: String?
    ) async throws -> PageResult {
        guard let source = context.source else {
            throw AppError.notFound
        }
        let attempts = context.options.autoRetryFailedPages ? 2 : 1
        var capturedError: AppError = .unknown
        var failover: ResolvedImageSource?

        for _ in 0..<attempts {
            do {
                let resolved = try await resolvedImageSource(
                    index: index,
                    payload: context.payload,
                    options: context.options,
                    source: source,
                    failover: failover
                )
                failover = resolved
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
            folderURL: context.folderURL,
            preferredRelativePath: preferredRelativePath
        )
    }

    private func downloadAndSavePage(
        index: Int,
        resolvedImageSource: ResolvedImageSource,
        context: PageDownloadContext,
        preferredRelativePath: String?
    ) async throws -> PageResult {
        let payload = context.payload
        let targetURL = resolvedImageSource.imageURL
        let transfer =
            try await pageDownloadResponse(
                url: targetURL,
                allowsCellular: context.options.allowCellular,
                context: .init(
                    gid: payload.gallery.gid,
                    pageIndex: index
                ),
                retriesRequest: false
            )
        let relativePath: String
        if let preferredRelativePath {
            relativePath = preferredRelativePath
        } else {
            let prefixData = try readResponsePrefixData(
                at: transfer.fileURL
            )
            let ext = fileExtension(
                for: targetURL,
                response: transfer.response,
                prefixData: prefixData
            )
            relativePath = storage.makePageRelativePath(
                gid: payload.gallery.gid,
                token: payload.gallery.token,
                index: index,
                fileExtension: ext
            )
        }
        let fileURL = context.folderURL
            .appendingPathComponent(relativePath)
        do {
            try moveDownloadedFile(
                from: transfer.fileURL,
                to: fileURL
            )
            if let taskIdentifier = transfer.taskIdentifier {
                await backgroundTaskStore.remove(taskIdentifier: taskIdentifier)
            }
        } catch {
            if let taskIdentifier = transfer.taskIdentifier {
                await backgroundTaskStore.remove(taskIdentifier: taskIdentifier)
                // The move never consumed the staged file; drop it so it doesn't
                // strand in the holding dir, matching the sibling failure paths.
                removeStagedBackgroundFile(transfer.fileURL)
            }
            throw error
        }
        return .init(
            index: index,
            relativePath: relativePath,
            imageURL: resolvedImageSource.imageURL
        )
    }
}
