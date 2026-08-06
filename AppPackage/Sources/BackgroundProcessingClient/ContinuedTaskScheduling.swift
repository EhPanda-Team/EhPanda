import BackgroundTasks
import Foundation

/// The slice of a system continued-processing task that ``ContinuedProcessingSession`` touches.
///
/// The store owns a genuinely interesting state machine — a re-entry guard, an identity gate, a
/// terminal transition that must run at most once — and none of it could be exercised while the
/// only way to obtain a task was to have the system launch one. This protocol is where that
/// changes: production keeps the one thin adapter below, and every lifecycle case drives the
/// store through a double instead.
///
/// `AnyObject` rather than a value type because the system task is a reference the store holds
/// across the whole session, and the adapter must forward to the same instance every time.
@MainActor
protocol ContinuedProcessingTasking: AnyObject {
    /// The card's current title, read back so a subtitle refresh can leave the title untouched.
    var title: String { get }
    /// The task's progress object. Writing to it is what moves the system card's fraction.
    var progress: Progress { get }
    /// Replaces both card strings at once, which is the only way the system offers to change one.
    func updateTitle(_ title: String, subtitle: String)
    /// Ends the task system-side and takes its card off screen.
    func setTaskCompleted(success: Bool)
    /// Installs the handler the system calls when the user cancels the card or the system
    /// reclaims the task.
    ///
    /// Deliberately a method taking a main-actor closure rather than a mirrored settable
    /// property. The system task's handler property is a plain, non-isolated function type, and
    /// it accepts a main-actor closure only because a closure *literal* formed in a main-actor
    /// context inherits that isolation. A native Swift property of the same shape would instead
    /// force an isolation-losing conversion at the assignment, and the only ways around that are
    /// exactly the escapes this repository bans. Do not "simplify" this back into a property.
    func setExpirationHandler(_ handler: @MainActor @escaping () -> Void)
}

/// What the seam hands the store when the system launches one of its registered requests.
///
/// The task is optional because a launch that could not be understood as a continued-processing
/// task still has to reach the store: the adapter completes the stray itself, but only the store
/// knows whether the failed launch belongs to the session it is currently awaiting.
typealias ContinuedTaskLaunchHandler = @MainActor (_ task: (any ContinuedProcessingTasking)?) -> Void

/// Every touch of the system task scheduler the session store needs, as injectable closures.
///
/// The store is confined to the main actor because the system objects it holds are not
/// `Sendable`; the closures carry that isolation in their types so the seam cannot be called from
/// anywhere the store could not have called the scheduler directly.
@MainActor
struct ContinuedTaskScheduling {
    /// Clears every pending request, whoever submitted it.
    var cancelAllRequests: @MainActor () -> Void
    /// Registers a launch handler for one identifier, returning whether the system accepted it.
    var register: @MainActor (_ identifier: String, _ launchHandler: @escaping ContinuedTaskLaunchHandler) -> Bool
    /// Submits a request for an already-registered identifier, throwing what the scheduler throws.
    var submit: @MainActor (_ identifier: String, _ title: String, _ subtitle: String) throws -> Void
    /// Takes one still-pending request back, by the identifier it was submitted under.
    var cancel: @MainActor (_ identifier: String) -> Void
}

extension ContinuedTaskScheduling {
    /// The only value that names the system scheduler, and the only code here a test cannot reach.
    static let live = Self(
        cancelAllRequests: {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        },
        // Registration happens POST-LAUNCH, at the first session start.
        // `ContinuedProcessingSession.start` mints ONE identifier per process as
        // "\(bundleIdentifier).continued.\(UUID().uuidString)", under the
        // `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` wildcard declared in App/Info.plist's
        // `BGTaskSchedulerPermittedIdentifiers`; a handler is registered for it at the first
        // successful registration, and that same identifier is submitted again for every later
        // session. No concrete identifier exists before a session starts, so there is nothing to
        // register at `didFinishLaunching`, and this closure has exactly one caller.
        //
        // The constraint that binds is UNIQUENESS, not repetition: a handler can never be
        // unregistered and a second registration of one identifier kills the app. That is why the
        // store keeps its identifier rather than re-deriving one per session — re-deriving met the
        // same rule while leaving one permanent handler behind per download burst (G-15-31).
        //
        // The design is device-proven rather than merely unfalsified: 15-UAT.md test 1 reads
        // `result: pass` on physical iOS 26 hardware, with pages continuing to land well past the
        // deleted 60-second grace window — an outcome reachable only if this post-launch
        // registration was honoured and the system actually launched the task. That record covers
        // registration and launch; no device run has yet exercised a reused identifier's second
        // submission, so it must not be read as evidence for that.
        register: { identifier, launchHandler in
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: .main
            ) { task in
                guard let continuedTask = task as? BGContinuedProcessingTask else {
                    // Nothing else will ever complete a task the store refuses to hold, and an
                    // uncompleted task can get the app killed, so the stray is ended right here.
                    task.setTaskCompleted(success: false)
                    launchHandler(nil)
                    return
                }
                launchHandler(SystemContinuedTask(continuedTask))
            }
        },
        submit: { identifier, title, subtitle in
            let request = BGContinuedProcessingTaskRequest(
                identifier: identifier,
                title: title,
                subtitle: subtitle
            )
            // A request the system cannot start immediately waits behind other work instead of
            // failing outright, which matters because nothing catches a lost session.
            request.strategy = .queue
            try BGTaskScheduler.shared.submit(request)
        },
        cancel: { identifier in
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        }
    )
}

/// Forwards ``ContinuedProcessingTasking`` straight to a system task, and does nothing else.
///
/// Every line here is untestable by construction, which is the point: this adapter and the live
/// scheduling value above are the whole of the untestable surface, and the store's lifecycle
/// logic now sits on the far side of them.
@MainActor
final class SystemContinuedTask: ContinuedProcessingTasking {
    private let task: BGContinuedProcessingTask

    init(_ task: BGContinuedProcessingTask) {
        self.task = task
    }

    var title: String {
        task.title
    }

    var progress: Progress {
        task.progress
    }

    func updateTitle(_ title: String, subtitle: String) {
        task.updateTitle(title, subtitle: subtitle)
    }

    func setTaskCompleted(success: Bool) {
        task.setTaskCompleted(success: success)
    }

    func setExpirationHandler(_ handler: @MainActor @escaping () -> Void) {
        // The wrapping literal is load-bearing rather than noise: formed here, in a main-actor
        // context, it inherits that isolation and so satisfies the system property's plain
        // function type without an isolation-losing conversion.
        task.expirationHandler = {
            handler()
        }
    }
}
