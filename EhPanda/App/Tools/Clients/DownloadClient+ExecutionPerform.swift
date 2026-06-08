//
//  DownloadClient+ExecutionPerform.swift
//  EhPanda
//

import Foundation

// MARK: - Perform Download
extension DownloadManager {
    struct PerformDownloadResult {
        let coverRelativePath: String?
        let pages: [PageResult]
    }

    func performDownload(
        payload: DownloadRequestPayload,
        versionSignature: String,
        folderRelativePath: String,
        existingDownload: DownloadedGallery
    ) async throws -> PerformDownloadResult {
        try storage.ensureRootDirectory()

        let workingFolderURL = storage.folderURL(
            relativePath: folderRelativePath
        )
        let workingSeed = try prepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: workingFolderURL,
            versionSignature: versionSignature
        )
        let pendingIndices = pendingPageIndices(
            payload: payload,
            folderURL: workingFolderURL,
            existingPageRelativePaths: workingSeed.existingPages
        )
        try storage.writeResumeState(
            .init(
                mode: payload.mode,
                versionSignature: versionSignature,
                pageCount: payload.galleryDetail.pageCount,
                downloadOptions: payload.options,
                pageSelection: payload.pageSelection?.sorted()
            ),
            folderURL: workingFolderURL
        )

        let executionContext = DownloadExecutionContext(
            existingDownload: existingDownload,
            versionSignature: versionSignature
        )
        do {
            let batchAndCover = try await executePageDownloads(
                payload: payload,
                workingSeed: workingSeed,
                pendingIndices: pendingIndices,
                workingFolderURL: workingFolderURL,
                executionContext: executionContext
            )
            return batchAndCover
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }
    }

    private func executePageDownloads(
        payload: DownloadRequestPayload,
        workingSeed: WorkingSeed,
        pendingIndices: [Int],
        workingFolderURL: URL,
        executionContext: DownloadExecutionContext
    ) async throws -> PerformDownloadResult {
        let existingDownload = executionContext.existingDownload
        let versionSignature = executionContext.versionSignature
        let coverRelativePath = try await downloadAndPersistCoverIfNeeded(
            payload: payload,
            folderURL: workingFolderURL,
            existingCoverRelativePath: workingSeed.coverRelativePath,
            existingDownload: existingDownload
        )
        let source = try await resolveSourceIfNeeded(
            payload: payload,
            pendingIndices: pendingIndices,
            folderURL: workingFolderURL,
            existingPages: workingSeed.existingPages
        )
        let downloadContext = PageDownloadContext(
            payload: payload,
            source: source,
            temporaryFolderURL: workingFolderURL
        )
        let batchResult = try await downloadPages(
            context: downloadContext,
            pendingPageIndices: pendingIndices,
            existingManifest: workingSeed.manifest,
            existingPageRelativePaths: workingSeed.existingPages
        )
        let finalizeCtx = FinalizeContext(
            versionSignature: versionSignature,
            coverRelativePath: coverRelativePath,
            batchResult: batchResult,
            existingDownload: existingDownload
        )
        try await finalizeBatchResult(
            context: finalizeCtx,
            payload: payload,
            folderURL: workingFolderURL
        )
        return PerformDownloadResult(
            coverRelativePath: coverRelativePath,
            pages: batchResult.pages
        )
    }

    private func downloadAndPersistCoverIfNeeded(
        payload: DownloadRequestPayload,
        folderURL: URL,
        existingCoverRelativePath: String?,
        existingDownload: DownloadedGallery
    ) async throws -> String? {
        let coverRelativePath = try await downloadCoverImage(
            payload: payload,
            temporaryFolderURL: folderURL,
            existingCoverRelativePath: existingCoverRelativePath
        )
        if coverRelativePath != existingDownload.coverRelativePath {
            try? await updateDownloadRecord(
                gid: payload.gallery.gid,
                createIfMissing: false
            ) { record in
                record.coverRelativePath = coverRelativePath
            }
        }
        return coverRelativePath
    }

    private func finalizeBatchResult(
        context: FinalizeContext,
        payload: DownloadRequestPayload,
        folderURL: URL
    ) async throws {
        if payload.pageSelection != nil {
            try? storage.writeResumeState(
                .init(
                    mode: payload.mode,
                    versionSignature: context.versionSignature,
                    pageCount: payload.galleryDetail.pageCount,
                    downloadOptions: payload.options
                ),
                folderURL: folderURL
            )
        }
        if !context.batchResult.failedPages.isEmpty {
            throw PartialDownloadError(
                failedPages: context.batchResult.failedPages
            )
        }
        try await finalizeDownload(
            payload: payload,
            folderURL: folderURL,
            finalizeContext: context
        )
    }

    private func resolveSourceIfNeeded(
        payload: DownloadRequestPayload,
        pendingIndices: [Int],
        folderURL: URL,
        existingPages: [Int: String]
    ) async throws -> ResolvedSource? {
        let missingIndices = pendingIndices.filter { index in
            guard let relativePath = existingPages[index] else {
                return true
            }
            let fileURL = folderURL.appendingPathComponent(relativePath)
            return !fileManager.operate {
                $0.fileExists(atPath: fileURL.path)
            }
        }
        if missingIndices.isEmpty {
            return nil
        }
        return try await resolveSource(
            payload: payload,
            requiredPageIndices: missingIndices
        )
    }

    private func finalizeDownload(
        payload: DownloadRequestPayload,
        folderURL: URL,
        finalizeContext: FinalizeContext
    ) async throws {
        let versionSignature = finalizeContext.versionSignature
        let batchResult = finalizeContext.batchResult
        let existingDownload = finalizeContext.existingDownload
        let manifest = makeManifest(
            payload: payload,
            coverRelativePath: finalizeContext.coverRelativePath,
            batchResult: batchResult,
            versionSignature: versionSignature
        )
        let hashedManifest = try storage.addingCurrentFileHashes(
            to: manifest,
            folderURL: folderURL
        )
        try storage.writeManifest(
            hashedManifest,
            folderURL: folderURL
        )
        try? storage.removeFailedPages(
            folderURL: folderURL
        )
        await cleanupCachedRemoteAssetsAfterSuccessfulDownload(
            payload: payload,
            pages: batchResult.pages,
            existingDownload: existingDownload
        )
    }

    private func makeManifest(
        payload: DownloadRequestPayload,
        coverRelativePath: String?,
        batchResult: DownloadBatchResult,
        versionSignature: String
    ) -> DownloadManifest {
        DownloadManifest(
            gid: payload.gallery.gid,
            host: payload.host,
            token: payload.gallery.token,
            title: payload.gallery.title,
            jpnTitle: payload.galleryDetail.jpnTitle,
            category: payload.gallery.category,
            language: payload.galleryDetail.language,
            uploader: payload.galleryDetail.uploader,
            tags: payload.gallery.tags,
            postedDate: payload.galleryDetail.postedDate,
            pageCount: payload.galleryDetail.pageCount,
            coverRelativePath: coverRelativePath,
            galleryURL: payload.gallery.galleryURL.forceUnwrapped,
            rating: payload.galleryDetail.rating,
            downloadOptions: payload.options,
            versionSignature: versionSignature,
            downloadedAt: .now,
            pages: batchResult.pages
                .sorted(by: { $0.index < $1.index })
                .map {
                    .init(
                        index: $0.index,
                        relativePath: $0.relativePath
                    )
                }
        )
    }
}
