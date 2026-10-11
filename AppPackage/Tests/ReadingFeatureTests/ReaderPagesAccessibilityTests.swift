import Foundation
@testable import ReadingFeature
import Testing

// The reader's pages are one accessibility element in every reading direction (owner, 2026-10-11). These cases pin
// what the element reads; `ReaderPageSyncUITests.testThePagesAreOneElementReadingTheirPage` finds it in the app.
@MainActor
@Suite
struct ReaderPagesAccessibilityTests {
    @Test
    func aPageReadsItsPosition() {
        let value = ReaderPagesAccessibility.description(of: [4], failedPages: [], total: 31)

        #expect(String(localized: value) == String(localized: .accessibilityPageOf(current: 4, total: 31)))
    }

    @Test
    func aSpreadReadsItsRange() {
        let value = ReaderPagesAccessibility.description(of: [4, 5], failedPages: [], total: 31)

        #expect(String(localized: value) == String(localized: .accessibilityPagesOf(first: 4, last: 5, total: 31)))
    }

    @Test
    func aFailedPageReadsThatItFailed() {
        let value = ReaderPagesAccessibility.description(of: [4], failedPages: [4], total: 31)

        let expected = LocalizedStringResource.accessibilityPageStatus(
            String(localized: .accessibilityPageOf(current: 4, total: 31)),
            String(localized: .accessibilityFailedToLoad)
        )
        #expect(String(localized: value) == String(localized: expected))
    }

    @Test
    func aSpreadNamesItsFailedPageUnlessBothFailed() {
        let range = String(localized: .accessibilityPagesOf(first: 4, last: 5, total: 31))
        let oneFailed = ReaderPagesAccessibility.description(of: [4, 5], failedPages: [5], total: 31)
        let bothFailed = ReaderPagesAccessibility.description(of: [4, 5], failedPages: [4, 5], total: 31)

        let namesPage = LocalizedStringResource.accessibilityPageStatus(
            range, String(localized: .accessibilityPageFailedToLoad(page: 5))
        )
        let failed = LocalizedStringResource.accessibilityPageStatus(
            range, String(localized: .accessibilityFailedToLoad)
        )
        #expect(String(localized: oneFailed) == String(localized: namesPage))
        #expect(String(localized: bothFailed) == String(localized: failed))
    }
}
