//
//  GalleryImageURLParserTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/02/11.
//

import Kanna
import XCTest
@testable import EhPanda

class GalleryImageURLParserTests: XCTestCase, TestHelper {
    func testExample() throws {
        let document = try htmlDocument(filename: .galleryNormalImageURL)
        try testGalleryNormalImageURLParser(doc: document)
        try testSkipServerIdentifierParser(doc: document)
    }

    func testGalleryNormalImageURLParser(doc: HTMLDocument) throws {
        let inputIndex = 1
        let (index, imageURL, originalImageURL) = try Parser.parseGalleryNormalImageURL(doc: doc, index: inputIndex)
        XCTAssertEqual(index, inputIndex)
        XCTAssertEqual(imageURL.absoluteString, "https://akrtazd.spuqplybaxmf.hath.network:65000/h/ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-1280-1920-jpg/keystamp=1694132700-fd778f8260;fileindex=132044713;xres=1280/87052610_5090394_0.jpg")
        XCTAssertEqual(originalImageURL?.absoluteString, "https://e-hentai.org/fullimg.php?gid=0000000&page=1&key=000000000")
    }
    func testSkipServerIdentifierParser(doc: HTMLDocument) throws {
        let identifier = try Parser.parseSkipServerIdentifier(doc: doc)
        XCTAssertEqual(identifier, "00000-000000")
    }
}

