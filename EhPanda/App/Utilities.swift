//
//  Utilities.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI
import Combine
import Kingfisher
import AudioToolbox
import LocalAuthentication

// MARK: Authorization
struct AuthorizationUtil {
    static var isSameAccount: Bool {
        if let ehentai = URL(string: Defaults.URL.ehentai),
           let exhentai = URL(string: Defaults.URL.exhentai)
        {
            let ehUID = CookiesUtil.get(for: ehentai, key: Defaults.Cookie.ipbMemberId).rawValue
            let exUID = CookiesUtil.get(for: exhentai, key: Defaults.Cookie.ipbMemberId).rawValue
            if !ehUID.isEmpty && !exUID.isEmpty { return ehUID == exUID } else { return true }
        } else {
            return true
        }
    }

    static var didLogin: Bool {
        CookiesUtil.verify(for: Defaults.URL.ehentai.safeURL(), isEx: false)
        || CookiesUtil.verify(for: Defaults.URL.exhentai.safeURL(), isEx: true)
    }

    static func localAuth(
        reason: String, successAction: (() -> Void)? = nil,
        failureAction: (() -> Void)? = nil,
        passcodeNotFoundAction: (() -> Void)? = nil
    ) {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason.localized) { success, _ in
                DispatchQueue.main.async {
                    if success { successAction?() } else { failureAction?() }
                }
            }
        } else {
            passcodeNotFoundAction?()
        }
    }
}

// MARK: App
struct AppUtil {
    static var opacityTransition: AnyTransition {
        AnyTransition.opacity.animation(.default)
    }
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "(null)"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "(null)"
    }

    static var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment[
          "XCTestConfigurationFilePath"
        ] != nil
    }

    static var galleryHost: GalleryHost {
        let rawValue: String? = UserDefaultsUtil.value(forKey: .galleryHost)
        return GalleryHost(rawValue: rawValue ?? "") ?? .ehentai
    }

    static func setGalleryHost(value: GalleryHost) {
        UserDefaultsUtil.set(value: value.rawValue, forKey: .galleryHost)
    }

    static func verifyEhPandaProfileName(with name: String?) -> Bool {
        ["EhPanda", "EhPanda (Default)"].contains(name ?? "")
    }

    static func configureKingfisher(bypassesSNIFiltering: Bool, handlesCookies: Bool = true) {
        let config = KingfisherManager.shared.downloader.sessionConfiguration
        if handlesCookies { config.httpCookieStorage = HTTPCookieStorage.shared }
        if bypassesSNIFiltering { config.protocolClasses = [DFURLProtocol.self] }
        KingfisherManager.shared.downloader.sessionConfiguration = config
    }

    static func presentActivity(items: [Any]) {
        let activityVC = UIActivityViewController(
            activityItems: items, applicationActivities: nil
        )
        if DeviceUtil.isPad {
            activityVC.popoverPresentationController?.sourceView = DeviceUtil.keyWindow
            activityVC.popoverPresentationController?.sourceRect = CGRect(
                x: DeviceUtil.screenW, y: 0, width: 200, height: 200
            )
        }
        activityVC.modalPresentationStyle = .overFullScreen
        DeviceUtil.keyWindow?.rootViewController?
            .present(activityVC, animated: true, completion: nil)
        HapticUtil.generateFeedback(style: .light)
    }

    static func dispatchMainSync(execute work: () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }
}

// MARK: Device
struct DeviceUtil {
    static var viewControllersCount: Int {
        guard let navigationVC = keyWindow?.rootViewController?.children.first
                as? UINavigationController else { return -1 }
        return navigationVC.viewControllers.count
    }

    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var isPadWidth: Bool {
        windowW >= 744
    }

    static var isSEWidth: Bool {
        windowW <= 320
    }

    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene }).last?
            .windows.filter({ $0.isKeyWindow }).last
    }

    static var isLandscape: Bool {
        [.landscapeLeft, .landscapeRight]
            .contains(keyWindow?.windowScene?.interfaceOrientation)
    }

    static var isPortrait: Bool {
        [.portrait, .portraitUpsideDown]
            .contains(keyWindow?.windowScene?.interfaceOrientation)
    }

    static var windowW: CGFloat {
        min(absWindowW, absWindowH)
    }

    static var windowH: CGFloat {
        max(absWindowW, absWindowH)
    }

    static var screenW: CGFloat {
        min(absScreenW, absScreenH)
    }

    static var screenH: CGFloat {
        max(absScreenW, absScreenH)
    }

    static var absWindowW: CGFloat {
        keyWindow?.frame.size.width ?? absScreenW
    }

    static var absWindowH: CGFloat {
        keyWindow?.frame.size.height ?? absScreenH
    }

    static var absScreenW: CGFloat {
        UIScreen.main.bounds.size.width
    }

    static var absScreenH: CGFloat {
        UIScreen.main.bounds.size.height
    }
}

// MARK: Haptic
struct HapticUtil {
    static func generateFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard !isLegacyTapticEngine else {
            generateLegacyFeedback()
            return
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func generateNotificationFeedback(style: UINotificationFeedbackGenerator.FeedbackType) {
        guard !isLegacyTapticEngine else {
            generateLegacyFeedback()
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(style)
    }

    private static func generateLegacyFeedback() {
        AudioServicesPlaySystemSound(1519)
        AudioServicesPlaySystemSound(1520)
        AudioServicesPlaySystemSound(1521)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private static var isLegacyTapticEngine: Bool {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return ["iPhone8,1", "iPhone8,2"].contains(identifier)
    }
}

// MARK: Pasteboard
struct PasteboardUtil {
    static var url: URL? {
        if UIPasteboard.general.hasURLs {
            return UIPasteboard.general.url
        } else {
            return nil
        }
    }

    static var changeCount: Int? {
        UserDefaultsUtil.value(forKey: .pasteboardChangeCount)
    }

    static func setChangeCount(value: Int) {
        UserDefaultsUtil.set(value: value, forKey: .pasteboardChangeCount)
    }

    static func clear() {
        UIPasteboard.general.string = ""
    }

    static func save(value: String) {
        UIPasteboard.general.string = value
        HapticUtil.generateNotificationFeedback(style: .success)
    }
}

// MARK: UserDefaults
struct UserDefaultsUtil {
    static func value<T: Codable>(forKey key: AppUserDefaults) -> T? {
        UserDefaults.standard.value(forKey: key.rawValue) as? T
    }

    static func set(value: Any, forKey key: AppUserDefaults) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}

enum AppUserDefaults: String {
    case galleryHost
    case pasteboardChangeCount
}

// MARK: Notification
struct NotificationUtil {
    static func post(_ notification: AppNotification) {
        NotificationCenter.default.post(name: notification.name, object: nil)
    }
}

enum AppNotification: String {
    case appWidthDidChange
    case bypassesSNIFilteringDidChange
    case readingViewShouldHideStatusBar
}

extension AppNotification {
    var name: NSNotification.Name {
        .init(rawValue: rawValue)
    }
    var publisher: NotificationCenter.Publisher {
        name.publisher
    }
}

// MARK: Cookies
struct CookiesUtil {
    static var shouldFetchIgneous: Bool {
        let url = Defaults.URL.exhentai.safeURL()
        return !CookiesUtil.get(for: url, key: Defaults.Cookie.ipbMemberId).rawValue.isEmpty
        && !CookiesUtil.get(for: url, key: Defaults.Cookie.ipbPassHash).rawValue.isEmpty
        && CookiesUtil.get(for: url, key: Defaults.Cookie.igneous).rawValue.isEmpty
    }
    static func initializeCookie(from cookie: HTTPCookie, value: String) -> HTTPCookie {
        var properties = cookie.properties
        properties?[.value] = value
        return HTTPCookie(properties: properties ?? [:]) ?? HTTPCookie()
    }

    static func checkExistence(for url: URL, key: String) -> Bool {
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            var existence: HTTPCookie?
            cookies.forEach { cookie in
                guard cookie.name == key else { return }
                existence = cookie
            }
            return existence != nil
        } else {
            return false
        }
    }

    static func set(
        for url: URL, key: String, value: String, path: String = "/",
        expiresTime: TimeInterval = TimeInterval(60 * 60 * 24 * 365)
    ) {
        let expiredDate = Date(timeIntervalSinceNow: expiresTime)
        let properties: [HTTPCookiePropertyKey: Any] = [
            .path: path, .name: key, .value: value,
            .originURL: url, .expires: expiredDate
        ]
        if let cookie = HTTPCookie(properties: properties) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    static func setIgneous(for response: HTTPURLResponse) {
        guard let setString = response.allHeaderFields["Set-Cookie"] as? String else { return }
        setString.components(separatedBy: ", ")
            .flatMap { $0.components(separatedBy: "; ") }.forEach { value in
                [Defaults.URL.ehentai, Defaults.URL.exhentai].forEach { url in
                    [Defaults.Cookie.ipbMemberId, Defaults.Cookie.ipbPassHash, Defaults.Cookie.igneous].forEach { key in
                        guard !(url == Defaults.URL.ehentai && key == Defaults.Cookie.igneous),
                              let range = value.range(of: "\(key)=") else { return }
                        set(for: url.safeURL(), key: key, value: String(value[range.upperBound...]) )
                    }
                }
            }
    }
    static func removeYay() {
        remove(for: Defaults.URL.exhentai.safeURL(), key: "yay")
    }

    static func remove(for url: URL, key: String) {
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            cookies.forEach { cookie in
                guard cookie.name == key else { return }
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    static func clearAll() {
        if let historyCookies = HTTPCookieStorage.shared.cookies {
            historyCookies.forEach {
                HTTPCookieStorage.shared.deleteCookie($0)
            }
        }
    }

    static func edit(for url: URL, key: String, value: String) {
        var newCookie: HTTPCookie?
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            cookies.forEach { cookie in
                guard cookie.name == key else { return }
                newCookie = initializeCookie(from: cookie, value: value)
                remove(for: url, key: key)
            }
        }
        guard let cookie = newCookie else { return }
        HTTPCookieStorage.shared.setCookie(cookie)
    }

    static func get(for url: URL, key: String) -> CookieValue {
        var value = CookieValue(rawValue: "", localizedString: Defaults.Cookie.null.localized)

        guard let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty else { return value }

        cookies.forEach { cookie in
            guard let expiresDate = cookie.expiresDate, cookie.name == key && !cookie.value.isEmpty else { return }

            guard expiresDate > .now else {
                value = CookieValue(rawValue: "", localizedString: Defaults.Cookie.expired.localized)
                return
            }

            guard cookie.value != Defaults.Cookie.mystery else {
                value = CookieValue(rawValue: cookie.value, localizedString: Defaults.Cookie.mystery.localized)
                return
            }

            value = CookieValue(rawValue: cookie.value, localizedString: "")
        }

        return value
    }

    static func verify(for url: URL, isEx: Bool) -> Bool {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: url),
                !cookies.isEmpty else { return false }

        var igneous, memberID, passHash: String?

        cookies.forEach { cookie in
            guard let expiresDate = cookie.expiresDate, expiresDate > .now, !cookie.value.isEmpty else { return }

            if cookie.name == Defaults.Cookie.igneous && cookie.value != Defaults.Cookie.mystery {
                igneous = cookie.value
            }

            if cookie.name == Defaults.Cookie.ipbMemberId {
                memberID = cookie.value
            }

            if cookie.name == Defaults.Cookie.ipbPassHash {
                passHash = cookie.value
            }
        }

        if isEx {
            return igneous != nil && memberID != nil && passHash != nil
        } else {
            return memberID != nil && passHash != nil
        }
    }
}

// MARK: URL
struct URLUtil {
    private static func checkIfHandleable(url: URL) -> Bool {
        (url.absoluteString.contains(Defaults.URL.ehentai) || url.absoluteString.contains(Defaults.URL.exhentai))
            && url.pathComponents.count >= 4 && ["g", "s"].contains(url.pathComponents[1])
            && !url.pathComponents[2].isEmpty && !url.pathComponents[3].isEmpty
    }

    static func parseGID(url: URL, isGalleryURL: Bool) -> String {
        var gid = url.pathComponents[2]
        let token = url.pathComponents[3]
        if let range = token.range(of: "-"), isGalleryURL {
            gid = String(token[..<range.lowerBound])
        }
        return gid
    }

    static func handleURL(
        _ url: URL, handlesOutgoingURL: Bool = false,
        completion: (Bool, URL?, Int?, String?) -> Void
    ) {
        guard checkIfHandleable(url: url) else {
            if handlesOutgoingURL {
                UIApplication.shared.open(url, options: [:])
            }
            completion(false, nil, nil, nil)
            return
        }

        let token = url.pathComponents[3]
        if let range = token.range(of: "-") {
            let pageIndex = Int(token[range.upperBound...])
            completion(true, url, pageIndex, nil)
            return
        }

        if let range = url.absoluteString.range(of: url.pathComponents[3] + "/") {
            let commentField = String(url.absoluteString[range.upperBound...])
            if let range = commentField.range(of: "#c") {
                let commentID = String(commentField[range.upperBound...])
                completion(false, url, nil, commentID)
                return
            }
        }

        completion(false, url, nil, nil)
    }
}

// MARK: File
struct FileUtil {
    static var documentDirectory: URL? {
        try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
    }

    static var logsDirectoryURL: URL? {
        documentDirectory?.appendingPathComponent(
            Defaults.FilePath.logs
        )
    }
}
