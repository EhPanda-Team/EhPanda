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
            subunits: .init(inFlightSubunitCount: 500),
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
    ///
    /// The bound is now REACHING rather than exceeding (G-15-2I): the measurement is held
    /// `ContinuedProgressNudge.headroom` sub-units below the scaled total, so a finished-looking
    /// measurement still has room for a stall nudge and the published count can never say the work
    /// is done while it is not.
    @Test
    func theFoldNeverReachesTheTotal() async throws {
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
            subunits: .init(inFlightSubunitCount: 999),
            subtitle: "10 / 10 pages · 1 gallery"
        )

        #expect(
            task.progress.completedUnitCount
                == 10 * ContinuedProcessingSession.subunitsPerUnit - ContinuedProgressNudge.headroom
        )
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
            subunits: .init(inFlightSubunitCount: 250),
            subtitle: "2 / 8 pages · 1 gallery"
        )

        let task = ContinuedTaskSpy()
        spy.launch(identifier, with: task)

        #expect(task.progress.completedUnitCount == 2250)
        #expect(task.progress.totalUnitCount == 8 * ContinuedProcessingSession.subunitsPerUnit)

        store.finish(sessionID: session.id, success: true)
    }

    /// BINDING (G-15-2I): a stalled liveness report with ZERO in-flight sub-units and nothing else
    /// to say still advances the published count by one sub-unit.
    ///
    /// There is deliberately no second "is there work" condition anywhere in the path, and this is
    /// the shape that proves it: an entirely idle-looking report is exactly what a queue stuck on a
    /// silent transfer produces, and it is the case the whole mechanism exists for.
    ///
    /// The session opens one page BEHIND the series, so the first push of it carries a measurement
    /// the store has not seen and the case observes the nudge from its baseline. `start` seeds the
    /// nudge with the caller's opening snapshot — a liveness report identical to THAT is a stalled
    /// report too, and nudging it is correct — so opening at the series' own value would put the
    /// first nudge before the first observation and hide the baseline the case is about.
    @Test
    func aStalledLivenessReportWithNothingInFlightStillAdvancesTheCount() async throws {
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

        var published = [Int64]()
        for _ in 0..<3 {
            store.updateProgress(
                sessionID: session.id,
                completedUnitCount: 4,
                totalUnitCount: 10,
                subunits: .init(inFlightSubunitCount: 0, nudgesWhenStalled: true),
                subtitle: "4 / 10 pages · 1 gallery"
            )
            published.append(task.progress.completedUnitCount)
        }

        expectNoDifference(published, [4000, 4001, 4002])
        // The denominator is untouched by any of it: the nudge is a numerator-only affordance.
        #expect(task.progress.totalUnitCount == 10 * ContinuedProcessingSession.subunitsPerUnit)

        store.finish(sessionID: session.id, success: true)
    }

    /// The cap and the ceiling together, over the hardest measurement there is: a queue that
    /// already looks finished. Forty stalled reports must never publish the scaled total — which
    /// would tell the system the work is done — and must stop climbing at the cap.
    @Test
    func aCappedNudgeOnAFinishedLookingMeasurementNeverReachesTheTotal() async throws {
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

        let scaledTotal = 10 * ContinuedProcessingSession.subunitsPerUnit
        var published = [Int64]()
        for _ in 0..<40 {
            store.updateProgress(
                sessionID: session.id,
                completedUnitCount: 10,
                totalUnitCount: 10,
                subunits: .init(inFlightSubunitCount: 999, nudgesWhenStalled: true),
                subtitle: "10 / 10 pages · 1 gallery"
            )
            published.append(task.progress.completedUnitCount)
        }

        #expect(published.allSatisfy({ $0 < scaledTotal }))
        #expect(
            published.last
                == scaledTotal - ContinuedProgressNudge.headroom + ContinuedProgressNudge.cap
        )
        // Which is one sub-unit short of the total: the headroom is the cap plus exactly that one.
        #expect(published.last == scaledTotal - 1)

        store.finish(sessionID: session.id, success: true)
    }

    /// An honest, MOVING measurement publishes exactly what it published before any of this
    /// existed: below the ceiling the expression is `completed * subunitsPerUnit + inFlight`, and
    /// the nudge contributes nothing because every report changes the measurement.
    ///
    /// The session opens one page behind the series for the same reason the case above does: every
    /// observed push has to carry a measurement the store has not already seen, or the first one
    /// would be a stalled report rather than a moving one.
    @Test
    func anHonestMovingSeriesIsUnchangedByTheNudge() async throws {
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

        let series = [
            MovingStep(completedUnitCount: 4, inFlightSubunitCount: 0),
            MovingStep(completedUnitCount: 4, inFlightSubunitCount: 500),
            MovingStep(completedUnitCount: 5, inFlightSubunitCount: 0),
            MovingStep(completedUnitCount: 5, inFlightSubunitCount: 250)
        ]
        var published = [Int64]()
        for step in series {
            store.updateProgress(
                sessionID: session.id,
                completedUnitCount: step.completedUnitCount,
                totalUnitCount: 10,
                // Marked as liveness reports throughout, so the case cannot pass by never offering
                // the nudge an opportunity: it passes because every measurement is new.
                subunits: .init(
                    inFlightSubunitCount: step.inFlightSubunitCount,
                    nudgesWhenStalled: true
                ),
                subtitle: "\(step.completedUnitCount) / 10 pages · 1 gallery"
            )
            published.append(task.progress.completedUnitCount)
        }

        expectNoDifference(published, [4000, 4500, 5000, 5250])

        store.finish(sessionID: session.id, success: true)
    }

    /// One step of a moving series. A named value rather than a tuple: an unlabeled multi-element
    /// tuple type is banned at error severity here, and `.0`/`.1` carry no meaning at a call site.
    private struct MovingStep {
        let completedUnitCount: Int64
        let inFlightSubunitCount: Int64
    }
}
