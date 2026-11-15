import Foundation

/// How long a user step may wait for its condition: an allowance counted in the time this process's main run loop
/// turned (``MainThreadWatch/turned``), with a hard bound on the wall clock.
///
/// A step's wait used to be wall-clock time from its start: on the hosted runner the main thread stopped for 15 to
/// 172 s inside such waits (run 43621303643: `popover-platter:opening waited=50.3s polls=2`,
/// `no-keyboard:never-announced waited=171.9s polls=1`), the deadline ran out while the step could not look, and the
/// first look after the stop failed the step, whatever the condition was by then. Now:
///
/// - Before: a step failed at its first look once `allowance` of wall-clock time had passed since it began.
/// - After: a step fails at its first look once the main run loop has turned for `allowance` since it began, where a
///   stretch between two turns counts for at most ``MainThreadWatch/turnCap`` (1 s), or once ``wallBound`` of
///   wall-clock time has passed, the bound for a process that has stopped for good.
///
/// On a host that keeps turning, the two are the same wait. A stop counts for one second, so a step still looks at
/// its condition for its whole allowance after a stop.
@MainActor
struct StepBudget {
    /// The longest any step waits on the wall clock. Two attempts of a step at this bound and their settles stay
    /// within XCTest's 300 s per-test allowance (`run-shard.sh`), which ends a process that never comes back.
    static let wallBound: Duration = .seconds(120)

    let allowance: Duration
    private let clock = ContinuousClock()
    private let start: ContinuousClock.Instant
    private let turnedAtStart: Duration
    private let mark: UInt64
    /// How many times the step looked at its condition.
    private(set) var polls = 0

    init(_ allowance: Duration) {
        MainThreadWatch.start()
        self.allowance = allowance
        start = clock.now
        turnedAtStart = MainThreadWatch.turned
        mark = MainThreadWatch.now()
    }

    /// Wall-clock time since the step began.
    var waited: Duration { start.duration(to: clock.now) }

    /// Time the main run loop turned since the step began.
    var turned: Duration { MainThreadWatch.turned - turnedAtStart }

    /// Whether the step has had its allowance, or has reached the wall-clock bound.
    var isSpent: Bool { turned >= allowance || waited >= Self.wallBound }

    /// Counts a look at the step's condition.
    mutating func look() {
        polls += 1
    }

    /// The longest stretch since the step began in which the main run loop did not turn, if one was a stall.
    var longestStall: MainThreadWatch.Stall? {
        MainThreadWatch.longestStall(since: mark)
    }

    /// The step's failure: `<reason> waited=<s>s turned=<s>s polls=<n>[ stall=<s>s/<kind>] process=<s>s`.
    func failure(_ reason: String) -> BrowsingScenarios.StepFailure {
        BrowsingScenarios.StepFailure(reason: reason, budget: self)
    }
}
