import Foundation
import Resources

/// A file size as the site gives it, a number and a binary unit, such as "26.2 MiB".
///
/// The site writes every size the same way, with an English decimal point, whatever the reader's language. The
/// gallery's own size (the Detail strip and Gallery Info) and the sizes of its torrents and archives, which arrive as
/// text, all go through this type, so each shows its number in the reader's number format.
struct SiteFileSize: Equatable, Sendable {
    let count: Float
    let unit: String

    init(count: Float, unit: String) {
        self.count = count
        self.unit = unit
    }

    /// Reads a size from the site's text: digits with an optional decimal point and decimals, one space and `KiB`,
    /// `MiB` or `GiB`, the units the app's parsers know. Anything else, such as "N/A", a size in another unit or one
    /// that is already in the reader's format, is not a site size and gives `nil`; its view shows the text unchanged.
    init?(siteText: String) {
        guard let match = siteText.wholeMatch(of: #/([0-9]+(?:\.[0-9]+)?) (KiB|MiB|GiB)/#),
              let count = Float(match.1)
        else { return nil }
        self.init(count: count, unit: String(match.2))
    }

    /// The number to at most the two decimals the site gives, in the reader's number format, without grouping.
    /// The unit stays with each caller, because the Detail strip sets it on a line of its own.
    func formattedCount(locale: Locale) -> String {
        count.formatted(.number.locale(locale).precision(.fractionLength(0...2)).grouping(.never))
    }

    /// The number in the reader's format, a space and the unit.
    func formatted(locale: Locale) -> String {
        formattedCount(locale: locale) + " " + unit
    }

    /// What VoiceOver reads for the whole size: the count in the reader's format, a space and the unit's word, so
    /// "26.2 MiB" is read as "26,2 mebibytes" rather than with the letters of the abbreviation. `nil` when the unit
    /// has no spoken form, in which case the caller falls back to the text it shows.
    func spoken(locale: Locale) -> String? {
        spokenUnit().map({ formattedCount(locale: locale) + " " + $0 })
    }

    /// The localized binary unit for VoiceOver, or `nil` for a unit the catalog does not know. The count only selects
    /// the plural form; each catalog variant contains the unit word alone, so VoiceOver does not repeat the number.
    func spokenUnit() -> String? {
        switch unit {
        case "KiB": String(localized: .accessibilitySizeKibibyte(quantity: count))
        case "MiB": String(localized: .accessibilitySizeMebibyte(quantity: count))
        case "GiB": String(localized: .accessibilitySizeGibibyte(quantity: count))
        default: nil
        }
    }
}
