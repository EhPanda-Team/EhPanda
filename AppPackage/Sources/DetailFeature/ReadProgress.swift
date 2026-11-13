import Foundation

/// How far through a gallery the reader will resume, as the Read button shows it.
enum ReadProgress {
    /// The resume page over the page count, from 0 to 1, or `nil` when there is nothing to draw: no saved page (the
    /// button stays as it was) or a page count that is not known yet (it cannot be divided by). A page past the count
    /// is a full ring.
    static func fraction(page: Int, pageCount: Int) -> Double? {
        guard page > 0, pageCount > 0 else { return nil }
        return min(Double(page) / Double(pageCount), 1)
    }

    /// What VoiceOver says after "Read": the resume page and the total, or the page alone when the total is not known;
    /// nothing for a gallery that was never read.
    static func accessibilityValue(page: Int, pageCount: Int) -> String {
        guard page > 0 else { return String() }
        guard pageCount > 0 else { return String(localized: .accessibilityPreviewPage(page: page)) }
        return String(localized: .accessibilityReadProgress(current: page, total: pageCount))
    }
}
