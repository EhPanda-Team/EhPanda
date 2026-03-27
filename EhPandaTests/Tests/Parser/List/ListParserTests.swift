//
//  ListParserTests.swift
//  EhPandaTests
//

import Kanna
import Testing
@testable import EhPanda

struct ListParserTests: TestHelper {
    @Test
    func testExample() throws {
        let tuples: [(ListParserTestType, HTMLDocument)] = try ListParserTestType.allCases.compactMap { type in
            (type, try htmlDocument(filename: type.filename))
        }
        #expect(tuples.count == ListParserTestType.allCases.count)

        try tuples.forEach { type, document in
            let galleries = try Parser.parseGalleries(doc: document)
            let uploaders = galleries.compactMap(\.uploader).filter(\.notEmpty)
            #expect(galleries.count == type.assertCount, "\(type)")
            if type.hasUploader {
                #expect(uploaders.count == type.assertCount, "\(type)")
            }
        }
    }
}
