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
/// `String` and `Bool` cross the seam callers use. That confinement is the deliberate alternative
/// to boxing the task in an unchecked-`Sendable` handle, which would trade a real guarantee for
/// an annotation.
@MainActor
public final class ContinuedProcessingSession {
    public static let shared = ContinuedProcessingSession()

    /// Every scheduler touch this store makes. Injected so the lifecycle below is testable; the
    /// live value is the only place the system scheduler is named.
    private let scheduling: ContinuedTaskScheduling

    private var task: (any ContinuedProcessingTasking)?
    private var continuation: AsyncStream<BackgroundProcessingEvent>.Continuation?
    /// Covers the window between a successful submission and the launch handler firing, when
    /// a session exists as far as the scheduler is concerned but no task object is held yet.
    private var isAwaitingTask = false
    private var didCancelStaleRequests = false
    /// The last counts pushed by the caller, kept so a task adopted after the first progress
    /// push is seeded with real numbers instead of starting the card back at zero.
    private var lastCompletedUnitCount: Int64 = 0
    private var lastTotalUnitCount: Int64 = 0

    /// Internal rather than private only so lifecycle tests can build an isolated store over spy
    /// scheduling. Production code must keep resolving this store through ``shared``: a second
    /// live store would submit a second session, which is precisely what the design forbids.
    init(scheduling: ContinuedTaskScheduling = .live) {
        self.scheduling = scheduling
    }

    /// Registers and submits a continued-processing session, returning the stream that reports
    /// its fate. The stream finishes itself after `expired`, after `unavailable`, or after
    /// ``finish(success:)``, so a consumer never has to cancel it from outside.
    ///
    /// Must be called in the foreground, in response to a user action: the scheduler validates
    /// foreground state itself and silently drops submissions it disagrees with.
    public func start(title: String, subtitle: String) -> AsyncStream<BackgroundProcessingEvent> {
        // One session at a time. A second registration of an identifier kills the app, and the
        // store holds exactly one task, so re-entry hands back an already-finished stream
        // rather than racing the live session.
        guard task == nil, continuation == nil, !isAwaitingTask else {
            return AsyncStream { $0.finish() }
        }

        let (stream, continuation) = AsyncStream.makeStream(of: BackgroundProcessingEvent.self)
        // Stored before anything below can yield or finish.
        self.continuation = continuation

        if !didCancelStaleRequests {
            didCancelStaleRequests = true
            // Clears any request a previous build left pending with the system, whose launch
            // handler no longer exists in this binary. Cancelling *all* requests is safe rather
            // than over-broad: the app submits exactly one kind of request, and the
            // single-session guard above means this process cannot yet have a submission of its
            // own in flight on the first call.
            scheduling.cancelAllRequests()
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            logger.error("No bundle identifier; cannot mint a continued-processing identifier.")
            endSession(yielding: .unavailable, success: false)
            return stream
        }

        // Freshly minted every session. Handlers can never be unregistered and the system kills
        // the app on a second registration of the same identifier, so the suffix must be a UUID
        // rather than anything — a clock included — that can repeat.
        let identifier = "\(bundleIdentifier).continued.\(UUID().uuidString)"

        let registered = scheduling.register(identifier) { [weak self] task in
            guard let self else { return }
            guard let task else {
                // The seam already completed the stray; only the session state is left to reset.
                endSession(yielding: .unavailable, success: false)
                return
            }
            // Adoption is all this handler may do. It runs on the main queue, so looping or
            // sleeping here — as some samples do — would freeze the UI; returning does not
            // complete the task.
            adopt(task)
        }
        guard registered else {
            logger.error("Identifier \(identifier, privacy: .public) is not permitted by Info.plist.")
            endSession(yielding: .unavailable, success: false)
            return stream
        }

        do {
            try scheduling.submit(identifier, title, subtitle)
            logger.notice("Submitted continued-processing request.")
        } catch {
            logger.error("\(error, privacy: .public)")
            endSession(yielding: .unavailable, success: false)
            return stream
        }

        isAwaitingTask = true
        return stream
    }

    /// Pushes fresh counts and a refreshed subtitle to the system card.
    ///
    /// The caller owns clamping and monotonicity: this store is domain-agnostic and knows
    /// nothing about what a unit means, so recomputing totals is the caller's policy.
    ///
    /// Calling this steadily is a liveness requirement, not decoration. The scheduler forcibly
    /// expires tasks that appear stalled, and prioritises terminating the ones reporting the
    /// least progress.
    public func updateProgress(completedUnitCount: Int64, totalUnitCount: Int64, subtitle: String) {
        lastCompletedUnitCount = completedUnitCount
        lastTotalUnitCount = totalUnitCount
        guard let task else { return }
        // Total first, so the fraction never transiently exceeds one while a growing queue is
        // being reported.
        task.progress.totalUnitCount = totalUnitCount
        task.progress.completedUnitCount = completedUnitCount
        task.updateTitle(task.title, subtitle: subtitle)
    }

    /// Completes the session successfully or otherwise, with no event: the caller already knows
    /// it ended the session, and the stream finishing is the signal.
    public func finish(success: Bool) {
        endSession(yielding: nil, success: success)
    }

    private func adopt(_ task: any ContinuedProcessingTasking) {
        self.task = task
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
    /// second call — a completion racing an expiration, or a `finish` arriving after the system
    /// already expired us — finds nothing to complete and nothing to yield. The system clears
    /// the expiration handler once it fires or once `setTaskCompleted(success:)` runs, so a late
    /// completion on an expired task is harmless in itself; local state still has to be reset
    /// here, because nothing else resets it.
    private func endSession(yielding event: BackgroundProcessingEvent?, success: Bool) {
        let endingTask = task
        let endingContinuation = continuation
        task = nil
        continuation = nil
        isAwaitingTask = false
        lastCompletedUnitCount = 0
        lastTotalUnitCount = 0

        endingTask?.setTaskCompleted(success: success)
        if let event {
            endingContinuation?.yield(event)
        }
        endingContinuation?.finish()
    }
}
