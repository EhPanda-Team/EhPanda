import AppTools
import Foundation
import AppModels
import OSLogExt
import ComposableArchitecture
import NetworkingFeature

private let logger = Logger(category: .init(describing: SettingReducer.self))

extension SettingReducer {
    @ReducerBuilder<State, Action>
    var reducerBody: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.setting) { _, _ in
                .send(.syncSetting)
            }
            .onChange(of: \.setting.galleryHost) { _, state in
                .merge(
                    .send(.syncSetting),
                    .run(operation: { [value = state.setting.galleryHost.rawValue] _ in
                        userDefaultsClient.setValue(value, .galleryHost)
                    })
                )
            }
            .onChange(of: \.setting.enablesTagsExtension) { _, state in
                var effects: [Effect<Action>] = [
                    .send(.syncSetting)
                ]
                if state.setting.enablesTagsExtension {
                    effects.append(.send(.rebuildTagTranslator))
                    effects.append(.send(.fetchTagTranslator))
                }
                return .merge(effects)
            }
            .onChange(of: \.setting.preferredColorScheme) { _, _ in
                .merge(
                    .send(.syncSetting),
                    .send(.syncUserInterfaceStyle)
                )
            }
            .onChange(of: \.setting.appIconType) { _, state in
                .merge(
                    .send(.syncSetting),
                    .run { [value = state.setting.appIconType.filename] send in
                        _ = await applicationClient.setAlternateIconName(value)
                        await send(.syncAppIconType)
                    }
                )
            }
            .onChange(of: \.setting.autoLockPolicy) { _, state in
                if state.setting.autoLockPolicy != .never && state.setting.backgroundBlurRadius == 0 {
                    state.setting.backgroundBlurRadius = 10
                }
                return .send(.syncSetting)
            }
            .onChange(of: \.setting.backgroundBlurRadius) { _, state in
                if state.setting.autoLockPolicy != .never && state.setting.backgroundBlurRadius == 0 {
                    state.setting.autoLockPolicy = .never
                }
                return .send(.syncSetting)
            }
            .onChange(of: \.setting.enablesLandscape) { _, state in
                var effects: [Effect<Action>] = [
                    .send(.syncSetting)
                ]
                if !state.setting.enablesLandscape {
                    effects.append(
                        .run { _ in
                            guard await !deviceClient.isPad() else { return }
                            await appDelegateClient.setPortraitOrientationMask()
                        }
                    )
                }
                return .merge(effects)
            }
            .onChange(of: \.setting.maximumScaleFactor) { _, state in
                if state.setting.doubleTapScaleFactor > state.setting.maximumScaleFactor {
                    state.setting.doubleTapScaleFactor = state.setting.maximumScaleFactor
                }
                return .send(.syncSetting)
            }
            .onChange(of: \.setting.doubleTapScaleFactor) { _, state in
                if state.setting.maximumScaleFactor < state.setting.doubleTapScaleFactor {
                    state.setting.maximumScaleFactor = state.setting.doubleTapScaleFactor
                }
                return .send(.syncSetting)
            }
            .onChange(of: \.setting.bypassesSNIFiltering) { _, state in
                .merge(
                    .send(.syncSetting),
                    .run(operation: { _ in await hapticsClient.generateFeedback(.soft) }),
                    .run(operation: { [value = state.setting.bypassesSNIFiltering] _ in dfClient.setActive(value) })
                )
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .send(.syncSetting)

            case .settingRowTapped(let screen):
                state.path.appendGuardingDuplicate(screen.pathElement)
                return .none

            case .pushLogin:
                state.path.appendGuardingDuplicate(.login(.init()))
                return .none

            // Account emits a delegate to push its children onto the shared stack.
            case .path(.element(id: _, action: .account(.delegate(.pushLogin)))):
                state.path.appendGuardingDuplicate(.login(.init()))
                return .none

            case .path(.element(id: _, action: .account(.delegate(.pushEhSetting)))):
                state.path.appendGuardingDuplicate(.ehSetting(.init()))
                return .none

            case .path(.element(id: _, action: .general(.delegate(.pushAppActivityLogs)))):
                state.path.appendGuardingDuplicate(.appActivityLogs(.init()))
                return .none

            case .path(.element(id: _, action: .appearance(.delegate(.pushAppIcon)))):
                state.path.appendGuardingDuplicate(.appIcon(.init()))
                return .none

            case .syncAppIconType:
                return .run { send in
                    await send(.syncAppIconTypeDone(await applicationClient.alternateIconName()))
                }

            case .syncAppIconTypeDone(let iconName):
                if let iconName {
                    state.setting.appIconType = AppIconType.allCases.filter({
                        iconName.contains($0.filename)
                    }).first ?? .default
                }
                return .none

            case .syncUserInterfaceStyle:
                let style = state.setting.preferredColorScheme.userInterfaceStyle
                return .run(operation: { _ in await applicationClient.setUserInterfaceStyle(style) })

            case .syncSetting:
                // Write-through to the persisted store. `setting` stays a working copy so that its
                // `BindingReducer` `.onChange` side effects keep firing; this mirrors it to storage.
                @Shared(.setting) var storedSetting
                $storedSetting.withLock { $0 = state.setting }
                return .none

            case .loadUserSettings:
                // `setting`/`user`/`tagTranslator` are all @Shared (auto-loaded); no database read.
                return handleLoadUserSettings(&state)

            case .loadUserSettingsDone:
                state.hasLoadedInitialSetting = true
                return .none

            case .createDefaultEhProfile:
                return .run { _ in
                    _ = await EhProfileRequest(action: .create, name: "EhPanda").response()
                }

            case .fetchIgneous:
                guard cookieClient.didLogin else { return .none }
                return .run { send in
                    let response = await IgneousRequest().response()
                    await send(.fetchIgneousDone(response))
                }

            case .fetchIgneousDone(let result):
                if case .success(let response) = result {
                    return .run { send in
                        logger.notice("Igneous token refreshed.")
                        cookieClient.setCredentials(response: response)
                        await send(.igneousRefreshed)
                    }
                }
                return .merge(
                    .run { _ in logger.notice("Igneous refresh failed.") },
                    .send(.igneousRefreshed)
                )

            case .fetchUserInfo:
                guard cookieClient.didLogin else { return .none }
                let uid = cookieClient
                    .getCookie(Defaults.URL.host, Defaults.Cookie.ipbMemberId).rawValue
                if !uid.isEmpty {
                    return .run { send in
                        let response = await UserInfoRequest(uid: uid).response()
                        await send(.fetchUserInfoDone(response))
                    }
                }
                return .none

            case .fetchUserInfoDone(let result):
                if case .success(let user) = result {
                    state.updateUser(user)
                }
                return .none

            case .fetchGreeting:
                return handleFetchGreeting(&state)

            case .fetchGreetingDone(let result):
                switch result {
                case .success(let greeting):
                    state.setGreeting(greeting)
                case .failure(let error):
                    if case .parseFailed = error {
                        var greeting = Greeting()
                        greeting.updateTime = Date()
                        state.setGreeting(greeting)
                    }
                }
                return .none

            case .fetchTagTranslator:
                return handleFetchTagTranslator(&state)

            case .fetchTagTranslatorDone(let result):
                state.tagTranslatorLoadingState = .idle
                switch result {
                case .success(let tagTranslator):
                    state.tagTranslator = tagTranslator
                    state.$tagTranslatorInfo.withLock {
                        $0 = TagTranslatorInfo(
                            language: tagTranslator.language,
                            updatedDate: tagTranslator.updatedDate,
                            hasCustomTranslations: tagTranslator.hasCustomTranslations
                        )
                    }
                case .failure(let error):
                    state.tagTranslatorLoadingState = .failed(error)
                }
                return .none

            // Offline rebuild of the in-memory table from the cached raw JSON described by the
            // persisted metadata (custom import → Application Support, remote → Caches).
            case .rebuildTagTranslator:
                let info = state.tagTranslatorInfo
                return .run { send in
                    if let tagTranslator = fileClient.loadCachedTagTranslator(info) {
                        await send(.tagTranslatorRebuilt(tagTranslator))
                    }
                }

            case .tagTranslatorRebuilt(let tagTranslator):
                state.tagTranslator = tagTranslator
                return .none

            case .fetchEhProfileIndex:
                guard cookieClient.didLogin else { return .none }
                return .run { send in
                    let response = await VerifyEhProfileRequest().response()
                    await send(.fetchEhProfileIndexDone(response))
                }

            case .fetchEhProfileIndexDone(let result):
                return handleFetchEhProfileIndexDone(result)

            case .fetchFavoriteCategories:
                guard cookieClient.didLogin else { return .none }
                return .run { send in
                    let response = await FavoriteCategoriesRequest().response()
                    await send(.fetchFavoriteCategoriesDone(response))
                }

            case .fetchFavoriteCategoriesDone(let result):
                if case .success(let categories) = result {
                    state.$user.withLock { $0.favoriteCategories = categories }
                }
                return .none

            // Login is a top-level stack element; it self-dismisses on success while Setting runs
            // the post-login setup.
            case .path(.element(id: _, action: .login(.loginDone))):
                return .merge(
                    .run(operation: { _ in cookieClient.removeYay() }),
                    .run(operation: { _ in cookieClient.syncExCookies() }),
                    .run(operation: { _ in cookieClient.fulfillAnotherHostField() }),
                    .send(.fetchIgneous),
                    .send(.fetchUserInfo),
                    .send(.fetchFavoriteCategories),
                    .send(.fetchEhProfileIndex)
                )

            case .path(.element(id: _, action: .account(.onLogoutConfirmButtonTapped))):
                state.$user.withLock { $0 = User() }
                return .merge(
                    .run(operation: { _ in cookieClient.clearAll() }),
                    .run(operation: { _ in await libraryClient.removeAllCachedImages() }),
                    .run { _ in logger.notice("Logged out.") }
                )

            case .path(.element(id: _, action: .general(.onTranslationsFilePicked(let url)))):
                return .run { send in
                    let result = await fileClient.importTagTranslator(url)
                    await send(.fetchTagTranslatorDone(result))
                }

            case .path(.element(id: _, action: .general(.onRemoveCustomTranslations))):
                // Drop the custom table from memory and metadata; the launch/remote flow refills it.
                state.tagTranslator = TagTranslator()
                state.$tagTranslatorInfo.withLock { $0.hasCustomTranslations = false }
                return .none

            case .igneousRefreshed:
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

}
