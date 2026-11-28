import AppModels
import CoreGraphics
import Foundation
import Resources

/// The snapshot states of `LibraryView` (19-18).
enum LibraryViewSnapshot: SnapshotProvider {
    @MainActor
    static var states: [SnapshotState] {
        [
            SnapshotState(
                id: "shell-library-sidebar",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 912, large: 912, accessibility5: 912),
                        landscape: .init(xSmall: 420, large: 420, accessibility5: 420)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 2344),
                        landscape: .init(xSmall: 863, large: 902, accessibility5: 2344)
                    )
                ),
                factory: .init(make: { BrowsingScenarios.library(selection: nil) })
            ),
            // Favorites under the menu hides its search field on scroll, so the list is brought to rest at its top
            // first, as the Favorites scenarios are: hosted early in a process it kept the field 2 points short
            // (run 42455556948, every text size but xSmall).
            SnapshotState(
                id: "shell-library-title-menu",
                heights: .committed(
                    iphone: .init(
                        portrait: .init(xSmall: 1184, large: 1190, accessibility5: 4506),
                        landscape: .init(xSmall: 1126, large: 1132, accessibility5: 2414)
                    ),
                    ipad: .init(
                        portrait: .init(xSmall: 1210, large: 1210, accessibility5: 1210),
                        landscape: .init(xSmall: 834, large: 834, accessibility5: 834)
                    )
                ),
                factory: ScenarioFactory(
                    make: { BrowsingScenarios.library(selection: .favorites(-1)) },
                    prepare: TracerScenarios.cacheHomeArtwork,
                    interact: { try await BrowsingScenarios.activate(String(localized: .RLocalizable.library), in: $0) }
                ).restingAtTop()
            )
        ]
    }
}
