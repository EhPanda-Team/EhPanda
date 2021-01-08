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

public func didLogin() -> Bool {
    guard let url = URL(string: Defaults.URL.ehentai),
          let cookies = HTTPCookieStorage.shared.cookies(for: url),
          !cookies.isEmpty else { return false }
    
    var passValue: String?
    var passExpires: Date?
    cookies.forEach { cookie in
        if cookie.name == "ipb_pass_hash" {
            passValue = cookie.value
            passExpires = cookie.expiresDate
        }
    }
    
    guard let value = passValue,
          let expires = passExpires,
          !value.isEmpty,
          expires > Date()
    else {
        cleanCookies()
        return false
    }
    
    return true
}

public var exx: Bool {
    UserDefaults.standard.string(forKey: "entry") == "Rra3MKpjKBJLgraHqt9t"
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
    return readableUnit(bytes: Int64(bytes))
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

public func cleanCookies() {
    if let historyCookies = HTTPCookieStorage.shared.cookies {
        historyCookies.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }
}

public func executeMainAsyncally(_ closure: @escaping (()->())) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

public func executeAsyncally(_ closure: @escaping (()->())) {
    DispatchQueue.global().async {
        closure()
    }
}

public func executeSyncally(_ closure: @escaping (()->())) {
    DispatchQueue.global().sync {
        closure()
    }
}
