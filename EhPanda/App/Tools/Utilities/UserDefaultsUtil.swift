//
//  UserDefaultsUtil.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/02.
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
