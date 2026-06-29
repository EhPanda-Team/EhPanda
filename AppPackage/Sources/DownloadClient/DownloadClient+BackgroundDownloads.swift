import OSLogExt
import Foundation
import AppModels

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

public actor BackgroundPageCompletionReceiver {
    private enum PendingEvent {
        case completion(taskIdentifier: Int, fileURL: URL, response: URLResponse)
        case failure(taskIdentifier: Int, error: AppError?)
    }

    private var coordinator: DownloadCoordinator?
    private var pendingEvents = [PendingEvent]()

    public init() {}

    // The background URLSession is live the moment it's created, so iOS can replay a
    // stored completion before the coordinator is installed one task-hop later. Buffer
    // anything that arrives in that window and drain it here, or the event would no-op
    // against a nil coordinator — stranding the staged file and letting resumeQueue
    // re-download an already-finished page (defeats the offline-finish guarantee).
    public func setCoordinator(_ coordinator: DownloadCoordinator) async {
        self.coordinator = coordinator
        let bufferedEvents = pendingEvents
        pendingEvents.removeAll()
        for event in bufferedEvents {
            await deliver(event, to: coordinator)
        }
    }

    public func handleCompletion(
        taskIdentifier: Int,
        fileURL: URL,
        response: URLResponse
    ) async {
        guard let coordinator else {
            pendingEvents.append(
                .completion(taskIdentifier: taskIdentifier, fileURL: fileURL, response: response)
            )
            return
        }
        await coordinator.handleBackgroundPageDownloadCompleted(
            taskIdentifier: taskIdentifier,
            fileURL: fileURL,
            response: response
        )
    }

    public func handleFailure(
        taskIdentifier: Int,
        error: AppError?
    ) async {
        guard let coordinator else {
            pendingEvents.append(.failure(taskIdentifier: taskIdentifier, error: error))
            return
        }
        await coordinator.handleBackgroundPageDownloadFailed(
            taskIdentifier: taskIdentifier,
            error: error
        )
    }

    private func deliver(
        _ event: PendingEvent,
        to coordinator: DownloadCoordinator
    ) async {
        switch event {
        case let .completion(taskIdentifier, fileURL, response):
            await coordinator.handleBackgroundPageDownloadCompleted(
                taskIdentifier: taskIdentifier,
                fileURL: fileURL,
                response: response
            )
        case let .failure(taskIdentifier, error):
            await coordinator.handleBackgroundPageDownloadFailed(
                taskIdentifier: taskIdentifier,
                error: error
            )
        }
    }
}

extension DownloadCoordinator {
    public func handleBackgroundPageDownloadCompleted(
        taskIdentifier: Int,
        fileURL: URL,
        response: URLResponse
    ) async {
        guard let record = await backgroundTaskStore.record(
            taskIdentifier: taskIdentifier
        ) else {
            removeStagedBackgroundFile(fileURL)
            return
        }

        do {
            try await attachBackgroundPageDownload(
                record: record,
                fileURL: fileURL,
                response: response
            )
        } catch {
            logger.error("\(error, privacy: .public)")
            removeStagedBackgroundFile(fileURL)
            // A fatal account error (quota/auth/ban) detected on an orphaned page must
            // settle the whole download like the foreground does, so scheduleNextIfNeeded
            // below can't auto-resume it against the ban (BUG-6 / no-auto-retry).
            if let appError = error as? AppError, isFatalAccountAppError(appError) {
                await settleDownloadFailure(gid: record.gid, error: appError)
            }
        }

        await backgroundTaskStore.remove(taskIdentifier: taskIdentifier)
        await notifyObservers()
        await scheduleNextIfNeeded()
    }

    public func handleBackgroundPageDownloadFailed(
        taskIdentifier: Int,
        error: AppError?
    ) async {
        guard let record = await backgroundTaskStore.record(
            taskIdentifier: taskIdentifier
        ) else {
            return
        }

        // A non-cancellation error surfaces as a page failure (DES-8: in-memory);
        // a cancellation only cleans up the persisted task record below.
        if let error {
            if !hasLoadedIndex {
                await reloadDownloadIndex()
            }
            if let folderRecord = downloadIndex[record.gid],
               folderRecord.manifest.pages[record.pageIndex] != nil {
                failedPageErrors[record.gid, default: [:]][record.pageIndex] = .init(
                    index: record.pageIndex,
                    relativePath: nil,
                    error: error
                )
            }
            if isFatalAccountAppError(error) {
                await settleDownloadFailure(gid: record.gid, error: error)
            }
        }

        await backgroundTaskStore.remove(taskIdentifier: taskIdentifier)
        await notifyObservers()
        await scheduleNextIfNeeded()
    }

    private func attachBackgroundPageDownload(
        record: DownloadBackgroundTaskStore.Record,
        fileURL: URL,
        response: URLResponse
    ) async throws {
        if !hasLoadedIndex {
            await reloadDownloadIndex()
        }
        guard let folderRecord = downloadIndex[record.gid] else {
            throw AppError.notFound
        }
        guard folderRecord.manifest.pages[record.pageIndex] != nil else {
            throw AppError.notFound
        }
        if let error = detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: response.url
        ) {
            failedPageErrors[record.gid, default: [:]][record.pageIndex] = .init(
                index: record.pageIndex,
                relativePath: nil,
                error: error
            )
            throw error
        }

        let relativePath = try backgroundPageRelativePath(
            record: record,
            fileURL: fileURL,
            response: response,
            folderRecord: folderRecord
        )
        let destinationURL = folderRecord.folderURL
            .appendingPathComponent(relativePath)
        if fileManager.operate({ $0.fileExists(atPath: destinationURL.path) }) {
            removeStagedBackgroundFile(fileURL)
        } else {
            try moveDownloadedFile(from: fileURL, to: destinationURL)
        }
        try flushManifestPageProgress(
            folderURL: folderRecord.folderURL,
            pages: [
                .init(
                    index: record.pageIndex,
                    relativePath: relativePath,
                    imageURL: response.url
                )
            ]
        )
    }

    private func backgroundPageRelativePath(
        record: DownloadBackgroundTaskStore.Record,
        fileURL: URL,
        response: URLResponse,
        folderRecord: DownloadFolderRecord
    ) throws -> String {
        let existingPages = storage.existingPageRelativePaths(
            folderURL: folderRecord.folderURL,
            manifest: folderRecord.manifest
        )
        if let relativePath = existingPages[record.pageIndex] {
            return relativePath
        }

        let prefixData = try readResponsePrefixData(at: fileURL)
        let ext = fileExtension(
            for: response.url ?? URL(fileURLWithPath: "download"),
            response: response,
            prefixData: prefixData
        )
        return storage.makePageRelativePath(
            gid: folderRecord.manifest.gid,
            token: folderRecord.manifest.token,
            index: record.pageIndex,
            fileExtension: ext
        )
    }

    public func removeStagedBackgroundFile(_ fileURL: URL) {
        try? fileManager.operate {
            guard $0.fileExists(atPath: fileURL.path) else { return }
            try $0.removeItem(at: fileURL)
        }
    }
}
