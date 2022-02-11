//
//  GalleryDetailParserTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/02/11.
//

import Kanna
import XCTest
@testable import EhPanda

class GalleryDetailParserTests: XCTestCase, TestHelper {
    func testExample() throws {
        let document = try htmlDocument(filename: .galleryDetail)
        let (detail, state) = try Parser.parseGalleryDetail(doc: document, gid: "1990291")
        XCTAssertEqual(detail.gid, "1990291")
        XCTAssertEqual(detail.title, "[Hiroya] Shirotaegiku | Dusty miller (COMIC ExE 32) [English] [INSURRECTION] [Digital]")
        XCTAssertEqual(detail.jpnTitle, "[広弥] 白妙菊 (コミック エグゼ 32) [英訳] [DL版]")
        XCTAssertFalse(detail.isFavorited)
        XCTAssertEqual(detail.visibility, .yes)
        XCTAssertEqual(detail.rating, 5)
        XCTAssertEqual(detail.userRating, 0)
        XCTAssertEqual(detail.ratingCount, 38)
        XCTAssertEqual(detail.category, .manga)
        XCTAssertEqual(detail.language, .english)
        XCTAssertEqual(detail.uploader, "Gekkou98")
        XCTAssertEqual(detail.coverURL?.absoluteString, "https://ehgt.org/t/d3/6b/d36b5a7a97f074fc7cbda7182884b71ae1143d57-883501-1416-2000-png_250.jpg")
        XCTAssertEqual(detail.archiveURL?.absoluteString, "https://e-hentai.org/archiver.php?gid=1990291&token=neVEr&or=goNNA--leTYoUdown")
        XCTAssertNil(detail.parentURL)
        XCTAssertEqual(detail.favoritedCount, 237)
        XCTAssertEqual(detail.pageCount, 35)
        XCTAssertEqual(detail.sizeCount, 44.8)
        XCTAssertEqual(detail.sizeType, "MB")
        XCTAssertEqual(detail.torrentCount, 1)
        XCTAssertEqual(state.tags.count, 4)
        XCTAssertEqual(state.previewURLs.count, 20)
        XCTAssertEqual(state.previewConfig, .large(rows: 4))
        XCTAssertEqual(state.comments.count, 4)
    }
}
