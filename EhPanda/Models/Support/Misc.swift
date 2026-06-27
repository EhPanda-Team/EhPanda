import CasePaths
import Foundation
import SwiftyBeaver

typealias Logger = SwiftyBeaver
typealias FavoritesSortOrder = EhSetting.FavoritesSortOrder

enum DateSeekDirection: Equatable {
    case newer
    case older
}

struct DateSeekNavigation: Hashable {
    /// The seekable directions available from the current page. Non-optional: a navigation only
    /// exists when at least one direction is, so the "neither" state is unrepresentable here — it
    /// is the `nil` of a `DateSeekNavigation?` instead.
    enum Directions: Hashable {
        case newer(URL)
        case older(URL)
        case both(newer: URL, older: URL)

        /// `nil` when neither URL is present — i.e. the page offers no date seek.
        init?(newer: URL?, older: URL?) {
            switch (newer, older) {
            case let (newer?, older?):
                self = .both(newer: newer, older: older)
            case let (newer?, nil):
                self = .newer(newer)
            case let (nil, older?):
                self = .older(older)
            case (nil, nil):
                return nil
            }
        }

        var newerURL: URL? {
            switch self {
            case .newer(let url), .both(newer: let url, older: _):
                return url
            case .older:
                return nil
            }
        }
        var olderURL: URL? {
            switch self {
            case .older(let url), .both(newer: _, older: let url):
                return url
            case .newer:
                return nil
            }
        }
    }

    var directions: Directions
    var minimumDate: Date
    var maximumDate: Date

    var newerURL: URL? { directions.newerURL }
    var olderURL: URL? { directions.olderURL }
    var dateRange: ClosedRange<Date> { minimumDate...maximumDate }

    func clampedDate(_ date: Date = Date()) -> Date {
        min(max(date, minimumDate), maximumDate)
    }

    func seekURL(date: Date, direction: DateSeekDirection) -> URL? {
        let baseURL: URL?
        switch direction {
        case .newer:
            baseURL = newerURL
        case .older:
            baseURL = olderURL
        }
        return baseURL?.appending(queryItems: ["seek": Self.dateFormatter.string(from: date)])
    }

    /// Formatter for the `seek` query parameter: fixed `yyyy-MM-dd`, UTC, POSIX locale.
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

protocol DateFormattable {
    var originalDate: Date { get }
}
extension DateFormattable {
    var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        formatter.calendar = Calendar.current
        return formatter.string(from: originalDate)
    }
}

struct PageNumber: Equatable {
    var current = 0
    var maximum = 0
    var lastItemTimestamp: String?
    var isNextButtonEnabled = false

    var isSinglePage: Bool {
        current == 0 && maximum == 0
    }
    func hasNextPage(isNumericBased: Bool = false) -> Bool {
        isNumericBased ? current < maximum : isNextButtonEnabled
    }
    mutating func resetPages() {
        self = Self()
    }
}

struct QuickSearchWord: Codable, Equatable, Identifiable {
    static var empty: Self { .init(name: "", content: "") }

    var id: UUID = .init()
    var name: String
    var content: String

    var effectiveSearchText: String {
        !content.isEmpty ? content : name
    }
}

@dynamicMemberLookup @CasePathable
enum LoadingState: Equatable, Hashable {
    case idle
    case loading
    case failed(AppError)
}
