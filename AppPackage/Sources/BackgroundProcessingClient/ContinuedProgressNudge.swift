/// The bounded way a session says "still working, nothing to add" (G-15-2I).
///
/// **Why anything is needed at all.** The scheduler stalls — and then reclaims — a task whose
/// progress has not advanced for around thirty seconds. Republishing an identical count is not an
/// advance, and the API offers no heartbeat call and no indeterminate mode, so a caller whose work
/// is genuinely stuck on one long unit has no vocabulary for its own liveness. The only sentence
/// available is to add something too small to see: one sub-unit is a thousandth of a page, below
/// the card's rendering resolution and below any percentage this app rounds to.
///
/// **Why it stays honest.** It is bounded to ONE sub-unit per stalled liveness report; it can never
/// accumulate across real progress, because any change in the measurement clears it outright; and a
/// DECREASE is published as readily as an increase, so it can never hold a number up. It is display
/// state of one session and nothing else reads it — no completeness quantity, no scheduling gate,
/// no retry basis derives from it.
///
/// **The headroom.** `cap + 1` sub-units are held back above the highest measurement the caller can
/// express, so a measurement that already looks finished can still be nudged and the published
/// count never REACHES the scaled total — which would mark the progress finished, the one reading
/// the nudge must never produce. The nudge lives inside that reserve, so the clamp can never
/// swallow it.
///
/// **Why the cap is thirty (owner decision 2026-08-19), re-derived rather than assumed.** Thirty
/// nudges at the ten-second liveness cadence is about five minutes. The longest legitimate flat
/// stretch this app can produce is a page starving through its attempts under the abandon rule:
/// roughly two attempts of seventy seconds, about a hundred and forty seconds plus resolution
/// latency — less than half the cap. The often-cited counter-example, a back-off wait after a quota
/// refusal, names no wait this app makes: a refusal arrives as a placeholder image, becomes a fatal
/// account error, and the run fails rather than waiting, so the queue moves or drains. Past the cap
/// the published count goes flat ON PURPOSE: the system reclaims the session about thirty seconds
/// later and the expiry arm pauses the schedulable downloads, which is the guarantee the cap
/// carries — a wedged queue cannot hold a session open forever. Any future in-run wait longer than
/// the cap (there is none today) must publish progress of its own or re-derive this number.
struct ContinuedProgressNudge: Equatable, Sendable {
    /// How many consecutive stalled liveness reports may be nudged before the count holds flat.
    static let cap: Int64 = 30
    /// The sub-units held back above the highest expressible measurement, so a full-looking
    /// measurement is still nudgeable and the published count never reaches the scaled total.
    static let headroom: Int64 = cap + 1

    /// The last measurement the caller expressed, already clamped by the store.
    private(set) var measuredSubunits: Int64
    /// How many consecutive stalled reports have been nudged on top of it.
    private(set) var count: Int64 = 0

    init(measuredSubunits: Int64 = 0) {
        self.measuredSubunits = measuredSubunits
    }

    /// What the card is told: the measurement plus whatever the nudge has added to it.
    var reportedSubunits: Int64 {
        measuredSubunits + count
    }

    /// Folds one report in, and says whether it was a STALLED liveness report — whether the
    /// published count now stands on the nudge rather than on a fresh measurement.
    ///
    /// A CHANGED measurement — in either direction — snaps the published value back to it and
    /// clears the nudge, so no accumulated fiction survives a real observation. An UNCHANGED
    /// measurement adds one sub-unit, up to the cap, and only when the caller marked the report as
    /// one of its periodic liveness re-pushes; an unchanged measurement from any other push holds
    /// the current value rather than dipping below it.
    ///
    /// AT THE CAP it still answers `true` although it added nothing, deliberately: the answer names
    /// the report, not the increment, and the caller logs on it — a session pinned at the cap is
    /// exactly what the last lines before the system reclaims it should say. Those lines are bounded
    /// by the reclaim itself, roughly thirty seconds past the cap at the ten-second cadence.
    @discardableResult
    mutating func record(measuredSubunits: Int64, nudgesWhenStalled: Bool) -> Bool {
        guard measuredSubunits == self.measuredSubunits else {
            self.measuredSubunits = measuredSubunits
            count = 0
            return false
        }
        guard nudgesWhenStalled else { return false }
        count = min(count + 1, Self.cap)
        return true
    }
}
