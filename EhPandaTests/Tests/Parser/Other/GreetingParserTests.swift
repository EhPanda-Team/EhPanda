//
//  GreetingParserTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/02/11.
//

import Kanna
import XCTest
@testable import EhPanda

class GreetingParserTests: XCTestCase, TestHelper {
    func testExample() throws {
        let document = try htmlDocument(filename: .galleryDetailWithGreeting)
        let greeting = try Parser.parseGreeting(doc: document)
        XCTAssertEqual(greeting.gainedEXP, 30)
        XCTAssertEqual(greeting.gainedCredits, 329)
        XCTAssertNil(greeting.gainedGP)
        XCTAssertNil(greeting.gainedHath)
        XCTAssertNotNil(greeting.updateTime)
        XCTAssertFalse(greeting.gainedNothing)
        XCTAssertNotNil(greeting.gainContent)
    }
}
