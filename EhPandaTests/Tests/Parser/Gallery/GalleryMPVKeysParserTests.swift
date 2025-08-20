//
//  GalleryMPVKeysParserTests.swift
//  EhPandaTests
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
