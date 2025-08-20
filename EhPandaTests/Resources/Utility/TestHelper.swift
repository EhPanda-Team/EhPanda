//
//  TestHelper.swift
//  TestHelper
//

import Kanna
import XCTest

protocol TestHelper {}

extension TestHelper where Self: XCTestCase {
    func htmlDocument(filename: HTMLFilename) throws -> HTMLDocument {
        guard let url = Bundle(for: Self.self).url(forResource: filename.rawValue, withExtension: "html") else {
            throw TestError.htmlDocumentNotFound(filename)
        }
        return try Kanna.HTML(url: url, encoding: .utf8)
    }
}
