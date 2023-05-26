//
//  AppLockReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/05.
//

import SwiftUI
import ComposableArchitecture

struct AppLockReducer: ReducerProtocol {
    struct State: Equatable {
        @BindingState var blurRadius: Double = 0
        var becameInactiveDate: Date?
        var isAppLocked = false

        // Setting `blurRadius` to zero causes the NavigationBar to collapse
        mutating func setBlurRadius(_ radius: Double) {
            blurRadius = max(0.00001, radius)
        }
    }

    enum Action: Equatable {
        case onBecomeActive(Int, Double)
        case onBecomeInactive(Double)
        case lockApp(Double)
        case unlockApp
        case authorize
        case authorizeDone(Bool)
    }

    @Dependency(\.authorizationClient) private var authorizationClient

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onBecomeActive(let threshold, let blurRadius):
                if let date = state.becameInactiveDate, threshold >= 0,
                   Date().timeIntervalSince(date) > Double(threshold)
                {
                    return .merge(
                        .init(value: .authorize),
                        .init(value: .lockApp(blurRadius))
                    )
                } else {
                    return .init(value: .unlockApp)
                }

            case .onBecomeInactive(let blurRadius):
                state.setBlurRadius(blurRadius)
                state.becameInactiveDate = .now
                return .none

            case .lockApp(let blurRadius):
                state.setBlurRadius(blurRadius)
                state.isAppLocked = true
                return .none

            case .unlockApp:
                state.setBlurRadius(0)
                state.isAppLocked = false
                state.becameInactiveDate = nil
                return .none

            case .authorize:
                return authorizationClient.localAuthroize(L10n.Localizable.LocalAuthorization.reason)
                    .map(Action.authorizeDone)

            case .authorizeDone(let isSucceeded):
                return isSucceeded ? .init(value: .unlockApp) : .none
            }
        }
    }
}
