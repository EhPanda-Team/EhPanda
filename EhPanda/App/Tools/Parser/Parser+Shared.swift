import Kanna
import Foundation

extension Parser {
    static func parseGTX00IndexFromTitle(from title: String) -> Int? {
        // The probable format of page title is "Page [Number]: filename"
        (
            title
                .components(separatedBy: ":")
                .first?
                .replacingOccurrences(of: "Page ", with: "")
                .trimmingCharacters(in: .whitespaces)
        )
        .flatMap(Int.init)
    }

    static func parseDate(time: String, format: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = formatter.date(from: time)
        else { throw AppError.parseFailed }

        return date
    }

    static func parseScriptVariable(name: String, doc: HTMLDocument) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"var\s+\#(escapedName)\s*=\s*["']([^"']*)["']\s*;"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        for script in doc.xpath("//script") {
            guard let text = script.text else { continue }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  let valueRange = Range(match.range(at: 1), in: text)
            else { continue }

            return String(text[valueRange])
        }
        return nil
    }

    static func parseScriptURL(name: String, doc: HTMLDocument) -> URL? {
        guard var value = parseScriptVariable(name: name, doc: doc)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else { return nil }
        value = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "\\u0026", with: "&")

        let baseURL = Defaults.URL.host
        let parsedURL: URL?
        if let url = URL(string: value), url.scheme != nil {
            parsedURL = url
        } else {
            parsedURL = URL(string: value, relativeTo: baseURL)?.absoluteURL
        }

        guard let parsedURL else { return nil }
        guard var components = URLComponents(url: parsedURL, resolvingAgainstBaseURL: false) else {
            return parsedURL
        }

        let knownGalleryHosts = [
            Defaults.URL.ehentai.host,
            Defaults.URL.exhentai.host,
            Defaults.URL.sexhentai.host
        ]
        .compactMap { $0?.lowercased() }

        if let host = components.host?.lowercased(),
           knownGalleryHosts.contains(host),
           let baseComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        {
            components.scheme = baseComponents.scheme
            components.host = baseComponents.host
        }
        return components.url
    }

    static func parseScriptDate(name: String, doc: HTMLDocument) -> Date? {
        guard let value = parseScriptVariable(name: name, doc: doc), !value.isEmpty else { return nil }
        return try? parseDate(time: value, format: "yyyy-MM-dd")
    }

    static func parsePageJumpNavigation(doc: HTMLDocument) -> PageJumpNavigation? {
        let navigation = PageJumpNavigation(
            previousURL: parseScriptURL(name: "prevurl", doc: doc),
            nextURL: parseScriptURL(name: "nexturl", doc: doc),
            minimumDate: parseScriptDate(name: "mindate", doc: doc),
            maximumDate: parseScriptDate(name: "maxdate", doc: doc)
        )
        return navigation.isEnabled ? navigation : nil
    }

    // swiftlint:disable cyclomatic_complexity
    /// Returns ratings parsed from stars image / text and if the return contains a userRating .
    static func parseRating(node: XMLElement) throws -> RatingResult {
        func parseTextRating(node: XMLElement) throws -> Float {
            guard let ratingString = node
              .at_xpath("//td [@id='rating_label']")?.text?
              .replacingOccurrences(of: "Average: ", with: "")
              .replacingOccurrences(of: "Not Yet Rated", with: "0"),
                  let rating = Float(ratingString)
            else { throw AppError.parseFailed }

            return rating
        }

        var tmpRatingString: String?
        var containsUserRating = false

        for link in node.xpath("//div") where
            link.className?.contains("ir") == true
            && link["style"]?.isEmpty == false {
            if tmpRatingString != nil { break }
            tmpRatingString = link["style"]
            containsUserRating = link.className != "ir"
        }

        guard let ratingString = tmpRatingString
        else { throw AppError.parseFailed }

        var tmpRating: Float?
        if ratingString.contains("0px") { tmpRating = 5.0 }
        if ratingString.contains("-16px") { tmpRating = 4.0 }
        if ratingString.contains("-32px") { tmpRating = 3.0 }
        if ratingString.contains("-48px") { tmpRating = 2.0 }
        if ratingString.contains("-64px") { tmpRating = 1.0 }
        if ratingString.contains("-80px") { tmpRating = 0.0 }

        guard var rating = tmpRating
        else { throw AppError.parseFailed }

        if ratingString.contains("-21px") { rating -= 0.5 }
        return RatingResult(
            imgRating: rating,
            textRating: try? parseTextRating(node: node),
            containsUserRating: containsUserRating
        )
    }
    // swiftlint:enable cyclomatic_complexity

    static func parseBanInterval(doc: HTMLDocument) -> BanInterval? {
        guard let text = doc.body?.text, let range = text.range(of: "The ban expires in ")
        else { return nil }

        let expireDescription = String(text[range.upperBound...])

        if let daysRange = expireDescription.range(of: "days"),
           let days = Int(expireDescription[..<daysRange.lowerBound]
            .trimmingCharacters(in: .whitespaces)) {
            if let andRange = expireDescription.range(of: "and"),
               let hoursRange = expireDescription.range(of: "hours"),
               let hours = Int(expireDescription[andRange.upperBound..<hoursRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)) {
                return .days(days, hours: hours)
            } else {
                return .days(days, hours: nil)
            }
        } else if let hoursRange = expireDescription.range(of: "hours"),
                  let hours = Int(expireDescription[..<hoursRange.lowerBound]
                    .trimmingCharacters(in: .whitespaces)) {
            if let andRange = expireDescription.range(of: "and"),
               let minutesRange = expireDescription.range(of: "minutes"),
               let minutes = Int(expireDescription[andRange.upperBound..<minutesRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)) {
                return .hours(hours, minutes: minutes)
            } else {
                return .hours(hours, minutes: nil)
            }
        } else if let minutesRange = expireDescription.range(of: "minutes"),
                  let minutes = Int(expireDescription[..<minutesRange.lowerBound]
                    .trimmingCharacters(in: .whitespaces)) {
            if let andRange = expireDescription.range(of: "and"),
               let secondsRange = expireDescription.range(of: "seconds"),
               let seconds = Int(expireDescription[andRange.upperBound..<secondsRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)) {
                return .minutes(minutes, seconds: seconds)
            } else {
                return .minutes(minutes, seconds: nil)
            }
        } else {
            Logger.error(
                "Unrecognized BanInterval format", context: [
                    "expireDescription": expireDescription
                ]
            )
            return .unrecognized(content: expireDescription)
        }
    }
}
