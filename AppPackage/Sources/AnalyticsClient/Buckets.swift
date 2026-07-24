import Foundation

// The only numeric vocabulary an analytics payload may carry: every counter and every duration
// ships as one of these buckets, never as an exact value, because exact counters measured against
// a stable per-install identifier erode anonymity in aggregate. D-08 carries **two** documented
// exceptions, both minted elsewhere and deliberately not expressible here — exact search-keyword
// length, and exact per-namespace tag counts, the latter added by D-16 as an amendment to D-08.
// One shared vocabulary rather than per-metric boundaries keeps the guarantee auditable in one
// file and lets unrelated metrics be compared on the same axis.

public enum CountBucket: String, CaseIterable, Equatable, Sendable {
    case zero = "0"
    case one = "1"
    case twoToFive = "2-5"
    case sixToTwenty = "6-20"
    case twentyOneToFifty = "21-50"
    case fiftyOnePlus = "51+"

    /// Classifies a count. Total by construction: every `Int` lands in exactly one bucket.
    ///
    /// A negative count is a programming error upstream rather than a user event, so it clamps to
    /// `.zero` instead of trapping — analytics must never be able to crash the app.
    public init(count: Int) {
        switch count {
        case ...0:
            self = .zero

        case 1:
            self = .one

        case 2...5:
            self = .twoToFive

        case 6...20:
            self = .sixToTwenty

        case 21...50:
            self = .twentyOneToFifty

        default:
            self = .fiftyOnePlus
        }
    }
}

public enum DurationBucket: String, CaseIterable, Equatable, Sendable {
    case underTenSeconds = "0-10s"
    case tenToSixtySeconds = "10-60s"
    case oneToFiveMinutes = "1-5m"
    case fiveToTwentyMinutes = "5-20m"
    case overTwentyMinutes = "20m+"

    /// Classifies an elapsed duration. Total by construction: every `TimeInterval` lands in
    /// exactly one bucket.
    ///
    /// Zero, negative and non-finite inputs all clamp to `.underTenSeconds`. A `NaN` duration
    /// compares false against every range and would otherwise fall through to the longest bucket,
    /// silently inflating session-length metrics.
    public init(seconds: TimeInterval) {
        guard seconds.isNaN == false else {
            self = .underTenSeconds
            return
        }

        switch seconds {
        case ..<10:
            self = .underTenSeconds

        case 10..<60:
            self = .tenToSixtySeconds

        case 60..<300:
            self = .oneToFiveMinutes

        case 300..<1_200:
            self = .fiveToTwentyMinutes

        default:
            self = .overTwentyMinutes
        }
    }
}
