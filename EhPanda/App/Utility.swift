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

var galleryHost: GalleryHost {
    let rawValue = UserDefaults
        .standard
        .string(forKey: "GalleryHost") ?? ""
    return GalleryHost(rawValue: rawValue) ?? .ehentai
}

var appIconType: IconType {
    var alterName: String?
    dispatchMainSync {
        alterName = UIApplication
            .shared.alternateIconName
    }
    if let iconName = alterName,
       let selection = IconType.allCases.filter(
        { iconName.contains($0.fileName ?? "") }
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
            localizedReason: reason.localized
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    successAction?()
                } else {
                    failureAction?()
                }
            }
        }
    } else {
        passcodeNotFoundAction?()
    }
}

// MARK: Device
var isPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

var isPadWidth: Bool {
    windowW > 768
}

var isSEWidth: Bool {
    windowW <= 320
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

var windowW: CGFloat {
    min(absWindowW, absWindowH)
}

var windowH: CGFloat {
    max(absWindowW, absWindowH)
}

var screenW: CGFloat {
    min(absScreenW, absScreenH)
}

var screenH: CGFloat {
    max(absScreenW, absScreenH)
}

var absWindowW: CGFloat {
    keyWindow?.frame.size.width ?? absScreenW
}

var absWindowH: CGFloat {
    keyWindow?.frame.size.height ?? absScreenH
}

var absScreenW: CGFloat {
    UIScreen.main.bounds.size.width
}

var absScreenH: CGFloat {
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
var opacityTransition: AnyTransition {
    AnyTransition.opacity.animation(.default)
}
var isUnitTesting: Bool {
    ProcessInfo.processInfo.environment[
      "XCTestConfigurationFilePath"
    ] != nil
}
func clearPasteboard() {
    UIPasteboard.general.string = ""
}

func saveToPasteboard(value: String) {
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

func isHandleableURL(url: URL) -> Bool {
    (url.absoluteString.contains(Defaults.URL.ehentai)
        || url.absoluteString.contains(Defaults.URL.exhentai))
        && url.pathComponents.count >= 4
        && ["g", "s"].contains(url.pathComponents[1])
        && !url.pathComponents[2].isEmpty
        && !url.pathComponents[3].isEmpty
}

func parseGID(url: URL, isGalleryURL: Bool) -> String {
    var gid = url.pathComponents[2]
    let token = url.pathComponents[3]
    if let range = token.range(of: "-"), isGalleryURL {
        gid = String(token[..<range.lowerBound])
    }
    return gid
}

func handleIncomingURL(
    _ url: URL, handlesOutgoingURL: Bool = false,
    completion: (Bool, URL?, Int?, String?) -> Void
) {
    guard isHandleableURL(url: url) else {
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

@available(*, deprecated, message: "Use @FocusState instead.")
func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}

func dispatchMainSync(execute work: () -> Void) {
    if Thread.isMainThread {
        work()
    } else {
        DispatchQueue.main.sync(execute: work)
    }
}

func presentActivityVC(items: [Any]) {
    let activityVC = UIActivityViewController(
        activityItems: items,
        applicationActivities: nil
    )
    if isPad {
        activityVC.popoverPresentationController?.sourceView = keyWindow
        activityVC.popoverPresentationController?.sourceRect = CGRect(
            x: screenW, y: 0,
            width: 200, height: 200
        )
    }
    activityVC.modalPresentationStyle = .overFullScreen
    keyWindow?.rootViewController?
        .present(
            activityVC,
            animated: true,
            completion: nil
        )
    impactFeedback(style: .light)
}

// MARK: FileManager
var documentDirectory: URL? {
    try? FileManager.default.url(
        for: .documentDirectory, in: .userDomainMask,
           appropriateFor: nil, create: true
    )
}
var logsDirectoryURL: URL? {
    documentDirectory?.appendingPathComponent(
        Defaults.FilePath.logs
    )
}

// MARK: UserDefaults
var pasteboardChangeCount: Int? {
    UserDefaults.standard.integer(forKey: "PasteboardChangeCount")
}

func setGalleryHost(with host: GalleryHost) {
    UserDefaults.standard.set(host.rawValue, forKey: "GalleryHost")
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

func postReadingViewShouldHideStatusBarNotification() {
    NotificationCenter.default.post(
        name: NSNotification.Name("ReadingViewShouldHideStatusBar"),
        object: nil
    )
}

func postBypassesSNIFilteringDidChangeNotification() {
    NotificationCenter.default.post(
        name: NSNotification.Name("BypassesSNIFilteringDidChange"),
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
func initializeCookieFrom(cookie: HTTPCookie, value: String) -> HTTPCookie {
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

func setCookie(response: HTTPURLResponse) {
    guard let setString = response.allHeaderFields["Set-Cookie"] as? String else { return }
    setString.components(separatedBy: ", ")
        .flatMap { $0.components(separatedBy: "; ") }
        .forEach { value in
            [Defaults.URL.ehentai, Defaults.URL.exhentai].forEach { url in
                [
                    Defaults.Cookie.ipbMemberId,
                    Defaults.Cookie.ipbPassHash,
                    Defaults.Cookie.igneous
                ].forEach { key in
                    guard !(
                        url == Defaults.URL.ehentai
                        && key == Defaults.Cookie.igneous
                    ) else { return }

                    if let range = value.range(of: "\(key)=") {
                        setCookie(
                            url: url.safeURL(),
                            key: key,
                            value: String(value[range.upperBound...])
                        )
                    }
                }
            }
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
                newCookie = initializeCookieFrom(cookie: cookie, value: value)
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
        localizedString: Defaults.Cookie.null.localized
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
                        localizedString: Defaults.Cookie.mystery.localized
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
                    localizedString: Defaults.Cookie.expired.localized
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
