@testable import BackgroundProcessingClient
import CustomDump
import Foundation
import Testing

/// The sub-unit fold the store applies beneath the caller's whole-unit pair (G-15-2D).
///
/// Split out of `ContinuedProcessingSessionTests` rather than added to it: that suite sits against
/// the 1000-line `file_length` gate, and these cases are about one property of `updateProgress`
/// rather than about the session lifecycle the other suite pins. Both build their own store over
/// their own scheduling spy, so neither touches the process-wide shared store.
@MainActor
@Suite
struct ContinuedProcessingSessionFoldTests {
    /// G-15-2D: sub-unit credit for units still in flight is folded BENEATH the whole-unit pair,
    /// so a long unit's transfer moves the reported numerator before that unit lands.
    @Test
    func updateProgressFoldsInFlightSubunitsBeneathTheWholeUnitPair() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "4 / 10 pages · 1 gallery",
                completedUnitCount: 4,
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
            inFlightSubunitCount: 500,
            subtitle: "4 / 10 pages · 1 gallery"
        )

        #expect(task.progress.completedUnitCount == 4500)
        #expect(task.progress.totalUnitCount == 10 * ContinuedProcessingSession.subunitsPerUnit)
        // The subtitle keeps reading whole pages: the fold is a numeric resolution the card's bar
        // shows, never a unit the text speaks in.
        expectNoDifference(
            task.titleUpdates,
            [.init(title: "Downloading galleries", subtitle: "4 / 10 pages · 1 gallery")]
        )

        store.finish(sessionID: session.id, success: true)
    }

    /// The store owns the fold's clamp, exactly as it owns the pair's own bound: a caller reporting
    /// in-flight credit on a finished queue must not push the bar past full.
    @Test
    func theFoldNeverExceedsTheTotal() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "10 / 10 pages · 1 gallery",
                completedUnitCount: 10,
                totalUnitCount: 10
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)
        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)

        store.updateProgress(
            sessionID: session.id,
            completedUnitCount: 10,
            totalUnitCount: 10,
            inFlightSubunitCount: 999,
            subtitle: "10 / 10 pages · 1 gallery"
        )

        #expect(task.progress.completedUnitCount == 10 * ContinuedProcessingSession.subunitsPerUnit)
        #expect(task.progress.totalUnitCount == 10 * ContinuedProcessingSession.subunitsPerUnit)

        store.finish(sessionID: session.id, success: true)
    }

    /// A task launched mid-transfer adopts the folded value, not the last whole unit: adoption
    /// seeds through the same expression a live push writes.
    @Test
    func adoptionSeedsTheFold() async throws {
        let spy = ContinuedTaskSchedulingSpy()
        let store = ContinuedProcessingSession(scheduling: spy.scheduling)
        let session = try #require(
            store.start(
                title: "Downloading galleries",
                subtitle: "2 / 8 pages · 1 gallery",
                completedUnitCount: 2,
                totalUnitCount: 8
            )
        )
        let identifier = try #require(spy.registeredIdentifiers.first)

        // Pushed BEFORE any task exists, which is the window this case is about: the store records
        // the fold and the launch that follows must report it.
        store.updateProgress(
            sessionID: session.id,
            completedUnitCount: 2,
            totalUnitCount: 8,
            inFlightSubunitCount: 250,
            subtitle: "2 / 8 pages · 1 gallery"
        )

        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)

        #expect(task.progress.completedUnitCount == 2250)
        #expect(task.progress.totalUnitCount == 8 * ContinuedProcessingSession.subunitsPerUnit)

        store.finish(sessionID: session.id, success: true)
    }
}
