import Foundation

// The site's tag suggestions (G-1 of quick 261126-wzg): what the tag completer of its My Tags page (`tagcompleter` in
// `ehg_mytags.c.js`, read 2026-11-26) asks the API's `tagsuggest` for, and which entries of the answer it lists.

/// A tag as the site names it: its namespace and its name.
public struct SiteTag: Equatable, Hashable, Sendable {
    public let namespace: TagNamespace
    public let name: String

    public init(namespace: TagNamespace, name: String) {
        self.namespace = namespace
        self.name = name
    }

    /// `namespace:name`, the form the site's tag field takes.
    public var fullName: String {
        namespace.rawValue + ":" + name
    }
}

/// One entry of the site's answer to `tagsuggest`: a tag, or an alias, which the site files under its canonical tag.
public struct SiteTagSuggestion: Equatable, Hashable, Identifiable, Sendable {
    /// The site's id of the suggested tag, an alias's own for an alias; the answer is keyed by it.
    public let id: Int
    /// The suggested tag; for an alias, the alias.
    public let tag: SiteTag
    /// The canonical tag an alias stands for (the answer's `mid`, `mns` and `mtn`); nil when the entry is no alias.
    public let canonical: SiteTag?

    public init(id: Int, tag: SiteTag, canonical: SiteTag?) {
        self.id = id
        self.tag = tag
        self.canonical = canonical
    }

    /// The tag choosing the entry puts in the field: an alias's canonical tag, as the site's list inserts it, else the
    /// tag itself.
    public var insertedTag: SiteTag {
        canonical ?? tag
    }

    /// Whether the site's list shows the entry for `query`: the entry's own `namespace:name` holds the query's text at
    /// the start of a word (its start, or after a space or a colon), in any case, as the list's `(^| |:)<text>` test
    /// does. The text is matched as written, where the site's list would read it as a pattern.
    public func matches(_ query: TagSuggestQuery) -> Bool {
        let name = " " + tag.fullName
        return name.range(of: " " + query.text, options: .caseInsensitive) != nil
            || name.range(of: ":" + query.text, options: .caseInsensitive) != nil
    }
}

/// What the site's tag completer sends for the text of its tag field, if anything: the text without its quotes, a
/// loose namespace written out (`f:` as `female:`), and nothing while fewer than two characters follow the namespace.
public struct TagSuggestQuery: Equatable, Hashable, Sendable {
    /// The loose namespaces the completer writes out, in the order it tries them: when the text's namespace (what comes
    /// before its last colon) starts with a prefix, the first such prefix's namespace replaces it. The prefixes are
    /// lower case only, as the site's are.
    private static let looseNamespaces: [(prefix: String, namespace: TagNamespace)] = [
        ("x", .mixed), ("mix", .mixed), ("mis", .temp), ("co", .cosplayer), ("lo", .location),
        ("t", .temp), ("f", .female), ("m", .male), ("r", .reclass), ("l", .language),
        ("p", .parody), ("c", .character), ("g", .group), ("a", .artist), ("o", .other)
    ]

    /// The text sent: the field's text without its quotes, a loose namespace written out.
    public let text: String
    /// What follows the namespace in `text`, after its last colon (all of it when it has none); two characters or
    /// more.
    public let term: String

    /// The query for `fieldText`; nil when fewer than two characters follow the namespace.
    public init?(_ fieldText: String) {
        var text = fieldText.filter({ $0 != "\"" && $0 != "'" })
        if let colon = text.lastIndex(of: ":"),
           let loose = Self.looseNamespaces.first(where: { text[..<colon].hasPrefix($0.prefix) }) {
            text = loose.namespace.rawValue + text[colon...]
        }
        let term = text.lastIndex(of: ":").map({ String(text[text.index(after: $0)...]) }) ?? text
        guard term.count >= 2 else { return nil }
        self.text = text
        self.term = term
    }
}
