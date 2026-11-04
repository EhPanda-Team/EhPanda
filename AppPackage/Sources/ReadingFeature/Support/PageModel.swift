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
/// lost at the moment of rest is sent again; a page the pager keeps missing is given up, and the index follows the page
/// on screen instead, so the indicator never names a page the screen does not show. A pager built anew, after a forced
/// refresh or a change of direction, starts the gate over (`pagerRebuilt()`): it need not report a phase as it appears,
/// so a gate left behind by a pager torn down mid-animation would otherwise hold every later turn.
struct PagerTurnGate {
    /// What brings a pager at rest on another page than the index back in step with it.
    enum Correction: Equatable {
        /// Send the pager to the index again.
        case sendAgain
        /// Give the index up, and let it follow the page on screen.
        case followScreen
    }

    /// How many times in a row the pager is sent again to a page it does not reach, before the index follows the
    /// page on screen instead.
    static let correctionLimit = 2

    private var isAnimating = false
    private var isAtRest = true
    private var corrections = 0
    private(set) var holdsTurn = false

    /// Whether a turn may be sent to the pager now; if not, it is held until the pager is at rest. A turn sent is a new
    /// target, so the pager's misses are counted afresh for it.
    mutating func admitsTurn() -> Bool {
        if isAnimating {
            holdsTurn = true
        } else {
            corrections = 0
        }
        return !isAnimating
    }

    /// Follows the pager's scroll phase. Returns `true` when the pager has come to rest with a turn held, and so
    /// has to be sent to the index. Any phase other than a programmatic animation, such as the reader's own drag,
    /// drops the held turn and starts the count of misses over: that scroll decides the page.
    mutating func phaseChanged(to phase: ScrollPhase) -> Bool {
        isAnimating = phase == .animating
        isAtRest = phase == .idle
        guard !isAnimating else { return false }
        if !isAtRest { corrections = 0 }
        defer { holdsTurn = false }
        return phase == .idle && holdsTurn
    }

    /// Starts the gate over for a pager built anew. A new pager starts at rest and need not report a scroll phase until
    /// it moves, so a gate left mid-animation by the pager it replaces would hold every turn and never check the page
    /// on screen. The new pager is placed on the index, which a held turn has already moved, so no turn is left to
    /// send.
    mutating func pagerRebuilt() {
        self = Self()
    }

    /// How the pager, at rest on the `shown` position, is brought back in step with `index`, or `nil` when it is in
    /// step or still moving. `shown` is `nil` while no single page fills the pager. The pager is sent again up to
    /// `correctionLimit` times in a row for one turn; after that the index follows the page on screen.
    mutating func correction(shown: Int?, index: Int) -> Correction? {
        guard isAtRest, let shown else { return nil }
        guard shown != index else {
            corrections = 0
            return nil
        }
        guard corrections < Self.correctionLimit else {
            corrections = 0
            return .followScreen
        }
        corrections += 1
        return .sendAgain
    }
}

/// Seeds the pager once, at the first measurement of an area it can lay pages out in.
///
/// The first measurement can be degenerate. With a full-width bar inset at the bottom of the reader, the iPad reader
/// first measured 0 by 1 pt, then 834 by 1052 pt (measured 2026-11-04 on iOS 27.2). The seed had waited for the first
/// measurement other than zero. That measurement was 0 by 1, too narrow to lay pages out in, so the seed was skipped,
/// and every later measurement was no longer the first one. The pager then opened on page 1 while the slider, and the
/// indicator with it, kept the resume page it is given at construction.
struct PagerSeed {
    private(set) var isSeeded = false

    /// Whether `size` is an area the pager can lay pages out in.
    static func isReadingArea(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    /// Whether the pager is to be seeded now, at a measurement of a reading area: `true` once, the first time.
    mutating func seeds() -> Bool {
        defer { isSeeded = true }
        return !isSeeded
    }
}
