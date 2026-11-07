import Foundation

/// Synthetic words for the 19-06 scenarios: search history, saved searches and tag suggestions. Every string is
/// invented for the public baselines (D-06); none is a real search, tag or gallery title.
public enum LibraryFixtures {
    /// Recent searches, oldest first, as the search history stores them.
    public static let historyKeywords = ["visual fixture", "public sample", "neutral words", "synthetic query"]

    /// Saved searches: a name and the search text it runs.
    public static let savedSearches: [(name: String, content: String)] = [
        ("Visual Search One", "visual fixture one"),
        ("Visual Search Two", "visual fixture two"),
        ("", "public sample")
    ]

    /// The search the results pages show.
    public static let resultsKeyword = "visual fixture"

    /// The word typed into Search for the suggestions state, and the translations it matches. Keys differ in
    /// length, so each suggestion's weight differs and the order is fixed.
    public static let typedTag = "visual"
    public static let tagTranslations: [TagTranslationFixture] = [
        .init(namespace: "other", key: "visual", value: "Visual"),
        .init(namespace: "other", key: "visual tag", value: "Visual Tag"),
        .init(namespace: "other", key: "visual fixture", value: "Visual Fixture"),
        .init(namespace: "other", key: "visual fixture tag", value: "Visual Fixture Tag")
    ]
}

/// One synthetic tag translation: the tag's namespace, its key and the translated text shown.
public struct TagTranslationFixture: Sendable {
    public let namespace: String
    public let key: String
    public let value: String
}
