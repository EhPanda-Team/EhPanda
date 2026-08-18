import AppModels
import Foundation
import Synchronization

public struct DownloadPageTaskContext: Equatable, Sendable {
    public let gid: String
    public let pageIndex: Int
    public init(
        gid: String,
        pageIndex: Int
    ) {
        self.gid = gid
        self.pageIndex = pageIndex
    }
}

public struct DownloadPageTransfer: Sendable {
    public let fileURL: URL
    public let response: URLResponse
    public let taskIdentifier: Int?
    public init(
        fileURL: URL,
        response: URLResponse,
        taskIdentifier: Int? = nil
    ) {
        self.fileURL = fileURL
        self.response = response
        self.taskIdentifier = taskIdentifier
    }
}

/// Reports one transfer's byte progress while it is still in flight.
///
/// Called on the delegate's own queue, already throttled by the delegate, so a handler is free to
/// hop onto an actor without fanning out a task per received chunk.
public typealias DownloadPageTransferProgressHandler = @Sendable (
    _ totalBytesWritten: Int64,
    _ totalBytesExpected: Int64
) -> Void

public struct DownloadPageDownloader: Sendable {
    public var download: @Sendable (
        URLRequest,
        DownloadPageTaskContext,
        @escaping DownloadPageTransferProgressHandler
    ) async throws -> DownloadPageTransfer
    public init(
        download: @escaping @Sendable (
            URLRequest,
            DownloadPageTaskContext,
            @escaping DownloadPageTransferProgressHandler
        ) async throws -> DownloadPageTransfer
    ) {
        self.download = download
    }

    /// The handler is deliberately ignored: `URLSession.download(for:)` reports no intermediate
    /// bytes at all, so a foreground transfer credits whole pages only. The live client uses
    /// `.background`, and the session heartbeat covers this path regardless.
    public static func foreground(urlSession: URLSession) -> Self {
        .init { request, _, _ in
            let (fileURL, response) = try await urlSession.download(for: request)
            return .init(
                fileURL: fileURL,
                response: response,
                taskIdentifier: nil
            )
        }
    }

    public static func background(
        identifier: String,
        taskStore: DownloadBackgroundTaskStore,
        holdingDirectory: URL,
        fileManager: sending FileManager = FileManager(),
        orphanedCompletionHandler: @escaping @Sendable (Int, URL, URLResponse) async -> Void = { _, _, _ in },
        orphanedFailureHandler: @escaping @Sendable (Int, AppError?) async -> Void = { _, _ in }
    ) -> Self {
        let session = BackgroundPageDownloadSession(
            identifier: identifier,
            taskStore: taskStore,
            holdingDirectory: holdingDirectory,
            fileManager: fileManager,
            orphanedCompletionHandler: orphanedCompletionHandler,
            orphanedFailureHandler: orphanedFailureHandler
        )
        return .init { request, context, onBytesWritten in
            try await session.download(
                for: request,
                context: context,
                onBytesWritten: onBytesWritten
            )
        }
    }
}

public enum DownloadBackgroundSessionEvents {
    public static let pageSessionIdentifier: String = "app.ehpanda.downloads.pages"

    @MainActor
    private static var completionHandlers = [String: () -> Void]()

    @MainActor
    public static func setCompletionHandler(
        _ completionHandler: @escaping () -> Void,
        for identifier: String
    ) {
        completionHandlers[identifier] = completionHandler
    }

    @MainActor
    public static func finishEvents(for identifier: String?) {
        guard let identifier,
              let completionHandler = completionHandlers.removeValue(
                forKey: identifier
              )
        else { return }
        completionHandler()
    }
}

// A FIFO-bounded map: stash entries left behind by orphaned tasks or cancel-vs-
// complete races (no registration ever claims them) can't grow without bound over
// a long-lived session.
private struct BoundedStash<Value> {
    private let capacity: Int
    private var order = [Int]()
    private var entries = [Int: Value]()

    init(capacity: Int) {
        self.capacity = capacity
    }

    mutating func insert(_ value: Value, forKey key: Int) {
        if entries[key] == nil {
            order.append(key)
        }
        entries[key] = value
        while order.count > capacity {
            let evictedKey = order.removeFirst()
            entries[evictedKey] = nil
        }
    }

    mutating func removeValue(forKey key: Int) -> Value? {
        guard let value = entries.removeValue(forKey: key) else {
            return nil
        }
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        return value
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

    private static let stashCapacity = 256

    private var continuations = [Int: CheckedContinuation<DownloadPageTransfer, Error>]()
    private var completions = BoundedStash<DownloadPageTransfer>(
        capacity: BackgroundDownloadTaskHub.stashCapacity
    )
    private var failures = BoundedStash<Failure>(
        capacity: BackgroundDownloadTaskHub.stashCapacity
    )

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
        completions.insert(transfer, forKey: taskIdentifier)
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
        failures.insert(failure, forKey: taskIdentifier)
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
        failures.insert(.cancelled, forKey: taskIdentifier)
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

    // Classifies a delegate error for the orphaned-failure route: `nil` for a
    // cancellation (clean up the task record only), the AppError otherwise.
    static func orphanedFailureError(from error: Error) -> AppError? {
        switch failure(from: error) {
        case .cancelled:
            return nil
        case .app(let appError):
            return appError
        }
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
        orphanedCompletionHandler: @escaping @Sendable (Int, URL, URLResponse) async -> Void,
        orphanedFailureHandler: @escaping @Sendable (Int, AppError?) async -> Void
    ) {
        self.taskStore = taskStore
        let delegate = BackgroundPageDownloadDelegate(
            hub: hub,
            taskStore: taskStore,
            holdingDirectory: holdingDirectory,
            fileManager: fileManager,
            orphanedCompletionHandler: orphanedCompletionHandler,
            orphanedFailureHandler: orphanedFailureHandler
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
        context: DownloadPageTaskContext,
        onBytesWritten: @escaping DownloadPageTransferProgressHandler
    ) async throws -> DownloadPageTransfer {
        let task = session.downloadTask(with: request)
        await taskStore.record(
            taskIdentifier: task.taskIdentifier,
            gid: context.gid,
            pageIndex: context.pageIndex
        )
        // Registered BEFORE `hub.wait` resumes the task, so no byte callback can arrive with no
        // forwarder to reach; removed on every exit, so a recycled task identifier cannot inherit
        // a departed transfer's handler.
        delegate.registerProgressForwarder(onBytesWritten, taskIdentifier: task.taskIdentifier)
        defer { delegate.removeProgressForwarder(taskIdentifier: task.taskIdentifier) }
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
    /// One in-flight transfer's byte handler, plus when it last forwarded.
    ///
    /// A named value rather than a pair, on the module's own rule; and the date lives beside the
    /// handler so the throttle decision and the stamp that records it happen under one lock.
    private struct ProgressForwarder: Sendable {
        let handler: DownloadPageTransferProgressHandler
        var lastForwardDate: Date?
    }

    /// The shortest gap between two forwarded byte reports for one transfer.
    ///
    /// Chunks arrive tens of times a second per transfer and each forward costs a hop onto the
    /// coordinator's actor, so this delegate-side throttle — not the coordinator's push throttle —
    /// is what keeps the fan-out bounded at the source.
    private static let progressForwardingMinimumInterval: TimeInterval = 0.25

    private let hub: BackgroundDownloadTaskHub
    private let taskStore: DownloadBackgroundTaskStore
    private let holdingDirectory: URL
    private let fileManager: DownloadFileManager
    private let orphanedCompletionHandler: @Sendable (Int, URL, URLResponse) async -> Void
    private let orphanedFailureHandler: @Sendable (Int, AppError?) async -> Void
    private let progressForwarders = Mutex([Int: ProgressForwarder]())

    init(
        hub: BackgroundDownloadTaskHub,
        taskStore: DownloadBackgroundTaskStore,
        holdingDirectory: URL,
        fileManager: sending FileManager,
        orphanedCompletionHandler: @escaping @Sendable (Int, URL, URLResponse) async -> Void,
        orphanedFailureHandler: @escaping @Sendable (Int, AppError?) async -> Void
    ) {
        self.hub = hub
        self.taskStore = taskStore
        self.holdingDirectory = holdingDirectory
        self.fileManager = DownloadFileManager(fileManager)
        self.orphanedCompletionHandler = orphanedCompletionHandler
        self.orphanedFailureHandler = orphanedFailureHandler
        super.init()
    }

    func registerProgressForwarder(
        _ handler: @escaping DownloadPageTransferProgressHandler,
        taskIdentifier: Int
    ) {
        progressForwarders.withLock({ $0[taskIdentifier] = ProgressForwarder(handler: handler) })
    }

    func removeProgressForwarder(taskIdentifier: Int) {
        progressForwarders.withLock({ $0[taskIdentifier] = nil })
    }

    /// Forwards a transfer's running byte totals, on the first callback and then at most once per
    /// `progressForwardingMinimumInterval`.
    ///
    /// The lookup, the throttle decision and the stamp that records it all happen inside one
    /// critical section, so two callbacks for the same task cannot both read a stale stamp and both
    /// forward. The handler is called OUTSIDE the lock: it hops onto an actor, and holding a mutex
    /// across that hand-off would serialize the delegate queue behind it.
    ///
    /// An unknown expected size (`NSURLSessionTransferSizeUnknown`) passes through unchanged; what
    /// to make of it is the receiver's decision, not this forwarder's.
    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskIdentifier = downloadTask.taskIdentifier
        let handler = progressForwarders.withLock { forwarders -> DownloadPageTransferProgressHandler? in
            guard var forwarder = forwarders[taskIdentifier] else { return nil }
            let forwardDate = Date()
            if let lastForwardDate = forwarder.lastForwardDate,
               forwardDate.timeIntervalSince(lastForwardDate) < Self.progressForwardingMinimumInterval {
                return nil
            }
            forwarder.lastForwardDate = forwardDate
            forwarders[taskIdentifier] = forwarder
            return forwarder.handler
        }
        handler?(totalBytesWritten, totalBytesExpectedToWrite)
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

    func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        Task { @MainActor in
            DownloadBackgroundSessionEvents.finishEvents(
                for: session.configuration.identifier
            )
        }
    }

    private func complete(
        taskIdentifier: Int,
        error: Error
    ) {
        Task {
            // The in-process waiter removes its own task record when `wait` throws;
            // an orphaned failure (no waiter) is routed instead, mirroring the
            // orphaned-completion path, so it isn't stashed and dropped silently.
            let consumed = await hub.fail(
                taskIdentifier: taskIdentifier,
                error: error
            )
            if !consumed {
                await orphanedFailureHandler(
                    taskIdentifier,
                    BackgroundDownloadTaskHub.orphanedFailureError(from: error)
                )
            }
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
