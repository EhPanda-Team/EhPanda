//
//  AppUtil.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/02.
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
