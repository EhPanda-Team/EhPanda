import Foundation
import XCTest

extension StubFixtureCopy {
    /// Keeps the saved gallery page's content but not the people or the pictures of the site it was saved from: the
    /// uploader and the commenters are named Reader 1, 2 and so on, the uploader's own comment (links to other
    /// sites) is a thank-you line, the commenters' profile links point nowhere, and each preview is a numbered page
    /// the stub serves itself in place of the site's sprite sheet, so a captured frame shows which page is where.
    func neutralizeDetail(named name: String = "GalleryDetail.html") throws {
        let page = root.appending(path: name)
        var html = try String(contentsOf: page, encoding: .utf8)

        let people = try NSRegularExpression(pattern: #"/uploader/([^"]+)">([^<]+)</a>"#)
        let found = people.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var readers = [String: Int]()
        for match in found {
            let person = String(html[try XCTUnwrap(Range(match.range(at: 2), in: html))])
            if readers[person] == nil { readers[person] = readers.count + 1 }
        }
        for match in found.reversed() {
            let person = String(html[try XCTUnwrap(Range(match.range(at: 2), in: html))])
            let number = try XCTUnwrap(readers[person])
            html.replaceSubrange(
                try XCTUnwrap(Range(match.range, in: html)),
                with: "/uploader/Reader\(number)\">Reader \(number)</a>"
            )
        }
        html = try Self.replacing(#"showuser=[0-9]+"#, in: html, with: "showuser=0")
        let links = #"https://www\.pixiv\.net/users/[0-9]+<br /><br />https://mks\.booth\.pm/<br />"#
            + #"https://twitter\.com/mks_fStD"#
        html = try Self.replacing(links, in: html, with: "Thank you for reading.")

        let previews = try NSRegularExpression(
            pattern: #"<div title="(Page ([0-9]+): [^"]*)" style="[^"]*"></div>"#
        )
        for match in previews.matches(in: html, range: NSRange(html.startIndex..., in: html)).reversed() {
            let title = html[try XCTUnwrap(Range(match.range(at: 1), in: html))]
            let number = html[try XCTUnwrap(Range(match.range(at: 2), in: html))]
            let source = "https://fixtures.ehpanda.invalid/page/\(number).png"
            html.replaceSubrange(
                try XCTUnwrap(Range(match.range, in: html)),
                with: #"<div title="\#(title)" style="background:transparent url(\#(source)) no-repeat"></div>"#
            )
        }
        try html.write(to: page, atomically: true, encoding: .utf8)
    }

    /// Gives every gallery of the saved metadata and of the saved front page the uploader Reader, so a card or a
    /// detail header that shows the uploader names no one.
    func neutralizeUploaders() throws {
        let list = root.appending(path: "FrontPageList.html")
        let html = try String(contentsOf: list, encoding: .utf8)
        let named = try Self.replacing(#"/uploader/[^"]+">[^<]+</a>"#, in: html, with: #"/uploader/Reader">Reader</a>"#)
        try named.write(to: list, atomically: true, encoding: .utf8)
        let metadata = root.appending(path: "GalleryMetadata.json")
        var response = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: metadata)) as? [String: Any]
        )
        let entries = try XCTUnwrap(response["gmetadata"] as? [[String: Any]]).map { entry in
            guard entry["uploader"] != nil else { return entry }
            return entry.merging(["uploader": "Reader"], uniquingKeysWith: { _, new in new })
        }
        response["gmetadata"] = entries
        try JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]).write(to: metadata)
    }

    private static func replacing(_ pattern: String, in text: String, with replacement: String) throws -> String {
        try NSRegularExpression(pattern: pattern).stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text),
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
    }
}
