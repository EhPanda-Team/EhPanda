import AppModels

// A payload-free mirror of `AppError`.
//
// Four `AppError` cases carry associated values: three carry free-form `String`s scraped from the
// site or built from a file operation, and one carries a `BanInterval` that can itself hold
// unrecognized scraped text. None of them may reach a payload, so the mirror below has no
// associated values at all — there is nothing for a future emission site to forward even by
// accident, which is D-06 enforced by the shape of the type.
//
// `init(_:)` switches exhaustively and binds nothing. The absence of a catch-all arm is the whole
// guarantee: a sixteenth `AppError` case is a compile error here, raised at exactly the moment
// someone has to decide whether it is safe to count and what to call it. A catch-all would have
// absorbed it silently into a neighbouring bucket instead, and nothing in the collected data
// would ever have shown that it happened.

public enum AppErrorKind: String, CaseIterable, Equatable, Sendable {
    case copyrightClaim
    case ipBanned
    case expunged
    case networkingFailed
    case webImageFailed
    case parseFailed
    case quotaExceeded
    case authenticationRequired
    case cloudflareChallengeFailed
    case loginCaptchaRequired
    case unsupportedDeepLink
    case fileOperationFailed
    case noUpdates
    case notFound
    case unknown
}

extension AppErrorKind {
    public init(_ error: AppError) {
        switch error {
        case .copyrightClaim:
            self = .copyrightClaim

        case .ipBanned:
            self = .ipBanned

        case .expunged:
            self = .expunged

        case .networkingFailed:
            self = .networkingFailed

        case .webImageFailed:
            self = .webImageFailed

        case .parseFailed:
            self = .parseFailed

        case .quotaExceeded:
            self = .quotaExceeded

        case .authenticationRequired:
            self = .authenticationRequired

        case .cloudflareChallengeFailed:
            self = .cloudflareChallengeFailed

        case .loginCaptchaRequired:
            self = .loginCaptchaRequired

        case .unsupportedDeepLink:
            self = .unsupportedDeepLink

        case .fileOperationFailed:
            self = .fileOperationFailed

        case .noUpdates:
            self = .noUpdates

        case .notFound:
            self = .notFound

        case .unknown:
            self = .unknown
        }
    }
}

// MARK: Error category

/// The coarse triage bucket an error belongs to.
///
/// A local mirror of the vendor's error-category vocabulary rather than a re-export of it, so
/// this taxonomy layer needs no SDK import and the spellings the dashboard groups by are visible
/// in this repository. Plan 14-06 translates it at the single call site that speaks to the SDK.
public enum AnalyticsErrorCategory: String, CaseIterable, Equatable, Sendable {
    /// An operation the app performed failed on its own terms.
    case thrownException = "thrown-exception"

    /// The user supplied or asked for something the app could not act on.
    case userInput = "user-input"

    /// The account, session or backend state blocks the app from proceeding.
    case appState = "app-state"
}

extension AppErrorKind {
    /// Which triage bucket this kind belongs to.
    ///
    /// The split follows where the failure originates rather than how it is presented: a request
    /// that failed is a thrown exception, a gate the account or host has put up is app state, and
    /// something the user handed the app or asked it for is user input. Every assignment is
    /// pinned individually in `AppErrorKindTests`, because a category quietly changing meaning
    /// would silently redraw a dashboard grouping without changing any signal name.
    public var category: AnalyticsErrorCategory {
        switch self {
        case .networkingFailed, .webImageFailed, .parseFailed, .fileOperationFailed,
             .cloudflareChallengeFailed, .unknown:
            .thrownException

        case .loginCaptchaRequired, .unsupportedDeepLink, .notFound:
            .userInput

        case .copyrightClaim, .ipBanned, .expunged, .quotaExceeded, .authenticationRequired,
             .noUpdates:
            .appState
        }
    }
}
