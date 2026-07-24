import AppModels
import Testing

// This suite is the absent-credential gate proving itself for the whole repository. Both accessors
// read `Bundle.main`, which under the test host is the test runner rather than the app bundle, so
// no analytics credential is reachable from any test here. Pinning that as an assertion — rather
// than working around it — is what makes it impossible for any other suite to accidentally emit a
// real signal into the owner's dataset, and it is the same single nil condition that covers
// contributor clones, forks, CI and SwiftUI previews.
@Suite
struct AppInfoAnalyticsTests {
    @Test
    func appIDIsNilUnderTestHost() {
        #expect(AppInfo.telemetryDeckAppID == nil)
    }

    @Test
    func saltIsNilUnderTestHost() {
        #expect(AppInfo.telemetryDeckSalt == nil)
    }
}
