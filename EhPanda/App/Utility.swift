//
//  Utility.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI
import Combine
import Kingfisher
import LocalAuthentication

public var isSameAccount: Bool {
    if let ehentai = URL(string: Defaults.URL.ehentai),
       let exhentai = URL(string: Defaults.URL.exhentai)
    {
        let ehUID = getCookieValue(
            url: ehentai,
            key: Defaults.Cookie.ipbMemberId
        ).rawValue
        let exUID = getCookieValue(
            url: exhentai,
            key: Defaults.Cookie.ipbMemberId
        ).rawValue

        if !ehUID.isEmpty && !exUID.isEmpty {
            return ehUID == exUID
        } else {
            return true
        }
    } else {
        return true
    }
}

public var didLogin: Bool {
    verifyCookies(url: Defaults.URL.ehentai.safeURL(), isEx: false)
        || verifyCookies(url: Defaults.URL.exhentai.safeURL(), isEx: true)
}

public var appVersion: String {
    Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "(null)"
}
public var appBuild: String {
    Bundle.main.object(
        forInfoDictionaryKey: "CFBundleVersion"
    ) as? String ?? "(null)"
}

public var exx: Bool {
    UserDefaults.standard.string(forKey: "entry") == "eLo8cLfAzfcub2sufyGd"
}

public var isPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

public var isPadWidth: Bool {
    windowW ?? screenW > 700
}

public var isLandscape: Bool {
    [.landscapeLeft, .landscapeRight]
        .contains(
            UIApplication.shared.windows.first?
                .windowScene?.interfaceOrientation
        )
}

public var isPortrait: Bool {
    [.portrait, .portraitUpsideDown]
        .contains(
            UIApplication.shared.windows.first?
                .windowScene?.interfaceOrientation
        )
}

public var windowW: CGFloat? {
    if let width = absoluteWindowW,
       let height = absoluteWindowH
    {
        return min(width, height)
    } else {
        return nil
    }
}

public var windowH: CGFloat? {
    if let width = absoluteWindowW,
       let height = absoluteWindowH
    {
        return max(width, height)
    } else {
        return nil
    }
}

public var screenW: CGFloat {
    min(absoluteScreenW, absoluteScreenH)
}

public var screenH: CGFloat {
    max(absoluteScreenW, absoluteScreenH)
}

public var absoluteWindowW: CGFloat? {
    UIApplication.shared.windows.first?.frame.size.width
}

public var absoluteWindowH: CGFloat? {
    UIApplication.shared.windows.first?.frame.size.height
}

public var absoluteScreenW: CGFloat {
    UIScreen.main.bounds.size.width
}

public var absoluteScreenH: CGFloat {
    UIScreen.main.bounds.size.height
}

public var galleryType: GalleryType {
    let rawValue = UserDefaults
        .standard
        .string(forKey: "GalleryType") ?? ""
    return GalleryType(rawValue: rawValue) ?? .ehentai
}

public var vcsCount: Int {
    guard let navigationVC = UIApplication
            .shared.windows.first?
            .rootViewController?
            .children.first
            as? UINavigationController
    else { return -1 }

    return navigationVC.viewControllers.count
}

public var appIconType: IconType {
    if let alterName = UIApplication
        .shared.alternateIconName,
       let selection = IconType.allCases.filter(
        { alterName.contains($0.fileName ?? "") }
       ).first
       {
        return selection
    } else {
        return .default
    }
}

// MARK: Tools
public func clearPasteboard() {
    UIPasteboard.general.string = ""
}

public func saveToPasteboard(_ value: String) {
    UIPasteboard.general.string = value
    notificFeedback(style: .success)
}

public func getPasteboardLink() -> URL? {
    if UIPasteboard.general.hasURLs {
        return UIPasteboard.general.url
    } else {
        return nil
    }
}

public func impactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style)
        .impactOccurred()
}
public func notificFeedback(style: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(style)
}

public func localAuth(
    reason: String,
    successAction: (() -> Void)? = nil,
    failureAction: (() -> Void)? = nil,
    passcodeNotFoundAction: (() -> Void)? = nil
) {
    let context = LAContext()
    var error: NSError?

    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason.localized()
        ) { success, _ in
            DispatchQueue.main.async {
                if success, let action = successAction {
                    action()
                } else if let action = failureAction {
                    action()
                }
            }
        }
    } else if let action = passcodeNotFoundAction {
        action()
    }
}

public func isValidDetailURL(url: URL) -> Bool {
    (url.absoluteString.contains(Defaults.URL.ehentai)
        || url.absoluteString.contains(Defaults.URL.exhentai))
        && url.pathComponents.count >= 4
        && url.pathComponents[1] == "g"
        && !url.pathComponents[2].isEmpty
        && !url.pathComponents[3].isEmpty
}

public func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}

// MARK: UserDefaults
public func setEntry(_ token: String?) {
    UserDefaults.standard.set(token, forKey: "entry")
}

public func setGalleryType(_ type: GalleryType) {
    UserDefaults.standard.set(type.rawValue, forKey: "GalleryType")
}

public func clearGalleryType() {
    UserDefaults.standard.set(nil, forKey: "GalleryType")
}

public func getPasteboardChangeCount() -> Int? {
    UserDefaults.standard.integer(forKey: "PasteboardChangeCount")
}

public func setPasteboardChangeCount(_ value: Int) {
    UserDefaults.standard.set(value, forKey: "PasteboardChangeCount")
}

public func postSlideMenuShouldCloseNotification() {
    NotificationCenter.default.post(
        name: NSNotification.Name("SlideMenuShouldClose"),
        object: nil
    )
}

public func postAppWidthDidChangeNotification() {
    NotificationCenter.default.post(
        name: NSNotification.Name("AppWidthDidChange"),
        object: nil
    )
}

public func postDetailViewOnDisappearNotification() {
    NotificationCenter.default.post(
        name: NSNotification.Name("DetailViewOnDisappear"),
        object: nil
    )
}

// MARK: Storage Management
public func readableUnit<I: BinaryInteger>(bytes: I) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    return formatter.string(fromByteCount: Int64(bytes))
}

public func browsingCaches() -> String {
    guard let fileURL = FileManager
            .default
            .urls(
                for: .cachesDirectory,
                in: .userDomainMask
            )
            .first?
            .appendingPathComponent(
                "cachedList.json"
            ),
          let data = try? Data(
            contentsOf: fileURL
          )
    else { return "0 KB" }

    return readableUnit(bytes: data.count)
}

public func clearCookies() {
    if let historyCookies = HTTPCookieStorage.shared.cookies {
        historyCookies.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }
}

// MARK: Thread
public func executeMainAsync(_ closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

public func executeMainAsync(_ delay: DispatchTimeInterval, _ closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        closure()
    }
}

public func executeAsync(_ closure: @escaping () -> Void) {
    DispatchQueue.global().async {
        closure()
    }
}

public func executeSync(_ closure: @escaping () -> Void) {
    DispatchQueue.global().sync {
        closure()
    }
}

// MARK: Cookies
public func initiateCookieFrom(_ cookie: HTTPCookie, value: String) -> HTTPCookie {
    var properties = cookie.properties
    properties?[.value] = value
    return HTTPCookie(properties: properties ?? [:]) ?? HTTPCookie()
}

public func checkExistence(url: URL, key: String) -> Bool {
    if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
        var existence: HTTPCookie?
        cookies.forEach { cookie in
            if cookie.name == key {
                existence = cookie
            }
        }
        return existence != nil
    } else {
        return false
    }
}

public func setCookie(url: URL, key: String, value: String) {
    let expiredDate = Date(
        timeIntervalSinceNow:
            TimeInterval(60 * 60 * 24 * 365)
    )
    let properties: [HTTPCookiePropertyKey: Any] =
    [
        .path: "/",
        .name: key,
        .value: value,
        .originURL: url,
        .expires: expiredDate
    ]
    if let cookie = HTTPCookie(properties: properties) {
        HTTPCookieStorage.shared.setCookie(cookie)
    }
}

public func removeCookie(url: URL, key: String) {
    if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
        cookies.forEach { cookie in
            if cookie.name == key {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
}

public func editCookie(url: URL, key: String, value: String) {
    var newCookie: HTTPCookie?
    if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
        cookies.forEach { cookie in
            if cookie.name == key
            {
                newCookie = initiateCookieFrom(cookie, value: value)
                removeCookie(url: url, key: key)
            }
        }
    }

    guard let cookie = newCookie else { return }
    HTTPCookieStorage.shared.setCookie(cookie)
}

public func getCookieValue(url: URL, key: String) -> CookieValue {
    var value = CookieValue(
        rawValue: "",
        localizedString: Defaults.Cookie.null.localized()
    )

    guard let cookies =
            HTTPCookieStorage
            .shared
            .cookies(for: url),
          !cookies.isEmpty
    else { return value }

    let date = Date()

    cookies.forEach { cookie in
        guard let expiresDate = cookie.expiresDate
        else { return }

        if cookie.name == key
            && !cookie.value.isEmpty
        {
            if expiresDate > date {
                if cookie.value == Defaults.Cookie.mystery {
                    value = CookieValue(
                        rawValue: cookie.value,
                        localizedString: Defaults.Cookie.mystery.localized()
                    )
                } else {
                    value = CookieValue(
                        rawValue: cookie.value,
                        localizedString: ""
                    )
                }
            } else {
                value = CookieValue(
                    rawValue: "",
                    localizedString: Defaults.Cookie.expired.localized()
                )
            }
        }
    }

    return value
}

func verifyCookies(url: URL, isEx: Bool) -> Bool {
    guard let cookies =
            HTTPCookieStorage
            .shared
            .cookies(for: url),
          !cookies.isEmpty
    else { return false }

    let date = Date()
    var igneous: String?
    var memberID: String?
    var passHash: String?

    cookies.forEach { cookie in
        guard let expiresDate = cookie.expiresDate
        else { return }

        if cookie.name == Defaults.Cookie.igneous
            && !cookie.value.isEmpty
            && cookie.value != Defaults.Cookie.mystery
            && expiresDate > date
        {
            igneous = cookie.value
        }

        if cookie.name == Defaults.Cookie.ipbMemberId
            && !cookie.value.isEmpty
            && expiresDate > date
        {
            memberID = cookie.value
        }

        if cookie.name == Defaults.Cookie.ipbPassHash
            && !cookie.value.isEmpty
            && expiresDate > date
        {
            passHash = cookie.value
        }
    }

    if isEx {
        return igneous != nil && memberID != nil && passHash != nil
    } else {
        return memberID != nil && passHash != nil
    }
}

// MARK: Image Modifier
struct KFImageModifier: ImageModifier {
    let targetScale: CGFloat

    func modify(_ image: KFCrossPlatformImage) -> KFCrossPlatformImage {
        let originW = image.size.width
        let originH = image.size.height
        let scale = originW / originH

        let targetW = originW * targetScale

        if abs(targetScale - scale) <= 0.2 {
            return image
                .kf
                .resize(
                    to: CGSize(
                        width: targetW,
                        height: originH
                    ),
                    for: .aspectFill
                )
        } else {
            return image
        }
    }
}
