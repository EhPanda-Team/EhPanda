import Observation
import SwiftUI

// Replaces the SwiftUIPager `Page` object as the reader's single plain-index source of truth
// (DEP-05 / D-07): the horizontal paging ScrollView, the vertical AdvancedList, autoplay, the
// slider, tap-to-turn, and resume seeding all read and write this one index. It mirrors the
// `Page` surface the reader used (`.index`, `.update(.next)`/`.update(.new(index:))`) so those
// call sites survive the swap as a type change only. Like `Page`, `update` performs the raw
// increment/set; clamping to the data source's bounds belongs to the write sites, which own the
// data source.
@Observable
@MainActor
final class PageModel {
    // Window for ReadingView's `performingChanges` echo guards around a programmatic index write.
    // The index and the horizontal pager's scroll position mirror one another through onChange
    // observers, so a one-sided write echoes back through the opposite observer and would
    // re-write the side that just changed — canceling an in-flight scroll. Writers raise their
    // flag, then lower it after this delay: long enough for the observer round-trip to settle,
    // short enough not to swallow the user's next gesture (timing verified by device UAT). The
    // vertical `AdvancedList` needs no window: it compares the page its position names instead.
    static let echoGuardDuration = 0.2

    var index: Int

    enum Update {
        case next
        case new(index: Int)
    }

    init(index: Int = 0) {
        self.index = index
    }

    func update(_ update: Update) {
        switch update {
        case .next:
            index += 1

        case .new(let index):
            self.index = index
        }
    }
}

/// Keeps the horizontal pager on the index while page turns are sent to it programmatically.
///
/// The paging ScrollView can lose a position it is handed while it is still moving, or as it comes to rest: it stays
/// on the earlier page, and its position binding keeps naming the later one, which is what the index then reads at
/// rest. The indicator then names the later page and the screen shows the earlier one until the next turn. This was
/// measured on iOS 27.2 (2026-11-03) with the slider seeking the pager while it still scrolled, the screen left a page
/// or two short; on an iPad the last turn of a drag, landing as the pager came to rest, was lost the same way.
///
/// Two rules keep the two in step. A turn that arrives while the pager animates only moves the index, and the pager
/// is sent to the index once it is at rest: holding the turn, rather than accepting where the pager stopped, keeps the
/// page the reader asked for. And once the pager is at rest, the page it shows is checked against the index, so a turn
/// lost at the moment of rest is sent again. A pager built anew, as after a change of direction, reports `.idle` as it
/// appears, which also clears a gate left behind by a pager torn down mid-animation.
struct PagerTurnGate {
    /// How many times in a row the pager is sent again to a page it does not reach, before the gate waits for the
    /// next turn or scroll instead.
    static let correctionLimit = 2

    private var isAnimating = false
    private var isAtRest = true
    private var corrections = 0
    private(set) var holdsTurn = false

    /// Whether a turn may be sent to the pager now; if not, it is held until the pager is at rest.
    mutating func admitsTurn() -> Bool {
        if isAnimating { holdsTurn = true }
        return !isAnimating
    }

    /// Follows the pager's scroll phase. Returns `true` when the pager has come to rest with a turn held, and so
    /// has to be sent to the index. Any phase other than a programmatic animation, such as the reader's own drag,
    /// drops the held turn: that scroll decides the page.
    mutating func phaseChanged(to phase: ScrollPhase) -> Bool {
        isAnimating = phase == .animating
        isAtRest = phase == .idle
        guard !isAnimating else { return false }
        defer { holdsTurn = false }
        return phase == .idle && holdsTurn
    }

    /// Whether the pager, at rest on the `shown` position, has to be sent again to `index`. `shown` is `nil` while no
    /// single page fills the pager. Pages the pager keeps failing to reach are given up after `correctionLimit` tries.
    mutating func needsCorrection(shown: Int?, index: Int) -> Bool {
        guard isAtRest, let shown else { return false }
        guard shown != index else {
            corrections = 0
            return false
        }
        guard corrections < Self.correctionLimit else { return false }
        corrections += 1
        return true
    }
}
