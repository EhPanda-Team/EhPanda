@testable import BackgroundProcessingClient
import Foundation
import Testing

@MainActor
private func requireSubmissionTask(
    store: ContinuedProcessingSession,
    spy: ContinuedTaskSchedulingSpy,
    sessionID: UUID
) async throws -> Task<Void, Never> {
    do {
        return try #require(store.submission?.task)
    } catch {
        let submissionTask = store.submission?.task
        store.finish(sessionID: sessionID, success: false)
        spy.releaseSubmission()
        await submissionTask?.value
        throw error
    }
}

@MainActor
private func requireRegisteredIdentifier(
    store: ContinuedProcessingSession,
    spy: ContinuedTaskSchedulingSpy,
    sessionID: UUID
) async throws -> String {
    do {
        return try #require(spy.registeredIdentifiers.last)
    } catch {
        let submissionTask = store.submission?.task
        store.finish(sessionID: sessionID, success: false)
        spy.releaseSubmission()
        await submissionTask?.value
        throw error
    }
}

@MainActor
@Suite
struct ContinuedSubmissionTests {
    /// The session API must return its stream while native submission is suspended. A launch and
    /// progress update remain usable before the submission settles.
    @Test
    func testStreamReturnsAndLaunchProgressContinueWhileSubmissionIsHeld() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        spy.holdSubmissions = true
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)

        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 10 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 10
            )
        )
        await spy.waitForSubmissionEntry()
        let submissionTask = try await requireSubmissionTask(store: store, spy: spy, sessionID: session.id)
        let identifier = try await requireRegisteredIdentifier(store: store, spy: spy, sessionID: session.id)
        #expect(spy.submissions.isEmpty)

        store.updateProgress(
            sessionID: session.id,
            completedUnitCount: 3,
            totalUnitCount: 10,
            subtitle: "3 / 10 pages · 1 gallery"
        )
        #expect(spy.submissions.isEmpty)
        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)
        #expect(task.progress.completedUnitCount == 3 * ContinuedProcessingSession.subunitsPerUnit)

        spy.releaseSubmission()
        await submissionTask.value
        store.finish(sessionID: session.id, success: true)
        #expect(task.completionSuccesses == [true])
        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        #expect(events == [.granted])
    }

    /// Ending a session while submit is suspended closes its stream immediately, then cancels the
    /// request only when native completion settles and releases the re-entry gate.
    @Test
    func testFinishDuringSubmissionSuspensionCancelsAndDefersReentry() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        spy.holdSubmissions = true
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        await spy.waitForSubmissionEntry()
        let submissionTask = try await requireSubmissionTask(store: store, spy: spy, sessionID: session.id)
        let identifier = try await requireRegisteredIdentifier(store: store, spy: spy, sessionID: session.id)

        store.finish(sessionID: session.id, success: true)
        #expect(spy.cancelledIdentifiers == [identifier])
        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        #expect(events.isEmpty)
        #expect(store.start(
            title: "Downloading galleries",
            subtitle: "0 / 4 pages · 1 gallery",
            completedUnitCount: 0,
            totalUnitCount: 4
        ) == nil)

        spy.releaseSubmission()
        await submissionTask.value
        #expect(spy.cancelledIdentifiers == [identifier, identifier])

        let successor = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        let successorSubmissionTask = try await requireSubmissionTask(store: store, spy: spy, sessionID: successor.id)
        await spy.waitForSubmissionEntry()
        await successorSubmissionTask.value
        #expect(spy.submissions.map(\.identifier) == [identifier, identifier])
        store.finish(sessionID: successor.id, success: true)
    }

    /// A delayed submission failure belongs to the ended session and cannot settle a successor.
    @Test
    func testDelayedSubmissionFailureIsolatedFromIdentifierReuse() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        spy.holdSubmissions = true
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let first = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        await spy.waitForSubmissionEntry()
        let submissionTask = try await requireSubmissionTask(store: store, spy: spy, sessionID: first.id)
        let identifier = try await requireRegisteredIdentifier(store: store, spy: spy, sessionID: first.id)
        spy.nextSubmissionError = ContinuedSubmissionFailure()
        store.finish(sessionID: first.id, success: true)
        #expect(spy.cancelledIdentifiers == [identifier])

        spy.releaseSubmission()
        await submissionTask.value
        #expect(spy.cancelledIdentifiers == [identifier, identifier])

        let successor = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        let successorSubmissionTask = try await requireSubmissionTask(store: store, spy: spy, sessionID: successor.id)
        await spy.waitForSubmissionEntry()
        await successorSubmissionTask.value
        #expect(spy.registeredIdentifiers.count == 1)
        #expect(spy.submissions.map(\.identifier) == [identifier])
        store.finish(sessionID: successor.id, success: true)
    }

    /// Expiration after adoption but before native submission settlement preserves terminal stream
    /// ownership and still applies the late request cleanup once submission completes.
    @Test
    func testExpirationBeforeSubmissionSettlementCancelsLateRequest() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        spy.holdSubmissions = true
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        await spy.waitForSubmissionEntry()
        let submissionTask = try await requireSubmissionTask(store: store, spy: spy, sessionID: session.id)
        let identifier = try await requireRegisteredIdentifier(store: store, spy: spy, sessionID: session.id)
        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)
        task.expire()
        #expect(task.completionSuccesses == [false])

        spy.releaseSubmission()
        await submissionTask.value
        #expect(spy.cancelledIdentifiers == [identifier])
        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        #expect(events == [.granted, .expired])
    }

    /// A submission error that arrives after launch still settles the current session and completes
    /// the adopted task; the submission record is the identity that makes this deterministic.
    @Test
    func testDelayedSubmissionFailureAfterLaunchEndsCurrentSession() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        spy.holdSubmissions = true
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "0 / 4 pages · 1 gallery",
                completedUnitCount: 0,
                totalUnitCount: 4
            )
        )
        await spy.waitForSubmissionEntry()
        let submissionTask = try await requireSubmissionTask(store: store, spy: spy, sessionID: session.id)
        let identifier = try await requireRegisteredIdentifier(store: store, spy: spy, sessionID: session.id)
        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)
        spy.nextSubmissionError = ContinuedSubmissionFailure()

        spy.releaseSubmission()
        await submissionTask.value
        #expect(task.completionSuccesses == [false])
        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        #expect(events == [.granted, .unavailable])
    }

}
