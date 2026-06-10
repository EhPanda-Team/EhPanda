//
//  AppLaunchAutomation.swift
//  EhPanda
//

import Foundation

struct AppLaunchAutomation: Sendable {
    struct LoginCookies: Sendable {
        let memberID: String
        let passHash: String
        let igneous: String?
    }

    let initialTab: TabBarItemType?
    let autoDownloadGID: String?
    let loginCookies: LoginCookies?
    let galleryURL: URL?

    static var current: Self? {
        #if DEBUG
        resolve(environment: ProcessInfo.processInfo.environment)
        #else
        nil
        #endif
    }

    static func resolve(environment: [String: String]) -> Self? {
        #if DEBUG
        let initialTab = environment["EHPANDA_AUTOMATION_TAB"]
            .flatMap(parseTab(rawValue:))
        let autoDownloadGID = trimmedValue(
            environment: environment,
            key: "EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID"
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
