import VisualSnapshotSupport
import XCTest

// The 19-08 scenarios: one class per group, one method per scenario, so simulator clones share the work. The
// Settings pages are split over two classes. The three Login scenarios have no method: their backdrop animates from
// the wall clock and never settles (see `SettingsScenarios.login(_:)`).

final class SettingsSnapshotTests: SnapshotMatrixCase {
    @MainActor func testRoot() async throws { try await capture(scenario: "settings-root") }
    @MainActor func testAccountSignedIn() async throws { try await capture(scenario: "settings-account-signed-in") }
    @MainActor func testAccountSignedOut() async throws { try await capture(scenario: "settings-account-signed-out") }
    @MainActor func testAccountLogoutConfirmation() async throws {
        try await capture(scenario: "settings-account-logout-confirmation")
    }
    @MainActor func testBlockedUsersFilled() async throws { try await capture(scenario: "blocked-users-filled") }
    @MainActor func testBlockedUsersEmpty() async throws { try await capture(scenario: "blocked-users-empty") }
}
