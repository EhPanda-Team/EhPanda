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

/// Synthetic download records over the `downloads-finite` galleries (19-06). Progress is a still: each record
/// holds a fixed number of landed pages out of the gallery's eight.
public struct DownloadRecordFixture: Sendable {
    public enum Status: Sendable {
        case completed, active, error, inactive
    }

    public let status: Status
    public let completedPages: Int
}

extension LibraryFixtures {
    /// The download folders, the first holding every record.
    public static let downloadFolders = ["Visual Folder A", "Visual Folder B", "Visual Folder C"]

    /// Six finished downloads, for the list and grid.
    public static let completedDownloads = Array(
        repeating: DownloadRecordFixture(status: .completed, completedPages: 8), count: 6
    )

    /// An active download five pages in and one that failed after three, above four finished ones.
    public static let activeFailedDownloads = [
        DownloadRecordFixture(status: .active, completedPages: 5),
        DownloadRecordFixture(status: .error, completedPages: 3)
    ] + completedDownloads.prefix(4)

    /// The detail page's download in progress: twelve of its pages landed.
    public static let detailDownloadPages = 12

    /// The detail page's tags: namespace and tag words, all invented.
    public static let detailTags: [(namespace: String, words: [String])] = [
        ("other", ["visual fixture", "public sample", "neutral words"]),
        ("language", ["english"])
    ]
}
