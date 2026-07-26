@testable import AppModels
import Foundation
import Testing

struct AppErrorStructuredTests {
    struct Expectation: Sendable {
        let error: AppError
        let isRetryable: Bool
        let localizedDescription: String
        let alertText: String
    }

    @Test(arguments: [
        Expectation(
            error: .copyrightClaim("Alice"),
            isRetryable: false,
            localizedDescription: "Copyright Claim",
            alertText: "This gallery is unavailable due to a copyright claim by Alice. Sorry about that."
        ),
        Expectation(
            error: .ipBanned(.hours(hours: 1, minutes: nil)),
            isRetryable: false,
            localizedDescription: "IP Banned",
            alertText: "Your IP address has been temporarily banned for excessive pageloads which indicates that "
                + "you are using automated mirroring / harvesting software. The ban expires in 1 hour."
        ),
        Expectation(
            error: .expunged("Removed by the uploader."),
            isRetryable: false,
            localizedDescription: "Gallery Expunged",
            alertText: "Removed by the uploader."
        ),
        Expectation(
            error: .networkingFailed,
            isRetryable: true,
            localizedDescription: "Network Error",
            alertText: "A network error occurred.\nPlease try again later."
        ),
        Expectation(
            error: .webImageFailed,
            isRetryable: true,
            localizedDescription: "Web Image Loading Error",
            alertText: ""
        ),
        Expectation(
            error: .parseFailed,
            isRetryable: true,
            localizedDescription: "Parse Error",
            alertText: "A parsing error occurred.\nPlease try again later."
        ),
        Expectation(
            error: .quotaExceeded,
            isRetryable: false,
            localizedDescription: "Quota Exceeded",
            alertText: "Image quota exceeded.\nPlease wait and try again later."
        ),
        Expectation(
            error: .authenticationRequired,
            isRetryable: false,
            localizedDescription: "Authentication Required",
            alertText: "Login required to access this content."
        ),
        // The forum's own refusal wording is the alert text, verbatim — the point of the case.
        Expectation(
            error: .loginRejected("You must enter a password."),
            isRetryable: true,
            localizedDescription: "Login Rejected",
            alertText: "You must enter a password."
        ),
        // A refusal the page gave no reason for is still a refusal, never an unknown error: the
        // title is unchanged and the body says plainly that no reason was given.
        Expectation(
            error: .loginRejected(nil),
            isRetryable: true,
            localizedDescription: "Login Rejected",
            alertText: "The site refused the sign-in without saying why.\n"
                + "Check your username and password, then try again."
        ),
        Expectation(
            error: .fileOperationFailed("Disk full."),
            isRetryable: true,
            localizedDescription: "File Operation Failed",
            alertText: "Local file operation failed.\nDisk full."
        ),
        Expectation(
            error: .noUpdates,
            isRetryable: true,
            localizedDescription: "No Updates Available",
            alertText: ""
        ),
        Expectation(
            error: .notFound,
            isRetryable: false,
            localizedDescription: "Not Found",
            alertText: "There seems to be nothing here."
        ),
        Expectation(
            error: .unknown,
            isRetryable: true,
            localizedDescription: "Unknown Error",
            alertText: "An unknown error occurred.\nPlease try again later."
        )
    ])
    func existingErrorBehaviorRemainsStable(_ expectation: Expectation) throws {
        #expect(expectation.error.isRetryable == expectation.isRetryable)
        #expect(expectation.error.localizedDescription == expectation.localizedDescription)
        #expect(expectation.error.alertText == expectation.alertText)
    }

    @Test
    func actionableErrorsProvideRecoverySuggestions() throws {
        #expect(AppError.networkingFailed.solution != nil)
        #expect(AppError.authenticationRequired.solution != nil)
        #expect(AppError.ipBanned(.minutes(minutes: 1, seconds: nil)).solution != nil)
        #expect(AppError.quotaExceeded.solution != nil)
        #expect(AppError.notFound.solution != nil)
        #expect(AppError.parseFailed.solution == nil)
    }

    @Test
    func cloudflareChallengeFailureIsNotRetryable() throws {
        #expect(AppError.cloudflareChallengeFailed.isRetryable == false)
    }

    @Test
    func cloudflareChallengeFailureIsFullyDescribed() throws {
        let error = AppError.cloudflareChallengeFailed
        let localizedError: any LocalizedError = error

        #expect(!error.localizedDescription.isEmpty)
        #expect(!error.alertText.isEmpty)
        #expect(error.solution != nil)
        #expect(localizedError.recoverySuggestion == error.solution)
    }

    // A CAPTCHA-gated login form is not a credential problem and cannot be retried away, so it
    // has to arrive as its own case rather than folded into the generic failure — otherwise the
    // user is sent back to re-check a password that was never wrong.
    @Test
    func loginCaptchaRequirementIsNotRetryableAndFullyDescribed() throws {
        let error = AppError.loginCaptchaRequired
        let localizedError: any LocalizedError = error

        #expect(error.isRetryable == false)
        #expect(!error.localizedDescription.isEmpty)
        #expect(!error.alertText.isEmpty)
        #expect(error.solution != nil)
        #expect(localizedError.recoverySuggestion == error.solution)
    }

    @Test
    func loginCaptchaRequirementIsDistinctFromAnUnsolvedWall() throws {
        // Both involve Cloudflare, and conflating them would point the user at the wrong recovery:
        // one is cleared by the in-app challenge surface, the other never can be.
        #expect(AppError.loginCaptchaRequired != AppError.cloudflareChallengeFailed)
        #expect(AppError.loginCaptchaRequired.solution != AppError.cloudflareChallengeFailed.solution)
    }

    @Test
    func everyErrorCaseCarriesADistinctIdentifier() throws {
        let allCases: [AppError] = [
            .copyrightClaim("Alice"),
            .ipBanned(.hours(hours: 1, minutes: nil)),
            .expunged("Removed by the uploader."),
            .networkingFailed,
            .webImageFailed,
            .parseFailed,
            .quotaExceeded,
            .authenticationRequired,
            .cloudflareChallengeFailed,
            .loginCaptchaRequired,
            .loginRejected("You must enter a password."),
            .fileOperationFailed("Disk full."),
            .noUpdates,
            .notFound,
            .unknown
        ]

        #expect(Set(allCases.map(\.id)).count == allCases.count)
    }

    @Test(arguments: [
        AppError.networkingFailed,
        .authenticationRequired,
        .ipBanned(.minutes(minutes: 1, seconds: nil)),
        .quotaExceeded,
        .notFound
    ])
    func localizedErrorUsesTheExistingDescriptionAndSolution(_ error: AppError) throws {
        let localizedError: any LocalizedError = error

        #expect(localizedError.errorDescription == error.localizedDescription)
        #expect(localizedError.recoverySuggestion == error.solution)
    }
}
