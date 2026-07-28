@testable import BackgroundProcessingClient
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
    private(set) var registeredIdentifiers = [String]()
    private(set) var submissions = [Submission]()
    private(set) var cancelledIdentifiers = [String]()
    private var launchHandlers = [String: ContinuedTaskLaunchHandler]()

    /// The seam value to hand the store under test. Registration always succeeds here; the
    /// refusal path is the store's early-unavailable branch, which owns no pending request.
    var scheduling: ContinuedTaskScheduling {
        ContinuedTaskScheduling(
            cancelAllRequests: {
                self.cancelAllCount += 1
            },
            register: { identifier, launchHandler in
                self.registeredIdentifiers.append(identifier)
                self.launchHandlers[identifier] = launchHandler
                return true
            },
            submit: { identifier, title, subtitle in
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
                subtitle: "0 / 10 pages · 1 gallery"
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
            completedUnitCount: 7,
            totalUnitCount: 9,
            subtitle: "7 / 9 pages · 1 gallery"
        )

        let secondSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery"
            )
        )
        #expect(spy.registeredIdentifiers.count == 2)
        let awaitedIdentifier = try #require(spy.registeredIdentifiers.last)
        #expect(awaitedIdentifier != abandonedIdentifier)
        #expect(spy.submissions.map(\.identifier) == [abandonedIdentifier, awaitedIdentifier])

        let adoptedTask = ContinuedTaskSpy()
        spy.launch(awaitedIdentifier, with: adoptedTask)
        #expect(adoptedTask.completionSuccesses.isEmpty)
        #expect(adoptedTask.progress.totalUnitCount == 0)
        #expect(adoptedTask.progress.completedUnitCount == 0)

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
                subtitle: "0 / 10 pages · 1 gallery"
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
                subtitle: "0 / 6 pages · 1 gallery"
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

    /// Refactor parity for the seam: adoption still seeds the card from the counts already pushed,
    /// later pushes still refresh the subtitle without disturbing the title, and the expiration
    /// handler the store installs still performs the terminal transition.
    @Test
    func testAdoptionSeedsProgressAndExpirationStillEndsTheSession() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery"
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)
        store.updateProgress(
            completedUnitCount: 3,
            totalUnitCount: 10,
            subtitle: "3 / 10 pages · 1 gallery"
        )

        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)
        #expect(task.progress.totalUnitCount == 10)
        #expect(task.progress.completedUnitCount == 3)

        store.updateProgress(
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
                subtitle: "0 / 10 pages · 1 gallery"
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)
        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)

        store.finish(sessionID: UUID(), success: false)
        #expect(task.completionSuccesses.isEmpty)

        store.updateProgress(
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
                subtitle: "0 / 10 pages · 1 gallery"
            )
        )
        let firstIdentifier = try #require(spy.registeredIdentifiers.first)
        #expect(spy.registeredIdentifiers.count == 1)
        #expect(spy.submissions.count == 1)

        let refusedSession = store.start(
            title: "Downloading galleries",
            subtitle: "0 / 20 pages · 2 galleries"
        )
        #expect(refusedSession == nil)
        #expect(spy.registeredIdentifiers.count == 1)
        #expect(spy.submissions.count == 1)

        store.finish(sessionID: firstSession.id, success: true)

        let laterSession = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 20 pages · 2 galleries"
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
}
