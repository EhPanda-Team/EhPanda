/// How much anonymous analytics the user chose to share, in the order the analytics choice lists them
/// (D-06a): each level sends everything the one before it sends, plus more (D-06f).
///
/// Stored on `Setting.analyticsLevel`, where `nil` means the user has not chosen yet; there is no
/// "none" case, and no level is a default. The raw values are the persisted spelling, so a case
/// may be added but never renamed.
public enum AnalyticsLevel: String, Codable, Sendable, CaseIterable, Equatable {
    /// Only the one install signal, with where the app was installed from (D-06b, D-06c).
    case minimal
    /// Minimal, plus usage, the screens and features used, technical details and error kinds (D-06f).
    case basic
    /// Basic, plus reading and download activity and the main settings (D-06f).
    case full
}
