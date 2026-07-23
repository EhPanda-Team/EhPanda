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
    static let unsupportedLinkDescription = "This link wasn't recognized as an EhPanda gallery link."

    static let stubNetworkEnvironmentKey = "EHPANDA_UITEST_STUB_NETWORK"
    static let fixtureDirectoryEnvironmentKey = "EHPANDA_UITEST_FIXTURE_DIR"
    static let clipboardURLEnvironmentKey = "EHPANDA_UITEST_CLIPBOARD_URL"
    static let launchGalleryURLEnvironmentKey = "EHPANDA_AUTOMATION_GALLERY_URL"

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
