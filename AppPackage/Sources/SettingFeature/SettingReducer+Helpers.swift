import Foundation
import AppModels
import ComposableArchitecture
import NetworkingFeature

extension SettingReducer {
    func handleLoadUserSettings(
        _ state: inout State, appEnv: AppEnv
    ) -> Effect<Action> {
        state.setting = appEnv.setting
        state.tagTranslator = appEnv.tagTranslator
        state.user = appEnv.user
        var effects: [Effect<Action>] = [
            .send(.syncAppIconType),
            .send(.loadUserSettingsDone),
            .send(.syncUserInterfaceStyle),
            .run { [state] _ in
                dfClient.setActive(state.setting.bypassesSNIFiltering)
            }
        ]
        if let value: String = userDefaultsClient.getValue(.galleryHost),
           let galleryHost = GalleryHost(rawValue: value) {
            state.setting.galleryHost = galleryHost
        }
        if cookieClient.shouldFetchIgneous {
            effects.append(.send(.fetchIgneous))
        }
        if cookieClient.didLogin {
            effects.append(contentsOf: [
                .send(.fetchUserInfo),
                .send(.fetchGreeting),
                .send(.fetchFavoriteCategories),
                .send(.fetchEhProfileIndex)
            ])
        }
        if state.setting.enablesTagsExtension {
            effects.append(.send(.fetchTagTranslator))
        }
        return .merge(effects)
    }

    func handleFetchGreeting(_ state: inout State) -> Effect<Action> {
        func verifyDate(with updateTime: Date?) -> Bool {
            guard let updateTime = updateTime else { return true }

            let currentTime = Date()
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = Defaults.DateFormat.greeting

            let currentTimeString = formatter.string(from: currentTime)
            if let currentDay = formatter.date(from: currentTimeString) {
                return currentTime > currentDay && updateTime < currentDay
            }

            return false
        }

        guard cookieClient.didLogin,
              state.setting.showsNewDawnGreeting
        else { return .none }
        let requestEffect = Effect.run { send in
            let response = await GreetingRequest().response()
            await send(Action.fetchGreetingDone(response))
        }
        if let greeting = state.user.greeting {
            if verifyDate(with: greeting.updateTime) {
                return requestEffect
            }
        } else {
            return requestEffect
        }
        return .none
    }

    func handleFetchTagTranslator(_ state: inout State) -> Effect<Action> {
        guard state.tagTranslatorLoadingState != .loading,
              !state.tagTranslator.hasCustomTranslations,
              let language = TranslatableLanguage.current
        else { return .none }
        state.tagTranslatorLoadingState = .loading

        var databaseEffect: Effect<Action>?
        if state.tagTranslator.language != language {
            state.tagTranslator = TagTranslator(language: language)
            databaseEffect = .send(.syncTagTranslator)
        }
        let updatedDate = state.tagTranslator.updatedDate
        let requestEffect = Effect.run { send in
            let response = await TagTranslatorRequest(language: language, updatedDate: updatedDate).response()
            await send(Action.fetchTagTranslatorDone(response))
        }
        if let databaseEffect = databaseEffect {
            return .merge(databaseEffect, requestEffect)
        } else {
            return requestEffect
        }
    }

    func handleFetchEhProfileIndexDone(
        _ result: Result<VerifyEhProfileResponse, AppError>
    ) -> Effect<Action> {
        var effects = [Effect<Action>]()

        if case .success(let response) = result {
            if let profileValue = response.profileValue {
                let hostURL = Defaults.URL.host
                let profileValueString = String(profileValue)
                let selectedProfileKey = Defaults.Cookie.selectedProfile

                let cookieValue = cookieClient.getCookie(hostURL, selectedProfileKey)
                if cookieValue.rawValue != profileValueString {
                    effects.append(
                        .run { _ in
                            cookieClient.setOrEditCookie(
                                for: hostURL, key: selectedProfileKey, value: profileValueString
                            )
                        }
                    )
                }
            } else if response.isProfileNotFound {
                effects.append(.send(.createDefaultEhProfile))
            } else {
                let message = "Found profile but failed in parsing value."
                effects.append(.run(operation: { _ in loggerClient.error(message, nil) }))
            }
        }
        return effects.isEmpty ? .none : .merge(effects)
    }
}
