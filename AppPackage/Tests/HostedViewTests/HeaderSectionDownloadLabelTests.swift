import AppModels
import ComposableArchitecture
import CookieClient
@testable import DetailFeature
import Foundation
import SwiftUI
import Testing

/// The download button's VoiceOver label names the state and the action a tap performs; a queued download reads
/// like a running one, with its saved pages once there are any (owner decision, 2026-11-21).
@MainActor
struct HeaderSectionDownloadLabelTests {
    private struct Host: View {
        @AccessibilityFocusState var readFocus: Bool

        private let downloadBadge: DownloadBadge

        init(downloadBadge: DownloadBadge) {
            self.downloadBadge = downloadBadge
        }

        var body: some View {
            HeaderSection(
                gallery: .preview,
                galleryDetail: .preview,
                downloadBadge: downloadBadge,
                downloadNeedsRepair: false,
                downloadFolders: [],
                isPreparingDownload: false,
                canDownload: true,
                displayJapaneseTitle: false,
                showFullTitle: false,
                showFullTitleAction: {},
                downloadAction: {},
                downloadToFolderAction: { _ in },
                manageFoldersAction: {},
                createDefaultFolderAction: {},
                favorAction: { _ in },
                unfavorAction: {},
                readingProgress: 0,
                navigateReadingAction: {},
                readButtonFocus: $readFocus,
                navigateUploaderAction: {}
            )
        }
    }

    private func isRead(_ label: String, for badge: DownloadBadge) throws -> Bool {
        // `@SharedReader(.didLogin)` reads the cookie store while the header is built.
        let elements = try withDependencies {
            $0.cookieClient = .noop
        } operation: {
            try LaidOutElements(of: Host(downloadBadge: badge), width: 402, size: .large)
        }
        return elements.frame(labelled: label) != nil
    }

    @Test
    func aQueuedDownloadWithNothingSavedReadsQueuedAndPause() throws {
        let badge = DownloadBadge(status: .queued, progress: .init(completedPageCount: 0, pageCount: 114))

        #expect(try isRead("Queued. Pause download", for: badge))
    }

    @Test
    func aQueuedDownloadWithSavedPagesReadsThem() throws {
        let badge = DownloadBadge(status: .queued, progress: .init(completedPageCount: 47, pageCount: 114))

        #expect(try isRead("Queued, 47 of 114. Pause download", for: badge))
    }

    @Test
    func aRunningDownloadKeepsItsLabel() throws {
        let badge = DownloadBadge(status: .active, progress: .init(completedPageCount: 47, pageCount: 114))

        #expect(try isRead("Downloading 47 of 114. Pause download", for: badge))
    }
}
