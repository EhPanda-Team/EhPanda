//
//  GalleryMPVKeysParserTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/02/11.
//

import Kanna
import XCTest
@testable import EhPanda

class GalleryMPVKeysParserTests: XCTestCase, TestHelper {
    func testExample() throws {
        let document = try htmlDocument(filename: .galleryMPVKeys)
        let (mpvKey, mpvImageKeys) = try Parser.parseMPVKeys(doc: document)
        XCTAssertEqual(mpvKey, "00000000000")
        XCTAssertEqual(mpvImageKeys.count, 194)
    }
}
