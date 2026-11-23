@testable import DetailFeature
import Foundation

/// The snapshot states of `PostCommentView` (19-18).
enum PostCommentViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "comments-post-empty",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.comments(.postEmpty) },
                    still: GalleryScenarios.holdStillOverKeyboard
                )
            ),
            SnapshotState(
                id: "comments-post-filled",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.comments(.postFilled) },
                    still: GalleryScenarios.holdStillOverKeyboard
                )
            ),
            SnapshotState(
                id: "comments-posting-warning",
                heights: .screen,
                factory: .init(
                    make: { try GalleryScenarios.comments(.postingWarning) },
                    still: GalleryScenarios.holdStillOverKeyboard,
                    interact: { window in
                        try await RevealStep.reveal(.label(String(localized: .accessibilityComment)))(window)
                        try await RevealStep.awaitDialogPlatter()(window)
                        try await BrowsingScenarios.waitForRest(window)
                        BrowsingScenarios.stopCaretBlink(in: window)
                        try await GalleryScenarios.holdStill(window)
                    }
                )
            )
        ]
    }
}
