//
//  SharedDataReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import ComposableArchitecture

let sharedDataReducer = Reducer<SharedData, SharedDataAction, AnyEnvironment> { state, action, _ in
    Logger.info(action)
    switch action {
    case .didFinishLaunching:
        var effects = [Effect<SharedDataAction, Never>]()

        if CookiesUtil.shouldFetchIgneous {
            effects.append(.init(value: .fetchIgneous))
        }
        if AuthorizationUtil.didLogin {
            effects.append(contentsOf: [
                .init(value: .fetchUserInfo),
                .init(value: .fetchFavoriteNames),
                .init(value: .fetchEhProfileIndex)
            ])
        }
        if let preferredLanguage = Locale.preferredLanguages.first {
            effects.append(.init(value: .fetchTagTranslator(preferredLanguage)))
        }

        return effects.isEmpty ? .none : .merge(effects)

    case .createDefaultEhProfile:
        return EhProfileRequest(action: .create, name: "EhPanda").effect.fireAndForget()

    case .fetchIgneous:
        return IgneousRequest().effect.fireAndForget()

    case .fetchUserInfo:
        let uid = state.user.apiuid
        guard !uid.isEmpty else { return .none }
        return UserInfoRequest(uid: uid).effect.map(SharedDataAction.fetchUserInfoDone)

    case .fetchUserInfoDone(let result):
        if case .success(let user) = result {
            state.user = user
        }
        return .none

    case .fetchTagTranslator(let preferredLanguage):
        guard let language = TranslatableLanguage.allCases.compactMap({ lang in
                  preferredLanguage.contains(lang.languageCode) ? lang : nil
              }).first
        else {
            state.tagTranslator = TagTranslator()
            state.setting.translatesTags = false
            return .none
        }
        if state.tagTranslator.language != language {
            state.tagTranslator = TagTranslator()
        }

        let updatedDate = state.tagTranslator.updatedDate
        return TagTranslatorRequest(language: language, updatedDate: updatedDate)
            .effect.map(SharedDataAction.fetchTagTranslatorDone)

    case .fetchTagTranslatorDone(let result):
        return .none

    case .fetchEhProfileIndex:
        return VerifyEhProfileRequest().effect.map(SharedDataAction.fetchEhProfileIndexDone)

    case .fetchEhProfileIndexDone(let result):
        if case .success(let (profileValue, profileNotFound)) = result {
            if let profileValue = profileValue {
                let hostURL = Defaults.URL.host
                let profileValueString = String(profileValue)
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
        return FavoriteNamesRequest().effect.map(SharedDataAction.fetchFavoriteNamesDone)

    case .fetchFavoriteNamesDone(let result):
        if case .success(let names) = result {
            state.user.favoriteNames = names
        }
        return .none
    }
}
