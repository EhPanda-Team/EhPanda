import Foundation

/// Synthetic values for the 19-08 scenarios: blocked members and the Login form. Every string is invented for the
/// public baselines (D-06); none is a real member, account, profile or log line.
public enum SettingsFixtures {
    /// Blocked members as the comment moderation stores them, in the order they were blocked. Member IDs are the
    /// identity (owner msg 1918); the names are the synthetic ones the comment fixtures use.
    public static let blockedMembers: [(memberID: String, name: String)] = [
        ("900003", "Visual Member 3"),
        ("900001", "Visual Member 1"),
        ("900002", "Visual Member 2")
    ]

    /// The Login form as a user fills it. The password field draws dots, never the text.
    public static let loginUsername = "visual-fixture"
    public static let loginPassword = "fixture-password"
}
