import AppTools
import Foundation
import OSLog

private let logger = Logger(
    subsystem: [Defaults.App.identifier, "DetailFeature"].joined(separator: "."),
    category: "CommentFilterTerms"
)

/// The posting filter's term list: language groups of terms, keyed by app locale (DD-04).
///
/// The bundled list is `Resources/CommentFilterTerms.json`, loaded once. It covers slurs, hate speech, threats and
/// harassment phrases in the six app languages and leaves out sexual vocabulary, since EhPanda is an adult-content
/// client. Every group applies to every comment, whatever the app's language, because a comment can be written in any
/// of them. Entries are written in their natural form; ``CommentFilterMatcher`` normalises each one once, on load,
/// the same way as the text (``CommentFilter/normalized(_:)``).
///
/// `exceptions` names, for a term, the ordinary words that hold it: a short CJK term matches as a substring, so a word
/// such as a neutral compound would otherwise raise the warning. Inside one of its exception words the term does not
/// count; anywhere else in the same text it still does, so an exception never hides the term itself.
struct CommentFilterTerms: Decodable, Equatable, Sendable {
    let groups: [String: [String]]
    /// For a term of the groups, the ordinary words it does not count inside.
    let exceptions: [String: [String]]
    /// The groups' terms, normalised once, each with the rule its script calls for and its exception words.
    let matchers: [CommentFilterMatcher]

    init(groups: [String: [String]], exceptions: [String: [String]] = [:]) {
        self.groups = groups
        self.exceptions = exceptions
        var normalizedExceptions = [String: [String]]()
        for (term, words) in exceptions {
            normalizedExceptions[CommentFilter.normalized(term), default: []] += words.map(CommentFilter.normalized)
        }
        matchers = groups.keys.sorted()
            .flatMap({ groups[$0] ?? [] })
            .compactMap({ CommentFilterMatcher(term: $0, exceptions: normalizedExceptions) })
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            groups: try container.decode([String: [String]].self, forKey: .groups),
            exceptions: try container.decodeIfPresent([String: [String]].self, forKey: .exceptions) ?? [:]
        )
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.groups == rhs.groups && lhs.exceptions == rhs.exceptions
    }

    private enum CodingKeys: String, CodingKey {
        case groups
        case exceptions
    }
}

extension CommentFilterTerms {
    /// The bundled list, loaded on first use. A list that fails to load leaves the filter matching nothing and logs
    /// the error; `CommentFilterTests` loads the same resource and fails on it, so a broken list cannot ship unseen.
    static let bundled: Self = {
        do {
            return try load(from: bundle)
        } catch {
            logger.error("The bundled comment filter list did not load: \(error, privacy: .public)")
            return Self(groups: [:])
        }
    }()

    static var bundle: Bundle { .module }

    static func load(from bundle: Bundle) throws -> Self {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    private static let resourceName = "CommentFilterTerms"
}
