import AppModels
import Foundation
@testable import GalleryListComponents
import Testing
import TestingSupport

// VoiceOver reads a waiting download's place among the waiting downloads; nothing draws it (B-6).
@Suite(.isolatedAppStorage)
struct DownloadBadgeAccessibilityTests {
    struct QueuedPosition: Sendable, CustomTestStringConvertible {
        let locale: String
        let expected: String

        var testDescription: String { "\(locale) → \(expected)" }
    }

    @Test(arguments: [
        QueuedPosition(locale: "en", expected: "Queued, position 2, 0 of 12"),
        QueuedPosition(locale: "de", expected: "In der Warteschlange, Position 2, 0 von 12"),
        QueuedPosition(locale: "ja", expected: "待機中、2番目、12ページ中0ページ"),
        QueuedPosition(locale: "ko", expected: "대기 중, 2번째, 12페이지 중 0페이지"),
        QueuedPosition(locale: "zh-Hans", expected: "等待中，第 2 个，共 12 页，已完成 0 页"),
        QueuedPosition(locale: "zh-Hant", expected: "等待中，第 2 個，共 12 頁，已完成 0 頁")
    ])
    func eachLocaleReadsTheWaitingPlace(_ reading: QueuedPosition) {
        var resource = LocalizedStringResource.downloadBadgeQueuedPositionAccessibility(
            position: 2,
            completed: 0,
            total: 12
        )
        resource.locale = Locale(identifier: reading.locale)

        #expect(String(localized: resource) == reading.expected)
    }

    @MainActor
    @Test
    func aWaitingBadgeReadsItsPlace() {
        let badge = DownloadBadge(
            status: .queued,
            progress: .init(completedPageCount: 3, pageCount: 12),
            waitingPosition: 2
        )

        #expect(
            DownloadBadgeLabel(badge: badge).accessibilityText
                == String(
                    localized: LocalizedStringResource.downloadBadgeQueuedPositionAccessibility(
                        position: 2,
                        completed: 3,
                        total: 12
                    )
                )
        )
    }

    @MainActor
    @Test
    func aBadgeWithoutAWaitingPlaceReadsAsBefore() {
        let progress = DownloadProgress(completedPageCount: 3, pageCount: 12)
        let progressReading = String(localized: .downloadBadgeProgressAccessibility(completed: 3, total: 12))

        let queued = DownloadBadge(status: .queued, progress: progress)
        #expect(
            DownloadBadgeLabel(badge: queued).accessibilityText
                == String(localized: .downloadBadgeQueued) + " " + progressReading
        )
        let active = DownloadBadge(status: .active, progress: progress, waitingPosition: 2)
        #expect(
            DownloadBadgeLabel(badge: active).accessibilityText
                == String(localized: .downloadBadgeDownloading) + " " + progressReading
        )
    }
}
