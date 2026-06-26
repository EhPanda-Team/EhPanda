//
//  Misc.swift
//  EhPanda
//

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
    var previousURL: URL?
    var nextURL: URL?
    var minimumDate: Date?
    var maximumDate: Date?

    var isEnabled: Bool {
        previousURL != nil || nextURL != nil
    }
    var dateRange: ClosedRange<Date> {
        (minimumDate ?? .distantPast)...(maximumDate ?? .distantFuture)
    }

    func clampedDate(_ date: Date = Date()) -> Date {
        if let maximumDate, date > maximumDate {
            return maximumDate
        }
        if let minimumDate, date < minimumDate {
            return minimumDate
        }
        return date
    }

    func seekURL(date: Date, direction: DateSeekDirection) -> URL? {
        let baseURL: URL?
        switch direction {
        case .newer:
            baseURL = previousURL
        case .older:
            baseURL = nextURL
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
    var dateSeekNavigation: DateSeekNavigation?

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
