import VisualSnapshotSupport
import XCTest

// The 19-07 scenarios: one class per group, one method per scenario, so simulator clones share the work. The
// detail pages are split over two classes.

final class CommentsSnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "comments-list") }
    @MainActor func testMenu() async throws { try await capture(scenario: "comments-menu") }
    @MainActor func testBlockConfirmation() async throws { try await capture(scenario: "comments-block-confirmation") }
    @MainActor func testBlockedRowCollapsed() async throws {
        try await capture(scenario: "comments-blocked-row-collapsed")
    }
    @MainActor func testBlockedRowShown() async throws { try await capture(scenario: "comments-blocked-row-shown") }
    @MainActor func testPostEmpty() async throws { try await capture(scenario: "comments-post-empty") }
    @MainActor func testPostFilled() async throws { try await capture(scenario: "comments-post-filled") }
    @MainActor func testPostingWarning() async throws { try await capture(scenario: "comments-posting-warning") }
}

final class ReportFormSnapshotTests: SnapshotMatrixCase {
    @MainActor func testLoading() async throws { try await capture(scenario: "report-form-loading") }
    @MainActor func testReady() async throws { try await capture(scenario: "report-form-ready") }
    @MainActor func testFilled() async throws { try await capture(scenario: "report-form-filled") }
    @MainActor func testSending() async throws { try await capture(scenario: "report-form-sending") }
    @MainActor func testSent() async throws { try await capture(scenario: "report-form-sent") }
    @MainActor func testUnavailable() async throws { try await capture(scenario: "report-form-unavailable") }
    @MainActor func testErrorAlert() async throws { try await capture(scenario: "report-form-error-alert") }
}
