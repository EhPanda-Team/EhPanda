@testable import DetailFeature
import Foundation
import UIKit

/// The snapshot states of `DetailView` (19-18).
enum DetailViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        let artwork = TracerScenarios.cacheHomeArtwork
        return [
            SnapshotState(
                id: "gallery-detail-loaded",
                heights: .screen,
                factory: .init(make: { try LibraryScenarios.detail(.loaded) }, prepare: artwork)
            ),
            SnapshotState(
                id: "gallery-detail-loading",
                heights: .screen,
                factory: .init(
                    make: { try LibraryScenarios.detail(.loading) }, prepare: artwork,
                    interact: BrowsingScenarios.freezeIndicators
                )
            ),
            SnapshotState(
                id: "gallery-detail-error",
                heights: .screen,
                factory: .init(make: { try LibraryScenarios.detail(.error) }, prepare: artwork)
            ),
            // The rating row is below the fold at accessibility5 (run 43403534542), and on an iPhone in landscape
            // its stars were (run 44025665174): the page is scrolled until Rate Gallery and the stars under it are
            // in view. Rate Gallery is matched whole: in Chinese its label (评分, 評分) is part of the average
            // rating's and of the rating count's, which are above it, and iPad zh-Hans and zh-Hant accessibility5
            // landscape stopped at those with the rating out of view (run 43451019962).
            SnapshotState(
                id: "gallery-detail-rating",
                heights: .screen,
                factory: .init(
                    make: { try LibraryScenarios.detail(.rating) }, prepare: artwork,
                    interact: { window in
                        let below = LibraryScenarios.userRatingHeight(compatibleWith: window.traitCollection)
                        try await RevealStep.reveal(.wholeLabel(String(localized: .rateGallery)), below: below)(window)
                    }
                )
            ),
            // Where the download button and its progress are below the fold (accessibility5 in iPhone landscape), the
            // pictures were the same as gallery-detail-loaded's (run 43451019962): the page is scrolled to it.
            SnapshotState(
                id: "gallery-detail-downloading",
                heights: .screen,
                factory: .init(
                    make: { try LibraryScenarios.detail(.downloading) }, prepare: artwork,
                    interact: RevealStep.reveal(.label(String(localized: .accessibilityPauseAction)))
                )
            ),
            SnapshotState(
                id: "gallery-detail-delete-download-confirmation",
                heights: .screen,
                factory: .init(
                    make: { try LibraryScenarios.detail(.deleteDownloadConfirmation) }, prepare: artwork
                )
            ),
            SnapshotState(
                id: "gallery-detail-retry-confirmation",
                heights: .screen,
                factory: .init(
                    make: { try LibraryScenarios.detail(.retryConfirmation) }, prepare: artwork
                )
            )
        ]
    }
}
