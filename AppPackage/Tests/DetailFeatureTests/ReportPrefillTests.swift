@testable import DetailFeature
import Foundation
import Testing

/// The comment prefill (18.1 D-07, DD-04): English, the approved wording, and a UTC date whatever the device uses.
struct ReportPrefillTests {
    static let date = Date(timeIntervalSince1970: 1_793_883_840) // 2026-11-05 13:04:00 UTC

    @Test
    func thePrefillIsTheApprovedBlockWithAUTCDate() {
        let text = ReportPrefill.text(author: "Alice", date: Self.date, comment: "First line\nsecond line")

        #expect(text == "Reporting a comment by Alice (2026-11-05 13:04 UTC):\n\"First line\nsecond line\"\n\n")
    }

    // The date ignores the device's time zone, locale and calendar: the formatter fixes all three. Just before and
    // after midnight UTC, any device zone but UTC would show another day or hour. (The device's zone is not changed
    // here: it is process-wide and other suites run in parallel.)
    @Test(arguments: [
        (1_793_921_340, "2026-11-05 23:29 UTC"),
        (1_793_923_260, "2026-11-06 00:01 UTC")
    ])
    func theDateIsUTCWhateverTheDeviceZone(seconds: Int, expected: String) {
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))

        let text = ReportPrefill.text(author: "Alice", date: date, comment: "x")

        #expect(text == "Reporting a comment by Alice (\(expected)):\n\"x\"\n\n")
    }

    // The blank space around the comment's text goes, so the quotes sit on the text; inner line breaks stay.
    @Test
    func theCommentTextIsTrimmed() {
        let text = ReportPrefill.text(author: "Bob", date: Self.date, comment: "\n  spam\nlink  \n")

        #expect(text == "Reporting a comment by Bob (2026-11-05 13:04 UTC):\n\"spam\nlink\"\n\n")
    }
}
