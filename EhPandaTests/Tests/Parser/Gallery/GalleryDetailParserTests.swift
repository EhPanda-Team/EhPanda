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
        let (detail, state) = try Parser.parseGalleryDetail(doc: document, gid: "2668586")
        XCTAssertEqual(detail.gid, "2668586")
        XCTAssertEqual(detail.title, "◆FANBOX◆ AI Fetish [87052610＆ai-fetish] [AI Generated]")
        XCTAssertEqual(detail.jpnTitle, nil)
        XCTAssertFalse(detail.isFavorited)
        XCTAssertEqual(detail.visibility, .yes)
        XCTAssertEqual(detail.rating, 0.5)
        XCTAssertEqual(detail.userRating, 0)
        XCTAssertEqual(detail.ratingCount, 6)
        XCTAssertEqual(detail.category, .misc)
        XCTAssertEqual(detail.language, .japanese)
        XCTAssertEqual(detail.uploader, "KEYLUN")
        XCTAssertEqual(detail.coverURL?.absoluteString, "https://ehgt.org/9d/71/9d71dd93bbf5cae13e9b5f9a1086b41600c9ce7e-6430614-2048-3072-png_250.jpg")
        XCTAssertEqual(detail.archiveURL?.absoluteString, "https://e-hentai.org/archiver.php?gid=0000000&token=0000000000&or=470592--63bbddc729b849100ec24ab920ffdb84b6542b23")
        XCTAssertNil(detail.parentURL)
        XCTAssertEqual(detail.favoritedCount, 6)
        XCTAssertEqual(detail.pageCount, 194)
        XCTAssertEqual(detail.sizeCount, 684.9)
        XCTAssertEqual(detail.sizeType, "MiB")
        XCTAssertEqual(detail.torrentCount, 1)
        XCTAssertEqual(state.tags.count, 1)
        XCTAssertEqual(state.previewURLs.count, 20)
        XCTAssertEqual(state.previewConfig, .large(rows: 4))
        XCTAssertEqual(state.comments.count, 1)
    }
}
