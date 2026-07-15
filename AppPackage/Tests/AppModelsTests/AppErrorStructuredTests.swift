import Foundation
import Testing
@testable import AppModels

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
            error: .ipBanned(.hours(1, minutes: nil)),
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
            localizedDescription: "Web image loading error",
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
            alertText: "Login required to access this download."
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
            localizedDescription: "No updates available",
            alertText: ""
        ),
        Expectation(
            error: .notFound,
            isRetryable: false,
            localizedDescription: "Not found",
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
        #expect(AppError.ipBanned(.minutes(1, seconds: nil)).solution != nil)
        #expect(AppError.quotaExceeded.solution != nil)
        #expect(AppError.notFound.solution != nil)
        #expect(AppError.parseFailed.solution == nil)
    }

    @Test(arguments: [
        AppError.networkingFailed,
        .authenticationRequired,
        .ipBanned(.minutes(1, seconds: nil)),
        .quotaExceeded,
        .notFound
    ])
    func localizedErrorUsesTheExistingDescriptionAndSolution(_ error: AppError) throws {
        let localizedError: any LocalizedError = error

        #expect(localizedError.errorDescription == error.localizedDescription)
        #expect(localizedError.recoverySuggestion == error.solution)
    }
}
