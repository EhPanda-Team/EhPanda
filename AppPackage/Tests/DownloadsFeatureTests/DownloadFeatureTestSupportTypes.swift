@testable import AppFeature
import BackgroundProcessingClient
import Foundation
import Synchronization

// MARK: - Supporting Types

/// A `Mutex`-backed mutable box whose `Sendable` conformance is genuinely checked by the compiler.
///
/// Named for what it is. The former name said "unchecked", advertising the unchecked-Sendable
/// escape hatch this project bans at error severity, while the type has always been the sanctioned
/// alternative to it.
final class LockedBox<Value: Sendable>: Sendable {
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
///
/// It also mirrors the live seam's *timing*: the live value is main-actor-confined, so every
/// endpoint hops off the calling actor, and every one of the three closures below therefore yields
/// at least once before it records. A double that is atomic where the seam suspends certifies
/// reentrancy races as impossible, which is how a drain suite can be green against a tail that
/// interleaves in production.
///
/// That timing rule is no longer stated here and honoured only here, which is how the sibling
/// `.unavailable` double came to ship atomic one file over (G-15-32).
/// `DownloadSourceInventoryTests` now owns it in two halves: one counts the suspension points of
/// every hand-built double at this seam, so a closure that stops yielding fails a build, and one
/// counts the doubles themselves, so a NEW hand-built double cannot appear atomic in a file no
/// table has heard of. The reasoning stays here; the enforcement is there.
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
    /// The call builds its complete argument set, signals `entered`, and parks BEFORE the identity
    /// guard and before recording anything. So while the gate is held the spy shows no trace of the
    /// parked push at all — `progressUpdates` and `rejectedProgressUpdates` gain their entry only
    /// once it is released, which is where both arming cases read it. Releasing it after a successor
    /// starts therefore exercises the same stale actor hop as the live seam without a clock,
    /// polling, or scheduler assumption.
    ///
    /// The gate deliberately promises no inspection of the parked arguments: nothing needs it. Both
    /// arming cases assert the parked push AFTER the release — `DownloadContinuedSessionIdentityTests`
    /// through `rejectedProgressUpdates`, `DownloadContinuedSessionInterleaveTests` through the
    /// parked push's ordered position among every recorded subtitle — and each of those is a
    /// stronger claim than reading the argument set mid-park, because it also pins WHICH side of the
    /// identity guard the push landed on. A field holding the in-flight update lived here unread
    /// until G-15-29 removed it.
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

    /// Delivers one event, honoring the live store's own terminal contract per case.
    ///
    /// `.granted` leaves the session live: the store yields it from its launch handler and goes on
    /// holding the task, so the stream stays open and the identity stays held.
    ///
    /// `.expired` and `.unavailable` are BOTH terminal, and the double must not treat them
    /// differently. In the live store every yield of either reaches the stream through
    /// `endSession(yielding:success:)`, which clears the held task, the continuation and the session
    /// identity and finishes the stream in the same step — which is exactly why the client seam's own
    /// doc says the stream finishes itself "after `expired`, after `unavailable`, or after `finish`".
    /// A double that yielded `.unavailable` while still holding its identity would refuse the next
    /// `start` at its single-session guard, so a suite staging a teardown-then-successor ordering
    /// could not reach the successor at all — the double, not production, deciding the outcome.
    func emit(_ event: BackgroundProcessingEvent) {
        switch event {
        case .granted:
            state.withLock({ $0.continuation })?.yield(event)
        case .expired, .unavailable:
            let continuation = takeContinuation()
            continuation?.yield(event)
            continuation?.finish()
        }
    }

    /// Delivers an expiration through the terminal path above, where the held session identity is
    /// released with the continuation and a consumer's `for await` loop falls out on its own.
    func expire() {
        emit(.expired)
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
                await Task.yield()
                let shouldRefuse = self.state.withLock {
                    $0.startCount += 1
                    $0.startTitles.append(title)
                    $0.startSubtitles.append(subtitle)
                    $0.startCompletedUnitCounts.append(completedUnitCount)
                    $0.startTotalUnitCounts.append(totalUnitCount)
                    // The single-session guard and the one-shot arm are separate refusal causes,
                    // and only the arm's own branch may consume it (G-15-10): a refusal caused by
                    // a live session must leave an armed refusal held for the start it was armed
                    // against.
                    guard $0.currentSessionID == nil else { return true }
                    guard !$0.refusesNextStart else {
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
                await Task.yield()
                // The live store accepts progress only for the identity it still owns.
                let update = ProgressUpdate(
                    sessionID: sessionID,
                    completedUnitCount: completedUnitCount,
                    totalUnitCount: totalUnitCount,
                    subtitle: subtitle
                )
                let gate = self.state.withLock {
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
                    if $0.currentSessionID == sessionID {
                        $0.progressUpdates.append(update)
                    } else {
                        $0.rejectedProgressUpdates.append(update)
                    }
                }
            },
            finish: { sessionID, success in
                await Task.yield()
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

/// Fails the metadata read for named paths while forwarding every other filesystem operation to
/// `FileManager`.
///
/// This is the faithful staging of the reachability class G-15-13 was narrowed to. The review's
/// candidates do not reach the failing branch: `attributesOfItem` is metadata-only, so descriptor
/// exhaustion never gets there, and it still answers for a data-protected file whose CONTENT is
/// unreadable. The reachable trigger is the narrower one where the attributes read ITSELF throws
/// for many-but-not-all files — an I/O error, a permission change, a volume going away mid-scan —
/// so the double throws from exactly that call and from nothing else.
///
/// Everything around it stays real, which is what makes the staging contract-faithful rather than
/// a shortcut to the outcome: the store still reaches the throw through `DownloadFileManager
/// .operate`, the directory enumeration and the existence check run against the real filesystem
/// and succeed, and the probe's content-read fallback is denied by real permissions rather than by
/// this double. No production path is bypassed.
final class PartialProbeFailureFileManager: FileManager {
    private let pathFragments: [String]
    private let error: any Error & Sendable

    init(
        pathFragments: [String],
        error: any Error & Sendable
    ) {
        self.pathFragments = pathFragments
        self.error = error
        super.init()
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        guard pathFragments.contains(where: { path.contains($0) }) else {
            return try super.attributesOfItem(atPath: path)
        }
        throw error
    }
}

/// The observable half of `PostRemovalListingFailureFileManager`, held by the case while the double
/// itself is `sending` into the store.
///
/// It exists so the injected failure can be COUNTED. An injection that is never consumed leaves
/// every assertion about the recovery passing over a path the case never entered, which is the exact
/// shape of a barrier that stops observing when the thing it guards moves — so the count is asserted
/// rather than the outcome alone.
final class PostRemovalListingFailureControl: Sendable {
    private struct State {
        var isArmed = false
        var consumedFailureCount = 0
    }

    private let state = Mutex(State())

    /// Arms the single failure. Called when the double observes the removal it keys on.
    func arm() {
        state.withLock({ $0.isArmed = true })
    }

    /// Answers whether this listing is the armed one, consuming the arming if so.
    func shouldFailListing() -> Bool {
        state.withLock { state in
            guard state.isArmed else { return false }
            state.isArmed = false
            state.consumedFailureCount += 1
            return true
        }
    }

    var consumedFailureCount: Int {
        state.withLock({ $0.consumedFailureCount })
    }
}

/// Fails the FIRST directory listing that follows a refuted page file's removal, then forwards every
/// filesystem operation to `FileManager` unchanged.
///
/// **The listing-call choreography this keys on**, because keying on an ordinal would silently
/// re-target itself the moment a call is added. Inside one `validateImageData` over a mismatched
/// page, the gallery folder is enumerated by `storage.validate`'s own page check, then by the
/// reconciliation's presence scan, then — after `removeRefutedPageFiles` has deleted the refuted
/// file — by the blanking pass's rescan, and then once more by the recovery's rescan. Only the third
/// of those follows a removal, so "the first listing after the removal" names the post-removal
/// rescan positionally-independently: exit 1 of the three post-removal exits, and the one the
/// recover-once path exists for. The arming is consumed by that listing, so the recovery's rescan
/// sees the real filesystem and the durable blank can land.
///
/// The removal itself is performed for real before arming — the page file really is gone, which is
/// what makes the recovery's fresh scan see it as the positive absence it now is.
final class PostRemovalListingFailureFileManager: FileManager {
    private let removedPathFragment: String
    private let listedPathFragment: String
    private let error: any Error & Sendable
    private let control: PostRemovalListingFailureControl

    init(
        removedPathFragment: String,
        listedPathFragment: String,
        error: any Error & Sendable,
        control: PostRemovalListingFailureControl
    ) {
        self.removedPathFragment = removedPathFragment
        self.listedPathFragment = listedPathFragment
        self.error = error
        self.control = control
        super.init()
    }

    override func removeItem(at url: URL) throws {
        try super.removeItem(at: url)
        guard url.path.contains(removedPathFragment) else { return }
        control.arm()
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        guard url.path.contains(listedPathFragment), control.shouldFailListing() else {
            return try super.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: mask
            )
        }
        throw error
    }
}

/// Replaces whatever sits at `fileURL` with a DANGLING symbolic link, so a directory listing still
/// yields the entry while the per-file probe cannot classify it.
///
/// This is the reachable staging of `PageFileScan.unprobedPages` — the per-file non-answer G-15-13
/// established — through the production probe rather than around it. `contentsOfDirectory` lists a
/// symlink whether or not its target exists, and `probeAssetFile`'s first line is a
/// `fileExists(atPath:)` that FOLLOWS the link, so the page is neither yielded by the scan nor
/// positively absent from it. Nothing else about the folder is touched, and no double stands in for
/// any production call.
///
/// A `0o000` mode cannot stage this and stages the other hold instead: `attributesOfItem` still
/// answers for an unreadable regular file, so such a page is YIELDED by the presence scan and only
/// the content read fails, which is `ContentMismatchScan.held`.
func makeAssetFileUnprobeable(at fileURL: URL) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: fileURL.path) {
        try fileManager.removeItem(at: fileURL)
    }
    try fileManager.createSymbolicLink(
        atPath: fileURL.path,
        withDestinationPath: fileURL.path + ".unresolvable"
    )
}

/// Marks a file immutable, so a `rename`-backed atomic write over it fails with `EPERM` while the
/// enclosing directory stays fully writable.
///
/// This is how a case stages a THROWING manifest write without a double anywhere: the store's
/// `writeJSON` bottoms out in `Data.write(to:options:.atomic)`, which is free Foundation and takes
/// no injected collaborator, so the only faithful staging is a real filesystem condition. Keeping
/// the directory writable is what separates this from a directory-permission change, which would
/// also block the page-file removal that has to succeed first.
func setImmutableFlag(_ isImmutable: Bool, at url: URL) throws {
    try FileManager.default.setAttributes(
        [.immutable: NSNumber(value: isImmutable)],
        ofItemAtPath: url.path
    )
}

/// Clears the immutable flag, absorbing the failure — the teardown counterpart of
/// `setImmutableFlag(_:at:)`.
///
/// Absorbing, because a teardown must not fail the case that asked for it, and because the flag may
/// already be clear when a case clears it explicitly mid-test. It must still RUN, or the leftover
/// flag would defeat the temporary tree's own removal.
func clearImmutableFlag(at url: URL) {
    do {
        try setImmutableFlag(false, at: url)
    } catch {
        // Teardown housekeeping: the file may already be clear, or already gone with its folder.
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
