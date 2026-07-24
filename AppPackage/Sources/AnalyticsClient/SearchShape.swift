import AppModels
import Foundation

// The other audited reduction boundary (D-19), and the one that cost an amendment.
//
// `SearchShape.init(keyword:)` is the single `String`-accepting entry point permitted anywhere on
// this module's public surface. D-09 forbids a bare `String` parameter outright; the owner
// amended it to allow exactly this initializer, and a second one reopens that decision rather
// than inheriting it. What was bought is auditability: the alternative avoided the `String` only
// by spreading the same reduction across every search site in the app, in modules whose tests do
// not prove it. Concentrating every content-reading line here means one exhaustively tested type
// stands between a keyword and a payload.
//
// The keyword is read, measured, and dropped. Nothing derived from its text is stored — only a
// bucket, a flag and a length — and `SearchShapeTests` proves that by reflecting over a
// constructed value rather than by reading this file.

public struct SearchShape: Equatable, Sendable {
    /// How many words the keyword held, through the shared bucket vocabulary.
    public let wordCount: CountBucket

    /// Whether any word was namespace-qualified, e.g. `female:…` or its `f:…` abbreviation.
    public let usedTagSyntax: Bool

    /// The exact number of characters in the keyword.
    ///
    /// This is D-08's original documented exception, permitted by D-07. It is a grapheme-cluster
    /// count, so a multi-byte keyword measures what a reader would call its length rather than
    /// its encoded size.
    public let keywordLength: Int

    public init(keyword: String) {
        let words = keyword.split(whereSeparator: \.isWhitespace)

        self.wordCount = .init(count: words.count)
        self.usedTagSyntax = words.contains(where: Self.isNamespaceQualified)
        self.keywordLength = keyword.count
    }
}

extension SearchShape {
    /// Every namespace prefix the search syntax accepts: the full names and their abbreviations.
    private static let namespacePrefixes: Set<String> = {
        let names = TagNamespace.allCases.map(\.rawValue)

        return Set(names).union(TagNamespace.abbreviations.values)
    }()

    /// Whether one word carries a namespace qualifier.
    ///
    /// A leading `-` excludes a term and a leading `"` opens a quoted phrase; both may sit in
    /// front of the namespace, so they are stepped over before the prefix is matched. A colon
    /// that is not preceded by a known namespace — a URL's scheme, a clock time — is not tag
    /// syntax, and the whole point of matching against a closed set is that it cannot be.
    private static func isNamespaceQualified(_ word: Substring) -> Bool {
        guard let separator = word.firstIndex(of: ":") else { return false }

        let prefix = word.prefix(upTo: separator).drop(while: { $0 == "\"" || $0 == "-" })

        return namespacePrefixes.contains(prefix.lowercased())
    }
}
