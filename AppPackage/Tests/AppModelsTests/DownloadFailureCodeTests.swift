@testable import AppModels
import Testing

struct DownloadFailureCodeTests {
    // Download manifests already on disk hold these values, so they outlive the case names.
    @Test
    func renamedCasesKeepTheirStoredValues() {
        #expect(DownloadFailureCode.imageLimitReached.rawValue == "quotaExceeded")
        #expect(DownloadFailureCode.loginRequired.rawValue == "authenticationRequired")
    }
}
