@testable import BackgroundProcessingClient
import CustomDump
import Foundation
import Testing

// MARK: - Supporting Types

/// Stands in for a system continued-processing task, recording everything the store pushes at it
/// and letting a case fire the expiration handler the store installed.
///
/// Main-actor confined rather than `Mutex`-backed, because the store it serves is itself confined
/// to the main actor: nothing here is ever touched from another isolation domain, so a lock would
/// buy no safety and only obscure the ordering each case depends on.
@MainActor
final class ContinuedTaskSpy: ContinuedProcessingTasking {
    /// One `updateTitle` call. A named record rather than a tuple: an unlabeled tuple type is
    /// banned at error severity here, and `.0`/`.1` reads carry no meaning at an assertion site.
    struct TitleUpdate: Equatable {
        let title: String
        let subtitle: String
    }

    let title: String
    let progress = Progress()
    private(set) var titleUpdates = [TitleUpdate]()
    private(set) var completionSuccesses = [Bool]()
    private(set) var expirationHandler: (@MainActor () -> Void)?

    init(title: String = "Downloading galleries") {
        self.title = title
    }

    func updateTitle(_ title: String, subtitle: String) {
        titleUpdates.append(TitleUpdate(title: title, subtitle: subtitle))
    }

    func setTaskCompleted(success: Bool) {
        completionSuccesses.append(success)
    }

    func setExpirationHandler(_ handler: @MainActor @escaping () -> Void) {
        expirationHandler = handler
    }

    /// Fires the installed handler, standing in for a card cancellation or a system reclaim —
    /// the two the SDK deliberately makes indistinguishable.
    func expire() {
        expirationHandler?()
    }
}

/// Stands in for the scheduling seam, recording every request the store makes of it and holding
/// each registered launch handler so a case can deliver a launch on its own schedule.
///
/// Handlers are kept keyed by identifier precisely because the real scheduler can never
/// unregister one: firing an old key is how these cases reproduce a launch arriving long after
/// the session that asked for it ended.
@MainActor
final class ContinuedTaskSchedulingSpy {
    /// One `submit` call, as a named record for the same reason as ``ContinuedTaskSpy/TitleUpdate``.
    struct Submission: Equatable {
        let identifier: String
        let title: String
        let subtitle: String
    }

    private(set) var cancelAllCount = 0
    /// Every identifier a registration was ATTEMPTED under, refused ones included: a refusal has to
    /// stay visible as an attempt that stored no handler, not as a call that never happened.
    private(set) var registeredIdentifiers = [String]()
    private(set) var submissions = [Submission]()
    private(set) var cancelledIdentifiers = [String]()
    private var launchHandlers = [String: ContinuedTaskLaunchHandler]()

    /// Refuses exactly one registration, the way `BGTaskScheduler` refuses an identifier its
    /// `Info.plist` does not permit.
    var refusesNextRegistration = false
    /// Thrown by exactly one submission, standing in for whichever refusal the real scheduler
    /// raises — the store treats the type as opaque and only its throwing matters here.
    var nextSubmissionError: (any Error)?

    /// The seam value to hand the store under test.
    ///
    /// Both outcomes the real scheduler can produce are controllable, because the store's three
    /// `.unavailable` producers are otherwise unreachable and the coordinator's liveness flag is
    /// released by nothing else than the event they yield. Each control is ONE-SHOT and is consumed
    /// only by the call it actually changes — the discipline G-15-10 established for the client
    /// spy's start arm, where an arm consumed by a call it did not cause left every later assertion
    /// running against control state the case believed it still held.
    var scheduling: ContinuedTaskScheduling {
        ContinuedTaskScheduling(
            cancelAllRequests: {
                self.cancelAllCount += 1
            },
            register: { identifier, launchHandler in
                self.registeredIdentifiers.append(identifier)
                guard !self.refusesNextRegistration else {
                    // Consumed on the refusing branch alone, and no handler is kept: the real
                    // scheduler registers nothing it refused, so a later launch under this
                    // identifier is impossible rather than merely unused.
                    self.refusesNextRegistration = false
                    return false
                }
                self.launchHandlers[identifier] = launchHandler
                return true
            },
            submit: { identifier, title, subtitle in
                if let error = self.nextSubmissionError {
                    // Cleared by the submission that throws it, and recorded as no submission at
                    // all: a request whose `submit` threw never reached the scheduler's queue, so
                    // listing it beside accepted ones would model an acceptance that did not happen.
                    self.nextSubmissionError = nil
                    throw error
                }
                self.submissions.append(
                    Submission(identifier: identifier, title: title, subtitle: subtitle)
                )
            },
            cancel: { identifier in
                self.cancelledIdentifiers.append(identifier)
            }
        )
    }

    /// Delivers a launch for `identifier`, exactly as the system would.
    ///
    /// A `nil` task stands for a launch the live seam could not read as a continued-processing
    /// task, which it completes itself before handing the store the `nil`.
    func launch(_ identifier: String, with task: (any ContinuedProcessingTasking)?) {
        launchHandlers[identifier]?(task)
    }
}

/// What an armed submission throws. Deliberately featureless: the store branches on the throw
/// itself and never on what was thrown, so a richer stand-in would model a distinction the
/// production code does not make.
struct ContinuedSubmissionFailure: Error {}

// MARK: - Tests

/// Pins the session store's lifecycle: which request is cancelled when, and which launched task
/// may be adopted.
///
/// Every case builds its own store over its own spy through the seam-injecting initializer, so
/// none touches the process-wide shared store and the suite stays parallel-safe.
///
/// Determinism throughout: the store is driven to completion first and its stream drained only
/// afterwards. `AsyncStream` buffers what was yielded, so a finished stream replays its whole
/// history into a plain `for await` loop — no polling helper and no sleep appears anywhere below.
@MainActor
@Suite
struct ContinuedProcessingSessionTests {
    /// CR-02 regression: a launch that arrives immediately after submission must adopt the
    /// non-zero snapshot start recorded, without waiting for a later progress push.
    @Test
    func testAdoptionSeedsProgressFromTheStartSnapshot() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "6 / 20 pages · 1 gallery",
                completedUnitCount: 6,
                totalUnitCount: 20
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)

        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)

        #expect(task.progress.completedUnitCount == 6)
        #expect(task.progress.totalUnitCount == 20)
        expectNoDifference(task.titleUpdates, [])

        store.finish(sessionID: session.id, success: true)
        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        expectNoDifference(events, [.granted])
    }

    /// CR-01 regression: a progress push carrying any id but the held session's must alter
    /// neither the adopted task nor the saved counts from which that task is driven.
    @Test
    func testAForeignProgressPushCannotRepaintTheHeldSession() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "1 / 10 pages · 1 gallery",
                completedUnitCount: 1,
                totalUnitCount: 10
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)
        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)

        store.updateProgress(
            sessionID: session.id,
            completedUnitCount: 4,
            totalUnitCount: 10,
            subtitle: "4 / 10 pages · 1 gallery"
        )
        expectNoDifference(
            task.titleUpdates,
            [.init(title: "Downloading galleries", subtitle: "4 / 10 pages · 1 gallery")]
        )

        store.updateProgress(
            sessionID: UUID(),
            completedUnitCount: 99,
            totalUnitCount: 100,
            subtitle: "99 / 100 pages · 9 galleries"
        )
        #expect(task.progress.completedUnitCount == 4)
        #expect(task.progress.totalUnitCount == 10)
        expectNoDifference(
            task.titleUpdates,
            [.init(title: "Downloading galleries", subtitle: "4 / 10 pages · 1 gallery")]
        )

        store.finish(sessionID: session.id, success: true)
        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        expectNoDifference(events, [.granted])
    }

    /// The regression the verification report names: a request abandoned by a short session must
    /// be taken back, must be refused if the system launches it anyway, and must not leave the
    /// store's single-session guard wedged against every later start.
    ///
    /// It also carries the seed-counter assertion: a progress push that lands while no session is
    /// live must not paint the next session's card.
    @Test
    func testEndedSessionCancelsItsPendingRequestAndALaterStartIsGranted() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let firstSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )
        #expect(spy.registeredIdentifiers.count == 1)
        let abandonedIdentifier = try #require(spy.registeredIdentifiers.first)
        #expect(spy.submissions.map(\.identifier) == [abandonedIdentifier])

        // The queue drained before the system ever got around to launching the request.
        store.finish(sessionID: firstSession.id, success: true)
        #expect(spy.cancelledIdentifiers == [abandonedIdentifier])

        // Cancellation is best-effort, so the system may still launch the request it was handed.
        let strayTask = ContinuedTaskSpy()
        spy.launch(abandonedIdentifier, with: strayTask)
        #expect(strayTask.completionSuccesses == [false])

        var firstEvents = [BackgroundProcessingEvent]()
        for await event in firstSession.events {
            firstEvents.append(event)
        }
        #expect(firstEvents.isEmpty)

        // A push arriving while no session is live: the caller owns clamping and monotonicity, so
        // the store cannot assume this never happens.
        store.updateProgress(
            sessionID: UUID(),
            completedUnitCount: 7,
            totalUnitCount: 9,
            subtitle: "7 / 9 pages · 1 gallery"
        )

        let secondSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "2 / 4 pages · 1 gallery",
                completedUnitCount: 2,
                totalUnitCount: 4
            )
        )
        #expect(spy.registeredIdentifiers.count == 2)
        let awaitedIdentifier = try #require(spy.registeredIdentifiers.last)
        #expect(awaitedIdentifier != abandonedIdentifier)
        #expect(spy.submissions.map(\.identifier) == [abandonedIdentifier, awaitedIdentifier])

        let adoptedTask = ContinuedTaskSpy()
        spy.launch(awaitedIdentifier, with: adoptedTask)
        #expect(adoptedTask.completionSuccesses.isEmpty)
        #expect(adoptedTask.progress.totalUnitCount == 4)
        #expect(adoptedTask.progress.completedUnitCount == 2)

        store.finish(sessionID: secondSession.id, success: true)
        #expect(adoptedTask.completionSuccesses == [true])
        // An adopted session owns no pending request, so ending it cancels nothing further.
        #expect(spy.cancelledIdentifiers == [abandonedIdentifier])
        // The stale-build sweep is once per process and unaffected by per-request cancellation.
        #expect(spy.cancelAllCount == 1)

        var secondEvents = [BackgroundProcessingEvent]()
        for await event in secondSession.events {
            secondEvents.append(event)
        }
        #expect(secondEvents == [.granted])
    }

    /// A launch handler outlives its session, so a stale one can fire while a different session is
    /// live. That launch must be completed and turned away rather than displacing the task the
    /// store is actually waiting for.
    ///
    /// The single `granted` drained at the end is what proves the stale launch never reached the
    /// live stream: an accepted stray would have yielded a second one.
    @Test
    func testAStaleLaunchIsCompletedAndNeverDisplacesTheAwaitedTask() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let firstSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )
        store.finish(sessionID: firstSession.id, success: true)
        let staleIdentifier = try #require(spy.registeredIdentifiers.first)

        var firstEvents = [BackgroundProcessingEvent]()
        for await event in firstSession.events {
            firstEvents.append(event)
        }
        #expect(firstEvents.isEmpty)

        let secondSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 6 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 6
            )
        )
        let liveIdentifier = try #require(spy.registeredIdentifiers.last)
        #expect(liveIdentifier != staleIdentifier)

        let staleTask = ContinuedTaskSpy()
        spy.launch(staleIdentifier, with: staleTask)
        #expect(staleTask.completionSuccesses == [false])

        let liveTask = ContinuedTaskSpy()
        spy.launch(liveIdentifier, with: liveTask)
        #expect(liveTask.completionSuccesses.isEmpty)

        store.finish(sessionID: secondSession.id, success: true)
        #expect(liveTask.completionSuccesses == [true])
        // Only the request nobody adopted was cancelled; the live one was launched, not withdrawn.
        #expect(spy.cancelledIdentifiers == [staleIdentifier])

        var secondEvents = [BackgroundProcessingEvent]()
        for await event in secondSession.events {
            secondEvents.append(event)
        }
        #expect(secondEvents == [.granted])
    }

    /// Refactor parity for the seam: adoption seeds the card from the start snapshot, later pushes
    /// still refresh the subtitle without disturbing the title, and the expiration handler the
    /// store installs still performs the terminal transition.
    @Test
    func testAdoptionSeedsProgressAndExpirationStillEndsTheSession() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "3 / 10 pages · 1 gallery",
                completedUnitCount: 3,
                totalUnitCount: 10
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)

        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)
        #expect(task.progress.totalUnitCount == 10)
        #expect(task.progress.completedUnitCount == 3)

        store.updateProgress(
            sessionID: session.id,
            completedUnitCount: 6,
            totalUnitCount: 10,
            subtitle: "6 / 10 pages · 1 gallery"
        )
        #expect(task.progress.completedUnitCount == 6)
        #expect(
            task.titleUpdates == [
                .init(title: "Downloading galleries", subtitle: "6 / 10 pages · 1 gallery")
            ]
        )

        task.expire()
        #expect(task.completionSuccesses == [false])

        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        #expect(events == [.granted, .expired])
    }

    /// CR-04 regression: a caller that lost ownership while suspended must not be able to finish
    /// the successor session now held by the store.
    @Test
    func testFinishWithAForeignSessionIDIsANoOp() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)
        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)

        store.finish(sessionID: UUID(), success: false)
        #expect(task.completionSuccesses.isEmpty)

        store.updateProgress(
            sessionID: session.id,
            completedUnitCount: 4,
            totalUnitCount: 10,
            subtitle: "4 / 10 pages · 1 gallery"
        )
        #expect(task.progress.totalUnitCount == 10)
        #expect(task.progress.completedUnitCount == 4)
        #expect(
            task.titleUpdates == [
                .init(title: "Downloading galleries", subtitle: "4 / 10 pages · 1 gallery")
            ]
        )

        store.finish(sessionID: session.id, success: true)
        #expect(task.completionSuccesses == [true])

        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        #expect(events == [.granted])
    }

    /// Refusal-observability regression: re-entry must return `nil` without touching the
    /// scheduler, and completing the held session must make the next start genuinely usable.
    @Test
    func testStartWhileASessionIsHeldIsRefusedAndALaterStartSucceeds() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let firstSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )
        let firstIdentifier = try #require(spy.registeredIdentifiers.first)
        #expect(spy.registeredIdentifiers.count == 1)
        #expect(spy.submissions.count == 1)

        let refusedSession = store.start(
            title: "Downloading galleries",
            subtitle: "0 / 20 pages · 2 galleries",
            completedUnitCount: 0,
            totalUnitCount: 20
        )
        #expect(refusedSession == nil)
        #expect(spy.registeredIdentifiers.count == 1)
        #expect(spy.submissions.count == 1)

        store.finish(sessionID: firstSession.id, success: true)

        let laterSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 20 pages · 2 galleries",
                completedUnitCount: 0,
                totalUnitCount: 20
            )
        )
        let laterIdentifier = try #require(spy.registeredIdentifiers.last)
        #expect(spy.registeredIdentifiers.count == 2)
        #expect(laterIdentifier != firstIdentifier)
        #expect(spy.submissions.map(\.identifier) == [firstIdentifier, laterIdentifier])

        store.finish(sessionID: laterSession.id, success: true)

        var firstEvents = [BackgroundProcessingEvent]()
        for await event in firstSession.events {
            firstEvents.append(event)
        }
        #expect(firstEvents.isEmpty)

        var laterEvents = [BackgroundProcessingEvent]()
        for await event in laterSession.events {
            laterEvents.append(event)
        }
        #expect(laterEvents.isEmpty)
    }

    /// G-15-17, first `.unavailable` producer: a process whose bundle carries no identifier.
    ///
    /// The arm executes before any scheduler touch, so its signature among the three is the empty
    /// registration list — no other producer leaves that. What the case pins is not the log line but
    /// the release contract: the coordinator treats every non-`nil` handle as a started session and
    /// learns otherwise only from the stream, so the yielded `.unavailable` plus the stream's own
    /// finish is the SOLE mechanism that releases `hasLiveContinuedSession`, with no fallback tier
    /// behind it (SC3's refusal half).
    @Test
    func testAMissingBundleIdentifierYieldsUnavailableAndReleasesTheStore() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling, bundleIdentifier: nil)

        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )

        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        // The whole array, not a membership check: a second event or a stream left open would both
        // be release failures, and the loop exiting at all is what proves the self-finish ran.
        expectNoDifference(events, [.unavailable])
        // Nothing was named, so nothing was handed over and nothing can be taken back.
        expectNoDifference(spy.registeredIdentifiers, [])
        expectNoDifference(spy.submissions, [])
        expectNoDifference(spy.cancelledIdentifiers, [])
        // The stale-build sweep still ran: it precedes the identifier check.
        #expect(spy.cancelAllCount == 1)

        // The re-entry guard is not wedged. This store still has no bundle identifier, so the next
        // start takes the same arm — a non-`nil` handle proves it was granted rather than refused.
        let laterSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        var laterEvents = [BackgroundProcessingEvent]()
        for await event in laterSession.events {
            laterEvents.append(event)
        }
        expectNoDifference(laterEvents, [.unavailable])
    }

    /// G-15-17, second `.unavailable` producer: the scheduler refuses to register the identifier,
    /// which is what an `Info.plist` that does not permit it produces.
    ///
    /// Its signature is one attempted registration and no submission — the arm reaches the
    /// scheduler and stops there. The follow-up start is the release proof and also pins that the
    /// store mints FRESH identity rather than retrying the refused one: re-registering an
    /// identifier is what the system kills the app for.
    @Test
    func testARefusedRegistrationYieldsUnavailableAndReleasesTheStore() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        spy.refusesNextRegistration = true
        let refusedSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )

        var refusedEvents = [BackgroundProcessingEvent]()
        for await event in refusedSession.events {
            refusedEvents.append(event)
        }
        expectNoDifference(refusedEvents, [.unavailable])
        #expect(spy.registeredIdentifiers.count == 1)
        let refusedIdentifier = try #require(spy.registeredIdentifiers.first)
        // The arm stopped at the registration: nothing was submitted, so there is nothing pending
        // for `endSession` to take back.
        expectNoDifference(spy.submissions, [])
        expectNoDifference(spy.cancelledIdentifiers, [])

        let grantedSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        #expect(spy.registeredIdentifiers.count == 2)
        let freshIdentifier = try #require(spy.registeredIdentifiers.last)
        #expect(freshIdentifier != refusedIdentifier)
        expectNoDifference(spy.submissions.map(\.identifier), [freshIdentifier])

        store.finish(sessionID: grantedSession.id, success: true)
        // The granted session never adopted a task, so ending it takes its own request back — and
        // only its own.
        expectNoDifference(spy.cancelledIdentifiers, [freshIdentifier])
        var grantedEvents = [BackgroundProcessingEvent]()
        for await event in grantedSession.events {
            grantedEvents.append(event)
        }
        #expect(grantedEvents.isEmpty)
    }

    /// G-15-17, third `.unavailable` producer: the submission itself throws.
    ///
    /// Its signature is an attempted registration with no recorded submission — the spy records a
    /// submission only when it did not throw, because a request whose `submit` threw never reached
    /// the scheduler's queue.
    ///
    /// **The cancelled list is the POST-WR-08 contract, deliberately.** G-15-17's suggested fix
    /// expects every producer to cancel nothing; that expectation was written against the ordering
    /// 15-37 replaced. `start` now records `pendingIdentifier` BEFORE handing the request over, so
    /// this arm — and only this one of the three — arrives at `endSession` holding an identifier and
    /// the take-back fires. `endSession`'s own paragraph states why that is deliberate rather than
    /// an oversight: "a throw is exactly the case where the store cannot know how far the submission
    /// got — so taking the request back covers a half-submitted request, while the alternative
    /// ordering covers nothing and risks leaving one behind."
    @Test
    func testAThrowingSubmissionYieldsUnavailableTakesItsRequestBackAndReleasesTheStore() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        spy.nextSubmissionError = ContinuedSubmissionFailure()
        let failedSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )

        var failedEvents = [BackgroundProcessingEvent]()
        for await event in failedSession.events {
            failedEvents.append(event)
        }
        expectNoDifference(failedEvents, [.unavailable])
        #expect(spy.registeredIdentifiers.count == 1)
        let failedIdentifier = try #require(spy.registeredIdentifiers.first)
        expectNoDifference(spy.submissions, [])
        expectNoDifference(spy.cancelledIdentifiers, [failedIdentifier])

        let grantedSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        // One-shot: the armed error was consumed by the submission that threw it, so this one
        // reaches the scheduler normally.
        let freshIdentifier = try #require(spy.registeredIdentifiers.last)
        #expect(freshIdentifier != failedIdentifier)
        expectNoDifference(spy.submissions.map(\.identifier), [freshIdentifier])

        store.finish(sessionID: grantedSession.id, success: true)
        expectNoDifference(spy.cancelledIdentifiers, [failedIdentifier, freshIdentifier])
        var grantedEvents = [BackgroundProcessingEvent]()
        for await event in grantedSession.events {
            grantedEvents.append(event)
        }
        #expect(grantedEvents.isEmpty)
    }

    /// `handleLaunch`'s nil-task path, first arm: the launch the store is actually waiting for is
    /// not a continued-processing task.
    ///
    /// The live seam has already completed that stray itself before handing the store a `nil`, so
    /// only session state is left to reset — and the session must end honestly rather than wait for
    /// a task that will never arrive. This arm is reached only AFTER a successful submission, which
    /// is what distinguishes it from the three producers above: the request was accepted, and the
    /// launch is what failed.
    @Test
    func testANilLaunchForTheAwaitedRequestYieldsUnavailable() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)
        expectNoDifference(spy.submissions.map(\.identifier), [identifier])
        expectNoDifference(spy.cancelledIdentifiers, [])

        spy.launch(identifier, with: nil)

        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        expectNoDifference(events, [.unavailable])
        // Never adopted, so the request is still the store's to take back.
        expectNoDifference(spy.cancelledIdentifiers, [identifier])

        let laterSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        let laterIdentifier = try #require(spy.registeredIdentifiers.last)
        #expect(laterIdentifier != identifier)
        let laterTask = ContinuedTaskSpy()
        spy.launch(laterIdentifier, with: laterTask)
        store.finish(sessionID: laterSession.id, success: true)
        #expect(laterTask.completionSuccesses == [true])

        var laterEvents = [BackgroundProcessingEvent]()
        for await event in laterSession.events {
            laterEvents.append(event)
        }
        expectNoDifference(laterEvents, [.granted])
    }

    /// `handleLaunch`'s nil-task path, second arm: the identity gate, which no case has driven.
    ///
    /// A launch handler can never be unregistered, so an identifier this process retired keeps a
    /// live handler that can fire at any later moment — the spy's keyed handlers mirror exactly
    /// that, keeping A's handler after A ends. A failed launch under a retired identifier concerns
    /// no live session, and ending B on it would tear down a session whose card the system is still
    /// showing.
    ///
    /// The two assertions after the stale delivery are what discriminate the gate from its absence:
    /// without it B is ended, so B's minted launch would be turned away and completed
    /// unsuccessfully, and B's stream would drain `[.unavailable]` instead of `[.granted]`.
    @Test
    func testAStaleNilLaunchCannotEndALiveSession() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let staleSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )
        let staleIdentifier = try #require(spy.registeredIdentifiers.first)
        store.finish(sessionID: staleSession.id, success: true)

        var staleEvents = [BackgroundProcessingEvent]()
        for await event in staleSession.events {
            staleEvents.append(event)
        }
        #expect(staleEvents.isEmpty)

        let liveSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 6 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 6
            )
        )
        let liveIdentifier = try #require(spy.registeredIdentifiers.last)
        #expect(liveIdentifier != staleIdentifier)

        spy.launch(staleIdentifier, with: nil)

        // The live session is still the one the store awaits: its own launch is adopted rather than
        // turned away, which an ended session could not do.
        let liveTask = ContinuedTaskSpy()
        spy.launch(liveIdentifier, with: liveTask)
        #expect(liveTask.completionSuccesses.isEmpty)
        #expect(liveTask.progress.totalUnitCount == 6)

        store.finish(sessionID: liveSession.id, success: true)
        #expect(liveTask.completionSuccesses == [true])
        // Only the retired request was ever taken back; the stale nil launch added no cancellation
        // of its own, because it belonged to a session that had already ended.
        expectNoDifference(spy.cancelledIdentifiers, [staleIdentifier])

        var liveEvents = [BackgroundProcessingEvent]()
        for await event in liveSession.events {
            liveEvents.append(event)
        }
        expectNoDifference(liveEvents, [.granted])
    }
}
