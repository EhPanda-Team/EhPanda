import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

// Settings, the Settings pages and the app-wide presentations (19-08).
extension ScenarioCatalog {
    static var settings: [String: ScenarioFactory] {
        [settingsRoot].reduce(into: [:]) { result, group in
            result.merge(group) { first, _ in first }
        }
    }

    private static var settingsRoot: [String: ScenarioFactory] {
        typealias Page = SettingsScenarios
        return [
            "settings-root": .init(make: { Page.settings([]) }),
            "settings-account-signed-in": .init(make: { Page.account(confirmingLogout: false) }),
            "settings-account-signed-out": .init(signedIn: false, make: { Page.account(confirmingLogout: false) }),
            "settings-account-logout-confirmation": .init(make: { Page.account(confirmingLogout: true) }),
            "blocked-users-filled": .init(make: { Page.blockedUsers(filled: true) }),
            "blocked-users-empty": .init(make: { Page.blockedUsers(filled: false) }),
            "settings-login-empty": .init(signedIn: false, make: { Page.login(.empty) }),
            "settings-login-filled": .init(
                signedIn: false, make: { Page.login(.filled) }, interact: LibraryScenarios.holdCaret
            ),
            "settings-login-error": .init(signedIn: false, make: { Page.login(.error) })
        ]
    }
}

@MainActor
enum SettingsScenarios {
    // MARK: Settings stack

    /// The Settings tab: its root, with `pages` pushed on its stack as the root's rows and the pages' own links push
    /// them. Each `actions` entry is sent to the page at its index once the stack is built, as the page's own
    /// presentation or a user's tap on it would send it.
    static func settings(_ pages: [SettingPath.State], actions: [(Int, SettingPath.Action)] = []) -> AnyView {
        var state = SettingReducer.State()
        state.path = StackState(pages)
        let store = Store(initialState: state, reducer: SettingReducer.init)
        let ids = Array(store.withState(\.path.ids))
        for (index, action) in actions {
            guard let id = ids.dropFirst(index).first else { continue }
            store.send(.path(.element(id: id, action: action)))
        }
        return AnyView(SettingView(store: store))
    }

    /// Account, loaded as the Settings stack loads it when the row is tapped; signed in or out follows the
    /// scenario's cookie client. With `confirmingLogout`, Log Out has been tapped.
    static func account(confirmingLogout: Bool) -> AnyView {
        var actions: [(Int, SettingPath.Action)] = [(0, .account(.onPresented))]
        if confirmingLogout {
            actions.append((0, .account(.logoutButtonTapped)))
        }
        return settings([.account(.init())], actions: actions)
    }

    /// Blocked Users over Account, with the synthetic members blocked or with none.
    static func blockedUsers(filled: Bool) -> AnyView {
        if filled {
            @Shared(.blockedCommentUsers) var blockedUsers
            $blockedUsers.withLock { users in
                for member in SettingsFixtures.blockedMembers {
                    users.block(memberID: member.memberID, name: member.name)
                }
            }
        }
        return settings([.account(.init()), .blockedUsers(.init())], actions: [(0, .account(.onPresented))])
    }

    enum LoginState {
        case empty, filled, error
    }

    /// Login over Account, signed out. Filled: the synthetic name and password, with the name field focused. Error:
    /// the same form after the site refused it, as the reducer answers a refused sign-in (its error toast).
    ///
    /// Not captured by a matrix method: the page's backdrop is two waves drawn in `TimelineView(.animation)` from the
    /// wall clock, so it never stands still and the settle times out (frozen layers do not stop it). The factories
    /// stay registered for the inventory; 19-10 decides between a not-applicable rule and an app change.
    static func login(_ kind: LoginState) -> AnyView {
        var login = LoginReducer.State()
        if kind != .empty {
            login.username = SettingsFixtures.loginUsername
            login.password = SettingsFixtures.loginPassword
        }
        if kind == .filled {
            login.focusedField = .username
        }
        var actions: [(Int, SettingPath.Action)] = [(0, .account(.onPresented))]
        if kind == .error {
            actions.append((1, .login(.loginDone(.failure(.loginRejected(nil))))))
        }
        return settings([.account(.init()), .login(login)], actions: actions)
    }
}
