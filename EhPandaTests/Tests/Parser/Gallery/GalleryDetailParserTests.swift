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
        let (detail, state) = try Parser.parseGalleryDetail(doc: document, gid: "2725078")
        XCTAssertEqual(detail.gid, "2725078")
        XCTAssertEqual(detail.title, "[Artist] mks")
        XCTAssertEqual(detail.jpnTitle, "[アーティスト] mks")
        XCTAssertFalse(detail.isFavorited)
        XCTAssertEqual(detail.visibility, .yes)
        XCTAssertEqual(detail.rating, 4.5)
        XCTAssertEqual(detail.userRating, 0)
        XCTAssertEqual(detail.ratingCount, 108)
        XCTAssertEqual(detail.category, .nonH)
        XCTAssertEqual(detail.language, .japanese)
        XCTAssertEqual(detail.uploader, "Pokom")
        XCTAssertEqual(detail.coverURL?.absoluteString, "https://ehgt.org/03/08/0308268821e99628b05a19fa54e2fc0fa9ad8f4b-1705560-1012-1470-png_250.jpg")
        XCTAssertEqual(detail.archiveURL?.absoluteString, "https://e-hentai.org/archiver.php?gid=3103480&token=0000000000&or=480566--44111f81616a100ccab3d9be8ac8b5adedb5d44e")
        XCTAssertEqual(detail.parentURL?.absoluteString, "https://e-hentai.org/g/2930572/daf4b9880d/")
        XCTAssertEqual(detail.favoritedCount, 587)
        XCTAssertEqual(detail.pageCount, 156)
        XCTAssertEqual(detail.sizeCount, 314.3)
        XCTAssertEqual(detail.sizeType, "MiB")
        XCTAssertEqual(detail.torrentCount, 1)
        XCTAssertEqual(state.tags.count, 1)
        XCTAssertEqual(state.previewURLs.count, 40)
        XCTAssertEqual(state.previewConfig, .normal(rows: 4))
        XCTAssertEqual(state.comments.count, 10)
    }
}
