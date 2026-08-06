import AppModels
import Foundation

// MARK: - Perform Download
extension DownloadCoordinator {
    public struct PerformDownloadResult {
        public let coverRelativePath: String?
        public let pages: [PageResult]
        public init(
            coverRelativePath: String? = nil,
            pages: [PageResult]
        ) {
            self.coverRelativePath = coverRelativePath
            self.pages = pages
        }
    }

    public func performDownload(
        payload: DownloadRequestPayload,
        options: DownloadRequestOptions,
        folderRelativePath: String,
        existingDownload: DownloadedGallery
    ) async throws -> PerformDownloadResult {
        try storage.ensureRootDirectory()

        let workingFolderURL = storage.folderURL(
            relativePath: folderRelativePath
        )
        // The preparation both announces and hands back the pages this run will fetch. Consuming
        // that list rather than recomputing it here is what keeps the announcement's gate and the
        // page loop reading the same set: two evaluations can be moved apart by a later fix, which
        // is how trust came to be granted for work the loop never did (G-15-27, T-15-47-03).
        let preparedRun = try await prepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: workingFolderURL
        )

        let executionContext = DownloadExecutionContext(
            payload: payload,
            options: options,
            existingDownload: existingDownload
        )
        return try await executePageDownloads(
            context: executionContext,
            workingSeed: preparedRun.workingSeed,
            pendingIndices: preparedRun.pendingPageIndices
        )
    }

    private func executePageDownloads(
        context: DownloadExecutionContext,
        workingSeed: WorkingSeed,
        pendingIndices: [Int]
    ) async throws -> PerformDownloadResult {
        let payload = context.payload
        let options = context.options
        let folderURL = workingSeed.folderURL
        let coverRelativePath = try await downloadCoverImage(
            payload: payload,
            options: options,
            folderURL: folderURL,
            existingCoverRelativePath: workingSeed.coverRelativePath
        )
        let source = try await resolveSourceIfNeeded(
            payload: payload,
            options: options,
            pendingIndices: pendingIndices,
            folderURL: folderURL,
            existingPages: workingSeed.existingPages
        )
        let downloadContext = PageDownloadContext(
            payload: payload,
            options: options,
            source: source,
            folderURL: folderURL
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
            existingDownload: context.existingDownload
        )
        try await finalizeBatchResult(
            context: finalizeCtx,
            payload: payload,
            folderURL: folderURL
        )
        return PerformDownloadResult(
            coverRelativePath: coverRelativePath,
            pages: batchResult.pages
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
        return manifest.pages.keys.sorted().filter { page in
            existingPages[page] == nil
        }
    }

    private func resolveSourceIfNeeded(
        payload: DownloadRequestPayload,
        options: DownloadRequestOptions,
        pendingIndices: [Int],
        folderURL: URL,
        existingPages: [Int: String]
    ) async throws -> ResolvedSource? {
        let missingIndices = pendingIndices.filter { page in
            guard let relativePath = existingPages[page] else {
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
            options: options,
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
