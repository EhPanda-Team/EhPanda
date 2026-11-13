import Foundation

/// Synthetic values for the 19-08 scenarios: blocked members, the Login form, the site settings' profiles and
/// favorite names, the Activity Logs entries and runs, and the Toplists page count. Every string is invented for the
/// public baselines (D-06); none is a real member, account, profile or log line.
public enum SettingsFixtures {
    /// Blocked members as the comment moderation stores them, in the order they were blocked. Member IDs are the
    /// identity (owner msg 1918); the names are the synthetic ones the comment fixtures use.
    public static let blockedMembers: [(memberID: String, name: String)] = [
        ("900003", "Visual Member 3"),
        ("900001", "Visual Member 1"),
        ("900002", "Visual Member 2")
    ]

    /// The signed-in member's cookies as Account shows them: an invented member ID, a fixed 32-digit hexadecimal
    /// pass hash and a fixed igneous, in the shapes the site hands out. None is a real account's.
    public static let cookieMemberID = "1234567"
    public static let cookiePassHash = "9f3c2a7d5e1b4c8a6d0e2f4a7b9c1d3e"
    public static let cookieIgneous = "4e7a9c2b1d"

    /// The Login form as a user fills it. The password field draws dots, never the text.
    public static let loginUsername = "visual-fixture"
    public static let loginPassword = "fixture-password"

    /// The site settings' profiles: the site's own default profile and the app's own profile, which is selected so
    /// that it can be deleted (the default profile cannot).
    public static let profiles: [(value: Int, name: String)] = [(1, "Default Profile"), (2, "EhPanda")]
    public static let selectedProfile = 2

    /// The ten favorite category names on the site settings page.
    public static let favoriteCategories = (0..<10).map({ "Visual Favorites \($0)" })

    /// Activity Logs entries of the current run: seconds after the fixed date, category, level and message.
    public static let logEntries: [LogEntryFixture] = [
        .init(offset: 2, category: "AppReducer", level: .notice, message: "Visual fixture launch finished."),
        .init(offset: 14, category: "SettingReducer", level: .info, message: "Visual fixture settings loaded."),
        .init(offset: 31, category: "DetailReducer", level: .debug, message: "Visual fixture gallery opened."),
        .init(offset: 47, category: "ReadingReducer", level: .error, message: "Visual fixture page failed to load."),
        .init(offset: 63, category: "DownloadClient", level: .fault, message: "Visual fixture download stopped.")
    ]

    /// The current run's count, and earlier runs: hours before the fixed date and each run's count that day.
    public static let currentRunCount = 3
    public static let previousRuns: [(hoursBefore: Int, runCount: Int)] = [(2, 2), (5, 1), (27, 4), (30, 3)]

    /// The last page index of Toplists, which the jump-page alert's message counts from (shown as one more).
    public static let toplistsLastPage = 4
}

/// One synthetic Activity Logs entry.
public struct LogEntryFixture: Sendable {
    public enum Level: Sendable {
        case debug, info, notice, error, fault
    }

    public let offset: Double
    public let category: String
    public let level: Level
    public let message: String
}
