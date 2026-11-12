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

final class DetailPagesSnapshotTests: SnapshotMatrixCase {
    @MainActor func testPreviews() async throws { try await capture(scenario: "detail-pages-previews") }
    @MainActor func testPreviewsLoading() async throws { try await capture(scenario: "detail-pages-previews-loading") }
    @MainActor func testGalleryInfo() async throws { try await capture(scenario: "detail-pages-gallery-info") }
    @MainActor func testDetailSearchList() async throws {
        try await capture(scenario: "detail-pages-detail-search-list")
    }
    @MainActor func testDetailSearchGrid() async throws {
        try await capture(scenario: "detail-pages-detail-search-grid")
    }
    @MainActor func testArchives() async throws { try await capture(scenario: "detail-pages-archives") }
    @MainActor func testArchivesInsufficientFunds() async throws {
        try await capture(scenario: "detail-pages-archives-insufficient-funds")
    }
}

final class DetailPagesMoreSnapshotTests: SnapshotMatrixCase {
    @MainActor func testTorrents() async throws { try await capture(scenario: "detail-pages-torrents") }
    @MainActor func testTorrentsEmpty() async throws { try await capture(scenario: "detail-pages-torrents-empty") }
    @MainActor func testTagDetail() async throws { try await capture(scenario: "detail-pages-tag-detail") }
    @MainActor func testNewDawn() async throws { try await capture(scenario: "detail-pages-new-dawn") }
    @MainActor func testFolderManager() async throws { try await capture(scenario: "detail-pages-folder-manager") }
    @MainActor func testFolderDeleteConfirmation() async throws {
        try await capture(scenario: "detail-pages-folder-delete-confirmation")
    }
}

final class ReaderSnapshotTests: SnapshotMatrixCase {
    @MainActor func testVertical() async throws { try await capture(scenario: "reader-vertical") }
    @MainActor func testHorizontal() async throws { try await capture(scenario: "reader-horizontal") }
    @MainActor func testTwoPageSpread() async throws { try await capture(scenario: "reader-two-page-spread") }
    @MainActor func testControls() async throws { try await capture(scenario: "reader-controls") }
    @MainActor func testSliderScrub() async throws { try await capture(scenario: "reader-slider-scrub") }
    @MainActor func testPageFailed() async throws { try await capture(scenario: "reader-page-failed") }
    @MainActor func testLoading() async throws { try await capture(scenario: "reader-loading") }
    @MainActor func testLiveText() async throws { try await capture(scenario: "reader-live-text") }
    @MainActor func testSettingsSheet() async throws { try await capture(scenario: "reader-settings-sheet") }
}
