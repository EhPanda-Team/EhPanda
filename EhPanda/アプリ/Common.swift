//
//  Common.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI
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
    guard let url = URL(string: Defaults.URL.loginVerify),
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

extension String {
    func lString() -> String {
        NSLocalizedString(self, comment: "")
    }
}

extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
