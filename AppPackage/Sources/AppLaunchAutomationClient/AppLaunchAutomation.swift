public import AppModels
import AppTools
public import Foundation

public struct AppLaunchAutomation: Sendable {
    public init(
        initialTab: TabBarItemType? = nil,
        initialLibraryGroup: LibraryGroup? = nil,
        autoDownloadGID: String? = nil,
        downloadFolderName: String? = nil,
        loginCookies: LoginCookies? = nil,
        galleryURL: URL? = nil,
        captureRoute: CaptureRoute? = nil
    ) {
        self.initialTab = initialTab
        self.initialLibraryGroup = initialLibraryGroup
        self.autoDownloadGID = autoDownloadGID
        self.downloadFolderName = downloadFolderName
        self.loginCookies = loginCookies
        self.galleryURL = galleryURL
        self.captureRoute = captureRoute
    }

    /// A screen a capture launch opens through the app's own navigation, with the gallery and page
    /// the capture's selection shows on it.
    public enum CaptureRoute: Equatable, Sendable {
        case home
        case detail(Gallery)
        case comments(Gallery)
        case filters
        case reading(Gallery, page: Int)
        case readingLiveText(Gallery, page: Int)
        case downloads
        case laboratory
    }

    public struct LoginCookies: Sendable {
        public let memberID: String
        public let passHash: String
        public let igneous: String?
        public init(
            memberID: String,
            passHash: String,
            igneous: String? = nil
        ) {
            self.memberID = memberID
            self.passHash = passHash
            self.igneous = igneous
        }
    }

    public let initialTab: TabBarItemType?
    public let initialLibraryGroup: LibraryGroup?
    public let autoDownloadGID: String?
    public let downloadFolderName: String?
    public let loginCookies: LoginCookies?
    public let galleryURL: URL?
    /// The screen a capture launch opens. Only a capture launch sets it, from its own
    /// configuration: no environment key names it, so it never combines with the routes above.
    public let captureRoute: CaptureRoute?

    public static var current: Self? {
        #if DEBUG
        resolve(environment: ProcessInfo.processInfo.environment)
        #else
        nil
        #endif
    }

    public static func resolve(environment: [String: String]) -> Self? {
        #if DEBUG
        let rawTab = environment["EHPANDA_AUTOMATION_TAB"]
        let initialLibraryGroup = rawTab.flatMap(parseLibraryGroup(rawValue:))
        let initialTab = rawTab.flatMap(parseTab(rawValue:))
        let autoDownloadGID = trimmedValue(
            environment: environment,
            key: "EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID"
        )
        let downloadFolderName = trimmedValue(
            environment: environment,
            key: "EHPANDA_AUTOMATION_DOWNLOAD_FOLDER"
        )
        let galleryURL = trimmedValue(
            environment: environment,
            key: "EHPANDA_AUTOMATION_GALLERY_URL"
        )
        .flatMap(URL.init(string:))
        let memberID = trimmedValue(
            environment: environment,
            key: "EHPANDA_AUTOMATION_IPB_MEMBER_ID"
        )
        let passHash = trimmedValue(
            environment: environment,
            key: "EHPANDA_AUTOMATION_IPB_PASS_HASH"
        )
        let igneous = trimmedValue(
            environment: environment,
            key: "EHPANDA_AUTOMATION_IGNEOUS"
        )
        let loginCookies: LoginCookies? = if let memberID, let passHash {
            LoginCookies(
                memberID: memberID,
                passHash: passHash,
                igneous: igneous
            )
        } else {
            nil
        }

        guard initialTab != nil
                || autoDownloadGID != nil
                || loginCookies != nil
                || galleryURL != nil
        else {
            return nil
        }
        return .init(
            initialTab: initialTab,
            initialLibraryGroup: initialLibraryGroup,
            autoDownloadGID: autoDownloadGID,
            downloadFolderName: downloadFolderName,
            loginCookies: loginCookies,
            galleryURL: galleryURL
        )
        #else
        nil
        #endif
    }

    private static func parseTab(rawValue: String) -> TabBarItemType? {
        switch rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
        case "home":
            return .home
        case "favorites":
            return .library
        case "search":
            return .search
        case "downloads":
            return .library
        case "library":
            return .library
        case "setting", "settings":
            return .setting
        default:
            return nil
        }
    }

    private static func parseLibraryGroup(rawValue: String) -> LibraryGroup? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "favorites":
            return .favorites(-1)
        case "downloads":
            return .downloads(.all)
        default:
            return nil
        }
    }

    private static func trimmedValue(
        environment: [String: String],
        key: String
    ) -> String? {
        environment[key]
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .flatMap(\.nonEmpty)
    }
}
