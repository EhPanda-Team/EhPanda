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
            folderURL: workingFolderURL
        )
        let pendingIndices = pendingPageIndices(
            payload: payload,
            folderURL: workingFolderURL,
            existingPageRelativePaths: workingSeed.existingPages
        )

        let executionContext = DownloadExecutionContext(
            existingDownload: existingDownload
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
        let coverRelativePath = try await downloadCoverIfNeeded(
            payload: payload,
            folderURL: workingFolderURL,
            existingCoverRelativePath: workingSeed.coverRelativePath
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
            folderURL: workingFolderURL
        )
        let batchResult = try await downloadPages(
            context: downloadContext,
            pendingPageIndices: pendingIndices,
            existingManifest: workingSeed.manifest,
            existingPageRelativePaths: workingSeed.existingPages
        )
        let finalizeCtx = FinalizeContext(
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

    private func downloadCoverIfNeeded(
        payload: DownloadRequestPayload,
        folderURL: URL,
        existingCoverRelativePath: String?
    ) async throws -> String? {
        try await downloadCoverImage(
            payload: payload,
            folderURL: folderURL,
            existingCoverRelativePath: existingCoverRelativePath
        )
    }

    private func finalizeBatchResult(
        context: FinalizeContext,
        payload: DownloadRequestPayload,
        folderURL: URL
    ) async throws {
        if !context.batchResult.failedPages.isEmpty {
            throw PartialDownloadError(
                failedPages: context.batchResult.failedPages
            )
        }
        let missingPageIndices = try missingFinalizedPageIndices(folderURL: folderURL)
        guard missingPageIndices.isEmpty else {
            throw IncompleteDownloadError(
                missingPageIndices: missingPageIndices
            )
        }
        try await finalizeDownload(
            payload: payload,
            folderURL: folderURL,
            finalizeContext: context
        )
    }

    private func missingFinalizedPageIndices(
        folderURL: URL
    ) throws -> [Int] {
        let manifest = try storage.readManifest(folderURL: folderURL)
        let existingPages = storage.existingPageRelativePaths(
            folderURL: folderURL,
            manifest: manifest
        )
        return manifest.pages.keys.sorted().filter { index in
            existingPages[index] == nil
        }
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
        let batchResult = finalizeContext.batchResult
        let existingDownload = finalizeContext.existingDownload
        let manifest = try storage.readManifest(folderURL: folderURL)
        let hashedManifest = try storage.addingCurrentFileHashes(
            to: manifest,
            folderURL: folderURL
        )
        try storage.writeManifest(
            hashedManifest,
            folderURL: folderURL
        )
        updateDownloadIndex(folderURL: folderURL, manifest: hashedManifest)
        await cleanupCachedRemoteAssetsAfterSuccessfulDownload(
            payload: payload,
            pages: batchResult.pages,
            existingDownload: existingDownload
        )
    }
}
