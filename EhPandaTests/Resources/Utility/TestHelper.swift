//
//  TestHelper.swift
//  TestHelper
//
//  Created by 荒木辰造 on R 3/08/21.
//

import XCTest
import Foundation
@testable import Kanna

protocol TestHelper {}

extension TestHelper where Self: XCTestCase {
    func getHTML(resourceName: String) -> HTMLDocument? {
        guard let url = Bundle(for: Self.self).url(
            forResource: resourceName,
            withExtension: "html"
        ),
              let html = try? Kanna.HTML(
                url: url, encoding: .utf8
              )
        else { return nil }

        return html
    }
}
