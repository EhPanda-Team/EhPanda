//
//  ListParserTests.swift
//  EhPandaTests
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

    func testPageJumpNavigation() throws {
        let document = try htmlDocument(filename: .frontPageMinimalList)
        let pageNumber = Parser.parsePageNum(doc: document)
        let navigation = try XCTUnwrap(pageNumber.jumpNavigation)

        XCTAssertTrue(pageNumber.hasNextPage())
        XCTAssertEqual(pageNumber.lastItemTimestamp, "2668517")
        XCTAssertNil(navigation.previousURL)
        XCTAssertEqual(navigation.nextURL?.absoluteString, "https://e-hentai.org/?next=2668517")
        XCTAssertEqual(Self.dateFormatter.string(from: try XCTUnwrap(navigation.minimumDate)), "2007-03-20")
        XCTAssertEqual(Self.dateFormatter.string(from: try XCTUnwrap(navigation.maximumDate)), "2023-09-08")
    }

    func testPageJumpSeekURL() throws {
        let document = try htmlDocument(filename: .frontPageMinimalList)
        let pageNumber = Parser.parsePageNum(doc: document)
        let navigation = try XCTUnwrap(pageNumber.jumpNavigation)
        let maximumDate = try XCTUnwrap(navigation.maximumDate)
        let url = try XCTUnwrap(navigation.seekURL(date: maximumDate, direction: .older))
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems

        XCTAssertEqual(queryItems?.first(where: { $0.name == "next" })?.value, "2668517")
        XCTAssertEqual(queryItems?.first(where: { $0.name == "seek" })?.value, "2023-09-08")
        XCTAssertNil(navigation.seekURL(date: maximumDate, direction: .newer))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
