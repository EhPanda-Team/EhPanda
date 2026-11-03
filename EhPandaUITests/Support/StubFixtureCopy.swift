import Foundation
import XCTest

/// A writable copy of the bundled stub fixtures, for a test that changes one of them.
///
/// A list page loads its rows from HTML and then their titles from the `gdata` API, whose saved
/// response names the same galleries. A retitle changes both, as the site's list and API agree.
struct StubFixtureCopy {
    let root: URL

    /// Copies every bundled fixture into a new directory that `testCase` removes at teardown.
    @MainActor
    init(for testCase: XCTestCase, named name: String) throws {
        root = FileManager.default.temporaryDirectory.appending(path: "\(name)-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let root = root
        testCase.addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let source = try XCTUnwrap(Bundle(for: StubFixtureCopyBundleToken.self).resourceURL)
        for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        where ["html", "json", "png"].contains(file.pathExtension) {
            try FileManager.default.copyItem(at: file, to: root.appending(path: file.lastPathComponent))
        }
    }

    /// Gives each gallery of the list fixture `listName` the title `title(index, current)` returns,
    /// in list order, or keeps it on `nil`. Titles are written as the site writes them, already
    /// HTML-escaped. Returns how many galleries the list has.
    @discardableResult
    func retitle(listNamed listName: String, _ title: (_ index: Int, _ current: String) -> String?) throws -> Int {
        let list = root.appending(path: listName)
        var html = try String(contentsOf: list, encoding: .utf8)
        let row = try NSRegularExpression(pattern: #"/g/([0-9]+)/[^/"]+/"><div class="glink">([^<]+)</div>"#)
        let matches = row.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var titles = [Int: String]()
        for (index, match) in matches.enumerated().reversed() {
            let gid = try XCTUnwrap(Range(match.range(at: 1), in: html).flatMap({ Int(html[$0]) }))
            let range = try XCTUnwrap(Range(match.range(at: 2), in: html))
            guard let replacement = title(index, String(html[range])) else { continue }
            html.replaceSubrange(range, with: replacement)
            titles[gid] = replacement
        }
        XCTAssertEqual(
            matches.count, html.components(separatedBy: #"<div class="glink">"#).count - 1,
            "Every \(listName) title must belong to a gallery link."
        )
        try html.write(to: list, atomically: true, encoding: .utf8)

        let metadata = root.appending(path: "GalleryMetadata.json")
        var response = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: metadata)) as? [String: Any]
        )
        let entries = try XCTUnwrap(response["gmetadata"] as? [[String: Any]]).map { entry in
            guard let gid = entry["gid"] as? Int, let title = titles.removeValue(forKey: gid) else { return entry }
            return entry.merging(["title": title], uniquingKeysWith: { _, new in new })
        }
        XCTAssertEqual(titles, [:], "The saved metadata must name every retitled gallery.")
        response["gmetadata"] = entries
        try JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]).write(to: metadata)
        return matches.count
    }
}

private final class StubFixtureCopyBundleToken {}
