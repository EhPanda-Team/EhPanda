//
//  DownloadClient+BackgroundDownloads.swift
//  EhPanda
//

import Foundation

actor BackgroundPageCompletionReceiver {
    private var coordinator: DownloadCoordinator?

    func setCoordinator(_ coordinator: DownloadCoordinator) {
        self.coordinator = coordinator
    }

    func handleCompletion(
        taskIdentifier: Int,
        fileURL: URL,
        response: URLResponse
    ) async {
        await coordinator?.handleBackgroundPageDownloadCompleted(
            taskIdentifier: taskIdentifier,
            fileURL: fileURL,
            response: response
        )
    }
}

extension DownloadCoordinator {
    func handleBackgroundPageDownloadCompleted(
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
            Logger.error(error)
            removeStagedBackgroundFile(fileURL)
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

    private func removeStagedBackgroundFile(_ fileURL: URL) {
        try? fileManager.operate {
            guard $0.fileExists(atPath: fileURL.path) else { return }
            try $0.removeItem(at: fileURL)
        }
    }
}
