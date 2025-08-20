//
//  BanIntervalParserTests.swift
//  EhPandaTests
//

import Kanna
import XCTest
@testable import EhPanda

class BanIntervalParserTests: XCTestCase, TestHelper {
    func testExample() throws {
        let document = try htmlDocument(filename: .ipBanned)
        let banInterval = Parser.parseBanInterval(doc: document)
        XCTAssertEqual(banInterval, .minutes(59, seconds: 48))
    }
}
