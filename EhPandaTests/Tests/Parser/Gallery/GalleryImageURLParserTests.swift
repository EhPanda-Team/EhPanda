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
        XCTAssertEqual(imageURL.absoluteString, "https://wqyqeng.mqwmzmzefnoz.hath.network:30001/h/a25994ccb4606902e21e5a9328784bb78d419466-369972-1280-1815-jpg/keystamp=1644575400-5f4af872e1;fileindex=77053242;xres=1280/001.jpg")
        XCTAssertEqual(originalImageURL?.absoluteString, "https://e-hentai.org/fullimg.php?gid=1563022&page=1&key=mjpgxpz9shm")
    }
    func testSkipServerIdentifierParser(doc: HTMLDocument) throws {
        let identifier = try Parser.parseSkipServerIdentifier(doc: doc)
        XCTAssertEqual(identifier, "30703-456826")
    }
}
