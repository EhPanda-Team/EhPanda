import AppTools
import Foundation
import AppModels
import Sharing
import OSLogExt
import ComposableArchitecture
import NetworkingFeature

private let logger = Logger(category: .init(describing: SettingReducer.self))

extension SettingReducer {
    func handleLoadUserSettings(_ state: inout State) -> Effect<Action> {
        // `setting` and `user` are both `@Shared` and auto-load from persisted storage — there is no
        // working copy to prime here. `tagTranslator` is in-memory and rebuilt from its cache below.
        var effects: [Effect<Action>] = [
            .send(.syncAppIconType),
            .send(.loadUserSettingsDone),
            .send(.syncUserInterfaceStyle),
            .run { [bypassesSNIFiltering = state.setting.bypassesSNIFiltering] _ in
                dfClient.setActive(bypassesSNIFiltering)
            }
        ]
        if let value: String = userDefaultsClient.getValue(.galleryHost),
           let galleryHost = GalleryHost(rawValue: value) {
            state.$setting.withLock { $0.galleryHost = galleryHost }
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
            // Rebuild the table from cache first (offline, immediate); `.rebuildTagTranslator` then
            // sequences the remote update check so a slow fetch can't be clobbered by a stale rebuild.
            effects.append(.send(.rebuildTagTranslator))
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
        if let greeting = state.greeting {
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
              !state.tagTranslatorInfo.hasCustomTranslations,
              let language = TranslatableLanguage.current
        else { return .none }
        state.tagTranslatorLoadingState = .loading

        // A language switch resets the in-memory table and its persisted metadata; the request then
        // downloads the new language's data from scratch.
        if state.tagTranslatorInfo.language != language {
            state.$tagTranslator.withLock { $0 = TagTranslator(language: language) }
            state.$tagTranslatorInfo.withLock { $0 = TagTranslatorInfo(language: language) }
        }
        let updatedDate = state.tagTranslatorInfo.updatedDate
        return .run { send in
            // Download the raw JSON, then let `FileClient` decode/convert/cache it into a translator.
            switch await TagTranslatorRequest(language: language, updatedDate: updatedDate).response() {
            case .success(let payload):
                if let tagTranslator = fileClient.cacheAndBuildRemoteTagTranslator(
                    payload.data, language, payload.updatedDate
                ) {
                    await send(.fetchTagTranslatorDone(.success(tagTranslator)))
                } else {
                    await send(.fetchTagTranslatorDone(.failure(.parseFailed)))
                }
            case .failure(let error):
                await send(.fetchTagTranslatorDone(.failure(error)))
            }
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
                effects.append(.run { _ in
                    logger.error("Found profile but failed in parsing value.")
                })
            }
        }
        return effects.isEmpty ? .none : .merge(effects)
    }
}
