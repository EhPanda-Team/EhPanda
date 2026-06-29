import OSLogExt
import AppTools
import AppModels
import Foundation
import ComposableArchitecture

private let logger = Logger(category: .init(describing: LogsClient.self))

public struct LogsClient: Sendable {
    /// Reads activity-log entries emitted by this process since `after`
    /// (or since boot when `after` is `nil`), sorted oldest-first.
    public var fetchNewEntries: @Sendable (_ after: Date?) async throws -> [AppActivityLog]
    /// Appends entries to a per-run jsonl file, creating it (and the logs directory) when needed.
    public var appendToRunFile: @Sendable (_ logs: [AppActivityLog], _ url: URL) async throws -> Void
    /// Reads back a previously written per-run jsonl file.
    public var readRunFile: @Sendable (_ url: URL) async throws -> [AppActivityLog]
    /// Lists the persisted per-run log files, newest run first.
    public var listRunFiles: @Sendable () async -> [RunLogFile]
    /// Derives the next run count for the given day from the existing log files
    /// (`max + 1` among that day's files, or `1` — so the count resets each new day).
    public var nextRunCount: @Sendable (_ date: Date) async -> Int
    /// In-memory, case-insensitive keyword filter over already-loaded logs.
    public var query: @Sendable (_ logs: [AppActivityLog], _ keyword: String) -> [AppActivityLog]
    /// The jsonl file URL for a given run.
    public var currentRunFileURL: @Sendable (_ runCount: Int, _ date: Date) -> URL
}

extension LogsClient {
    public static let live: Self = .init(
        fetchNewEntries: { after in
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = after.map(store.position(date:))
                ?? store.position(timeIntervalSinceLatestBoot: .zero)
            let predicate = NSPredicate(format: "subsystem BEGINSWITH %@", Defaults.App.identifier)
            let entries = Array(try store.getEntries(at: position, matching: predicate))
            let logEntries = entries.compactMap { $0 as? OSLogEntryLog }
            if logEntries.count != entries.count {
                logger.warning("""
                    Some log entries could not be read as OSLogEntryLog. \
                    Read \(logEntries.count, privacy: .public) of \(entries.count, privacy: .public).
                    """)
            }
            let logs = logEntries
                .filter { $0.subsystem.caseInsensitiveContains(Defaults.App.identifier) }
                .map(AppActivityLog.init(osLog:))
                .sorted { $0.date < $1.date }
            guard let after else { return logs }
            return logs.filter { $0.date > after }
        },
        appendToRunFile: { logs, url in
            guard !logs.isEmpty else { return }
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            var payload = Data()
            for log in logs {
                payload.append(try encoder.encode(log))
                payload.append(0x0A)
            }

            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: payload)
            } else {
                try payload.write(to: url, options: .atomic)
            }
        },
        readRunFile: { url in
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return data.split(separator: 0x0A).compactMap { line in
                try? decoder.decode(AppActivityLog.self, from: Data(line))
            }
        },
        listRunFiles: {
            let directory = FileUtil.logsDirectoryURL
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
                return []
            }
            return names
                .compactMap { RunLogFile(fileURL: directory.appendingPathComponent($0)) }
                // Newest first across days: counts reset daily, so order by day then count.
                .sorted { $0.date != $1.date ? $0.date > $1.date : $0.runCount > $1.runCount }
        },
        nextRunCount: { date in
            let directory = FileUtil.logsDirectoryURL
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
                return 1
            }
            let today = RunLogFile.dayString(for: date)
            let todayCounts = names
                .compactMap { RunLogFile(fileURL: directory.appendingPathComponent($0)) }
                .filter { RunLogFile.dayString(for: $0.date) == today }
                .map(\.runCount)
            return (todayCounts.max() ?? 0) + 1
        },
        query: { logs, keyword in
            guard !keyword.isEmpty else { return logs }
            return logs.filter { log in
                [log.dateDescription, log.level.title, log.category, log.message]
                    .joined(separator: " ")
                    .caseInsensitiveContains(keyword)
            }
        },
        currentRunFileURL: { runCount, date in
            FileUtil.logsDirectoryURL.appendingPathComponent(
                RunLogFile.fileName(date: date, runCount: runCount)
            )
        }
    )
}

// MARK: API
public enum LogsClientKey: DependencyKey {
    public static let liveValue = LogsClient.live
    public static let previewValue = LogsClient.noop
    public static let testValue = LogsClient.unimplemented
}

extension DependencyValues {
    public var logsClient: LogsClient {
        get { self[LogsClientKey.self] }
        set { self[LogsClientKey.self] = newValue }
    }
}

// MARK: Test
extension LogsClient {
    public static let noop: Self = .init(
        fetchNewEntries: { _ in [] },
        appendToRunFile: { _, _ in },
        readRunFile: { _ in [] },
        listRunFiles: { [] },
        nextRunCount: { _ in 1 },
        query: { logs, _ in logs },
        currentRunFileURL: { _, _ in FileUtil.logsDirectoryURL }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        fetchNewEntries: IssueReporting.unimplemented(placeholder: placeholder()),
        appendToRunFile: IssueReporting.unimplemented(placeholder: placeholder()),
        readRunFile: IssueReporting.unimplemented(placeholder: placeholder()),
        listRunFiles: IssueReporting.unimplemented(placeholder: placeholder()),
        nextRunCount: IssueReporting.unimplemented(placeholder: placeholder()),
        query: IssueReporting.unimplemented(placeholder: placeholder()),
        currentRunFileURL: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
