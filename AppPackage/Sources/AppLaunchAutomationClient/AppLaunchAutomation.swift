import Foundation
import AppModels

public struct AppLaunchAutomation: Sendable {
    public init(
        initialTab: TabBarItemType? = nil,
        autoDownloadGID: String? = nil,
        downloadFolderName: String? = nil,
        loginCookies: LoginCookies? = nil,
        galleryURL: URL? = nil
    ) {
        self.initialTab = initialTab
        self.autoDownloadGID = autoDownloadGID
        self.downloadFolderName = downloadFolderName
        self.loginCookies = loginCookies
        self.galleryURL = galleryURL
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
    public let autoDownloadGID: String?
    public let downloadFolderName: String?
    public let loginCookies: LoginCookies?
    public let galleryURL: URL?

    public static var current: Self? {
        #if DEBUG
        resolve(environment: ProcessInfo.processInfo.environment)
        #else
        nil
        #endif
    }

    public static func resolve(environment: [String: String]) -> Self? {
        #if DEBUG
        let initialTab = environment["EHPANDA_AUTOMATION_TAB"]
            .flatMap(parseTab(rawValue:))
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
            return .favorites
        case "search":
            return .search
        case "downloads":
            return .downloads
        case "setting", "settings":
            return .setting
        default:
            return nil
        }
    }

    private static func trimmedValue(
        environment: [String: String],
        key: String
    ) -> String? {
        environment[key]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(\.nonEmpty)
    }
}
