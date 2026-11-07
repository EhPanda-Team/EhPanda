@testable import AppFeature
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
@testable import HomeFeature
import Kingfisher
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

// The three-scenario tracer of 19-01: one class per scenario, so simulator clones can share them. The gate never
// runs classes whose name starts with `Tracer` (19-10); the scenarios themselves are part of the inventory, and
// their factories are registered in their group files (`ScenarioCatalog+Browsing.swift`, `+Gallery.swift`).

final class TracerSnapshotTests: SnapshotMatrixCase {
    @MainActor
    func testHomePopulated() async throws {
        try await capture(scenario: "home-populated")
    }
}

final class TracerAgewallSnapshotTests: SnapshotMatrixCase {
    @MainActor
    func testAgewallUnticked() async throws {
        try await capture(scenario: "agewall-unticked")
    }
}

final class TracerCommentsSnapshotTests: SnapshotMatrixCase {
    @MainActor
    func testCommentsBlockConfirmation() async throws {
        try await capture(scenario: "comments-block-confirmation")
    }
}

@MainActor
enum TracerScenarios {
    // MARK: Home

    static func homeGalleries() -> [Gallery] {
        PublicVisualFixtures.homeGalleries.enumerated().map { index, fixture in
            Gallery(
                gid: fixture.gid, token: fixture.token, title: fixture.title, rating: 4.5, tags: [],
                category: .doujinshi, uploader: "Visual Fixture", pageCount: fixture.pageCount,
                postedDate: PublicVisualFixtures.fixedDate,
                coverURL: URL(string: "https://visual-fixture.invalid/home/\(index).png"), galleryURL: nil
            )
        }
    }

    /// Fills Kingfisher's memory cache with the synthetic covers, so no cover loads while the window settles.
    static func cacheHomeArtwork() async throws {
        for (index, gallery) in homeGalleries().enumerated() {
            guard let url = gallery.coverURL else { continue }
            let image = PublicVisualFixtures.artwork(marker: gallery.gid, colorIndex: index)
            try await ImageCache.default.store(image, forKey: url.absoluteString, toDisk: false)
        }
    }

    static func home() -> AnyView {
        let galleries = homeGalleries()
        var state = HomeReducer.State()
        state.popularGalleries = Array(galleries.prefix(1))
        state.cardPageIndex = 0
        state.currentCardID = galleries.first?.gid ?? ""
        state.frontPageGalleries = Array(galleries.dropFirst().prefix(2))
        state.toplistsGalleries = Dictionary(
            uniqueKeysWithValues: ToplistsType.allCases.map({ ($0.categoryIndex, []) })
        )
        if let toplist = ToplistsType.allCases.first {
            state.toplistsGalleries[toplist.categoryIndex] = Array(galleries.dropFirst(3))
        }
        return AnyView(NavigationStack {
            HomeView(store: Store(initialState: state, reducer: HomeReducer.init))
        })
    }

    // MARK: First launch

    static func ageWall() -> AnyView {
        let state = FirstLaunchReducer.State()
        state.$setting.withLock {
            $0.ageDeclarationVersion = nil
            $0.analyticsLevel = nil
        }
        return AnyView(FirstLaunchGateView(store: Store(initialState: state, reducer: FirstLaunchReducer.init)))
    }

    // MARK: Comments

    static let commentsGalleryURL = URL(string: "https://e-hentai.org/g/1/visual-token/")

    /// Synthetic comments by synthetic members, matched by member ID (owner msg 1918).
    static func commentFixtures() -> [GalleryComment] {
        (0..<6).map { index in
            GalleryComment(
                votedUp: false, votedDown: false, votable: true, editable: false, score: "+\(12 - index)",
                author: "Visual Member \(index + 1)", authorMemberID: "\(900_001 + index)",
                contents: [.init(
                    id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(index))),
                    type: .plainText, text: AttributedString(PublicVisualFixtures.commentText(index: index))
                )],
                commentID: PublicVisualFixtures.commentIDs[index],
                commentDate: PublicVisualFixtures.fixedDate.addingTimeInterval(-3600 * Double(index + 1))
            )
        }
    }

    static func comments() throws -> AnyView {
        guard let url = commentsGalleryURL else { throw ScenarioCatalogError.missingFixture("comments") }
        let comments = commentFixtures()
        let state = CommentsReducer.State(gid: "1", token: "visual-token", galleryURL: url, comments: comments)
        state.moderation.$blockedUsers.withLock({ $0 = [] })
        let store = Store(initialState: state, reducer: CommentsReducer.init)
        return AnyView(NavigationStack {
            CommentsView(
                store: store, gid: "1", token: "visual-token", apiKey: "", galleryURL: url, comments: comments
            )
        })
    }

    /// Chooses Block on the first comment, on screen at every text size, through the row's own accessibility action,
    /// as VoiceOver would; the row then presents its block confirmation.
    static func chooseBlock(_ window: UIWindow) async throws {
        let root = try XCTUnwrap(window.rootViewController?.view)
        let title = String(localized: .commentBlock("Visual Member 1"))
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while true {
            do {
                try AccessibilityActionDriver.perform(title, in: root)
                return
            } catch AccessibilityActionDriver.Failure.notFound where clock.now < deadline {
                // The list lays its rows out over the first frames.
                try await clock.sleep(for: .milliseconds(100))
            }
        }
    }
}
