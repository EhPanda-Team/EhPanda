import AppModels

// The only place in this repository where an analytics name or parameter key is created. Every
// literal below is declared once, in the two constant enums at the bottom of the file, so the
// claim "one String-minting site" is checkable by reading this file rather than by grepping the
// tree. Nothing else in the app may assemble a name or a key.
//
// Every rendered *value* originates from a closed enum's raw value, from a `Bool` rendered as
// `"true"` / `"false"`, or from one of D-08's two documented exact-`Int` exceptions — the search
// keyword length (D-07) and the per-namespace tag counts (D-16). No value is interpolated from app
// content; there is no app content to reach, because no `AnalyticsSignal` case can carry any.
//
// Keys are dot-namespaced, and that is not cosmetic. The SDK reserves a flat set of parameter keys
// — `platform`, `locale`, `region` and twenty-odd more — and a collision is only *logged*: the
// signal is still sent, silently overwriting device metadata. A `Domain.name` key cannot collide
// with a flat reserved key, and `AnalyticsSignalRenderingTests` asserts it case-insensitively
// rather than trusting the shape.
//
// This file must not import the SDK. It renders to plain Swift values; plan 14-06 owns the single
// call site that speaks to the vendor and translates `AnalyticsErrorCategory` there.

extension AnalyticsSignal {
    /// The wire form of a signal: everything that crosses the outbound boundary, and nothing else.
    ///
    /// Two shapes, because two SDK entry points are in play. `error` carries an identifier and a
    /// category instead of a name, routing to the vendor's error preset so its built-in error
    /// insights work; the preset's free-form `message:` parameter is opted out in `COVERAGE.md`
    /// precisely because the natural value for it would be a localized description.
    enum Rendered: Equatable, Sendable {
        case signal(name: String, parameters: [String: String])
        case error(id: String, category: AnalyticsErrorCategory, parameters: [String: String])
    }
}

extension AnalyticsSignal {
    /// This signal's name and flat parameter dictionary.
    ///
    /// The `switch` is exhaustive with no catch-all arm, deliberately: a case added to
    /// `AnalyticsSignal` without a rendering is a compile error raised here, at exactly the point
    /// where someone has to decide what the dashboard should call it. A catch-all would have let
    /// the new signal ship unrendered, or ship under a neighbour's name, with nothing in the
    /// collected data to show that it happened.
    var rendered: Rendered {
        switch self {
        // MARK: Navigation

        case .homeSectionViewed(let section):
            .signal(
                name: SignalName.homeSectionViewed,
                parameters: [ParameterKey.navigationSection: section.rawValue]
            )

        case .tabOpened(let tab):
            .signal(
                name: SignalName.tabOpened,
                parameters: [ParameterKey.navigationTab: tab.rawValue]
            )

        case .galleryDetailOpened(let category, let tagNamespaces):
            .signal(
                name: SignalName.galleryDetailOpened,
                parameters: Self.galleryParameters(category: category, tagNamespaces: tagNamespaces)
            )

        // MARK: Search and discovery

        case .searchPerformed(let shape, let resultCount):
            .signal(
                name: SignalName.searchPerformed,
                parameters: Self.searchParameters(shape: shape, resultCount: resultCount)
            )

        case .filterPanelOpened(let surface):
            .signal(
                name: SignalName.filterPanelOpened,
                parameters: [ParameterKey.searchSurface: surface.rawValue]
            )

        case .quickSearchPanelOpened(let surface):
            .signal(
                name: SignalName.quickSearchPanelOpened,
                parameters: [ParameterKey.searchSurface: surface.rawValue]
            )

        case .quickSearchWordUsed:
            .signal(name: SignalName.quickSearchWordUsed, parameters: [:])

        case .tagTapped(let namespace):
            .signal(
                name: SignalName.tagTapped,
                parameters: Self.tagNamespaceParameters(namespace)
            )

        // MARK: Reading and downloads

        case .readingSessionEnded(let pagesRead, let duration):
            .signal(
                name: SignalName.readingSessionEnded,
                parameters: [
                    ParameterKey.readingPagesRead: pagesRead.rawValue,
                    ParameterKey.readingDuration: duration.rawValue
                ]
            )

        case .downloadStateChanged(let outcome):
            .signal(
                name: SignalName.downloadStateChanged,
                parameters: [ParameterKey.downloadOutcome: outcome.rawValue]
            )

        // MARK: Errors and account

        case .errorSurfaced(let kind):
            .error(id: kind.rawValue, category: kind.category, parameters: [:])

        case .loginFailed(let failureKind):
            .signal(
                name: SignalName.loginFailed,
                parameters: [ParameterKey.accountLoginFailureKind: failureKind.rawValue]
            )

        case .cloudflareChallengeEncountered:
            .signal(name: SignalName.cloudflareChallengeEncountered, parameters: [:])
        }
    }
}

// MARK: Parameter assembly

extension AnalyticsSignal {
    /// The category spelling plus one key per namespace the gallery actually uses.
    ///
    /// The counts ship exact rather than bucketed — D-16, the owner amendment that gave D-08 its
    /// second documented exception. A namespace the gallery does not use contributes no key at
    /// all, so the key set is itself the "which namespaces are present" half of D-07.
    private static func galleryParameters(
        category: Category,
        tagNamespaces: TagNamespaceCounts
    ) -> [String: String] {
        var parameters = [ParameterKey.galleryCategory: category.analyticsName]

        for (namespace, count) in tagNamespaces.countsByNamespace {
            parameters[ParameterKey.tagNamespaceCount(namespace)] = String(count)
        }

        return parameters
    }

    /// The reduced shape of a search, with the keyword itself already discarded by `SearchShape`.
    ///
    /// The length ships exact as D-08's original documented exception; the word count and the
    /// result count both go through the shared bucket vocabulary like every other counter.
    private static func searchParameters(shape: SearchShape, resultCount: CountBucket) -> [String: String] {
        [
            ParameterKey.searchWordCount: shape.wordCount.rawValue,
            ParameterKey.searchUsedTagSyntax: String(shape.usedTagSyntax),
            ParameterKey.searchKeywordLength: String(shape.keywordLength),
            ParameterKey.searchResultCount: resultCount.rawValue
        ]
    }

    /// The namespace of a tapped tag, or the shared anonymous spelling when the app does not
    /// recognize it. An unrecognized namespace was scraped text, so it may not name itself.
    private static func tagNamespaceParameters(_ namespace: TagNamespace?) -> [String: String] {
        let key = namespace.map(TagNamespaceKey.known) ?? .unrecognized

        return [ParameterKey.galleryTagNamespace: key.analyticsName]
    }
}

// MARK: The literals

/// Every signal name, spelled once.
///
/// `Domain.eventName`, matching the SDK's own built-in signal names. No `defaultSignalPrefix` is
/// configured: the app ID already scopes the dataset, and a prefix would add a second place where
/// a name is assembled, which is the one property this file exists to prevent.
private enum SignalName {
    static let homeSectionViewed = "Navigation.homeSectionViewed"
    static let tabOpened = "Navigation.tabOpened"
    static let galleryDetailOpened = "Navigation.galleryDetailOpened"
    static let searchPerformed = "Search.performed"
    static let filterPanelOpened = "Search.filterPanelOpened"
    static let quickSearchPanelOpened = "Search.quickSearchPanelOpened"
    static let quickSearchWordUsed = "Search.quickSearchWordUsed"
    static let tagTapped = "Search.tagTapped"
    static let readingSessionEnded = "Reading.sessionEnded"
    static let downloadStateChanged = "Download.stateChanged"
    static let loginFailed = "Account.loginFailed"
    static let cloudflareChallengeEncountered = "Account.cloudflareChallengeEncountered"
}

/// Every parameter key, spelled once. Each carries a dot, which is what keeps the whole set clear
/// of the SDK's flat reserved keys.
private enum ParameterKey {
    static let navigationSection = "Navigation.section"
    static let navigationTab = "Navigation.tab"
    static let galleryCategory = "Gallery.category"
    static let galleryTagNamespace = "Gallery.tagNamespace"
    static let searchWordCount = "Search.wordCount"
    static let searchUsedTagSyntax = "Search.usedTagSyntax"
    static let searchKeywordLength = "Search.keywordLength"
    static let searchResultCount = "Search.resultCount"
    static let searchSurface = "Search.surface"
    static let readingPagesRead = "Reading.pagesRead"
    static let readingDuration = "Reading.duration"
    static let downloadOutcome = "Download.outcome"
    static let accountLoginFailureKind = "Account.loginFailureKind"

    /// One key per namespace present on an opened gallery, below the shared tag-namespace key.
    ///
    /// The interpolated half is a `TagNamespaceKey` spelling — a closed case set, or the literal
    /// `unrecognized` — so the key remains as fixed a vocabulary as the constants above it. A
    /// scraped raw namespace can never reach this, which is the point of `TagNamespaceKey`.
    static func tagNamespaceCount(_ key: TagNamespaceKey) -> String {
        "\(galleryTagNamespace).\(key.analyticsName)"
    }
}
