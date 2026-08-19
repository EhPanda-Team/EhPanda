@testable import BackgroundProcessingClient
import Testing

/// The bounded stall nudge as a value (G-15-2I): what one report does to the published count.
///
/// Pinned here over the reporter itself rather than only through the store, because these are
/// arithmetic properties — one per stalled report, snap back either way, a hard cap — and staging
/// each of them through a system task would pin the staging. `ContinuedProcessingSessionFoldTests`
/// owns the other half: that the store publishes what this value says.
@Suite
struct ContinuedProgressNudgeTests {
    private static let measurement: Int64 = 4000

    /// One sub-unit per stalled liveness report, and the MEASUREMENT is untouched by any of them —
    /// which is what makes the next real observation able to clear the whole thing.
    @Test
    func eachStalledLivenessReportAddsExactlyOneSubunit() {
        var nudge = ContinuedProgressNudge(measuredSubunits: Self.measurement)

        for _ in 0..<3 {
            // Recorded into a local first: `#expect` takes an autoclosure, and a mutating call
            // cannot run inside one.
            let didNudge = nudge.record(measuredSubunits: Self.measurement, nudgesWhenStalled: true)
            #expect(didNudge)
        }

        #expect(nudge.reportedSubunits == Self.measurement + 3)
        #expect(nudge.count == 3)
        #expect(nudge.measuredSubunits == Self.measurement)
    }

    /// Any change snaps the published value back to it and clears the nudge — and a DECREASE is
    /// published as readily as an increase, which is the property that keeps the mechanism from
    /// ever holding a number up.
    @Test
    func anyChangeInEitherDirectionSnapsBackAndClearsTheNudge() {
        var nudge = ContinuedProgressNudge(measuredSubunits: Self.measurement)
        for _ in 0..<3 {
            nudge.record(measuredSubunits: Self.measurement, nudgesWhenStalled: true)
        }

        let didNudgeOnIncrease = nudge.record(
            measuredSubunits: Self.measurement + 500,
            nudgesWhenStalled: true
        )
        #expect(!didNudgeOnIncrease)
        #expect(nudge.reportedSubunits == Self.measurement + 500)
        #expect(nudge.count == 0)

        let didNudgeOnDecrease = nudge.record(
            measuredSubunits: Self.measurement - 200,
            nudgesWhenStalled: true
        )
        #expect(!didNudgeOnDecrease)
        #expect(nudge.reportedSubunits == Self.measurement - 200)
        #expect(nudge.count == 0)
    }

    /// BINDING (owner decision 2026-08-19): thirty CONSECUTIVE nudges, then flat. Forty reports
    /// rather than thirty-one, so the case fails on any cap that merely stops later.
    @Test
    func theNudgeIsCappedAtThirtyConsecutiveReports() {
        #expect(ContinuedProgressNudge.cap == 30)
        #expect(ContinuedProgressNudge.headroom == 31)

        var nudge = ContinuedProgressNudge(measuredSubunits: Self.measurement)
        for _ in 0..<40 {
            nudge.record(measuredSubunits: Self.measurement, nudgesWhenStalled: true)
        }

        #expect(nudge.count == 30)
        #expect(nudge.reportedSubunits == Self.measurement + 30)

        nudge.record(measuredSubunits: Self.measurement, nudgesWhenStalled: true)
        #expect(nudge.reportedSubunits == Self.measurement + 30)
    }

    /// A non-liveness push carrying an unchanged measurement neither increments nor DIPS: it holds
    /// what is already published, so an intra-unit report arriving between two beats cannot make
    /// the card lose the ground the nudge gained.
    @Test
    func anUnchangedNonLivenessReportHoldsWithoutIncrementing() {
        var nudge = ContinuedProgressNudge(measuredSubunits: Self.measurement)
        for _ in 0..<2 {
            nudge.record(measuredSubunits: Self.measurement, nudgesWhenStalled: true)
        }

        let didNudgeOnOtherPush = nudge.record(
            measuredSubunits: Self.measurement,
            nudgesWhenStalled: false
        )
        #expect(!didNudgeOnOtherPush)
        #expect(nudge.count == 2)
        #expect(nudge.reportedSubunits == Self.measurement + 2)

        let didNudgeOnBeat = nudge.record(measuredSubunits: Self.measurement, nudgesWhenStalled: true)
        #expect(didNudgeOnBeat)
        #expect(nudge.count == 3)
    }
}
