import Foundation
import XCTest

extension XCTestCase {
    /// A fresh plain-named app-storage suite whose persistent domain is removed when the case tears down: the XCTest
    /// counterpart of TestingSupport's `.isolatedAppStorage` trait, which this target cannot link. Not
    /// `UserDefaults.inMemory`, whose suite is file-backed and goes stale under parallel load. Each call gives a suite
    /// of its own, so a capture loop keeps one per coordinate.
    func makeIsolatedAppStorage() throws -> UserDefaults {
        let suiteName = "isolated-app-storage-\(UUID().uuidString)"
        let appStorage = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        return appStorage
    }
}
