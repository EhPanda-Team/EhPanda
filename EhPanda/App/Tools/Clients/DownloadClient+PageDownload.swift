//
//  DownloadClient+PageDownload.swift
//  EhPanda
//

import Foundation

// MARK: - Download Pages
extension DownloadManager {
    private struct PageDownloadProgress {
        var results: [PageResult] = []
        var failedPages: [Int: DownloadFailedPagesSnapshot.Page?] = [:]
        var completedCount: Int = 0
        var pendingResolvedPages: [PageResult] = []
        var lastFlushDate: Date = Date()
    }

    func downloadPages(
        context: PageDownloadContext,
        pendingPageIndices: [Int],
        existingManifest: DownloadManifest?,
        existingPageRelativePaths: [Int: String]
    ) async throws -> DownloadBatchResult {
        let existingPages = buildExistingPages(
            existingManifest: existingManifest,
            existingPageRelativePaths: existingPageRelativePaths
        )
        var progress = PageDownloadProgress()
        progress.failedPages = (try? storage
            .readFailedPages(
                folderURL: context.temporaryFolderURL
            ).map) ?? [:]

        try await initializePageDownloadState(
            context: context,
            existingPages: existingPages,
            progress: &progress
        )

        let restoredIndices = Set(
            progress.results
                .prefix(progress.completedCount)
                .map(\.index)
        )
        let remainingPageIndices = pendingPageIndices
            .filter { !restoredIndices.contains($0) }
        var wasCancelled = false
        await processRemainingPages(
            context: context,
            remainingPageIndices: remainingPageIndices,
            existingPages: existingPages,
            progress: &progress,
            wasCancelled: &wasCancelled
        )

        if wasCancelled || Task.isCancelled {
            throw CancellationError()
        }
        try await flushDownloadProgress(
            context: .init(
                gid: context.payload.gallery.gid,
                folderURL: context.temporaryFolderURL
            ),
            pendingResolvedPages: &progress.pendingResolvedPages,
            completedCount: progress.completedCount,
            lastFlushDate: &progress.lastFlushDate,
            force: true
        )
        return try buildBatchResult(
            results: progress.results,
            failedPages: progress.failedPages,
            temporaryFolderURL: context.temporaryFolderURL
        )
    }

    private func initializePageDownloadState(
        context: PageDownloadContext,
        existingPages: [Int: String],
        progress: inout PageDownloadProgress
    ) async throws {
        let payload = context.payload
        let pageIndices = Array(1...payload.galleryDetail.pageCount)
        collectExistingPages(
            pageIndices: pageIndices,
            existingPages: existingPages,
            context: context,
            results: &progress.results,
            failedPages: &progress.failedPages
        )
        progress.completedCount = progress.results.count
        guard progress.completedCount > 0 else { return }
        let completedCount = progress.completedCount
        try flushManifestPageProgress(
            folderURL: context.temporaryFolderURL,
            pages: progress.results
        )
        try await updateDownloadRecord(
            gid: payload.gallery.gid,
            createIfMissing: false
        ) { record in
            record.completedPageCount = Int64(completedCount)
        }
        await notifyObservers()
    }

    private func buildBatchResult(
        results: [PageResult],
        failedPages: [Int: DownloadFailedPagesSnapshot.Page?],
        temporaryFolderURL: URL
    ) throws -> DownloadBatchResult {
        let failedSnapshot = DownloadFailedPagesSnapshot(
            pages: failedPages.values
                .compactMap { $0 }
                .filter {
                    !isCancellationLikeAppError($0.failure.appError)
                }
                .sorted(by: { $0.index < $1.index })
        )
        if failedSnapshot.pages.isEmpty {
            try? storage.removeFailedPages(
                folderURL: temporaryFolderURL
            )
        } else {
            try storage.writeFailedPages(
                failedSnapshot,
                folderURL: temporaryFolderURL
            )
        }
        return .init(
            pages: results,
            failedPages: failedSnapshot.pages
        )
    }

    private func buildExistingPages(
        existingManifest: DownloadManifest?,
        existingPageRelativePaths: [Int: String]
    ) -> [Int: String] {
        let manifestPages = Dictionary(
            uniqueKeysWithValues:
                (existingManifest?.pages ?? [])
                .filter { !$0.relativePath.hasSuffix(".pending") }
                .map { ($0.index, $0.relativePath) }
        )
        return manifestPages.merging(
            existingPageRelativePaths,
            uniquingKeysWith: { manifestPath, _ in manifestPath }
        )
    }

    private func collectExistingPages(
        pageIndices: [Int],
        existingPages: [Int: String],
        context: PageDownloadContext,
        results: inout [PageResult],
        failedPages: inout [Int: DownloadFailedPagesSnapshot.Page?]
    ) {
        for index in pageIndices {
            guard let relativePath = existingPages[index] else {
                continue
            }
            let fileURL = context.temporaryFolderURL
                .appendingPathComponent(relativePath)
            guard fileManager.operate({ $0.fileExists(atPath: fileURL.path) }) else {
                continue
            }
            failedPages[index] = nil
            results.append(
                .init(
                    index: index,
                    relativePath: relativePath,
                    imageURL: nil
                )
            )
        }
    }

    private func processRemainingPages(
        context: PageDownloadContext,
        remainingPageIndices: [Int],
        existingPages: [Int: String],
        progress: inout PageDownloadProgress,
        wasCancelled: inout Bool
    ) async {
        let payload = context.payload
        await withTaskGroup(of: PageTaskOutcome.self) { group in
            var pendingIterator =
                remainingPageIndices.makeIterator()
            seedInitialPageTasks(
                to: &group,
                iterator: &pendingIterator,
                context: context,
                pageCount: remainingPageIndices.count,
                existingPages: existingPages
            )
            while let outcome = await group.next() {
                if wasCancelled || Task.isCancelled
                    || schedulingBlockedGalleryIDs
                    .contains(payload.gallery.gid) {
                    wasCancelled = true
                    group.cancelAll()
                    continue
                }
                applyPageTaskOutcome(
                    outcome,
                    progress: &progress,
                    wasCancelled: &wasCancelled,
                    group: &group
                )
                guard !wasCancelled else { continue }
                try? await flushDownloadProgress(
                    context: .init(
                        gid: payload.gallery.gid,
                        folderURL: context.temporaryFolderURL
                    ),
                    pendingResolvedPages:
                        &progress.pendingResolvedPages,
                    completedCount: progress.completedCount,
                    lastFlushDate: &progress.lastFlushDate,
                    force: false
                )
                if let nextIndex = pendingIterator.next() {
                    addPageDownloadTask(
                        to: &group,
                        index: nextIndex,
                        context: context,
                        existingPages: existingPages
                    )
                }
            }
        }
    }

    private func seedInitialPageTasks(
        to group: inout TaskGroup<PageTaskOutcome>,
        iterator: inout IndexingIterator<[Int]>,
        context: PageDownloadContext,
        pageCount: Int,
        existingPages: [Int: String]
    ) {
        let workerCount = context.payload.options.workerCount
        for _ in 0..<min(workerCount, pageCount) {
            guard let index = iterator.next() else { break }
            addPageDownloadTask(
                to: &group,
                index: index,
                context: context,
                existingPages: existingPages
            )
        }
    }

    private func applyPageTaskOutcome(
        _ outcome: PageTaskOutcome,
        progress: inout PageDownloadProgress,
        wasCancelled: inout Bool,
        group: inout TaskGroup<PageTaskOutcome>
    ) {
        switch outcome {
        case .success(let pageResult):
            progress.completedCount += 1
            progress.failedPages[pageResult.index] = nil
            progress.results.append(pageResult)
            progress.pendingResolvedPages.append(pageResult)

        case .failure(let failure):
            if isCancellationLikeAppError(failure.error) {
                wasCancelled = true
                group.cancelAll()
                return
            }
            progress.failedPages[failure.index] = .init(
                index: failure.index,
                relativePath: failure.relativePath,
                failure: .init(error: failure.error)
            )

        case .cancelled:
            wasCancelled = true
            group.cancelAll()
        }
    }

    private func addPageDownloadTask(
        to group: inout TaskGroup<PageTaskOutcome>,
        index: Int,
        context: PageDownloadContext,
        existingPages: [Int: String]
    ) {
        group.addTask {
            do {
                return .success(
                    try await self.downloadPage(
                        index: index,
                        context: context,
                        preferredRelativePath:
                            existingPages[index]
                    )
                )
            } catch is CancellationError {
                return .cancelled
            } catch let error as AppError {
                return .failure(
                    .init(
                        index: index,
                        relativePath: existingPages[index],
                        error: error
                    )
                )
            } catch {
                if Self.isCancellationLikeError(error) {
                    return .cancelled
                }
                return .failure(
                    .init(
                        index: index,
                        relativePath: existingPages[index],
                        error: .fileOperationFailed(
                            error.localizedDescription
                        )
                    )
                )
            }
        }
    }
}
