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

final class FrontPageSnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "front-page-list") }
    @MainActor func testGrid() async throws { try await capture(scenario: "front-page-grid") }
    @MainActor func testLoading() async throws { try await capture(scenario: "front-page-loading") }
    @MainActor func testError() async throws { try await capture(scenario: "front-page-error") }
    @MainActor func testEmpty() async throws { try await capture(scenario: "front-page-empty") }
    @MainActor func testSearch() async throws { try await capture(scenario: "front-page-search") }
}

final class PopularSnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "popular-list") }
    @MainActor func testGrid() async throws { try await capture(scenario: "popular-grid") }
    @MainActor func testLoading() async throws { try await capture(scenario: "popular-loading") }
    @MainActor func testError() async throws { try await capture(scenario: "popular-error") }
}

final class WatchedSnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "watched-list") }
    @MainActor func testGrid() async throws { try await capture(scenario: "watched-grid") }
    @MainActor func testEmpty() async throws { try await capture(scenario: "watched-empty") }
    @MainActor func testError() async throws { try await capture(scenario: "watched-error") }
    @MainActor func testSignedOut() async throws { try await capture(scenario: "watched-signed-out") }
}

final class ToplistsSnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "toplists-list") }
    @MainActor func testGrid() async throws { try await capture(scenario: "toplists-grid") }
    @MainActor func testError() async throws { try await capture(scenario: "toplists-error") }
    @MainActor func testPeriodMenu() async throws { try await capture(scenario: "toplists-period-menu") }
}

final class HistorySnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "history-list") }
    @MainActor func testGrid() async throws { try await capture(scenario: "history-grid") }
    @MainActor func testEmpty() async throws { try await capture(scenario: "history-empty") }
    @MainActor func testClearConfirmation() async throws { try await capture(scenario: "history-clear-confirmation") }
}
