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
        XCTAssertEqual(detail.title, "●PIXIV● HYYT [67227995]")
        XCTAssertEqual(detail.jpnTitle, nil)
        XCTAssertFalse(detail.isFavorited)
        XCTAssertEqual(detail.visibility, .yes)
        XCTAssertEqual(detail.rating, 4.5)
        XCTAssertEqual(detail.userRating, 0)
        XCTAssertEqual(detail.ratingCount, 569)
        XCTAssertEqual(detail.category, .imageSet)
        XCTAssertEqual(detail.language, .japanese)
        XCTAssertEqual(detail.uploader, "KEYLUN")
        XCTAssertEqual(detail.coverURL?.absoluteString, "https://ehgt.org/5e/b5/5eb550886fe58da8c780d9ab9182717ae9bcda91-604248-2235-3016-jpg_250.jpg")
        XCTAssertEqual(detail.archiveURL?.absoluteString, "https://e-hentai.org/archiver.php?gid=0000000&token=0000000000&or=471924--76094077f7be1ee86673ef75c45e0d382961dc9c")
        XCTAssertEqual(detail.parentURL?.absoluteString, "https://e-hentai.org/g/2624293/78cf5e78a5/")
        XCTAssertEqual(detail.favoritedCount, 9218)
        XCTAssertEqual(detail.pageCount, 612)
        XCTAssertEqual(detail.sizeCount, 657.6)
        XCTAssertEqual(detail.sizeType, "MiB")
        XCTAssertEqual(detail.torrentCount, 5)
        XCTAssertEqual(state.tags.count, 4)
        XCTAssertEqual(state.previewURLs.count, 40)
        XCTAssertEqual(state.previewConfig, .normal(rows: 4))
        XCTAssertEqual(state.comments.count, 49)
    }
}
