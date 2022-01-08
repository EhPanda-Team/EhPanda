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
