import AppTools
import CasePaths
import Foundation

public typealias FavoritesSortOrder = EhSetting.FavoritesSortOrder

public enum DateSeekDirection: Equatable, Sendable {
    case newer
    case older
}

public struct DateSeekNavigation: Hashable, Sendable {
    public init(
        directions: Directions,
        minimumDate: Date,
        maximumDate: Date
    ) {
        self.directions = directions
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
    }
    /// The seekable directions available from the current page. Non-optional: a navigation only
    /// exists when at least one direction is, so the "neither" state is unrepresentable here — it
    /// is the `nil` of a `DateSeekNavigation?` instead.
    public enum Directions: Hashable, Sendable {
        case newer(URL)
        case older(URL)
        case both(newer: URL, older: URL)

        /// `nil` when neither URL is present — i.e. the page offers no date seek.
        public init?(newer: URL?, older: URL?) {
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

        public var newerURL: URL? {
            switch self {
            case .newer(let url), .both(newer: let url, older: _):
                return url
            case .older:
                return nil
            }
        }
        public var olderURL: URL? {
            switch self {
            case .older(let url), .both(newer: _, older: let url):
                return url
            case .newer:
                return nil
            }
        }
    }

    public var directions: Directions
    public var minimumDate: Date
    public var maximumDate: Date

    public var newerURL: URL? { directions.newerURL }
    public var olderURL: URL? { directions.olderURL }
    public var dateRange: ClosedRange<Date> { minimumDate...maximumDate }

    public func clampedDate(_ date: Date = Date()) -> Date {
        min(max(date, minimumDate), maximumDate)
    }

    public func seekURL(date: Date, direction: DateSeekDirection) -> URL? {
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
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

public protocol DateFormattable {
    var originalDate: Date { get }
}
extension DateFormattable {
    public var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        formatter.calendar = Calendar.current
        return formatter.string(from: originalDate)
    }
}

public struct PageNumber: Equatable, Sendable {
    public init(
        current: Int = 0,
        maximum: Int = 0,
        lastItemTimestamp: String? = nil,
        isNextButtonEnabled: Bool = false
    ) {
        self.current = current
        self.maximum = maximum
        self.lastItemTimestamp = lastItemTimestamp
        self.isNextButtonEnabled = isNextButtonEnabled
    }
    public var current = 0
    public var maximum = 0
    public var lastItemTimestamp: String?
    public var isNextButtonEnabled = false

    public var isSinglePage: Bool {
        current == 0 && maximum == 0
    }
    public func hasNextPage(isNumericBased: Bool = false) -> Bool {
        isNumericBased ? current < maximum : isNextButtonEnabled
    }
    public mutating func resetPages() {
        self = Self()
    }
}

public struct QuickSearchWord: Codable, Equatable, Identifiable, Sendable {
    public init(
        id: UUID = .init(),
        name: String,
        content: String
    ) {
        self.id = id
        self.name = name
        self.content = content
    }
    public static var empty: Self { .init(name: "", content: "") }

    // Version anchor for future breaking migrations; additive changes ride the tolerant decoder.
    public var schemaVersion = 1
    public var id: UUID = .init()
    public var name: String
    public var content: String

    public var effectiveSearchText: String {
        !content.isEmpty ? content : name
    }
}

// MARK: Manually decode
extension QuickSearchWord {
    // Tolerant decoding keeps an existing persisted list valid across future additive changes.
    public init(from decoder: Decoder) {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? container?.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? 1
        id = (try? container?.decodeIfPresent(UUID.self, forKey: .id)) ?? .init()
        name = (try? container?.decodeIfPresent(String.self, forKey: .name)) ?? ""
        content = (try? container?.decodeIfPresent(String.self, forKey: .content)) ?? ""
    }
}

@dynamicMemberLookup @CasePathable
public enum LoadingState: Equatable, Hashable, Sendable {
    case idle
    case loading
    case failed(AppError)
}
