import Foundation
import AppModels

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
            payload: payload,
            options: options,
            existingDownload: existingDownload
        )
        return try await executePageDownloads(
            context: executionContext,
            workingSeed: workingSeed,
            pendingIndices: pendingIndices
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
        return manifest.pages.keys.sorted().filter { index in
            existingPages[index] == nil
        }
    }

    private func resolveSourceIfNeeded(
        payload: DownloadRequestPayload,
        options: DownloadRequestOptions,
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
