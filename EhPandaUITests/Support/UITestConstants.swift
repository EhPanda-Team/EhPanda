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
