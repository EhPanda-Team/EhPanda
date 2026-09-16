import Accessibility
import AppModels
import Foundation

extension GalleryComment {
    /// Marks only a Latin AM/PM token for spelling while preserving the visible date string.
    var accessibilityAttributedDateString: AttributedString {
        let locale = Locale.current
        let calendar = Calendar.current
        let timeZone = calendar.timeZone
        var result = AttributedString(formattedDateString)
        let style = Date.FormatStyle(
            date: .numeric,
            time: .shortened,
            locale: locale,
            calendar: calendar,
            timeZone: timeZone
        ).attributedStyle
        let semantic = style.format(originalDate)
        guard let run = semantic.runs.first(where: {
            $0.attributes.foundation.dateField == .amPM
        }) else { return result }
        let token = String(semantic[run.range].characters)
        guard ["AM", "PM"].contains(token.uppercased()), let range = result.range(of: token) else {
            return result
        }
        result[range].accessibilitySpeechSpellsOutCharacters = true
        return result
    }
}
