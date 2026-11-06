import Foundation

enum UITestConstants {
    static let primaryGID = "3103480"
    static let primaryToken = "0000000000"
    static let alternateGID = "2930572"
    static let alternateToken = "daf4b9880d"
    static let singlePageToken = "0000000000"
    static let pageIndex = 2
    static let commentID = "6894060"

    static let primaryMarkerTitle = "EhPanda UITest Fixture"
    static let alternateMarkerTitle = "EhPanda UITest Fixture Alt"
    static let unsupportedLinkDescription = "EhPanda can only open gallery links."

    static let stubNetworkEnvironmentKey = "EHPANDA_UITEST_STUB_NETWORK"
    static let fixtureDirectoryEnvironmentKey = "EHPANDA_UITEST_FIXTURE_DIR"
    static let clipboardURLEnvironmentKey = "EHPANDA_UITEST_CLIPBOARD_URL"
    static let launchGalleryURLEnvironmentKey = "EHPANDA_AUTOMATION_GALLERY_URL"
    /// `show` launches into the real first launch, `analytics` onto its analytics choice with the age
    /// already confirmed; absent (or any other value), a stubbed launch is preset past both.
    static let firstLaunchEnvironmentKey = "EHPANDA_UITEST_FIRST_LAUNCH"
    /// A file path; the stub protocol appends one `METHOD host path` line to it for each request it sees.
    static let requestLogEnvironmentKey = "EHPANDA_UITEST_REQUEST_LOG"
    /// A JSON array of `{"memberID": …, "name": …}` objects, written as the comment block list at launch; absent, the
    /// list is empty.
    static let blockedUsersEnvironmentKey = "EHPANDA_UITEST_BLOCKED_USERS"
    /// The signed-in user's display name, for own-comment tests; absent, no name is stored.
    static let displayNameEnvironmentKey = "EHPANDA_UITEST_DISPLAY_NAME"
    /// `1` makes each horizontal pager the reader builds drop its first `.idle` report.
    static let dropInitialIdleEnvironmentKey = "EHPANDA_UITEST_DROP_INITIAL_IDLE"
    /// How the stub answers the Report form: `ready` (absent or unknown), `slowLoad`, `holdSend`, `failSend` or
    /// `unavailable`.
    static let reportScenarioEnvironmentKey = "EHPANDA_UITEST_REPORT_SCENARIO"

    /// UIKit names a toolbar's More button itself, and the name depends on the bar holding it:
    /// iOS 27 calls a navigation bar's `TopOverflowBarButtonItem`.
    static let overflowButtonIdentifiers = [
        "OverflowBarButtonItem", "TopOverflowBarButtonItem", "BottomOverflowBarButtonItem"
    ]
    static var overflowButtonPredicate: NSPredicate {
        NSPredicate(format: "identifier IN %@", overflowButtonIdentifiers)
    }

    /// A gallery of a list in either layout. A grid lays its cards out in a scroll view, not a
    /// collection view, and a list's layout persists on the simulator from earlier tests.
    static var galleryItemPredicate: NSPredicate {
        NSPredicate(format: "identifier BEGINSWITH %@", "gallery-list-item-")
    }

    static func galleryURL(
        scheme: String,
        gid: String = primaryGID,
        token: String = primaryToken
    ) -> URL? {
        URL(string: "\(scheme)://e-hentai.org/g/\(gid)/\(token)/")
    }

    static func singlePageURL(scheme: String) -> URL? {
        URL(string: "\(scheme)://e-hentai.org/s/\(singlePageToken)/\(primaryGID)-\(pageIndex)")
    }

    static func commentURL(scheme: String) -> URL? {
        URL(string: "\(scheme)://e-hentai.org/g/\(primaryGID)/\(primaryToken)/#c\(commentID)")
    }

    static func malformedURL(scheme: String) -> URL? {
        URL(string: "\(scheme)://attacker.example/g/\(primaryGID)/\(primaryToken)/")
    }
}
