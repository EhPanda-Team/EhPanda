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

// MARK: Account
var isSameAccount: Bool {
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

var didLogin: Bool {
    verifyCookies(url: Defaults.URL.ehentai.safeURL(), isEx: false)
        || verifyCookies(url: Defaults.URL.exhentai.safeURL(), isEx: true)
}

// MARK: App
var appVersion: String {
    Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "(null)"
}
var appBuild: String {
    Bundle.main.object(
        forInfoDictionaryKey: "CFBundleVersion"
    ) as? String ?? "(null)"
}

var galleryType: GalleryType {
    let rawValue = UserDefaults
        .standard
        .string(forKey: "GalleryType") ?? ""
    return GalleryType(rawValue: rawValue) ?? .ehentai
}

var appIconType: IconType {
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

func localAuth(
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

// MARK: Device
var isPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

var isPadWidth: Bool {
    windowW ?? screenW > 700
}

var viewControllersCount: Int {
    if let navigationVC = keyWindow?
        .rootViewController?
        .children.first
        as? UINavigationController
    {
        return navigationVC
            .viewControllers.count
    }
    return -1
}

var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
        .filter({ $0.activationState == .foregroundActive })
        .compactMap({ $0 as? UIWindowScene }).last?
        .windows.filter({ $0.isKeyWindow }).last
}

var isLandscape: Bool {
    [.landscapeLeft, .landscapeRight]
        .contains(
            keyWindow?.windowScene?
                .interfaceOrientation
        )
}

var isPortrait: Bool {
    [.portrait, .portraitUpsideDown]
        .contains(
            keyWindow?.windowScene?
                .interfaceOrientation
        )
}

var windowW: CGFloat? {
    if let width = absoluteWindowW,
       let height = absoluteWindowH
    {
        return min(width, height)
    } else {
        return nil
    }
}

var windowH: CGFloat? {
    if let width = absoluteWindowW,
       let height = absoluteWindowH
    {
        return max(width, height)
    } else {
        return nil
    }
}

var screenW: CGFloat {
    min(absoluteScreenW, absoluteScreenH)
}

var screenH: CGFloat {
    max(absoluteScreenW, absoluteScreenH)
}

var absoluteWindowW: CGFloat? {
    keyWindow?.frame.size.width
}

var absoluteWindowH: CGFloat? {
    keyWindow?.frame.size.height
}

var absoluteScreenW: CGFloat {
    UIScreen.main.bounds.size.width
}

var absoluteScreenH: CGFloat {
    UIScreen.main.bounds.size.height
}

func impactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style)
        .impactOccurred()
}
func notificFeedback(style: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(style)
}

// MARK: Tools
var animatedTransition: AnyTransition {
    AnyTransition.opacity.animation(.default)
}
func clearPasteboard() {
    UIPasteboard.general.string = ""
}

func saveToPasteboard(_ value: String) {
    UIPasteboard.general.string = value
    notificFeedback(style: .success)
}

func getPasteboardLink() -> URL? {
    if UIPasteboard.general.hasURLs {
        return UIPasteboard.general.url
    } else {
        return nil
    }
}

func isValidDetailURL(url: URL) -> Bool {
    (url.absoluteString.contains(Defaults.URL.ehentai)
        || url.absoluteString.contains(Defaults.URL.exhentai))
        && url.pathComponents.count >= 4
        && url.pathComponents[1] == "g"
        && !url.pathComponents[2].isEmpty
        && !url.pathComponents[3].isEmpty
}

@available(*, deprecated, message: "Use @FocusState instead.")
func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}

func copyHTMLIfNeeded(_ html: String?) {
    if isDebugModeOn, let value = html {
        saveToPasteboard(value)
    }
}

func getStringWithComma(_ value: Int) -> String? {
    let decimalFormatter = NumberFormatter()
    decimalFormatter.numberStyle = .decimal
    decimalFormatter.locale = Locale.current

    let string = decimalFormatter.string(
        from: value as NSNumber
    )
    return string
}

// MARK: UserDefaults
let isDebugModeOn = UserDefaults.standard.bool(forKey: "debugModeOn")

let isTokenMatched = UserDefaults.standard.string(forKey: "token") == "r9vG3pcs2mT9MoWj2ZJR"

var pasteboardChangeCount: Int? {
    UserDefaults.standard.integer(forKey: "PasteboardChangeCount")
}

func setToken(with token: String?) {
    UserDefaults.standard.set(token, forKey: "token")
}

func setDebugMode(with debugModeOn: Bool) {
    UserDefaults.standard.set(debugModeOn, forKey: "debugModeOn")
}

func setGalleryType(with type: GalleryType) {
    UserDefaults.standard.set(type.rawValue, forKey: "GalleryType")
}

func clearGalleryType() {
    UserDefaults.standard.set(nil, forKey: "GalleryType")
}

func setPasteboardChangeCount(with value: Int) {
    UserDefaults.standard.set(value, forKey: "PasteboardChangeCount")
}

func postSlideMenuShouldCloseNotification() {
    NotificationCenter.default.post(
        name: NSNotification.Name("SlideMenuShouldClose"),
        object: nil
    )
}

func postAppWidthDidChangeNotification() {
    NotificationCenter.default.post(
        name: NSNotification.Name("AppWidthDidChange"),
        object: nil
    )
}

func postDetailViewOnDisappearNotification() {
    NotificationCenter.default.post(
        name: NSNotification.Name("DetailViewOnDisappear"),
        object: nil
    )
}

// MARK: Storage Management
func readableUnit<I: BinaryInteger>(bytes: I) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    return formatter.string(fromByteCount: Int64(bytes))
}

func browsingCaches() -> String {
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

// MARK: Cookies
func initializeCookieFrom(_ cookie: HTTPCookie, value: String) -> HTTPCookie {
    var properties = cookie.properties
    properties?[.value] = value
    return HTTPCookie(properties: properties ?? [:]) ?? HTTPCookie()
}

func checkExistence(url: URL, key: String) -> Bool {
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

func setCookie(url: URL, key: String, value: String) {
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

func removeCookie(url: URL, key: String) {
    if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
        cookies.forEach { cookie in
            if cookie.name == key {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
}

func clearCookies() {
    if let historyCookies = HTTPCookieStorage.shared.cookies {
        historyCookies.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }
}

func editCookie(url: URL, key: String, value: String) {
    var newCookie: HTTPCookie?
    if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
        cookies.forEach { cookie in
            if cookie.name == key
            {
                newCookie = initializeCookieFrom(cookie, value: value)
                removeCookie(url: url, key: key)
            }
        }
    }

    guard let cookie = newCookie else { return }
    HTTPCookieStorage.shared.setCookie(cookie)
}

func getCookieValue(url: URL, key: String) -> CookieValue {
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

        let targetW = originH * targetScale

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
