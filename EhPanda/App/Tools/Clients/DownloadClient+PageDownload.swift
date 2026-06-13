//
//  DownloadClient+PageDownload.swift
//  EhPanda
//

import Foundation

// MARK: - Download Pages
extension DownloadManager {
    private struct PageDownloadProgress {
        var results: [PageResult] = []
        var failedPages: [Int: PageFailure?] = [:]
        var completedCount: Int = 0
        var pendingResolvedPages: [PageResult] = []
        var lastFlushDate: Date = Date()
    }

    private struct PageDownloadControl {
        var wasCancelled = false
        var didAbortForFatalError = false
    }

    func downloadPages(
        context: PageDownloadContext,
        pendingPageIndices: [Int],
        existingManifest: DownloadManifest,
        existingPageRelativePaths: [Int: String]
    ) async throws -> DownloadBatchResult {
        let existingPages = buildExistingPages(
            existingManifest: existingManifest,
            existingPageRelativePaths: existingPageRelativePaths
        )
        var progress = PageDownloadProgress()
        progress.failedPages = failedPageErrors[context.payload.gallery.gid]?
            .mapValues(Optional.some) ?? [:]

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
        var control = PageDownloadControl()
        await processRemainingPages(
            context: context,
            remainingPageIndices: remainingPageIndices,
            existingPages: existingPages,
            progress: &progress,
            control: &control
        )

        if control.wasCancelled || Task.isCancelled {
            throw CancellationError()
        }
        try await flushDownloadProgress(
            context: .init(
                gid: context.payload.gallery.gid,
                folderURL: context.folderURL
            ),
            pendingResolvedPages: &progress.pendingResolvedPages,
            lastFlushDate: &progress.lastFlushDate,
            force: true
        )
        return try buildBatchResult(
            results: progress.results,
            failedPages: progress.failedPages
        )
    }

    private func initializePageDownloadState(
        context: PageDownloadContext,
        existingPages: [Int: String],
        progress: inout PageDownloadProgress
    ) async throws {
        let pageIndices = Array(
            1...context.payload.galleryDetail.pageCount
        )
        collectExistingPages(
            pageIndices: pageIndices,
            existingPages: existingPages,
            context: context,
            results: &progress.results,
            failedPages: &progress.failedPages
        )
        progress.completedCount = progress.results.count
        guard progress.completedCount > 0 else { return }
        try flushManifestPageProgress(
            folderURL: context.folderURL,
            pages: progress.results
        )
        await notifyObservers()
    }

    private func buildBatchResult(
        results: [PageResult],
        failedPages: [Int: PageFailure?]
    ) throws -> DownloadBatchResult {
        let activeFailedPages = failedPages.values
            .compactMap { $0 }
            .filter {
                !isCancellationLikeAppError($0.error)
            }
            .sorted(by: { $0.index < $1.index })
        return .init(
            pages: results,
            failedPages: activeFailedPages
        )
    }

    private func buildExistingPages(
        existingManifest: DownloadManifest,
        existingPageRelativePaths: [Int: String]
    ) -> [Int: String] {
        let manifestPageIndices = Set(existingManifest.pages.keys)
        return existingPageRelativePaths.filter {
            manifestPageIndices.contains($0.key)
        }
    }

    private func collectExistingPages(
        pageIndices: [Int],
        existingPages: [Int: String],
        context: PageDownloadContext,
        results: inout [PageResult],
        failedPages: inout [Int: PageFailure?]
    ) {
        for index in pageIndices {
            guard let relativePath = existingPages[index] else {
                continue
            }
            let fileURL = context.folderURL
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
        control: inout PageDownloadControl
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
                guard !control.didAbortForFatalError else {
                    group.cancelAll()
                    continue
                }
                if control.wasCancelled || Task.isCancelled
                    || schedulingBlockedGalleryIDs
                    .contains(payload.gallery.gid) {
                    control.wasCancelled = true
                    group.cancelAll()
                    continue
                }
                applyPageTaskOutcome(
                    outcome,
                    progress: &progress,
                    wasCancelled: &control.wasCancelled,
                    didAbortForFatalError: &control.didAbortForFatalError,
                    group: &group
                )
                guard !control.wasCancelled, !control.didAbortForFatalError else { continue }
                try? await flushDownloadProgress(
                    context: .init(
                        gid: payload.gallery.gid,
                        folderURL: context.folderURL
                    ),
                    pendingResolvedPages:
                        &progress.pendingResolvedPages,
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
        didAbortForFatalError: inout Bool,
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
            progress.failedPages[failure.index] = failure
            if isFatalAccountAppError(failure.error) {
                didAbortForFatalError = true
                group.cancelAll()
            }

        case .cancelled:
            guard !didAbortForFatalError else { return }
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

    private func isFatalAccountAppError(_ error: AppError) -> Bool {
        switch error {
        case .quotaExceeded, .authenticationRequired, .ipBanned:
            return true
        case .databaseCorrupted, .copyrightClaim, .expunged, .networkingFailed,
             .webImageFailed, .parseFailed, .fileOperationFailed, .noUpdates,
             .notFound, .unknown:
            return false
        }
    }
}
