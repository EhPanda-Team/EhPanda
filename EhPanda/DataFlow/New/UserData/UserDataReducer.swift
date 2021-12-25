//
//  UserDataReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import ComposableArchitecture

let userDataReducer = Reducer<UserData, UserDataAction, AnyEnvironment> { state, action, _ in
    Logger.info(action)
    switch action {
    case .didFinishLaunching:
        CookiesUtil.removeYay()
        return .merge(
            CookiesUtil.shouldFetchIgneous ? .init(value: .fetchIgneous) : .none,
            .init(value: .fetchUserInfo), .init(value: .fetchFavoriteNames), .init(value: .fetchEhProfileIndex)
        )
    case .createDefaultEhProfile:
        return EhProfileRequest(action: .create, name: "EhPanda").effect.fireAndForget()
    case .fetchIgneous:
        return IgneousRequest().effect.fireAndForget()
    case .fetchUserInfo:
        let uid = state.user.apiuid
        guard !uid.isEmpty else { return .none }
        return UserInfoRequest(uid: uid).effect.map(UserDataAction.fetchUserInfoDone)
    case .fetchUserInfoDone(let result):
        if case .success(let user) = result {
            state.user = user
        }
        return .none
    case .fetchEhProfileIndex:
        return VerifyEhProfileRequest().effect.map(UserDataAction.fetchEhProfileIndexDone)
    case .fetchEhProfileIndexDone(let result):
        if case .success(let (profileValue, profileNotFound)) = result {
            if let profileValue = profileValue {
                let profileValueString = String(profileValue)
                let hostURL = Defaults.URL.host.safeURL()
                let selectedProfileKey = Defaults.Cookie.selectedProfile

                let cookieValue = CookiesUtil.get(for: hostURL, key: selectedProfileKey)
                if cookieValue.rawValue != profileValueString {
                    CookiesUtil.set(for: hostURL, key: selectedProfileKey, value: profileValueString)
                }
            } else if profileNotFound {
                return .init(value: .createDefaultEhProfile)
            } else {
                Logger.error("Found profile but failed in parsing value.")
            }
        }
        return .none
    case .fetchFavoriteNames:
        return FavoriteNamesRequest().effect.map(UserDataAction.fetchFavoriteNamesDone)
    case .fetchFavoriteNamesDone(let result):
        if case .success(let names) = result {
            state.user.favoriteNames = names
        }
        return .none
    }
}
