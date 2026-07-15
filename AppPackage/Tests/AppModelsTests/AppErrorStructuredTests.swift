import Foundation
import Testing
@testable import AppModels

struct AppErrorStructuredTests {
    @Test
    func actionableErrorsProvideRecoverySuggestions() throws {
        #expect(AppError.networkingFailed.solution != nil)
        #expect(AppError.authenticationRequired.solution != nil)
        #expect(AppError.parseFailed.solution == nil)
    }

    @Test(arguments: [AppError.networkingFailed, .authenticationRequired])
    func localizedErrorUsesTheExistingDescriptionAndSolution(_ error: AppError) throws {
        let localizedError: any LocalizedError = error

        #expect(localizedError.errorDescription == error.localizedDescription)
        #expect(localizedError.recoverySuggestion == error.solution)
    }
}
