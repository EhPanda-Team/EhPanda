import AppTools
import Foundation

/// A persisted per-launch activity-log file, named `ehpanda-<yyyyMMdd>-<launchCount>.jsonl`.
public struct LaunchLogFile: Identifiable, Equatable, Sendable {
    public let url: URL
    public let date: Date
    public let launchCount: Int

    public var id: Int { launchCount }

    public init(url: URL, date: Date, launchCount: Int) {
        self.url = url
        self.date = date
        self.launchCount = launchCount
    }

    /// Parses a `LaunchLogFile` from a log-file URL, returning `nil` when the
    /// file name does not match the `ehpanda-<yyyyMMdd>-<launchCount>.jsonl` format.
    public init?(fileURL: URL) {
        let name = fileURL.lastPathComponent
        let prefix = Defaults.FilePath.activityLogPrefix
        let suffix = "." + Defaults.FilePath.activityLogExtension
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }

        let core = name.dropFirst(prefix.count).dropLast(suffix.count)
        let components = core.split(separator: "-")
        guard components.count == 2,
              components[0].count == 8,
              let date = Self.fileNameDateFormatter.date(from: String(components[0])),
              let launchCount = Int(components[1])
        else { return nil }

        self.init(url: fileURL, date: date, launchCount: launchCount)
    }

    /// The canonical `ehpanda-<yyyyMMdd>-<launchCount>.jsonl` file name for a launch.
    public static func fileName(date: Date, launchCount: Int) -> String {
        "\(Defaults.FilePath.activityLogPrefix)\(dayString(for: date))-\(launchCount)"
            + ".\(Defaults.FilePath.activityLogExtension)"
    }

    /// The `yyyyMMdd` day component used in log file names, in the device's local time zone.
    /// Two launches share a day (and thus the same launch-count sequence) iff these match.
    public static func dayString(for date: Date) -> String {
        fileNameDateFormatter.string(from: date)
    }

    // No explicit time zone: the day rolls over at the device's local midnight, matching how
    // the picker groups launches and the user's notion of "a different day".
    private static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
