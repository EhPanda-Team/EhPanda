//
//  UserDefaultsUtil.swift
//  EhPanda
//

import Foundation

struct UserDefaultsUtil {
    static func value<T: Codable>(forKey key: AppUserDefaults) -> T? {
        UserDefaults.standard.value(forKey: key.rawValue) as? T
    }
}

enum AppUserDefaults: String {
    case galleryHost
    case clipboardChangeCount
}
