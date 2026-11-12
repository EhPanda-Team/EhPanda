import CoreGraphics
import SwiftUI

/// The reader's page: the one value the indicator, the slider, the saved progress and the pager all follow
/// (17-READER-ROOT-CAUSE.md §3, D-18).
///
/// The reader used to keep the page in several places at once (the page model's index, the pager's scroll position,
/// the position shown on screen, the slider's value, the saved progress and the vertical list's position) and copied
/// each into the next as it changed. Those copies could disagree: a turn lost while the pager moved, or a pager rebuilt
/// mid-turn, left the indicator naming a page the screen did not show. This value is the only copy. The page the
/// reader names is `page`, a reading page counted from 1, or the target of the one pending turn while that turn is
/// under way (`displayedPage`). `page` changes only to a page the pager reported showing at rest, or by `commit(page:)`
/// for the resume page and the saved progress; a turn the pager cannot reach ends on the page it shows (DD-02).
///
/// Every pager the view builds carries the `generation` it was built in. A rebuild (a forced refresh, a change of
/// direction or of the pages laid out) starts a new one, and an observation from an older pager, still on its way when
/// the new one was built, is ignored. The view moves the pager only on a `PagerCommand`, which names the generation
/// it is for.
struct ReaderPosition: Equatable, Sendable {
    /// The one turn under way: the page asked for, and how often the pager has been sent to it again.
    struct Request: Equatable, Sendable {
        let target: Int
        /// The pager the turn was sent to.
        let generation: Int
        /// How many times in a row the pager, at rest on another page, has been sent to `target` again.
        fileprivate(set) var tries = 0
        /// Whether the turn arrived while the pager animated, and waits for it to come to rest before it is sent.
        fileprivate(set) var isHeld = false
    }

    /// How many times in a row the pager is sent again to a page it does not reach, before the page on screen is
    /// committed instead (DD-02). The paging ScrollView can drop a position handed to it while it moves or comes to
    /// rest (measured on iOS 27.2, 2026-11-03), so a miss is sent again; a page it keeps missing is given up, so the
    /// indicator never names a page the screen does not show.
    static let retryLimit = 2

    /// The committed reading page, from 1.
    private(set) var page: Int
    /// The turn under way, if any. The latest turn replaces an earlier one.
    private(set) var request: Request?
    /// The identity of the pager the view shows. Observations and commands of another generation are stale.
    private(set) var generation = 0
    /// How the pager of the current generation moves.
    private(set) var motion = PagerMotion.idle
    /// The latest command, numbered so the view carries out each one once, even a command equal to the one before.
    private(set) var issued: IssuedPagerCommand?

    /// Starts on `page`, the resume page, before any pager is built.
    init(page: Int) {
        self.page = max(page, 1)
    }

    /// The page the reader names: the target of the turn under way, or the committed page.
    var displayedPage: Int {
        request?.target ?? page
    }

    /// Where a pager is placed as it is built: on the displayed page. The first pager is built once the reading area
    /// is measured (`PagerSeed`), and a rebuilt one after `pagerRebuilt()`.
    var placement: PagerCommand {
        .place(page: displayedPage, generation: generation)
    }

    /// Sets the committed page, for the resume page and for the saved progress.
    mutating func commit(page: Int) {
        self.page = max(page, 1)
    }

    /// Asks for `target`, clamped to the gallery's pages when it has any. Returns the command that sends the pager
    /// there, or `nil` when the reader already names it or the pager animates: a turn that arrives while the pager
    /// animates is held and sent once it is at rest, because a position handed to the paging ScrollView while it moves
    /// can be lost. Each turn is a new target, so the pager's misses are counted afresh for it.
    mutating func turn(to target: Int, pageCount: Int) -> PagerCommand? {
        let target = pageCount > 0 ? min(max(target, 1), pageCount) : max(target, 1)
        guard target != displayedPage else { return nil }
        let isAnimating = motion == .animating
        request = Request(target: target, generation: generation, isHeld: isAnimating)
        return isAnimating ? nil : issue(.drive(page: target, generation: generation))
    }

    /// Follows the pager's motion. Returns the command that sends a held turn once the pager is at rest. The reader's
    /// own scroll drops the turn under way: that scroll decides the page.
    mutating func pagerPhaseChanged(to motion: PagerMotion, generation: Int) -> PagerCommand? {
        guard generation == self.generation else { return nil }
        self.motion = motion
        switch motion {
        case .animating:
            return nil

        case .scrolling:
            request = nil
            return nil

        case .idle:
            guard var request, request.isHeld else { return nil }
            request.isHeld = false
            self.request = request
            return issue(.drive(page: request.target, generation: generation))
        }
    }

    /// Takes the page the pager shows at rest, `nil` while no single page fills it. With no turn under way, as after
    /// the reader's own scroll, the page shown is committed. A turn that landed is committed; one that missed sends
    /// the pager again, up to `retryLimit` times in a row, and then commits the page shown (DD-02). Nothing changes
    /// while the pager moves, or for an observation of an older pager.
    mutating func pagerSettled(shown: Int?, generation: Int) -> PagerCommand? {
        guard generation == self.generation, motion == .idle, let shown else { return nil }
        guard var request, request.generation == generation else {
            page = shown
            return nil
        }
        guard !request.isHeld else { return nil }
        guard shown != request.target, request.tries < Self.retryLimit else {
            page = shown
            self.request = nil
            return nil
        }
        request.tries += 1
        self.request = request
        return issue(.drive(page: request.target, generation: generation))
    }

    /// Starts a new generation for a pager built anew, placed on the displayed page. A turn under way is committed: the
    /// new pager is placed on its target, so nothing is left to send, and a later observation of the old pager, which
    /// may have been torn down mid-animation, is stale. The new pager starts at rest; it need not report a phase until
    /// it moves.
    mutating func pagerRebuilt() -> PagerCommand {
        page = displayedPage
        request = nil
        generation += 1
        motion = .idle
        return issue(placement)
    }

    private mutating func issue(_ command: PagerCommand) -> PagerCommand {
        issued = IssuedPagerCommand(serial: (issued?.serial ?? 0) + 1, command: command)
        return command
    }
}

/// What the view does to the pager, for the pager of one generation. The page is a reading page; the view maps it
/// to the pager's position for the layout it shows (`PageHandler.mapToPager`).
enum PagerCommand: Equatable, Sendable {
    /// Put the pager on the page without animation, as it is built.
    case place(page: Int, generation: Int)
    /// Scroll the pager to the page, a turn.
    case drive(page: Int, generation: Int)

    var page: Int {
        switch self {
        case .place(let page, _), .drive(let page, _):
            page
        }
    }

    var generation: Int {
        switch self {
        case .place(_, let generation), .drive(_, let generation):
            generation
        }
    }
}

/// A `PagerCommand` with its place in the sequence of commands, so two equal commands in a row are two changes.
struct IssuedPagerCommand: Equatable, Sendable {
    let serial: Int
    let command: PagerCommand
}

/// How the pager moves, as its scroll phase reports it.
public enum PagerMotion: Equatable, Sendable {
    /// At rest.
    case idle
    /// A programmatic scroll: a turn the view sent.
    case animating
    /// The reader's own scroll: tracking, interacting or decelerating.
    case scrolling

    init(_ phase: ScrollPhase) {
        switch phase {
        case .idle:
            self = .idle

        case .animating:
            self = .animating

        default:
            self = .scrolling
        }
    }
}

/// Records whether the reader has measured an area it can lay pages out in, so the first pager is built only then.
///
/// The first measurement can be degenerate. With a full-width bar inset at the bottom of the reader, the iPad reader
/// first measured 0 by 1 pt, then 834 by 1052 pt (measured 2026-11-04 on iOS 27.2). A pager built at the first
/// measurement, rather than at the first reading area, opened on page 1 while the indicator kept the resume page.
struct PagerSeed {
    private(set) var isMeasured = false

    /// Whether `size` is an area the pager can lay pages out in.
    static func isReadingArea(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    /// Records a measurement of a reading area. Returns `true` once, the first time.
    mutating func measures() -> Bool {
        defer { isMeasured = true }
        return !isMeasured
    }
}
