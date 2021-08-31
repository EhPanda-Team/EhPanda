//
//  ParserTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on 2021/08/21.
//

import XCTest
@testable import Kanna
@testable import EhPanda

// MARK: List
enum ListParserTestType: String, CaseIterable {
    case frontPage = "FrontPage"
    case watched = "Watched"
    case popular = "Popular"
    case favorites = "Favorites"
    case toplists = "Toplists"
}

extension ListParserTestType {
    var assertCount: Int {
        switch self {
        case .frontPage:
            return 200
        case .watched:
            return 200
        case .popular:
            return 50
        case .favorites:
            return 92
        case .toplists:
            return 50
        }
    }
}

class ListParserTests: XCTestCase, TestHelper {
    func testExample() {
        let tuples: [(ListParserTestType, HTMLDocument)] =
        ListParserTestType.allCases.compactMap { type in
            (type, getHTML(resourceName: type.rawValue)!)
        }
        XCTAssertEqual(tuples.count, ListParserTestType.allCases.count)

        tuples.forEach { type, document in
            XCTAssertEqual(
                Parser.parseListItems(doc: document).count,
                type.assertCount, type.rawValue
            )
        }
    }
}

// MARK: Gallery
class GalleryParserTests: XCTestCase, TestHelper {
    func testExample() {
        let (detail, state) = try! Parser.parseGalleryDetail(
            doc: getHTML(resourceName: "GalleryDetail")!, gid: "1990291"
        )
        XCTAssertEqual(detail.gid, "1990291")
        XCTAssertEqual(detail.title, "[Hiroya] Shirotaegiku | Dusty miller (COMIC ExE 32) [English] [INSURRECTION] [Digital]")
        XCTAssertEqual(detail.jpnTitle, "[広弥] 白妙菊 (コミック エグゼ 32) [英訳] [DL版]")
        XCTAssertFalse(detail.isFavored)
        XCTAssertEqual(detail.visibility, .yes)
        XCTAssertEqual(detail.rating, 5)
        XCTAssertEqual(detail.userRating, 0)
        XCTAssertEqual(detail.ratingCount, 38)
        XCTAssertEqual(detail.category, .manga)
        XCTAssertEqual(detail.language, .english)
        XCTAssertEqual(detail.uploader, "Gekkou98")
        XCTAssertEqual(detail.coverURL, "https://ehgt.org/t/d3/6b/d36b5a7a97f074fc7cbda7182884b71ae1143d57-883501-1416-2000-png_250.jpg")
        XCTAssertEqual(detail.archiveURL, "https://e-hentai.org/archiver.php?gid=1990291&token=neVEr&or=goNNA--leTYoUdown")
        XCTAssertNil(detail.parentURL)
        XCTAssertEqual(detail.favoredCount, 237)
        XCTAssertEqual(detail.pageCount, 35)
        XCTAssertEqual(detail.sizeCount, 44.8)
        XCTAssertEqual(detail.sizeType, "MB")
        XCTAssertEqual(detail.torrentCount, 1)
        XCTAssertEqual(state.tags.count, 4)
        XCTAssertEqual(state.previews.count, 20)
        XCTAssertEqual(state.previewConfig, .large(rows: 4))
        XCTAssertEqual(state.comments.count, 4)
    }
}

// MARK: Greeting
class GreetingParserTests: XCTestCase, TestHelper {
    func testExample() {
        let greeting = try! Parser.parseGreeting(
            doc: getHTML(resourceName: "GalleryDetailWithGreeting")!
        )
        XCTAssertEqual(greeting.gainedEXP, 30)
        XCTAssertEqual(greeting.gainedCredits, 9)
        XCTAssertNil(greeting.gainedGP)
        XCTAssertNil(greeting.gainedHath)
        XCTAssertNotNil(greeting.updateTime)
        XCTAssertFalse(greeting.gainedNothing)
        XCTAssertNotNil(greeting.gainContent)
    }
}
