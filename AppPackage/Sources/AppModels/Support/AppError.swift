import Foundation
import Resources

public enum AppError: Error, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { localizedDescription }

    public init(_ error: any Error) {
        self = error as? AppError ?? .unknown
    }

    case copyrightClaim(String)
    case ipBanned(BanInterval)
    case expunged(String)
    case networkingFailed
    case webImageFailed
    case parseFailed
    case quotaExceeded
    case authenticationRequired
    case cloudflareChallengeFailed
    case loginCaptchaRequired
    /// The forum refused the credential, with its own explanation when it gave one.
    ///
    /// A non-nil payload is the message from the forum's error box verbatim, already markup-stripped
    /// and length bounded by `Parser.parseLoginErrorMessage`. It exists because that reason was
    /// previously parsed, logged and then dropped: every refusal — a wrong password, a missing field,
    /// the attempt-lockout — arrived on screen as `.unknown`, so the app knew exactly what had
    /// happened and told the user nothing.
    ///
    /// `nil` is the refusal whose page carried no readable reason. It is still this case and not
    /// `.unknown`: the app does not know *why* the sign-in was refused, but it does know **that** it
    /// was, and reporting a known login failure as an unknown error throws away the half that is
    /// certain.
    case loginRejected(String?)
    case unsupportedDeepLink
    case fileOperationFailed(String)
    case noUpdates
    case notFound
    case unknown
}

extension AppError {
    public var isRetryable: Bool {
        switch self {
        // `.loginRejected` is retryable: unlike a CAPTCHA gate, a refused credential is exactly the
        // condition a corrected one clears, and it reported as `.unknown` (retryable) until now.
        case .networkingFailed, .parseFailed,
             .fileOperationFailed, .noUpdates, .unknown, .webImageFailed, .loginRejected:
            return true
        case .copyrightClaim, .expunged, .quotaExceeded, .authenticationRequired, .notFound,
             .ipBanned, .cloudflareChallengeFailed, .loginCaptchaRequired, .unsupportedDeepLink:
            return false
        }
    }
    public var localizedDescription: String {
        switch self {
        case .copyrightClaim:
            return String(localized: .appErrorCopyrightClaim)
        case .ipBanned:
            return String(localized: .appErrorIpBanned)
        case .expunged:
            return String(localized: .appErrorGalleryExpunged)
        case .networkingFailed:
            return String(localized: .appErrorNetworkError)
        case .webImageFailed:
            return String(localized: .appErrorWebImageLoadingError)
        case .parseFailed:
            return String(localized: .appErrorParseError)
        case .quotaExceeded:
            return String(localized: .appErrorQuotaExceeded)
        case .authenticationRequired:
            return String(localized: .appErrorAuthenticationRequired)
        case .cloudflareChallengeFailed:
            return String(localized: .appErrorCloudflareChallengeFailed)
        case .loginCaptchaRequired:
            return String(localized: .appErrorLoginCaptchaRequired)
        case .loginRejected:
            return String(localized: .appErrorLoginRejected)
        case .unsupportedDeepLink:
            return String(localized: .appErrorUnsupportedDeepLink)
        case .fileOperationFailed:
            return String(localized: .appErrorFileOperationFailed)
        case .noUpdates:
            return String(localized: .appErrorNoUpdatesAvailable)
        case .notFound:
            return String(localized: .appErrorNotFound)
        case .unknown:
            return String(localized: .appErrorUnknownError)
        }
    }
    public var alertText: String {
        let tryLater = String(localized: .tryLater)
        switch self {
        case .copyrightClaim(let owner):
            return String(localized: .copyrightClaim(owner))
        case .ipBanned(let interval):
            return String(localized: .ipBanned(interval.description))
        case .expunged(let reason):
            switch reason {
            case String(localized: .RConstant.responseGalleryUnavailable):
                return String(localized: .galleryUnavailable)
            default:
                return reason
            }
        case .networkingFailed:
            return [String(localized: .networkError), tryLater].joined(separator: "\n")
        case .parseFailed:
            return [String(localized: .parsing), tryLater].joined(separator: "\n")
        case .quotaExceeded:
            return String(localized: .appErrorQuotaExceededDescription)
        case .authenticationRequired:
            return String(localized: .appErrorAuthenticationRequiredDescription)
        case .cloudflareChallengeFailed:
            return String(localized: .appErrorCloudflareChallengeFailedDescription)
        case .loginCaptchaRequired:
            return String(localized: .appErrorLoginCaptchaRequiredDescription)
        case .loginRejected(let reason):
            // The forum's own wording, verbatim — the same treatment `.expunged` gives a
            // server-supplied reason. Substituting app-authored copy here would discard the only
            // part of the response that distinguishes one refusal from another. When the page
            // carried no reason there is nothing to quote, so the app says that plainly rather than
            // retreating to "unknown error" and discarding what it does know.
            return reason ?? String(localized: .appErrorLoginRejectedDescription)
        case .unsupportedDeepLink:
            return String(localized: .appErrorUnsupportedDeepLinkDescription)
        case .fileOperationFailed(let reason):
            return [String(localized: .appErrorLocalFileOperationFailed), reason]
                .filter({ !$0.isEmpty })
                .joined(separator: "\n")
        case .noUpdates, .webImageFailed:
            return ""
        case .notFound:
            return String(localized: .notFound)
        case .unknown:
            return [String(localized: .unknown), tryLater].joined(separator: "\n")
        }
    }
}

extension AppError {
    public var solution: String? {
        switch self {
        case .networkingFailed:
            String(localized: .appErrorNetworkSolution)
        case .authenticationRequired:
            String(localized: .appErrorAuthenticationSolution)
        case .cloudflareChallengeFailed:
            String(localized: .appErrorCloudflareChallengeSolution)
        case .loginCaptchaRequired:
            String(localized: .appErrorLoginCaptchaSolution)
        case .loginRejected:
            // Applies whether or not the forum gave a reason: the credential is the first thing to
            // re-check, and the web-login route is the escalation when it is not the problem.
            //
            // This and the `.cloudflareChallengeFailed` / `.loginCaptchaRequired` solutions above
            // name the browser and its position, never the control's appearance — an icon can be
            // restyled without anyone thinking to revisit a localized string in six languages. All
            // three point at the same control, so reword them together; they drifted once already
            // when only this one was updated.
            String(localized: .appErrorLoginRejectedSolution)
        case .unsupportedDeepLink:
            String(localized: .appErrorUnsupportedDeepLinkSolution)
        case .ipBanned:
            String(localized: .appErrorIpBannedSolution)
        case .quotaExceeded:
            String(localized: .appErrorQuotaExceededSolution)
        case .notFound:
            String(localized: .appErrorNotFoundSolution)
        case .copyrightClaim, .expunged, .webImageFailed, .parseFailed, .fileOperationFailed,
             .noUpdates, .unknown:
            nil
        }
    }
}

extension AppError: LocalizedError {
    public var errorDescription: String? {
        localizedDescription
    }

    public var recoverySuggestion: String? {
        solution
    }
}

public enum BanInterval: Equatable, Hashable, Sendable {
    case days(days: Int, hours: Int?)
    case hours(hours: Int, minutes: Int?)
    case minutes(minutes: Int, seconds: Int?)
    case unrecognized(content: String)
}

extension BanInterval {
    public var description: String {
        var params: [String]
        let and = String(localized: .banIntervalAnd)

        switch self {
        case .days(let days, let hours):
            params = [daysWithUnit(days)]
            if let hours = hours {
                params += [and, hoursWithUnit(hours)]
            }
        case .hours(let hours, let minutes):
            params = [hoursWithUnit(hours)]
            if let minutes = minutes {
                params += [and, minutesWithUnit(minutes)]
            }
        case .minutes(let minutes, let seconds):
            params = [minutesWithUnit(minutes)]
            if let seconds = seconds {
                params += [and, secondsWithUnit(seconds)]
            }
        case .unrecognized(let content):
            params = [content]
        }
        return params.filter({ !$0.isEmpty }).joined(separator: " ")
    }

    private func daysWithUnit(_ days: Int) -> String {
        String(localized: .RLocalizable.days(count: days))
    }
    private func hoursWithUnit(_ hours: Int) -> String {
        String(localized: .RLocalizable.hours(count: hours))
    }
    private func minutesWithUnit(_ minutes: Int) -> String {
        String(localized: .RLocalizable.minutes(count: minutes))
    }
    private func secondsWithUnit(_ seconds: Int) -> String {
        String(localized: .RLocalizable.seconds(count: seconds))
    }
}
