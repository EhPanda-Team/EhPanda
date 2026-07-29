@testable import AppFeature
import BackgroundProcessingClient
import Foundation
import Synchronization

// MARK: - Supporting Types

final class UncheckedBox<Value: Sendable>: Sendable {
    private let storage: Mutex<Value>

    init(_ value: Value) {
        storage = Mutex(value)
    }

    var value: Value {
        get { storage.withLock({ $0 }) }
        set { storage.withLock({ $0 = newValue }) }
    }
}

struct RequestRecorderSnapshot: Equatable {
    var detailRequests = 0
    var metadataRequests = 0
    var mpvRequests = 0
    var imageDispatchRequests = 0
    var imageDownloads = 0
    var previewPageNumbers = [Int]()
}

final class RequestRecorder: Sendable {
    private let state = Mutex(RequestRecorderSnapshot())

    func recordDetail() {
        state.withLock({ $0.detailRequests += 1 })
    }

    func recordMetadata() {
        state.withLock({ $0.metadataRequests += 1 })
    }

    func recordPreview(_ pageNumber: Int) {
        state.withLock({ $0.previewPageNumbers.append(pageNumber) })
    }

    func recordMPV() {
        state.withLock({ $0.mpvRequests += 1 })
    }

    func recordImageDispatch() {
        state.withLock({ $0.imageDispatchRequests += 1 })
    }

    func recordImageDownload() {
        state.withLock({ $0.imageDownloads += 1 })
    }

    func reset() {
        state.withLock({ $0 = .init() })
    }

    func snapshot() -> RequestRecorderSnapshot {
        state.withLock({ $0 })
    }
}

/// Stands in for the continued-processing session client, recording everything a case pushes at
/// the seam and letting the case deliver events on its own schedule.
///
/// The whole of its state sits behind one `Mutex` so the spy is genuinely `Sendable` and can be
/// read from the case while the coordinator's actor writes to it.
///
/// The spy mirrors the live store's single-session guard: `start` refuses while a session identity
/// is held. A matching `finish` releases that identity, while `expire()` takes the continuation and
/// releases the identity atomically before delivering the terminal event. The one-shot
/// `refuseNextStart()` control remains available for explicit refusal coverage.
final class BackgroundProcessingClientSpy: Sendable {
    /// One `updateProgress` call. A named record rather than a tuple: an unlabeled tuple type is
    /// banned at error severity here, and `.0`/`.1` reads carry no meaning at an assertion site.
    struct ProgressUpdate: Equatable {
        let sessionID: UUID
        let completedUnitCount: Int64
        let totalUnitCount: Int64
        let subtitle: String
    }

    /// One `finish` call. Naming both fields keeps identity assertions readable and satisfies the
    /// project's error-severity tuple rule.
    struct FinishRecord: Equatable {
        let sessionID: UUID
        let success: Bool
    }

    /// One-shot rendezvous for a staged start. `entered()` returns only after the spy has recorded
    /// the start, and `release()` lets that start return its session handle.
    struct StartGate: Sendable {
        fileprivate let enteredEvents: AsyncStream<Void>
        fileprivate let releaseContinuation: AsyncStream<Void>.Continuation

        func entered() async {
            for await _ in enteredEvents {
                return
            }
        }

        func release() {
            releaseContinuation.yield()
            releaseContinuation.finish()
        }
    }

    /// One-shot rendezvous for a staged progress push. `entered()` returns after the call has
    /// crossed the seam with its complete arguments; `release()` lets the identity guard decide
    /// whether the update still belongs to the held session.
    struct ProgressGate: Sendable {
        fileprivate let enteredEvents: AsyncStream<Void>
        fileprivate let releaseContinuation: AsyncStream<Void>.Continuation

        func entered() async {
            for await _ in enteredEvents {
                return
            }
        }

        func release() {
            releaseContinuation.yield()
            releaseContinuation.finish()
        }
    }

    /// The spy-owned half of a start gate. Keeping both continuations in the mutex-protected state
    /// lets the next start take the gate atomically with its complete recording.
    private struct ArmedStartGate: Sendable {
        let enteredContinuation: AsyncStream<Void>.Continuation
        let releaseEvents: AsyncStream<Void>
    }

    /// The spy-owned half of a progress gate, taken atomically by the next progress call.
    private struct ArmedProgressGate: Sendable {
        let enteredContinuation: AsyncStream<Void>.Continuation
        let releaseEvents: AsyncStream<Void>
    }

    private struct State {
        var startCount = 0
        var startTitles = [String]()
        var startSubtitles = [String]()
        var startCompletedUnitCounts = [Int64]()
        var startTotalUnitCounts = [Int64]()
        var startSessionIDs = [UUID]()
        var progressUpdates = [ProgressUpdate]()
        var rejectedProgressUpdates = [ProgressUpdate]()
        var finishRecords = [FinishRecord]()
        var currentSessionID: UUID?
        var continuation: AsyncStream<BackgroundProcessingEvent>.Continuation?
        var armedStartGate: ArmedStartGate?
        var armedProgressGate: ArmedProgressGate?
        var inFlightProgressUpdate: ProgressUpdate?
        var refusesNextStart = false
    }

    private let state = Mutex(State())

    var startCount: Int { state.withLock({ $0.startCount }) }
    var startTitles: [String] { state.withLock({ $0.startTitles }) }
    var startSubtitles: [String] { state.withLock({ $0.startSubtitles }) }
    var startCompletedUnitCounts: [Int64] { state.withLock({ $0.startCompletedUnitCounts }) }
    var startTotalUnitCounts: [Int64] { state.withLock({ $0.startTotalUnitCounts }) }
    var startSessionIDs: [UUID] { state.withLock({ $0.startSessionIDs }) }
    var progressUpdates: [ProgressUpdate] { state.withLock({ $0.progressUpdates }) }
    var rejectedProgressUpdates: [ProgressUpdate] {
        state.withLock({ $0.rejectedProgressUpdates })
    }
    var finishRecords: [FinishRecord] { state.withLock({ $0.finishRecords }) }
    var finishCount: Int { finishRecords.count }
    var finishSuccesses: [Bool] { finishRecords.map(\.success) }

    /// Arms a one-shot gate for the next accepted start.
    ///
    /// The start records its complete session state before signaling `entered`, then parks until
    /// the returned handle is released. No clock or polling participates in the rendezvous.
    func armStartGate() -> StartGate {
        let (enteredEvents, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let (releaseEvents, releaseContinuation) = AsyncStream.makeStream(of: Void.self)
        state.withLock {
            $0.armedStartGate = ArmedStartGate(
                enteredContinuation: enteredContinuation,
                releaseEvents: releaseEvents
            )
        }
        return StartGate(
            enteredEvents: enteredEvents,
            releaseContinuation: releaseContinuation
        )
    }

    /// Arms a one-shot gate for the next progress push.
    ///
    /// The call records its complete argument set before signaling `entered`, then parks before
    /// the identity guard. Releasing it after a successor starts therefore exercises the same
    /// stale actor hop as the live seam without a clock, polling, or scheduler assumption.
    func armProgressGate() -> ProgressGate {
        let (enteredEvents, enteredContinuation) = AsyncStream.makeStream(of: Void.self)
        let (releaseEvents, releaseContinuation) = AsyncStream.makeStream(of: Void.self)
        state.withLock {
            $0.armedProgressGate = ArmedProgressGate(
                enteredContinuation: enteredContinuation,
                releaseEvents: releaseEvents
            )
        }
        return ProgressGate(
            enteredEvents: enteredEvents,
            releaseContinuation: releaseContinuation
        )
    }

    /// Makes the next start observable as a refusal: the call and strings are recorded, but no
    /// session identity or event continuation is created.
    func refuseNextStart() {
        state.withLock({ $0.refusesNextStart = true })
    }

    /// Delivers one event to whoever is consuming the live stream, leaving the stream open.
    func emit(_ event: BackgroundProcessingEvent) {
        let continuation = state.withLock({ $0.continuation })
        continuation?.yield(event)
    }

    /// Delivers an expiration and then finishes the stream, mirroring the real client's
    /// self-finishing contract: the held session identity is released with the continuation and a
    /// consumer's `for await` loop falls out on its own.
    func expire() {
        let continuation = takeContinuation()
        continuation?.yield(.expired)
        continuation?.finish()
    }

    /// Hands back the live continuation and clears the held identity in the same critical section,
    /// matching the live store's terminal cleanup so a transition cannot apply twice.
    private func takeContinuation() -> AsyncStream<BackgroundProcessingEvent>.Continuation? {
        state.withLock {
            let continuation = $0.continuation
            $0.currentSessionID = nil
            $0.continuation = nil
            return continuation
        }
    }

    var client: BackgroundProcessingClient {
        BackgroundProcessingClient(
            start: { title, subtitle, completedUnitCount, totalUnitCount in
                let shouldRefuse = self.state.withLock {
                    $0.startCount += 1
                    $0.startTitles.append(title)
                    $0.startSubtitles.append(subtitle)
                    $0.startCompletedUnitCounts.append(completedUnitCount)
                    $0.startTotalUnitCounts.append(totalUnitCount)
                    guard $0.currentSessionID == nil, !$0.refusesNextStart else {
                        $0.refusesNextStart = false
                        return true
                    }
                    return false
                }
                guard !shouldRefuse else { return nil }

                let (stream, continuation) = AsyncStream.makeStream(
                    of: BackgroundProcessingEvent.self
                )
                let sessionID = UUID()
                let gate = self.state.withLock {
                    $0.startSessionIDs.append(sessionID)
                    $0.currentSessionID = sessionID
                    $0.continuation = continuation
                    let gate = $0.armedStartGate
                    $0.armedStartGate = nil
                    return gate
                }
                if let gate {
                    gate.enteredContinuation.yield()
                    gate.enteredContinuation.finish()
                    for await _ in gate.releaseEvents {
                        break
                    }
                }
                return BackgroundProcessingSession(id: sessionID, events: stream)
            },
            updateProgress: { sessionID, completedUnitCount, totalUnitCount, subtitle in
                // The live store accepts progress only for the identity it still owns.
                let update = ProgressUpdate(
                    sessionID: sessionID,
                    completedUnitCount: completedUnitCount,
                    totalUnitCount: totalUnitCount,
                    subtitle: subtitle
                )
                let gate = self.state.withLock {
                    $0.inFlightProgressUpdate = update
                    let gate = $0.armedProgressGate
                    $0.armedProgressGate = nil
                    return gate
                }
                if let gate {
                    gate.enteredContinuation.yield()
                    gate.enteredContinuation.finish()
                    for await _ in gate.releaseEvents {
                        break
                    }
                }
                self.state.withLock {
                    $0.inFlightProgressUpdate = nil
                    if $0.currentSessionID == sessionID {
                        $0.progressUpdates.append(update)
                    } else {
                        $0.rejectedProgressUpdates.append(update)
                    }
                }
            },
            finish: { sessionID, success in
                // The live store records the request at this seam but releases only a matching ID.
                let continuation: AsyncStream<BackgroundProcessingEvent>.Continuation? =
                    self.state.withLock {
                        $0.finishRecords.append(
                            FinishRecord(sessionID: sessionID, success: success)
                        )
                        guard $0.currentSessionID == sessionID else { return nil }
                        let continuation = $0.continuation
                        $0.currentSessionID = nil
                        $0.continuation = nil
                        return continuation
                    }
                continuation?.finish()
            }
        )
    }
}

final class ScheduledGalleryRecorder: Sendable {
    private let state = Mutex([String]())

    func record(_ gid: String) {
        state.withLock({ $0.append(gid) })
    }

    func snapshot() -> [String] {
        state.withLock({ $0 })
    }
}

/// Fails one named removal while forwarding every other filesystem operation to `FileManager`.
///
/// The production path reaches removal through `DownloadFileManager.operate`, so injection here
/// exercises that real call chain, including the store's path-escape guard. A named path failure is
/// deterministic on every machine and under every sandbox, unlike changing temporary-directory
/// permissions.
final class FailingRemovalFileManager: FileManager {
    private let pathFragment: String
    private let error: any Error & Sendable

    init(
        pathFragment: String,
        error: any Error & Sendable
    ) {
        self.pathFragment = pathFragment
        self.error = error
        super.init()
    }

    override func removeItem(at url: URL) throws {
        guard url.path.contains(pathFragment) else {
            try super.removeItem(at: url)
            return
        }
        throw error
    }
}

/// Removes a temporary file or directory a case created, absorbing the failure.
func removeTemporaryItem(at url: URL) {
    do {
        try FileManager.default.removeItem(at: url)
    } catch {
        // Cleanup under the system temporary directory is housekeeping, not a result any case
        // asserts, so a failed removal must not fail the test that asked for it. This is also
        // called before a create to clear a stale leftover, where "no such file" is the norm.
    }
}

/// Sleeps for `duration`, absorbing the cancellation error.
///
/// Two call shapes rely on this. A blocker task occupies a coordinator slot until the case cancels
/// it, so cancellation is the expected exit — and a `Task<Void, Never>` body has no way to rethrow
/// it anyway. A poll loop re-checks its own predicate every tick, so a cancelled sleep must return
/// to that predicate rather than unwind past it.
func sleepIgnoringCancellation(for duration: Duration) async {
    do {
        try await Task.sleep(for: duration)
    } catch {
        // Cancellation is the caller's exit condition, checked by the loop or awaited by the case
        // that cancelled the task; it is never a result to report.
    }
}

/// Decodes a stubbed request body as a JSON object, or `nil` when it is not one.
///
/// The stub handlers route on the decoded `method` field, so a body that is absent or is not JSON
/// is a legitimate answer — "this is not that request" — rather than a failure.
func requestBodyJSONObject(from request: URLRequest) -> [String: Any]? {
    guard let data = requestBodyData(from: request) else {
        return nil
    }
    do {
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    } catch {
        return nil
    }
}

func requestBodyData(from request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let readCount = stream.read(buffer, maxLength: bufferSize)
        guard readCount >= 0 else {
            return nil
        }
        guard readCount > 0 else {
            break
        }
        data.append(buffer, count: readCount)
    }

    return data
}

final class FailFastURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(
            self, didFailWithError: URLError(.cancelled)
        )
    }

    override func stopLoading() {}
}

final class HangingURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {}

    override func stopLoading() {
        client?.urlProtocol(
            self,
            didFailWithError: URLError(.cancelled)
        )
    }
}

final class SharedSessionStubURLProtocol: URLProtocol {
    static let headerKey = "X-TestSession-ID"

    private static let handlers = SharedSessionStubHandlers()

    static func setHandler(
        for sessionID: String,
        handler: @escaping @Sendable (URLRequest) throws -> (response: HTTPURLResponse, data: Data)
    ) {
        handlers.setHandler(for: sessionID, handler: handler)
    }

    static func removeHandler(for sessionID: String) {
        handlers.removeHandler(for: sessionID)
    }

    private static func handler(
        for request: URLRequest
    ) -> (@Sendable (URLRequest) throws -> (response: HTTPURLResponse, data: Data))? {
        guard let sessionID = request.value(
            forHTTPHeaderField: headerKey
        ) else {
            return nil
        }
        return handlers.handler(for: sessionID)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        handler(for: request) != nil
    }

    override static func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler(for: request) else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class SharedSessionStubHandlers: Sendable {
    private let handlers = Mutex<
        [String: @Sendable (URLRequest) throws -> (response: HTTPURLResponse, data: Data)]
    >([:])

    func setHandler(
        for sessionID: String,
        handler: @escaping @Sendable (URLRequest) throws -> (response: HTTPURLResponse, data: Data)
    ) {
        handlers.withLock({ $0[sessionID] = handler })
    }

    func removeHandler(for sessionID: String) {
        handlers.withLock({ $0[sessionID] = nil })
    }

    func handler(
        for sessionID: String
    ) -> (@Sendable (URLRequest) throws -> (response: HTTPURLResponse, data: Data))? {
        handlers.withLock({ $0[sessionID] })
    }
}
