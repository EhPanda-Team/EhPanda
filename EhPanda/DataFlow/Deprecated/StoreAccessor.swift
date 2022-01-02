//
//  StoreAccessor.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/05/04.
//

import SwiftUI

protocol StoreAccessor {
    var store: DeprecatedStore { get }
}

// MARK: AppState
extension StoreAccessor {
    var appState: DeprecatedAppState {
        store.appState
    }
    var environment: DeprecatedAppState.Environment {
        appState.environment
    }
    var settings: DeprecatedAppState.Settings {
        appState.settings
    }
    var homeInfo: DeprecatedAppState.HomeInfo {
        appState.homeInfo
    }
    var detailInfo: DeprecatedAppState.DetailInfo {
        appState.detailInfo
    }
    var contentInfo: DeprecatedAppState.ContentInfo {
        appState.contentInfo
    }
}

// MARK: Environment
extension StoreAccessor {
    var isAppUnlocked: Bool {
        environment.isAppUnlocked
    }
    var viewControllersCount: Int {
        environment.viewControllersCount
    }
}

// MARK: Settings
extension StoreAccessor {
    var user: User {
        settings.user
    }
    var currentGP: String? {
        user.currentGP
    }
    var currentCredits: String? {
        user.currentCredits
    }
    var favoriteNames: [Int: String]? {
        user.favoriteNames
    }
    var setting: Setting {
        settings.setting
    }
    var searchFilter: Filter {
        settings.searchFilter
    }
    var globalFilter: Filter {
        settings.globalFilter
    }
    var accentColor: Color {
        setting.accentColor
    }
    var appIconType: IconType {
        setting.appIconType
    }
    var backgroundBlurRadius: Double {
        setting.backgroundBlurRadius
    }
    var autoLockPolicy: AutoLockPolicy {
        setting.autoLockPolicy
    }
    var detectsLinksFromPasteboard: Bool {
        setting.detectsLinksFromPasteboard
    }
}
