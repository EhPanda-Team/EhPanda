import XCTest

// The 19-06 scenarios: one class per group, one method per scenario, so simulator clones share the work.

final class SearchSnapshotTests: SnapshotMatrixCase {
    @MainActor func testRootEmpty() async throws { try await capture(scenario: "search-root-empty") }
    @MainActor func testRootHistory() async throws { try await capture(scenario: "search-root-history") }
    @MainActor func testClearConfirmation() async throws { try await capture(scenario: "search-clear-confirmation") }
    @MainActor func testTypingSuggestions() async throws { try await capture(scenario: "search-typing-suggestions") }
    @MainActor func testResultsList() async throws { try await capture(scenario: "search-results-list") }
    @MainActor func testResultsGrid() async throws { try await capture(scenario: "search-results-grid") }
    @MainActor func testResultsEmpty() async throws { try await capture(scenario: "search-results-empty") }
    @MainActor func testResultsError() async throws { try await capture(scenario: "search-results-error") }
}

final class QuickSearchSnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "quick-search-list") }
    @MainActor func testEmpty() async throws { try await capture(scenario: "quick-search-empty") }
    @MainActor func testDeleteConfirmation() async throws {
        try await capture(scenario: "quick-search-delete-confirmation")
    }
    @MainActor func testWordEditor() async throws { try await capture(scenario: "quick-search-word-editor") }
    @MainActor func testFilters() async throws { try await capture(scenario: "quick-search-filters") }
    @MainActor func testFiltersResetConfirmation() async throws {
        try await capture(scenario: "quick-search-filters-reset-confirmation")
    }
    @MainActor func testDateSeek() async throws { try await capture(scenario: "quick-search-date-seek") }
}

final class FavoritesSnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "favorites-list") }
    @MainActor func testGrid() async throws { try await capture(scenario: "favorites-grid") }
    @MainActor func testEmpty() async throws { try await capture(scenario: "favorites-empty") }
    @MainActor func testSignedOut() async throws { try await capture(scenario: "favorites-signed-out") }
    @MainActor func testCategoryMenu() async throws { try await capture(scenario: "favorites-category-menu") }
}
