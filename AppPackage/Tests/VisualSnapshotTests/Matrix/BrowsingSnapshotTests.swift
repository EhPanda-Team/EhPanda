import XCTest

// The 19-05 scenarios: one class per group, one method per scenario, so simulator clones share the work
// (19-RESEARCH §4). Each method captures its scenario's in-process coordinates through the catalog.

final class FirstLaunchSnapshotTests: SnapshotMatrixCase {
    @MainActor func testAgewallTicked() async throws { try await capture(scenario: "agewall-ticked") }
    @MainActor func testAgewallUnticked() async throws { try await capture(scenario: "agewall-unticked") }
    @MainActor func testAnalyticsChoiceNone() async throws { try await capture(scenario: "analytics-choice-none") }
    @MainActor func testAnalyticsChoiceMinimal() async throws {
        try await capture(scenario: "analytics-choice-minimal")
    }
    @MainActor func testAnalyticsChoiceBasic() async throws { try await capture(scenario: "analytics-choice-basic") }
    @MainActor func testAnalyticsChoiceFull() async throws { try await capture(scenario: "analytics-choice-full") }
}

final class ShellSnapshotTests: SnapshotMatrixCase {
    @MainActor func testLibrarySidebar() async throws { try await capture(scenario: "shell-library-sidebar") }
    @MainActor func testLibraryTitleMenu() async throws { try await capture(scenario: "shell-library-title-menu") }
}

final class HomeSnapshotTests: SnapshotMatrixCase {
    @MainActor func testHomePopulated() async throws { try await capture(scenario: "home-populated") }
    @MainActor func testHomeLoading() async throws { try await capture(scenario: "home-loading") }
    @MainActor func testHomeError() async throws { try await capture(scenario: "home-error") }
}
