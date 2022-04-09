//
//  Extensions.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/03/26.
//

import XCTest

extension XCTWaiter {
    static func wait(timeout: TimeInterval) {
        _ = Self.wait(for: [.init()], timeout: timeout)
    }
}
