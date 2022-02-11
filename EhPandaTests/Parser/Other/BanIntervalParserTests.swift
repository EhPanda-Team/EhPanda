//
//  BanIntervalParserTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/02/11.
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
