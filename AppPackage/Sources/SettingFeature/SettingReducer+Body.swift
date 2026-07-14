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
        // No `BindingReducer`: every Setting screen writes `setting` through its own `@Shared`, so the
        // parent never sees a `.binding` action. Per-edit side effects live in each screen's reducer,
        // and cross-field invariants live on the `Setting` model, so every write path stays consistent.
        Reduce { state, action in
            switch action {
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

            // The General screen edits `enablesTagsExtension` via `@Shared(.setting)`; rebuild the tag
            // translator when it's turned on. The model's `didSet` clears the sub-toggles on disable, so
            // only the enable case does work here. `.rebuildTagTranslator` sequences the remote fetch
            // after the offline cache rebuild.
            case .path(.element(id: _, action: .general(.delegate(.enablesTagsExtensionChanged)))):
                return state.setting.enablesTagsExtension ? .send(.rebuildTagTranslator) : .none

            case .path(.element(id: _, action: .appearance(.delegate(.pushAppIcon)))):
                state.path.appendGuardingDuplicate(.appIcon(.init()))
                return .none

            case .syncAppIconType:
                return .run { send in
                    await send(.syncAppIconTypeDone(await applicationClient.alternateIconName()))
                }

            case .syncAppIconTypeDone(let iconName):
                if let iconName {
                    state.$setting.withLock { $0.appIconType = .matching(alternateIconName: iconName) }
                }
                return .none

            case .syncUserInterfaceStyle:
                let style = state.setting.preferredColorScheme.userInterfaceStyle
                return .run(operation: { _ in await applicationClient.setUserInterfaceStyle(style) })

            case .loadUserSettings:
                // `setting`/`user`/`tagTranslator` are all @Shared (auto-loaded).
                return handleLoadUserSettings(&state)

            case .loadUserSettingsDone:
                state.hasLoadedInitialSetting = true
                return .none

            case .createDefaultEhProfile(let host):
                return .run { _ in
                    do throws(AppError) {
                        _ = try await EhProfileRequest(
                            host: host,
                            action: .create,
                            name: "EhPanda"
                        )
                        .response()
                    } catch {
                        return
                    }
                }

            case .fetchIgneous:
                guard cookieClient.didLogin else { return .none }
                return .run { send in
                    do throws(AppError) {
                        let response = try await IgneousRequest().response()
                        await send(.fetchIgneousDone(.success(response)))
                    } catch {
                        await send(.fetchIgneousDone(.failure(error)))
                    }
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
                    .getCookie(state.setting.galleryHost.url, Defaults.Cookie.ipbMemberId).rawValue
                if !uid.isEmpty {
                    return .run { send in
                        do throws(AppError) {
                            let user = try await UserInfoRequest(uid: uid).response()
                            await send(.fetchUserInfoDone(.success(user)))
                        } catch {
                            await send(.fetchUserInfoDone(.failure(error)))
                        }
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
                    state.$tagTranslator.withLock { $0 = tagTranslator }
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
            // persisted metadata (custom import → Application Support, remote → Caches), THEN the
            // remote update check. Sequenced in one effect so the (slower) network fetch can't land a
            // fresh table and metadata only to be overwritten by a rebuild that captured stale info.
            case .rebuildTagTranslator:
                let info = state.tagTranslatorInfo
                return .run { send in
                    if let tagTranslator = fileClient.loadCachedTagTranslator(info) {
                        await send(.tagTranslatorRebuilt(tagTranslator))
                    }
                    await send(.fetchTagTranslator)
                }

            case .tagTranslatorRebuilt(let tagTranslator):
                state.$tagTranslator.withLock { $0 = tagTranslator }
                return .none

            case .fetchEhProfileIndex:
                guard cookieClient.didLogin else { return .none }
                let host = state.setting.galleryHost
                return .run { send in
                    do throws(AppError) {
                        let response = try await VerifyEhProfileRequest(host: host).response()
                        await send(.fetchEhProfileIndexDone(host, .success(response)))
                    } catch {
                        await send(.fetchEhProfileIndexDone(host, .failure(error)))
                    }
                }

            case .fetchEhProfileIndexDone(let host, let result):
                return handleFetchEhProfileIndexDone(&state, host, result)

            case .fetchFavoriteCategories:
                guard cookieClient.didLogin else { return .none }
                let host = state.setting.galleryHost
                return .run { send in
                    do throws(AppError) {
                        let categories = try await FavoriteCategoriesRequest(host: host).response()
                        await send(.fetchFavoriteCategoriesDone(.success(categories)))
                    } catch {
                        await send(.fetchFavoriteCategoriesDone(.failure(error)))
                    }
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
                // Drop the custom table from memory, metadata, and disk; the launch/remote flow refills
                // it. FileClient owns the path, so the file lifecycle stays behind one module.
                state.$tagTranslator.withLock { $0 = TagTranslator() }
                state.$tagTranslatorInfo.withLock { $0.hasCustomTranslations = false }
                return .run { _ in fileClient.removeCustomTranslations() }

            case .igneousRefreshed:
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

}
