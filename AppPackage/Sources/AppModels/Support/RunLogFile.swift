import AppTools
import Foundation

/// A persisted per-run activity-log file, named `ehpanda-<yyyyMMdd>-<runCount>.jsonl`.
public struct RunLogFile: Identifiable, Equatable, Sendable {
    public let url: URL
    public let date: Date
    public let runCount: Int

    public var id: Int { runCount }

    public init(url: URL, date: Date, runCount: Int) {
        self.url = url
        self.date = date
        self.runCount = runCount
    }

    /// Parses a `RunLogFile` from a log-file URL, returning `nil` when the
    /// file name does not match the `ehpanda-<yyyyMMdd>-<runCount>.jsonl` format.
    public init?(fileURL: URL) {
        let nameComponents = fileURL.lastPathComponent.split(separator: ".")
        guard nameComponents.count == 2,
              String(nameComponents[1]) == Defaults.FilePath.activityLogExtension
        else { return nil }

        let components = nameComponents[0].split(separator: "-")
        guard components.count == 3,
              String(components[0]) == Defaults.FilePath.activityLogPrefix,
              components[1].count == 8,
              let date = Self.fileNameDateFormatter.date(from: String(components[1])),
              let runCount = Int(components[2])
        else { return nil }

        self.init(url: fileURL, date: date, runCount: runCount)
    }

    /// The canonical `ehpanda-<yyyyMMdd>-<runCount>.jsonl` file name for a run.
    public static func fileName(date: Date, runCount: Int) -> String {
        [
            [
                Defaults.FilePath.activityLogPrefix,
                dayString(for: date),
                String(runCount)
            ]
            .joined(separator: "-"),

            Defaults.FilePath.activityLogExtension
        ]
        .joined(separator: ".")
    }

    /// The `yyyyMMdd` day component used in log file names, in the device's local time zone.
    /// Two runs share a day (and thus the same run-count sequence) iff these match.
    public static func dayString(for date: Date) -> String {
        fileNameDateFormatter.string(from: date)
    }

    // No explicit time zone: the day rolls over at the device's local midnight, matching how
    // the picker groups runs and the user's notion of "a different day".
    private static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
