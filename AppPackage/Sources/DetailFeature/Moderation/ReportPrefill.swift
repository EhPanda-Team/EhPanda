import AppModels
import Foundation

/// The block a comment report's Details starts with (18.1 D-07): which comment the report is about, because the site's
/// report covers the whole gallery.
///
/// It is English in every app language, since the site's staff read it (Camo msg 1938), and the wording is the
/// approved copy's, so it is not a catalog key.
enum ReportPrefill {
    /// `Reporting a comment by {name} ({date}):\n"{comment text}"\n\n`, with `{date}` as `yyyy-MM-dd HH:mm 'UTC'`
    /// whatever the device's time zone, calendar and locale (DD-04). The comment text is trimmed of the blank space
    /// around it, so the quotes sit on the text.
    static func text(author: String, date: Date, comment: String) -> String {
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Reporting a comment by \(author) (\(format(date))):\n\"\(text)\"\n\n"
    }

    /// The comment's text as it shows: each text, link or URL run on its own line, images left out.
    static func commentText(of comment: GalleryComment) -> String {
        comment.contents
            .compactMap { content in
                switch content.type {
                case .plainText, .linkedText:
                    content.text.map({ String($0.characters) })
                case .singleLink:
                    content.link?.absoluteString
                case .singleImg, .doubleImg, .linkedImg, .doubleLinkedImg:
                    nil
                }
            }
            .joined(separator: "\n")
    }

    private static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        return formatter.string(from: date)
    }
}
