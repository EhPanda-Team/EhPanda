//
//  AppUtil.swift
//  EhPanda
//

import Foundation

struct AppUtil {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "null"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "null"
    }

    private static let internalIsTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    public static var isTesting: Bool {
        #if DEBUG
        internalIsTesting
        #else
        false
        #endif
    }

    static var galleryHost: GalleryHost {
        let rawValue: String? = UserDefaultsUtil.value(forKey: .galleryHost)
        return GalleryHost(rawValue: rawValue ?? "") ?? .ehentai
    }

    static func dispatchMainSync(execute work: () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
}

struct AppLaunchAutomation {
    struct LoginCookies {
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
        let autoDownloadGID = trimmedValue(environment: environment, key: "EHPANDA_AUTOMATION_AUTO_DOWNLOAD_GID")
        let galleryURL = trimmedValue(environment: environment, key: "EHPANDA_AUTOMATION_GALLERY_URL")
            .flatMap(URL.init(string:))
        let memberID = trimmedValue(environment: environment, key: "EHPANDA_AUTOMATION_IPB_MEMBER_ID")
        let passHash = trimmedValue(environment: environment, key: "EHPANDA_AUTOMATION_IPB_PASS_HASH")
        let igneous = trimmedValue(environment: environment, key: "EHPANDA_AUTOMATION_IGNEOUS")
        let loginCookies: LoginCookies? = if let memberID, let passHash {
            LoginCookies(memberID: memberID, passHash: passHash, igneous: igneous)
        } else {
            nil
        }

        guard initialTab != nil || autoDownloadGID != nil || loginCookies != nil || galleryURL != nil else {
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
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
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

    private static func trimmedValue(environment: [String: String], key: String) -> String? {
        environment[key]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(\.nilIfEmpty)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
