//
//  Extensions.swift
//  EhPandaTests
//

import XCTest

extension XCTWaiter {
    static func wait(timeout: TimeInterval) {
        _ = Self.wait(for: [.init()], timeout: timeout)
    }
}
