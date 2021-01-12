//
//  Common.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI
import Combine
import SDWebImageSwiftUI

class Common {
    
}


public func ePrint(_ error: Error) {
    print("debugMark " + error.localizedDescription)
}

public func ePrint(_ string: String) {
    print("debugMark " + string)
}

public func ePrint(_ string: String?) {
    print("debugMark " + (string ?? "エラーの内容が解析できませんでした"))
}

public var didLogin: Bool {
    verifyCookies(url: URL(string: Defaults.URL.ehentai)!, isEx: false)
}
public var exAccess: Bool {
    verifyCookies(url: URL(string: Defaults.URL.exhentai)!, isEx: true)
}

public func getCookieValue(url: URL, cookieName: String) -> String? {
    guard let cookies =
            HTTPCookieStorage
            .shared
            .cookies(for: url),
          !cookies.isEmpty
    else { return nil }
    
    let date = Date()
    var value: String?
    
    cookies.forEach { cookie in
        guard let expiresDate = cookie.expiresDate
        else { return }
        
        if cookie.name == cookieName
            && !cookie.value.isEmpty
        {
            value = expiresDate > date
                ? cookie.value : "期限切れ"
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
                
        if cookie.name == "igneous"
            && !cookie.value.isEmpty
            && cookie.value != "mystery"
            && expiresDate > date
        {
            igneous = cookie.value
        }
        
        if cookie.name == "ipb_member_id"
            && !cookie.value.isEmpty
            && expiresDate > date
        {
            memberID = cookie.value
        }
        
        if cookie.name == "ipb_pass_hash"
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

public func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style)
        .impactOccurred()
}

public var exx: Bool {
    UserDefaults.standard.string(forKey: "entry") == "Rra3MKpjKBJLgraHqt9t"
}

public var isPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

public var galleryType: GalleryType {
    let rawValue = UserDefaults
        .standard
        .string(forKey: "GalleryType")
        ?? "E-Hentai"
    return GalleryType(rawValue: rawValue)!
}

public func readableUnit(bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    return formatter.string(fromByteCount: bytes)
}

public func diskImageCaches() -> String {
    let bytes = SDImageCache.shared.totalDiskSize()
    
    if bytes == 0 {
        return "0 KB"
    } else {
        return readableUnit(bytes: Int64(bytes))
    }
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
    
    return readableUnit(bytes: Int64(data.count))
}

public func clearCookies() {
    if let historyCookies = HTTPCookieStorage.shared.cookies {
        historyCookies.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }
}

public func executeMainAsync(_ closure: @escaping (()->())) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

public func executeMainAsync(_ delay: Double, _ closure: @escaping (()->())) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        closure()
    }
}

public func executeAsync(_ closure: @escaping (()->())) {
    DispatchQueue.global().async {
        closure()
    }
}

public func executeSync(_ closure: @escaping (()->())) {
    DispatchQueue.global().sync {
        closure()
    }
}
