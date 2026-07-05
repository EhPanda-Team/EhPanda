import SwiftUI
import ComposableArchitecture
import URLClient
import HapticsClient
import DownloadClient
import BackgroundProcessingClient
import CookieClient
import AppLaunchAutomationClient
import DeviceClient
import HomeFeature
import SearchFeature
import FavoritesFeature
import DownloadsFeature
import SettingFeature
import OSLogExt

private let logger = Logger(category: .init(describing: AppReducer.self))

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var appDelegateState = AppDelegateReducer.State()
        var appRouteState = AppRouteReducer.State()
        var appLockState = AppLockReducer.State()
        var tabBarState = TabBarReducer.State()
        var homeState = HomeReducer.State()
        var favoritesState = FavoritesReducer.State()
        var searchRootState = SearchRootReducer.State()
        var downloadsState = DownloadsReducer.State()
        var settingState = SettingReducer.State()
        var appLogsPumpState = AppActivityLogsPumpReducer.State()
        var scenePhase = ScenePhase.active
        var hasEnteredBackground = false
        var didRunLaunchAutomation = false
        var isAwaitingIgneousForLaunchAutomation = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onScenePhaseChange(ScenePhase)
        case runLaunchAutomation

        case appDelegate(AppDelegateReducer.Action)
        case appRoute(AppRouteReducer.Action)
        case appLock(AppLockReducer.Action)

        case tabBar(TabBarReducer.Action)

        case home(HomeReducer.Action)
        case favorites(FavoritesReducer.Action)
        case searchRoot(SearchRootReducer.Action)
        case downloads(DownloadsReducer.Action)
        case setting(SettingReducer.Action)
        case appLogsPump(AppActivityLogsPumpReducer.Action)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.backgroundProcessingClient) private var backgroundProcessingClient
    @Dependency(\.appLaunchAutomationClient) private var appLaunchAutomationClient
    @Dependency(\.urlClient) private var urlClient

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.appRouteState.destination) { oldValue, state in
                // iPad presents Setting as a modal sheet; when it's dismissed, reset its navigation
                // stack so reopening starts at the root.
                if oldValue?.setting != nil, state.appRouteState.destination == nil {
                    state.settingState.path.removeAll()
                }
                return .none
            }
            .onChange(of: \.settingState.setting) { _, _ in
                .send(.setting(.syncSetting))
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onScenePhaseChange(let scenePhase):
                state.scenePhase = scenePhase
                guard state.settingState.hasLoadedInitialSetting else { return .none }

                switch scenePhase {
                case .active:
                    let threshold = state.settingState.setting.autoLockPolicy.rawValue
                    let blurRadius = state.settingState.setting.backgroundBlurRadius
                    var effects: [Effect<Action>] = [
                        .send(.appLock(.onBecomeActive(threshold, blurRadius))),
                        .send(.appLogsPump(.startPump)),
                        .run { _ in logger.notice("App entered foreground.") }
                    ]
                    // iOS interposes .inactive on a foreground return
                    // (.background -> .inactive -> .active), so the previous
                    // phase is never .background here. Latch the background
                    // entry instead: reconcile once per cycle, never on a
                    // transient .inactive blip (Control Center, notifications).
                    if state.hasEnteredBackground {
                        state.hasEnteredBackground = false
                        effects.append(
                            .run { _ in
                                await downloadClient.reconcileDownloads()
                            }
                        )
                    }
                    return .merge(effects)

                case .inactive:
                    let blurRadius = state.settingState.setting.backgroundBlurRadius
                    return .send(.appLock(.onBecomeInactive(blurRadius)))

                case .background:
                    state.hasEnteredBackground = true
                    // Ask iOS for a later background window to finish the queue; the
                    // beginBackgroundTask assertion only covers the brief grace
                    // period right after backgrounding.
                    return .merge(
                        .send(.appLogsPump(.pausePump)),
                        .run { _ in
                            logger.notice("App entered background.")
                            if await downloadClient.hasPendingWork() {
                                backgroundProcessingClient.schedule()
                            }
                        }
                    )

                default:
                    return .none
                }

            case .runLaunchAutomation:
                guard !state.didRunLaunchAutomation,
                      let automation = appLaunchAutomationClient.current()
                else { return .none }

                state.didRunLaunchAutomation = true
                return .run { send in
                    if let galleryURL = automation.galleryURL,
                       urlClient.checkIfHandleable(galleryURL) {
                        await send(.appRoute(.handleDeepLink(galleryURL)))
                    } else if let initialTab = automation.initialTab {
                        await send(.tabBar(.setTabBarItemType(initialTab)))
                    }
                }

            case .appDelegate(.onLaunchFinish):
                // No database preparation to await anymore: import any launch-automation cookies and
                // load the persisted settings straight away.
                let loginCookies = appLaunchAutomationClient.current()?.loginCookies
                return .merge(
                    .send(.appLogsPump(.startPump)),
                    .run { send in
                        if let loginCookies {
                            cookieClient.importAutomationCookies(
                                memberID: loginCookies.memberID,
                                passHash: loginCookies.passHash,
                                igneous: loginCookies.igneous
                            )
                        }
                        await send(.setting(.loadUserSettings))
                    }
                )

            case .appDelegate:
                return .none

            case .appRoute:
                return .none

            case .appLock(.unlockApp):
                var effects: [Effect<Action>] = [
                    .send(.setting(.fetchGreeting))
                ]
                if state.settingState.setting.detectsLinksFromClipboard {
                    effects.append(.send(.appRoute(.detectClipboardURL)))
                }
                return .merge(effects)

            case .appLock:
                return .none

            case .tabBar(.setTabBarItemType(let type)):
                var effects = [Effect<Action>]()
                let hapticEffect: Effect<Action> = .run { _ in
                    await hapticsClient.generateFeedback(.soft)
                }
                if type == state.tabBarState.tabBarItemType {
                    switch type {
                    case .home:
                        if !state.homeState.path.isEmpty {
                            state.homeState.path.removeAll()
                        } else {
                            effects.append(.send(.home(.fetchAllGalleries)))
                        }
                    case .favorites:
                        if !state.favoritesState.path.isEmpty {
                            state.favoritesState.path.removeAll()
                            effects.append(hapticEffect)
                        } else if cookieClient.didLogin {
                            effects.append(.send(.favorites(.fetchGalleries())))
                            effects.append(hapticEffect)
                        }
                    case .search:
                        if !state.searchRootState.path.isEmpty {
                            state.searchRootState.path.removeAll()
                        } else {
                            // Keywords/quick-search words are live via @Shared now; re-tapping the
                            // Search tab at its root refreshes the recently-viewed galleries instead.
                            effects.append(.send(.searchRoot(.fetchHistoryGalleries)))
                        }
                    case .downloads:
                        if !state.downloadsState.path.isEmpty {
                            state.downloadsState.path.removeAll()
                        } else {
                            effects.append(.send(.downloads(.fetchDownloads)))
                        }
                        effects.append(hapticEffect)
                    case .setting:
                        if !state.settingState.path.isEmpty {
                            state.settingState.path.removeAll()
                            effects.append(hapticEffect)
                        }
                    }
                    if [.home, .search].contains(type) {
                        effects.append(hapticEffect)
                    }
                }
                return effects.isEmpty ? .none : .merge(effects)

            case .tabBar:
                return .none

            case .home(.path(.element(id: _, action: .watched(.onNotLoginViewButtonTapped)))),
                 .favorites(.onNotLoginViewButtonTapped):
                var effects: [Effect<Action>] = [
                    .run(operation: { _ in await hapticsClient.generateFeedback(.soft) }),
                    .send(.tabBar(.setTabBarItemType(.setting)))
                ]
                effects.append(.send(.setting(.settingRowTapped(.account))))
                if !cookieClient.didLogin {
                    effects.append(
                        .run { send in
                            let isPad = await deviceClient.isPad()
                            let delay = UInt64(isPad ? 1200 : 200)
                            try await Task.sleep(for: .milliseconds(delay))
                            await send(.setting(.pushLogin))
                        }
                    )
                }
                return .merge(effects)

            // A gallery tapped on iPad presents modally (hosted by AppRoute) instead of pushing
            // inline; the tab hosts delegate that presentation up here.
            case let .home(.delegate(.presentGalleryDetail(gallery))),
                 let .searchRoot(.delegate(.presentGalleryDetail(gallery))),
                 let .favorites(.delegate(.presentGalleryDetail(gallery))):
                return .send(.appRoute(.presentGalleryDetail(gallery, nil)))

            case let .downloads(.delegate(.presentGalleryDetail(gallery, download))):
                return .send(.appRoute(.presentGalleryDetail(gallery, download)))

            case .home:
                return .none

            case .favorites:
                return .none

            case .searchRoot:
                return .none

            case .downloads:
                return .none

            case .setting(.loadUserSettingsDone):
                var effects = [Effect<Action>]()
                let threshold = state.settingState.setting.autoLockPolicy.rawValue
                let blurRadius = state.settingState.setting.backgroundBlurRadius
                if threshold >= 0 {
                    state.appLockState.becameInactiveDate = .distantPast
                    effects.append(.send(.appLock(.onBecomeActive(threshold, blurRadius))))
                }
                if state.settingState.setting.detectsLinksFromClipboard {
                    effects.append(.send(.appRoute(.detectClipboardURL)))
                }
                state.isAwaitingIgneousForLaunchAutomation = shouldDelayLaunchAutomationUntilIgneous(
                    state: state
                )
                if !state.isAwaitingIgneousForLaunchAutomation {
                    effects.append(.send(.runLaunchAutomation))
                }
                return effects.isEmpty ? .none : .merge(effects)

            case .setting(.igneousRefreshed):
                guard state.isAwaitingIgneousForLaunchAutomation,
                      !shouldDelayLaunchAutomationUntilIgneous(state: state)
                else { return .none }
                state.isAwaitingIgneousForLaunchAutomation = false
                return .send(.runLaunchAutomation)

            case .setting(.fetchGreetingDone(let result)):
                return .send(.appRoute(.fetchGreetingDone(result)))

            case .setting:
                return .none

            case .appLogsPump:
                return .none
            }
        }

        Scope(state: \.appRouteState, action: \.appRoute, child: AppRouteReducer.init)
        Scope(state: \.appLockState, action: \.appLock, child: AppLockReducer.init)
        Scope(state: \.appDelegateState, action: \.appDelegate, child: AppDelegateReducer.init)
        Scope(state: \.tabBarState, action: \.tabBar, child: TabBarReducer.init)
        Scope(state: \.homeState, action: \.home, child: HomeReducer.init)
        Scope(state: \.favoritesState, action: \.favorites, child: FavoritesReducer.init)
        Scope(state: \.searchRootState, action: \.searchRoot, child: SearchRootReducer.init)
        Scope(state: \.downloadsState, action: \.downloads, child: DownloadsReducer.init)
        Scope(state: \.settingState, action: \.setting, child: SettingReducer.init)
        Scope(state: \.appLogsPumpState, action: \.appLogsPump, child: AppActivityLogsPumpReducer.init)
    }
}

private extension AppReducer {
    func shouldDelayLaunchAutomationUntilIgneous(state: State) -> Bool {
        guard !state.didRunLaunchAutomation,
              cookieClient.shouldFetchIgneous,
              let automation = appLaunchAutomationClient.current()
        else { return false }

        if let galleryURL = automation.galleryURL,
           galleryURL.host?.contains("exhentai.org") == true {
            return true
        }

        return automation.autoDownloadGID != nil
            && state.settingState.setting.galleryHost == .exhentai
    }
}
