//
//  AppLockStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/05.
//

import SwiftUI
import ComposableArchitecture

struct AppLockState: Equatable {
    @BindableState var blurRadius: Double = 0
    var becomeInactiveDate: Date?
    var isAppLocked = false

    // Setting `blurRadius` to zero causes the NavigationBar to collapse
    mutating func setBlurRadius(_ radius: Double) {
        blurRadius = max(0.00001, radius)
    }
}

enum AppLockAction {
    case authorize
    case authorizeDone(Bool)
}

struct AppLockEnvironment {
    let authorizationClient: AuthorizationClient
}

let appLockReducer = Reducer<AppLockState, AppLockAction, AppLockEnvironment> { state, action, environment in
    switch action {
    case .authorize:
        return environment.authorizationClient
            .localAuth("The App has been locked due to the auto-lock expiration.")
            .map(AppLockAction.authorizeDone)

    case .authorizeDone(let isSucceeded):
        if isSucceeded {
            state.setBlurRadius(0)
            state.isAppLocked = false
            state.becomeInactiveDate = nil
        }
        return .none
    }
}
