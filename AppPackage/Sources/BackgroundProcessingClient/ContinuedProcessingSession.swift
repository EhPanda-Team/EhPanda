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
    /// The prefix every minted request identifier is built from, resolved once at construction.
    ///
    /// Injected for the same reason `scheduling` is: without it the missing-identifier arm of
    /// `start` is unreachable by any case, and an unexecuted arm is an unverified one. `nil` means
    /// a process with no bundle identifier at all, which no shipping app is.
    private let bundleIdentifier: String?

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
    /// The one identifier this process has successfully registered a launch handler under, set on
    /// the single path where `scheduling.register` returned true and never cleared.
    ///
    /// The rule the identifier has to satisfy is UNIQUENESS, not freshness: a handler can never be
    /// unregistered and the system kills the app on a second registration of one identifier.
    /// Minting a fresh one per session satisfied the stronger rule at an unbounded price — a
    /// session ends at every queue drain, every expiration and every `.unavailable`, so one app run
    /// with a dozen download bursts left a dozen permanent handlers, each retaining a closure and a
    /// string for the life of the process (G-15-31). Reuse is legal because ``endSession`` takes the
    /// pending request back, so between sessions the scheduler holds nothing under this identifier
    /// and the same one is free to be submitted again.
    ///
    /// Recorded only after a SUCCESSFUL registration, which is what separates the two failure arms
    /// without a branch that classifies them. A refused registration stored no handler, so nothing
    /// is recorded here and the next start mints and attempts again — a transient refusal must not
    /// permanently disable background coverage, and re-attempting under the identifier that was
    /// refused is what the system kills the app for. A throwing submission registered successfully,
    /// so its retry reuses this identifier and reaches the register call not at all: that arm is
    /// where the unbounded accumulation actually lived.
    private var registeredIdentifier: String?
    /// The last counts supplied by the caller, seeded by start and refreshed by later progress
    /// pushes, so a task adopted at any point reports real numbers.
    private var lastCompletedUnitCount: Int64 = 0
    private var lastTotalUnitCount: Int64 = 0

    /// Internal rather than private only so lifecycle tests can build an isolated store over spy
    /// scheduling. Production code must keep resolving this store through ``shared``: a second
    /// live store would submit a second session, which is precisely what the design forbids.
    init(
        scheduling: ContinuedTaskScheduling = .live,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        self.scheduling = scheduling
        self.bundleIdentifier = bundleIdentifier
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

        guard let bundleIdentifier = bundleIdentifier else {
            logger.error("No bundle identifier; cannot mint a continued-processing identifier.")
            endSession(yielding: .unavailable, success: false)
            return session
        }

        // Registered at most once per process and re-submitted for every later session.
        // ``registeredIdentifier`` states the rule that makes the reuse both required and legal,
        // and why a refused registration deliberately records nothing. The suffix is a UUID rather
        // than anything — a clock included — that can repeat, because the one identifier this
        // process registers must be one no earlier build of it can also have registered.
        let identifier: String
        if let registeredIdentifier {
            identifier = registeredIdentifier
        } else {
            let mintedIdentifier = "\(bundleIdentifier).continued.\(UUID().uuidString)"
            let registered = scheduling.register(mintedIdentifier) { [weak self] task in
                guard let self else { return }
                // Handling the launch is all this handler may do. It runs on the main queue, so
                // looping or sleeping here — as some samples do — would freeze the UI; returning
                // does not complete the task.
                handleLaunch(task, expecting: mintedIdentifier)
            }
            guard registered else {
                logger.error("Identifier \(mintedIdentifier, privacy: .public) is not permitted by Info.plist.")
                endSession(yielding: .unavailable, success: false)
                return session
            }
            registeredIdentifier = mintedIdentifier
            identifier = mintedIdentifier
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
    /// A launch handler can never be unregistered, so the one identifier this process registers
    /// keeps a live handler that can fire long after the session that submitted a request under it
    /// ended.
    ///
    /// What the comparison against `pendingIdentifier` distinguishes narrowed when that identifier
    /// became process-scoped (G-15-31): it no longer separates this store's own launch from a
    /// leftover by STRING — both carry the same one — only a launch this store is currently
    /// AWAITING from one it is not. Every arrival state, and what each still does:
    ///
    /// - No session live, `pendingIdentifier` nil: a task launch is completed unsuccessfully and
    ///   turned away, a `nil` launch is ignored. Unchanged.
    /// - A session holding an adopted task, `pendingIdentifier` cleared by ``adopt(_:expecting:)``:
    ///   the same, and the held task is never displaced. Unchanged.
    /// - A session AWAITING a task: the one window where a leftover is indistinguishable from the
    ///   live launch, and nothing the SDK supplies can separate them — this closure captures one
    ///   identifier for the life of the process and the launched task carries no submission
    ///   generation. So there is no mitigation to implement, only a consequence to state. A
    ///   leftover TASK launch is adopted, which costs nothing real: it is this app's own earlier
    ///   request for the same work, `adopt` re-seeds progress from the live session's snapshot, the
    ///   caller's card title is a constant, and the only carried-over datum is a subtitle the next
    ///   progress push replaces. A leftover `nil` launch ends the awaiting session with
    ///   `.unavailable`, and that outcome — the only one that changed for the worse — is accepted:
    ///   the arm is doubly defensive, since only a launch the seam cannot read as a
    ///   continued-processing task reaches it and only requests of that kind are ever submitted
    ///   under this identifier, and `.unavailable` is silent by contract, so no page is lost or
    ///   duplicated and the next qualifying start opens a new session.
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
        //
        // Both halves now discriminate by AWAITING-ness rather than by identifier string;
        // ``handleLaunch(_:expecting:)`` enumerates every arrival state and states the one
        // consequence that changed.
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
