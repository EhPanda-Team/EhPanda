//
//  ListParserTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/02/11.
//

import Kanna
import XCTest
@testable import EhPanda

class ListParserTests: XCTestCase, TestHelper {
    func testExample() throws {
        let tuples: [(ListParserTestType, HTMLDocument)] = try ListParserTestType.allCases.compactMap { type in
            (type, try htmlDocument(filename: type.filename))
        }
        XCTAssertEqual(tuples.count, ListParserTestType.allCases.count)

        try tuples.forEach { type, document in
            let galleries = try Parser.parseGalleries(doc: document)
            let uploaders = galleries.compactMap(\.uploader).filter(\.notEmpty)
            XCTAssertEqual(galleries.count, type.assertCount, .init(describing: type))
            if type.hasUploader {
                XCTAssertEqual(uploaders.count, type.assertCount, .init(describing: type))
            }
        }
    }
}
