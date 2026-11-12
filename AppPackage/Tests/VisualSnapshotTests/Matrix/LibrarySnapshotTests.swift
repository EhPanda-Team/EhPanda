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

final class DownloadsSnapshotTests: SnapshotMatrixCase {
    @MainActor func testList() async throws { try await capture(scenario: "downloads-list") }
    @MainActor func testGrid() async throws { try await capture(scenario: "downloads-grid") }
    @MainActor func testEmpty() async throws { try await capture(scenario: "downloads-empty") }
    @MainActor func testActiveFailed() async throws { try await capture(scenario: "downloads-active-failed") }
    @MainActor func testDeleteConfirmation() async throws {
        try await capture(scenario: "downloads-delete-confirmation")
    }
    @MainActor func testMoveConfirmation() async throws { try await capture(scenario: "downloads-move-confirmation") }
    @MainActor func testInspector() async throws { try await capture(scenario: "downloads-inspector") }
    @MainActor func testInspectorError() async throws { try await capture(scenario: "downloads-inspector-error") }
}

final class GalleryDetailSnapshotTests: SnapshotMatrixCase {
    @MainActor func testLoaded() async throws { try await capture(scenario: "gallery-detail-loaded") }
    @MainActor func testLoading() async throws { try await capture(scenario: "gallery-detail-loading") }
    @MainActor func testError() async throws { try await capture(scenario: "gallery-detail-error") }
    @MainActor func testRating() async throws { try await capture(scenario: "gallery-detail-rating") }
    @MainActor func testDownloading() async throws { try await capture(scenario: "gallery-detail-downloading") }
    @MainActor func testDeleteDownloadConfirmation() async throws {
        try await capture(scenario: "gallery-detail-delete-download-confirmation")
    }
    @MainActor func testRetryConfirmation() async throws {
        try await capture(scenario: "gallery-detail-retry-confirmation")
    }
    @MainActor func testSheet() async throws { try await capture(scenario: "gallery-detail-sheet") }
}
