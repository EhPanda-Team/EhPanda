import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: ContinuedProcessingSession.self))

/// Everything a continued-processing session can report back to whoever started it.
///
/// The vocabulary is exactly three cases wide because the system offers no finer distinction:
/// a session is running, it has ended, or it never began.
public enum BackgroundProcessingEvent: Equatable, Sendable {
    /// The system started the task; its progress card is live and the work is covered.
    case granted
    /// The session ended. A user tap on the card's cancel affordance and a system resource
    /// reclaim both arrive through the task's expiration handler, and the SDK provides no way
    /// to tell them apart, so callers deliberately get one signal covering both — treating
    /// them differently would mean guessing.
    case expired
    /// The session never started: registration was refused, submission threw, or the process
    /// is running where background processing is unsupported (notably the Simulator). Silent
    /// by contract — nothing user-visible may follow, because no fallback tier exists.
    case unavailable
}

/// Owns the single continued-processing task this process may have in flight, and every touch
/// of it.
///
/// The system task and its `Progress` are system-owned and non-`Sendable`. Registering the launch
/// handler on the main queue and confining this whole store to the main actor is what makes
/// holding them safe: the system objects never cross an isolation boundary, and only `Int64`,
/// `UUID`, `String` and `Bool` cross the seam callers use. That confinement is the deliberate
/// alternative to boxing the task in an unchecked-`Sendable` handle, which would trade a real
/// guarantee for an annotation.
@MainActor
public final class ContinuedProcessingSession {
    public static let shared = ContinuedProcessingSession()

    /// Every scheduler touch this store makes. Injected so the lifecycle below is testable; the
    /// live value is the only place the system scheduler is named.
    private let scheduling: ContinuedTaskScheduling

    private var task: (any ContinuedProcessingTasking)?
    private var continuation: AsyncStream<BackgroundProcessingEvent>.Continuation?
    /// The identity callers use to complete this session.
    ///
    /// Minted in the same synchronous run that stores the continuation and cleared only in
    /// `endSession`. This names the session across the seam; `pendingIdentifier` separately names
    /// the request held by the system scheduler.
    private var sessionID: UUID?
    /// The identifier of the request this session is handing to the scheduler, non-`nil` from just
    /// *before* the submission call until either adoption or the end of the session.
    ///
    /// It is the handle the store needs to take a request back. Without it the only cancellation
    /// available is the all-requests sweep, which is far too broad to run per session. It is
    /// recorded ahead of the submission rather than after it so a launch delivered during that call
    /// can be recognized as this session's; `start` documents why, and `endSession` documents what
    /// that ordering means for the throwing arm.
    private var pendingIdentifier: String?
    /// Covers the window from just before the request is submitted until the launch handler fires,
    /// when a session may exist as far as the scheduler is concerned but no task object is held
    /// yet. It opens with `pendingIdentifier`, for the same reason.
    private var isAwaitingTask = false
    private var didCancelStaleRequests = false
    /// The last counts supplied by the caller, seeded by start and refreshed by later progress
    /// pushes, so a task adopted at any point reports real numbers.
    private var lastCompletedUnitCount: Int64 = 0
    private var lastTotalUnitCount: Int64 = 0

    /// Internal rather than private only so lifecycle tests can build an isolated store over spy
    /// scheduling. Production code must keep resolving this store through ``shared``: a second
    /// live store would submit a second session, which is precisely what the design forbids.
    init(scheduling: ContinuedTaskScheduling = .live) {
        self.scheduling = scheduling
    }

    /// Registers and submits a continued-processing session, returning its identified event
    /// stream. The stream finishes itself after `expired`, after `unavailable`, or after
    /// ``finish(sessionID:success:)``, so a consumer never has to cancel it from outside.
    ///
    /// Must be called in the foreground, in response to a user action: the scheduler validates
    /// foreground state itself and silently drops submissions it disagrees with.
    public func start(
        title: String,
        subtitle: String,
        completedUnitCount: Int64,
        totalUnitCount: Int64
    ) -> BackgroundProcessingSession? {
        // One session at a time. A second registration of an identifier kills the app, and the
        // store holds exactly one task, so re-entry is refused before any scheduler touch.
        guard task == nil, continuation == nil, !isAwaitingTask else {
            return nil
        }

        let (stream, continuation) = AsyncStream.makeStream(of: BackgroundProcessingEvent.self)
        let sessionID = UUID()
        let session = BackgroundProcessingSession(id: sessionID, events: stream)
        // Stored before anything below can yield or finish.
        self.continuation = continuation
        self.sessionID = sessionID
        // A predecessor's trailing push must not seed this card. The caller's fresh snapshot is
        // recorded instead: zeroing here traded a stale number for a false one.
        lastCompletedUnitCount = completedUnitCount
        lastTotalUnitCount = totalUnitCount

        if !didCancelStaleRequests {
            didCancelStaleRequests = true
            // Clears any request a previous build left pending with the system, whose launch
            // handler no longer exists in this binary. Cancelling *all* requests is safe rather
            // than over-broad: the app submits exactly one kind of request, and the
            // single-session guard above means this process cannot yet have a submission of its
            // own in flight on the first call.
            //
            // This does not subsume the per-request cancellation in ``endSession``, nor the other
            // way around: the sweep covers requests left behind by a *previous build*, whose
            // handlers are not in this binary at all, and by construction runs once; the
            // per-request cancel is this process's own per-session bookkeeping and has to run
            // every time a session ends without adopting its task.
            scheduling.cancelAllRequests()
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            logger.error("No bundle identifier; cannot mint a continued-processing identifier.")
            endSession(yielding: .unavailable, success: false)
            return session
        }

        // Freshly minted every session. Handlers can never be unregistered and the system kills
        // the app on a second registration of the same identifier, so the suffix must be a UUID
        // rather than anything — a clock included — that can repeat.
        let identifier = "\(bundleIdentifier).continued.\(UUID().uuidString)"

        let registered = scheduling.register(identifier) { [weak self] task in
            guard let self else { return }
            // Handling the launch is all this handler may do. It runs on the main queue, so
            // looping or sleeping here — as some samples do — would freeze the UI; returning does
            // not complete the task.
            handleLaunch(task, expecting: identifier)
        }
        guard registered else {
            logger.error("Identifier \(identifier, privacy: .public) is not permitted by Info.plist.")
            endSession(yielding: .unavailable, success: false)
            return session
        }

        // Identity BEFORE the hand-over (WR-08). The request is named and the awaiting window is
        // open before the scheduler can possibly launch it, so a launch delivered *during*
        // `submit` passes `adopt`'s identity gate and is adopted. With these two lines after the
        // call, that launch was turned away as a stray, completed unsuccessfully, and then awaited
        // forever by a store that had just declared itself awaiting a task nobody would deliver.
        // Production cannot stage that delivery — this type is `@MainActor` and the system delivers
        // launches on the main queue, so `submit` cannot reenter it — but this seam exists to be
        // driven by injected doubles, and a synchronous double is exactly what the ordering must
        // survive. Nothing may assign either property after the call returns: `adopt` clears
        // `pendingIdentifier` itself, and a trailing assignment would put a dead identifier back.
        pendingIdentifier = identifier
        isAwaitingTask = true

        do {
            try scheduling.submit(identifier, title, subtitle)
            logger.notice("Submitted continued-processing request.")
        } catch {
            // The type is the operational signal — which refusal this was — and it is a closed set
            // of symbol names. The value is not: a scheduler error may embed arbitrary system
            // strings, so it stays private (IN-04). `DownloadLogPrivacyInvariantTests` scans this
            // module under the download client's rules and fails on the raw-value shape.
            logger.error(
                """
                Continued-processing submission failed, \
                error type: \(String(describing: type(of: error)), privacy: .public), \
                error: \(error, privacy: .private).
                """
            )
            endSession(yielding: .unavailable, success: false)
            return session
        }

        return session
    }

    /// Pushes fresh counts and a refreshed subtitle to the named system card.
    ///
    /// The caller owns clamping and monotonicity: this store is domain-agnostic and knows
    /// nothing about what a unit means, so recomputing totals is the caller's policy.
    /// The saved counts are what adoption seeds from, so a foreign push must not reach either
    /// those counts or an already adopted task.
    ///
    /// Calling this steadily is a liveness requirement, not decoration. The scheduler forcibly
    /// expires tasks that appear stalled, and prioritises terminating the ones reporting the
    /// least progress.
    public func updateProgress(
        sessionID: UUID,
        completedUnitCount: Int64,
        totalUnitCount: Int64,
        subtitle: String
    ) {
        guard self.sessionID == sessionID else { return }
        lastCompletedUnitCount = completedUnitCount
        lastTotalUnitCount = totalUnitCount
        guard let task else { return }
        // Total first, so the fraction never transiently exceeds one while a growing queue is
        // being reported.
        task.progress.totalUnitCount = totalUnitCount
        task.progress.completedUnitCount = completedUnitCount
        task.updateTitle(task.title, subtitle: subtitle)
    }

    /// Completes the named session successfully or otherwise, with no event.
    ///
    /// A caller that lost ownership across its own suspension can present only its original id,
    /// so it cannot end a successor the store currently holds.
    public func finish(sessionID: UUID, success: Bool) {
        guard self.sessionID == sessionID else { return }
        endSession(yielding: nil, success: success)
    }

    /// Applies one launch of the request registered under `identifier`.
    ///
    /// A launch handler can never be unregistered, so every identifier this process has ever
    /// registered keeps a live handler that can fire long after its session ended. The expected
    /// identifier is what lets this store tell its own launch from someone else's leftovers.
    private func handleLaunch(_ task: (any ContinuedProcessingTasking)?, expecting identifier: String) {
        guard let task else {
            // The launch was not a continued-processing task and the seam has already completed
            // the stray, so only session state is left to reset — and only if the failed launch
            // is this session's. A stale handler's failure concerns no live session.
            guard pendingIdentifier == identifier else { return }
            endSession(yielding: .unavailable, success: false)
            return
        }
        adopt(task, expecting: identifier)
    }

    private func adopt(_ task: any ContinuedProcessingTasking, expecting identifier: String) {
        // Completing what is turned away is the point, not an accessory: a dropped stray is a
        // leaked system task, a second progress card, and — once the system force-expires it for
        // reporting no progress — a foreign expiration delivered into a live session, pausing
        // work the user never touched.
        guard pendingIdentifier == identifier, self.task == nil else {
            task.setTaskCompleted(success: false)
            return
        }
        pendingIdentifier = nil
        self.task = task
        // These counts come from the snapshot captured by start, or a newer accepted push.
        task.progress.totalUnitCount = lastTotalUnitCount
        task.progress.completedUnitCount = lastCompletedUnitCount
        task.setExpirationHandler { [weak self] in
            // There is no documented budget after expiration, so this does nothing but perform
            // the terminal transition — no I/O, no awaits.
            self?.endSession(yielding: .expired, success: false)
        }
        isAwaitingTask = false
        continuation?.yield(.granted)
    }

    /// Ends the session, at most once.
    ///
    /// The held task and continuation are cleared *before* anything terminal happens, so a
    /// second call — a completion racing an expiration, or a targeted `finish` arriving after
    /// the system already expired us — finds nothing to complete and nothing to yield. The
    /// system clears the expiration handler once it fires or once `setTaskCompleted(success:)`
    /// runs, so a late completion on an expired task is harmless in itself; local state still has
    /// to be reset here, because nothing else resets it.
    ///
    /// A session that never adopted a task still owns a request the scheduler is holding, and
    /// that request is taken back here. Under the chosen queue submission strategy a submission
    /// routinely outlives a short session — the queue drains and the caller finishes in seconds
    /// while the request is still waiting its turn — so without this cancel the system starts it
    /// later against a session that no longer exists. The launch would then be adopted into
    /// nothing, wedge the single-session re-entry guard, and leave background coverage silently
    /// dead for the rest of the process.
    ///
    /// The three early unavailable paths no longer answer alike, because the identifier is now
    /// recorded before the request is handed over (WR-08). The no-bundle-identifier and
    /// refused-registration arms still run before it is set and so cancel nothing, which stays
    /// correct: neither reached `submit`, so neither left a request pending. The throwing-submission
    /// arm now arrives here holding the identifier, so the take-back fires for a request the
    /// scheduler never acknowledged accepting. That is a deliberate defensive no-op rather than an
    /// oversight: cancelling an identifier the scheduler does not hold is harmless by its API
    /// contract, and a throw is exactly the case where the store cannot know how far the submission
    /// got — so taking the request back covers a half-submitted request, while the alternative
    /// ordering covers nothing and risks leaving one behind.
    private func endSession(yielding event: BackgroundProcessingEvent?, success: Bool) {
        let endingTask = task
        let endingContinuation = continuation
        // Adoption already cleared the identifier, so a session that holds a task has no request
        // left to take back. The conditional is written defense rather than live logic.
        let abandonedIdentifier = endingTask == nil ? pendingIdentifier : nil
        task = nil
        continuation = nil
        sessionID = nil
        pendingIdentifier = nil
        isAwaitingTask = false
        lastCompletedUnitCount = 0
        lastTotalUnitCount = 0

        if let abandonedIdentifier {
            scheduling.cancel(abandonedIdentifier)
        }
        endingTask?.setTaskCompleted(success: success)
        if let event {
            endingContinuation?.yield(event)
        }
        endingContinuation?.finish()
    }
}
