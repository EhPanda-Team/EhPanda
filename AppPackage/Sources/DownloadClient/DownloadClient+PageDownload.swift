import AppModels
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Download Pages
extension DownloadCoordinator {
    private struct PageDownloadProgress {
        var results: [PageResult] = []
        var failedPages: [Int: PageFailure?] = [:]
        var pendingResolvedPages: [PageResult] = []
        var lastFlushDate: Date = Date()
    }

    private struct PageDownloadControl {
        var wasCancelled = false
        var didAbortForFatalError = false
    }

    public func downloadPages(
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

        let restoredIndices = Set(progress.results.map(\.index))
        let remainingPageIndices = pendingPageIndices
            .filter({ !restoredIndices.contains($0) })
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
        // G-15-14. The invariant is the whole class, not this site: no range in this module is
        // built from an unguarded page count. `makeInitialManifest` and `reusableExistingManifest`
        // already branch on the same value, so zero is a modeled input here too — and `1...0` is an
        // invalid ClosedRange that traps the process rather than failing the download. The empty
        // case is spelled as a conditional construction, in `makeInitialManifest`'s shape, rather
        // than an early return: the rest of this body then runs unchanged over an empty index list,
        // so no input reaches a different tail than it did before.
        let pageCount = context.payload.galleryDetail.pageCount
        let pageIndices = pageCount > 0 ? Array(1...pageCount) : []
        collectExistingPages(
            pageIndices: pageIndices,
            existingPages: existingPages,
            context: context,
            results: &progress.results,
            failedPages: &progress.failedPages
        )
        // The collection itself is the condition, and always was: the counter this used to read was
        // assigned `progress.results.count` on the line above and tested for positivity here, so it
        // never said anything the collection does not. Nothing read it afterwards — the batch result
        // is built from `progress.results`, and the manifest flush is handed the same collection —
        // which is what made the increment in `applyPageTaskOutcome` a pure dead write once 15-45
        // removed the last reader (G-15-29).
        guard progress.results.isEmpty == false else { return }
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
            .compactMap({ $0 })
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
        for page in pageIndices {
            guard let relativePath = existingPages[page] else {
                continue
            }
            let fileURL = context.folderURL
                .appendingPathComponent(relativePath)
            guard fileManager.operate({ $0.fileExists(atPath: fileURL.path) }) else {
                continue
            }
            failedPages[page] = nil
            results.append(
                .init(
                    index: page,
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
                    || schedulingBlockedGalleryCounts[
                        payload.gallery.gid
                    ] != nil {
                    control.wasCancelled = true
                    group.cancelAll()
                    continue
                }
                applyPageTaskOutcome(
                    outcome,
                    gid: payload.gallery.gid,
                    progress: &progress,
                    control: &control,
                    group: &group
                )
                guard !control.wasCancelled, !control.didAbortForFatalError else { continue }
                // This cadence flush is opportunistic; a later forced flush persists
                // accumulated progress, so failure here must not abort page scheduling.
                do {
                    try await flushDownloadProgress(
                        context: .init(
                            gid: payload.gallery.gid,
                            folderURL: context.folderURL
                        ),
                        pendingResolvedPages:
                            &progress.pendingResolvedPages,
                        lastFlushDate: &progress.lastFlushDate,
                        force: false
                    )
                } catch {
                    logger.error("Download progress cadence flush failed: \(error, privacy: .private)")
                }
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
        let workerCount = context.options.workerCount
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

    /// Applies one page's outcome to the run's accumulated progress and control flags.
    ///
    /// The two flags travel as the `PageDownloadControl` value they already live in at the call
    /// site, rather than as two `inout Bool`s: the pair is one decision — how this batch should
    /// end — and passing them separately is what pushed this signature past the module's parameter
    /// limit when the gallery identifier joined it.
    private func applyPageTaskOutcome(
        _ outcome: PageTaskOutcome,
        gid: String,
        progress: inout PageDownloadProgress,
        control: inout PageDownloadControl,
        group: inout TaskGroup<PageTaskOutcome>
    ) {
        switch outcome {
        case .success(let pageResult):
            progress.failedPages[pageResult.index] = nil
            progress.results.append(pageResult)
            progress.pendingResolvedPages.append(pageResult)

        case .failure(let failure):
            if isCancellationLikeAppError(failure.error) {
                control.wasCancelled = true
                group.cancelAll()
                return
            }
            // The deliberate mover: a page that will not land in this run gives back its sub-page
            // credit. Deliberately after the cancellation-like return — a cancelled page is not a
            // failed one, and its credit is retired with the run instead.
            withdrawInFlightPageCredit(gid: gid, pageIndex: failure.index)
            progress.failedPages[failure.index] = failure
            if isFatalAccountAppError(failure.error) {
                control.didAbortForFatalError = true
                group.cancelAll()
            }

        case .cancelled:
            guard !control.didAbortForFatalError else { return }
            control.wasCancelled = true
            group.cancelAll()
        }
    }

    private func addPageDownloadTask(
        to group: inout TaskGroup<PageTaskOutcome>,
        index page: Int,
        context: PageDownloadContext,
        existingPages: [Int: String]
    ) {
        group.addTask {
            do {
                return .success(
                    try await self.downloadPage(
                        index: page,
                        context: context,
                        preferredRelativePath:
                            existingPages[page]
                    )
                )
            } catch is CancellationError {
                return .cancelled
            } catch let error as AppError {
                return .failure(
                    .init(
                        index: page,
                        relativePath: existingPages[page],
                        error: error
                    )
                )
            } catch {
                if Self.isCancellationLikeError(error) {
                    return .cancelled
                }
                return .failure(
                    .init(
                        index: page,
                        relativePath: existingPages[page],
                        error: .fileOperationFailed(
                            error.localizedDescription
                        )
                    )
                )
            }
        }
    }

    /// Whether an error is account-level fatal and must abort the whole page batch.
    ///
    /// Scope is intentionally **account-level only**: quota, auth, IP ban and an unsolved Cloudflare
    /// wall affect every in-flight and queued page, so continuing the batch only wastes requests and
    /// can worsen a ban.
    /// Gallery-level errors (`.expunged`, `.copyrightClaim`) are deliberately *not* fatal here — they
    /// mean the gallery is gone, but they surface before per-page download and are handled upstream,
    /// so a per-page occurrence is treated like any other page failure rather than aborting the batch.
    public func isFatalAccountAppError(_ error: AppError) -> Bool {
        switch error {
        // `.loginRejected` is unreachable from a page batch — it is thrown only by the login POST —
        // but it is account-level auth by the rule above, so it is classified with its neighbours
        // rather than defaulted. If a future path ever does surface it here, aborting the batch is
        // the safe reading: no page request succeeds while the credential is refused.
        case .quotaExceeded, .authenticationRequired, .ipBanned, .cloudflareChallengeFailed,
             .loginCaptchaRequired, .loginRejected:
            return true
        case .copyrightClaim, .expunged, .networkingFailed,
             .webImageFailed, .parseFailed, .fileOperationFailed, .noUpdates,
             .notFound, .unknown, .unsupportedDeepLink:
            return false
        }
    }
}
