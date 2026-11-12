import VisualSnapshotSupport
import XCTest

// The 19-08 scenarios: one class per group, one method per scenario, so simulator clones share the work. The
// Settings pages are split over two classes. The Login backdrop stands still under Reduce Motion (19-10), so its three
// scenarios settle like the rest.

final class SettingsSnapshotTests: SnapshotMatrixCase {
    @MainActor func testRoot() async throws { try await capture(scenario: "settings-root") }
    @MainActor func testAccountSignedIn() async throws { try await capture(scenario: "settings-account-signed-in") }
    @MainActor func testAccountSignedOut() async throws { try await capture(scenario: "settings-account-signed-out") }
    @MainActor func testAccountLogoutConfirmation() async throws {
        try await capture(scenario: "settings-account-logout-confirmation")
    }
    @MainActor func testBlockedUsersFilled() async throws { try await capture(scenario: "blocked-users-filled") }
    @MainActor func testBlockedUsersEmpty() async throws { try await capture(scenario: "blocked-users-empty") }
    @MainActor func testLoginEmpty() async throws { try await capture(scenario: "settings-login-empty") }
    @MainActor func testLoginFilled() async throws { try await capture(scenario: "settings-login-filled") }
    @MainActor func testLoginError() async throws { try await capture(scenario: "settings-login-error") }
}

final class SettingsPagesSnapshotTests: SnapshotMatrixCase {
    @MainActor func testGeneralMinimal() async throws { try await capture(scenario: "settings-pages-general-minimal") }
    @MainActor func testGeneralBasic() async throws { try await capture(scenario: "settings-pages-general-basic") }
    @MainActor func testGeneralFull() async throws { try await capture(scenario: "settings-pages-general-full") }
    @MainActor func testGeneralCacheConfirmation() async throws {
        try await capture(scenario: "settings-pages-general-cache-confirmation")
    }
    @MainActor func testGeneralTranslationsConfirmation() async throws {
        try await capture(scenario: "settings-pages-general-translations-confirmation")
    }
    @MainActor func testActivityLogs() async throws { try await capture(scenario: "settings-pages-activity-logs") }
    @MainActor func testActivityLogsEmpty() async throws {
        try await capture(scenario: "settings-pages-activity-logs-empty")
    }
    @MainActor func testActivityLogsRunPicker() async throws {
        try await capture(scenario: "settings-pages-activity-logs-run-picker")
    }
}

final class SettingsPagesMoreSnapshotTests: SnapshotMatrixCase {
    @MainActor func testAppearance() async throws { try await capture(scenario: "settings-pages-appearance") }
    @MainActor func testAppIcon() async throws { try await capture(scenario: "settings-pages-app-icon") }
    @MainActor func testDownload() async throws { try await capture(scenario: "settings-pages-download") }
    @MainActor func testReading() async throws { try await capture(scenario: "settings-pages-reading") }
    @MainActor func testLaboratory() async throws { try await capture(scenario: "settings-pages-laboratory") }
    @MainActor func testAbout() async throws { try await capture(scenario: "settings-pages-about") }
    @MainActor func testSiteSettings() async throws { try await capture(scenario: "settings-pages-site-settings") }
    @MainActor func testSiteSettingsConfirmation() async throws {
        try await capture(scenario: "settings-pages-site-settings-confirmation")
    }
    @MainActor func testSiteSettingsError() async throws {
        try await capture(scenario: "settings-pages-site-settings-error")
    }
}

final class AppWideSnapshotTests: SnapshotMatrixCase {
    @MainActor func testAppAlert() async throws { try await capture(scenario: "app-wide-app-alert") }
    @MainActor func testErrorInfo() async throws { try await capture(scenario: "app-wide-error-info") }
    @MainActor func testToastSuccess() async throws { try await capture(scenario: "app-wide-toast-success") }
    @MainActor func testToastFailure() async throws { try await capture(scenario: "app-wide-toast-failure") }
}
