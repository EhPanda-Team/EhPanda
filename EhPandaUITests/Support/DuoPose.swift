import XCTest

/// The Duo simulator's inner display does not follow XCTest's device-orientation setter.
/// An opted-in host driver applies each request with the pose CLI and acknowledges completion.
@MainActor
enum DuoPose {
    enum Orientation: String {
        case portrait
        case landscape = "landscape-left"
    }

    static func set(_ orientation: Orientation) throws {
        let path = try XCTUnwrap(
            ProcessInfo.processInfo.environment["EHPANDA_DUO_POSE_DIRECTORY"],
            "Duo rotation tests require the host pose driver."
        )
        let directory = URL(filePath: path, directoryHint: .isDirectory)
        let identifier = UUID().uuidString
        let request = Data("\(identifier)\n\(orientation.rawValue)".utf8)
        try request.write(to: directory.appending(path: "request"), options: .atomic)
        let acknowledgement = directory.appending(path: "acknowledgement")
        let applied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.contents(atPath: acknowledgement.path(percentEncoded: false)) == Data(identifier.utf8)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [applied], timeout: 15), .completed, "Host did not apply the requested pose")
    }
}
