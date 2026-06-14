//
//  DownloadPageDownloader.swift
//  EhPanda
//

import Foundation

struct DownloadPageTaskContext: Equatable, Sendable {
    let gid: String
    let pageIndex: Int
}

struct DownloadPageTransfer: Sendable {
    let fileURL: URL
    let response: URLResponse
    let taskIdentifier: Int?
}

struct DownloadPageDownloader: Sendable {
    var download: @Sendable (URLRequest, DownloadPageTaskContext) async throws -> DownloadPageTransfer

    static func foreground(urlSession: URLSession) -> Self {
        .init { request, _ in
            let (fileURL, response) = try await urlSession.download(for: request)
            return .init(
                fileURL: fileURL,
                response: response,
                taskIdentifier: nil
            )
        }
    }

    static func background(
        identifier: String,
        taskStore: DownloadBackgroundTaskStore,
        holdingDirectory: URL,
        fileManager: sending FileManager = .default,
        orphanedCompletionHandler: @escaping @Sendable (Int, URL, URLResponse) async -> Void = { _, _, _ in }
    ) -> Self {
        let session = BackgroundPageDownloadSession(
            identifier: identifier,
            taskStore: taskStore,
            holdingDirectory: holdingDirectory,
            fileManager: fileManager,
            orphanedCompletionHandler: orphanedCompletionHandler
        )
        return .init { request, context in
            try await session.download(for: request, context: context)
        }
    }
}

private actor BackgroundDownloadTaskHub {
    private enum Failure: Error, Sendable {
        case cancelled
        case app(AppError)

        var error: Error {
            switch self {
            case .cancelled:
                return CancellationError()
            case .app(let appError):
                return appError
            }
        }
    }

    private var continuations = [Int: CheckedContinuation<DownloadPageTransfer, Error>]()
    private var completions = [Int: DownloadPageTransfer]()
    private var failures = [Int: Failure]()

    func wait(
        taskIdentifier: Int,
        startTask: @escaping @Sendable () -> Void,
        cancelTask: @escaping @Sendable () -> Void
    ) async throws -> DownloadPageTransfer {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                register(
                    continuation,
                    taskIdentifier: taskIdentifier
                )
                startTask()
            }
        } onCancel: {
            cancelTask()
            Task {
                await self.cancel(taskIdentifier: taskIdentifier)
            }
        }
    }

    func succeed(
        taskIdentifier: Int,
        transfer: DownloadPageTransfer
    ) -> Bool {
        if let continuation = continuations.removeValue(forKey: taskIdentifier) {
            continuation.resume(returning: transfer)
            return true
        }
        completions[taskIdentifier] = transfer
        return false
    }

    func fail(
        taskIdentifier: Int,
        error: Error
    ) -> Bool {
        let failure = Self.failure(from: error)
        if let continuation = continuations.removeValue(forKey: taskIdentifier) {
            continuation.resume(throwing: failure.error)
            return true
        }
        failures[taskIdentifier] = failure
        return false
    }

    private func register(
        _ continuation: CheckedContinuation<DownloadPageTransfer, Error>,
        taskIdentifier: Int
    ) {
        if let transfer = completions.removeValue(forKey: taskIdentifier) {
            continuation.resume(returning: transfer)
            return
        }
        if let failure = failures.removeValue(forKey: taskIdentifier) {
            continuation.resume(throwing: failure.error)
            return
        }
        continuations[taskIdentifier] = continuation
    }

    private func cancel(taskIdentifier: Int) {
        if let continuation = continuations.removeValue(forKey: taskIdentifier) {
            continuation.resume(throwing: CancellationError())
            return
        }
        failures[taskIdentifier] = .cancelled
    }

    private static func failure(from error: Error) -> Failure {
        if error is CancellationError {
            return .cancelled
        }
        if let error = error as? AppError {
            return .app(error)
        }
        if let error = error as? URLError,
           error.code == .cancelled {
            return .cancelled
        }
        if DownloadCoordinator.isCancellationLikeError(error) {
            return .cancelled
        }
        if error is URLError {
            return .app(.networkingFailed)
        }
        return .app(.unknown)
    }
}

private actor BackgroundPageDownloadSession {
    private let taskStore: DownloadBackgroundTaskStore
    private let hub = BackgroundDownloadTaskHub()
    private let delegate: BackgroundPageDownloadDelegate
    private let session: URLSession

    init(
        identifier: String,
        taskStore: DownloadBackgroundTaskStore,
        holdingDirectory: URL,
        fileManager: sending FileManager,
        orphanedCompletionHandler: @escaping @Sendable (Int, URL, URLResponse) async -> Void
    ) {
        self.taskStore = taskStore
        let delegate = BackgroundPageDownloadDelegate(
            hub: hub,
            taskStore: taskStore,
            holdingDirectory: holdingDirectory,
            fileManager: fileManager,
            orphanedCompletionHandler: orphanedCompletionHandler
        )
        self.delegate = delegate
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    func download(
        for request: URLRequest,
        context: DownloadPageTaskContext
    ) async throws -> DownloadPageTransfer {
        let task = session.downloadTask(with: request)
        await taskStore.record(
            taskIdentifier: task.taskIdentifier,
            gid: context.gid,
            pageIndex: context.pageIndex
        )
        do {
            return try await hub.wait(
                taskIdentifier: task.taskIdentifier,
                startTask: { task.resume() },
                cancelTask: { task.cancel() }
            )
        } catch {
            await taskStore.remove(taskIdentifier: task.taskIdentifier)
            throw error
        }
    }
}

private final class BackgroundPageDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let hub: BackgroundDownloadTaskHub
    private let taskStore: DownloadBackgroundTaskStore
    private let holdingDirectory: URL
    private let fileManager: DownloadFileManager
    private let orphanedCompletionHandler: @Sendable (Int, URL, URLResponse) async -> Void

    init(
        hub: BackgroundDownloadTaskHub,
        taskStore: DownloadBackgroundTaskStore,
        holdingDirectory: URL,
        fileManager: sending FileManager,
        orphanedCompletionHandler: @escaping @Sendable (Int, URL, URLResponse) async -> Void
    ) {
        self.hub = hub
        self.taskStore = taskStore
        self.holdingDirectory = holdingDirectory
        self.fileManager = DownloadFileManager(fileManager)
        self.orphanedCompletionHandler = orphanedCompletionHandler
        super.init()
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskIdentifier = downloadTask.taskIdentifier
        guard let response = downloadTask.response else {
            complete(taskIdentifier: taskIdentifier, error: AppError.notFound)
            return
        }

        do {
            let stagedURL = try stageDownload(
                at: location,
                taskIdentifier: taskIdentifier
            )
            let transfer = DownloadPageTransfer(
                fileURL: stagedURL,
                response: response,
                taskIdentifier: taskIdentifier
            )
            Task {
                let consumed = await hub.succeed(
                    taskIdentifier: taskIdentifier,
                    transfer: transfer
                )
                if !consumed {
                    await orphanedCompletionHandler(
                        taskIdentifier,
                        stagedURL,
                        response
                    )
                }
            }
        } catch {
            complete(taskIdentifier: taskIdentifier, error: error)
        }
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        complete(taskIdentifier: task.taskIdentifier, error: error)
    }

    private func complete(
        taskIdentifier: Int,
        error: Error
    ) {
        Task {
            _ = await taskStore.remove(taskIdentifier: taskIdentifier)
            _ = await hub.fail(
                taskIdentifier: taskIdentifier,
                error: error
            )
        }
    }

    private func stageDownload(
        at location: URL,
        taskIdentifier: Int
    ) throws -> URL {
        let stagedURL = holdingDirectory
            .appendingPathComponent("\(taskIdentifier)-\(UUID().uuidString).download")
        try fileManager.operate {
            try $0.createDirectory(
                at: holdingDirectory,
                withIntermediateDirectories: true
            )
            try $0.moveItem(at: location, to: stagedURL)
        }
        return stagedURL
    }
}
