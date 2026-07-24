import AppModels

// The closed vocabulary every analytics payload value is drawn from. Nothing declared here is
// derived from app content: each type is a fixed case set decided at compile time, so a payload
// assembled out of this file cannot carry a title, a keyword, a URL or a tag value. That is D-09
// expressed as types rather than as a review convention — a contributor adding a signal later
// cannot express a free-form payload, because no type in this module can hold one.
//
// Two rules hold throughout:
//
// 1. Raw values are left implicit, so each spelling equals its case name. The pinning lives in
//    `AnalyticsVocabularyTests` instead, which is the stronger place for it: a rename there is a
//    failing test naming the dashboard column it would have orphaned.
// 2. Every mapping out of a domain enum is an exhaustive `switch` with no catch-all arm. When a
//    new case appears upstream the build breaks at exactly the point where someone has to decide
//    what the dashboard should call it, rather than folding the new case into a neighbour.

/// A section of the Home tab, as a single closed spelling rather than a screen name.
///
/// `HomeFeature` splits the same five destinations across two enums — `HomeSectionType` for the
/// two list sections and `HomeMiscGridType` for the three grids. Mapping them here would mean
/// depending on `HomeFeature` from a client module and inverting the dependency direction the
/// package holds everywhere else, so the emission site does the mapping and this stays a plain
/// closed enum.
public enum HomeSection: String, CaseIterable, Equatable, Sendable {
    case frontpage
    case toplists
    case popular
    case watched
    case history
}

/// One of the app's five root tabs.
public enum AppTab: String, CaseIterable, Equatable, Sendable {
    case home
    case favorites
    case search
    case downloads
    case setting
}

extension AppTab {
    public init(_ type: TabBarItemType) {
        switch type {
        case .home:
            self = .home

        case .favorites:
            self = .favorites

        case .search:
            self = .search

        case .downloads:
            self = .downloads

        case .setting:
            self = .setting
        }
    }
}

/// The screen a filter or quick-search panel was opened from.
///
/// One case per reducer that owns such a panel, so a single signal can say where a search was
/// shaped without transmitting a free-form screen name.
public enum SearchSurface: String, CaseIterable, Equatable, Sendable {
    case search
    case searchRoot
    case frontpage
    case popular
    case watched
    case favorites
    case detailSearch
}

/// What became of a download.
public enum DownloadOutcome: String, CaseIterable, Equatable, Sendable {
    case started
    case retried
    case completed
    case failed
    case deleted
    case moved
    // Added by D-20. Pause and resume are separate cases rather than one `paused`: the app sends a
    // single toggle action for both directions, and collapsing them would count two opposite user
    // intents under one name.
    case paused
    case resumed
    // Added by D-21. Re-fetching an already-downloaded gallery flagged `updateAvailable` is its own
    // outcome, deliberately not folded into `completed` — that would conflate a first download with
    // an update.
    case updated
}

/// Why a login attempt did not succeed.
///
/// `other` exists so an unclassified failure still lands somewhere countable. It is a bucket for
/// login outcomes only, and carries nothing describing the failure it stands for.
public enum LoginFailureKind: String, CaseIterable, Equatable, Sendable {
    case rejected
    case captchaRequired
    case cloudflareChallengeFailed
    case networkingFailed
    case other
}

// MARK: Stable spellings for the Int-raw domain enums

// `ReadingDirection` and `ListDisplayMode` are `Int`-raw because their raw values are persisted
// ordinals, not names. Sending those ordinals would put a column of bare integers on the
// dashboard, and inserting a case upstream would silently re-number every later one — changing
// the meaning of history already collected, with nothing in the data to show that it happened.

extension ReadingDirection {
    var analyticsName: String {
        switch self {
        case .vertical:
            "vertical"

        case .rightToLeft:
            "rightToLeft"

        case .leftToRight:
            "leftToRight"
        }
    }
}

extension ListDisplayMode {
    var analyticsName: String {
        switch self {
        case .detail:
            "detail"

        case .thumbnail:
            "thumbnail"
        }
    }
}

// `Category` is already `String`-raw, but its raw values are the site's display strings —
// "Artist CG", "Non-H" — which are scraped-surface spellings rather than ones this app chose.
// A separate spelling keeps the dashboard vocabulary in one house style and, more usefully,
// makes the eleven-case set a compile-time commitment: a twelfth category breaks the build.
//
// All eleven cases ship, `imageSet` and `private` included (D-15). `Category.private` is a
// display-only bucket in this codebase and may never reach a real payload; it is spelled anyway,
// because omitting a case on the grounds that it is unlikely narrows D-07 by a different route.
extension Category {
    var analyticsName: String {
        switch self {
        case .doujinshi:
            "doujinshi"

        case .manga:
            "manga"

        case .artistCG:
            "artistCG"

        case .gameCG:
            "gameCG"

        case .western:
            "western"

        case .nonH:
            "nonH"

        case .imageSet:
            "imageSet"

        case .cosplay:
            "cosplay"

        case .asianPorn:
            "asianPorn"

        case .misc:
            "misc"

        case .private:
            "private"
        }
    }
}
