import OSLog
import SwiftUI
import Resources
import Foundation

public struct AppActivityLog: Sendable, Equatable, Identifiable, Codable {
    public let date: Date
    public let category: String
    public let level: OSLogEntryLog.Level
    public let message: String

    public var id: String {
        dateDescription + message
    }

    public var dateDescription: String {
        Self.logDateFormatter.string(from: date)
    }

    private static let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss.SSS"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    public init(
        date: Date,
        category: String,
        level: OSLogEntryLog.Level,
        message: String
    ) {
        self.date = date
        self.category = category
        self.level = level
        self.message = message
    }

    public init(osLog: OSLogEntryLog) {
        self.init(
            date: osLog.date,
            category: osLog.category,
            level: osLog.level,
            message: osLog.composedMessage
        )
    }

    // `OSLogEntryLog.Level` is an `Int`-backed enum, so it is persisted as its raw value.
    private enum CodingKeys: String, CodingKey {
        case date, category, level, message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        category = try container.decode(String.self, forKey: .category)
        let levelRawValue = try container.decode(Int.self, forKey: .level)
        level = OSLogEntryLog.Level(rawValue: levelRawValue) ?? .undefined
        message = try container.decode(String.self, forKey: .message)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(category, forKey: .category)
        try container.encode(level.rawValue, forKey: .level)
        try container.encode(message, forKey: .message)
    }
}

public extension OSLogEntryLog.Level {
    var color: Color {
        switch self {
        case .debug: .indigo
        case .info: .blue
        case .notice: .gray
        case .error: .orange
        case .fault: .red
        case .undefined: .primary
        @unknown default: .primary
        }
    }

    var title: String {
        switch self {
        case .undefined: L10n.Localizable.AppActivityLogsView.Level.undefined
        case .debug: L10n.Localizable.AppActivityLogsView.Level.debug
        case .info: L10n.Localizable.AppActivityLogsView.Level.info
        case .notice: L10n.Localizable.AppActivityLogsView.Level.notice
        case .error: L10n.Localizable.AppActivityLogsView.Level.error
        case .fault: L10n.Localizable.AppActivityLogsView.Level.fault
        @unknown default: ""
        }
    }
}
