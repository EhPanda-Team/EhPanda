import Foundation

public enum AppInfo {
    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "null"
    }
    public static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "null"
    }

    /// TelemetryDeck's write-only ingestion key, substituted into the bundle at build time from an
    /// untracked local build configuration.
    ///
    /// `nil` is the intended state rather than a failure. A contributor clone, a fork, CI, the test
    /// host and SwiftUI previews all supply no credential and all resolve to `nil` here, and
    /// analytics no-ops on that single check — only the owner's release machine carries the local
    /// file that fills this in, so no other build can reach the owner's dataset.
    public static var telemetryDeckAppID: String? {
        nonEmptyInfoDictionaryString(forKey: "TelemetryDeckAppID")
    }

    /// The salt TelemetryDeck hashes the anonymized identifier with, substituted into the bundle
    /// from the same untracked local build configuration as ``telemetryDeckAppID``.
    ///
    /// `nil` is the intended state on any build that supplied no credential, exactly as above: such
    /// a build transmits nothing, so it has nothing to salt.
    public static var telemetryDeckSalt: String? {
        nonEmptyInfoDictionaryString(forKey: "TelemetryDeckSalt")
    }

    /// Reads a bundle metadata string, collapsing the three absent-value shapes onto one `nil`: a
    /// missing key, a value that is not a string, and the empty string that an unfilled `$(VAR)`
    /// substitution leaves behind. One nil condition is what lets callers gate on a single check.
    private static func nonEmptyInfoDictionaryString(forKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let internalIsTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    public static var isTesting: Bool {
        #if DEBUG
        internalIsTesting
        #else
        false
        #endif
    }
}
