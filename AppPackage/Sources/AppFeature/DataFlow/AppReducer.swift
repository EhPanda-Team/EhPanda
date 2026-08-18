import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import DeviceClient
import DownloadClient
import DownloadsFeature
import FavoritesFeature
import HapticsClient
import HomeFeature
import OSLogExt
import SearchFeature
import SettingFeature
import SwiftUI

private let logger = Logger(category: .init(describing: AppReducer.self))

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var appDelegateState = AppDelegateReducer.State()
        var presentationState = PresentationFeature.State()
        var tabBarState = TabBarReducer.State()
        var homeState = HomeReducer.State()
        var favoritesState = FavoritesReducer.State()
        var searchRootState = SearchRootReducer.State()
        var downloadsState = DownloadsReducer.State()
        var settingState = SettingReducer.State()
        @Shared(.privacyMaskBlur) var privacyMaskBlur: Double
        var appLogsPumpState = AppActivityLogsPumpReducer.State()
        var scenePhase = ScenePhase.active
        /// Whether the download client currently holds a continued-processing session — the fact
        /// that decides whether backgrounding may pause the activity-log pump.
        var isContinuedSessionLive = false
        var hasEnteredBackground = false
        var didRunLaunchAutomation = false
        var isAwaitingIgneousForLaunchAutomation = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onScenePhaseChange(ScenePhase)
        case continuedSessionLivenessChanged(Bool)
        case runLaunchAutomation

        case appDelegate(AppDelegateReducer.Action)
        case presentation(PresentationFeature.Action)

        case tabBar(TabBarReducer.Action)

        case home(HomeReducer.Action)
        case favorites(FavoritesReducer.Action)
        case searchRoot(SearchRootReducer.Action)
        case downloads(DownloadsReducer.Action)
        case setting(SettingReducer.Action)
        case appLogsPump(AppActivityLogsPumpReducer.Action)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.appLaunchAutomationClient) private var appLaunchAutomationClient

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.presentationState.destination) { oldValue, state in
                // iPad presents Setting as a modal sheet; when it's dismissed, reset its navigation
                // stack so reopening starts at the root.
                if oldValue?.setting != nil, state.presentationState.destination == nil {
                    state.settingState.path.removeAll()
                }
                return .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onScenePhaseChange(let scenePhase):
                state.scenePhase = scenePhase

                // Collected before the settings guard, because reporting the scene phase to the
                // download client is not a setting-dependent behavior: a transfer created while
                // backgrounded must be stamped as such however far the launch has got.
                var effects = [Effect<Action>]()
                switch scenePhase {
                case .active:
                    state.$privacyMaskBlur.withLock({ $0 = 0 })
                    effects.append(.run(operation: { _ in await downloadClient.setIsInBackground(false) }))

                case .inactive:
                    let intensity = state.settingState.setting.privacyMaskIntensity
                    state.$privacyMaskBlur.withLock({ $0 = intensity })

                case .background:
                    state.hasEnteredBackground = true
                    effects.append(.run(operation: { _ in await downloadClient.setIsInBackground(true) }))

                default:
                    break
                }

                guard state.settingState.hasLoadedInitialSetting else {
                    return effects.isEmpty ? .none : .merge(effects)
                }

                switch scenePhase {
                case .active:
                    effects.append(contentsOf: [
                        .send(.setting(.fetchGreeting)),
                        .send(.appLogsPump(.startPump)),
                        .run { _ in logger.notice("App entered foreground.") }
                    ])
                    if state.settingState.setting.detectLinksFromClipboard
                        || UITestAutomation.shouldDetectClipboardURL {
                        effects.append(.send(.presentation(.detectClipboardURL)))
                    }
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
                    return effects.isEmpty ? .none : .merge(effects)

                case .background:
                    // Backgrounding no longer requests any background window: a
                    // continued-processing session, if one exists, was started earlier by the
                    // user action that mobilized the download queue.
                    // Pause the activity-log pump on background only when NO continued-processing
                    // session is live. A live session keeps the process alive and the pump's 5 s
                    // OSLogStore read is cheap, so keeping it ticking is what makes background-side
                    // lines — an expiry, its pause sweep — reach disk. The pause is sequenced behind
                    // the log line inside one `.run`, so the background line is emitted before the
                    // final drain runs; best effort only, since OSLog visibility is not synchronous.
                    effects.append(
                        state.isContinuedSessionLive
                            ? .run { _ in logger.notice("App entered background.") }
                            : .run { send in
                                logger.notice("App entered background.")
                                await send(.appLogsPump(.pausePump))
                            }
                    )
                    // Backgrounding fires no reader `onDisappear`/dismiss, so flush the active reading
                    // session's last debounced page here — otherwise a force-quit from the background
                    // drops it. The reader is located from navigation state (see `readingFlushEffects`).
                    effects.append(contentsOf: readingFlushEffects(state))
                    return .merge(effects)

                default:
                    return effects.isEmpty ? .none : .merge(effects)
                }

            case .continuedSessionLivenessChanged(let isLive):
                guard state.isContinuedSessionLive != isLive else { return .none }
                state.isContinuedSessionLive = isLive
                // The live session ended while the app is backgrounded: nothing keeps the process
                // alive any more, so drain the pump now — the expiry and its pause sweep were just
                // logged, and this is the last chance to get them onto disk.
                guard !isLive, state.scenePhase == .background else { return .none }
                return .send(.appLogsPump(.pausePump))

            case .runLaunchAutomation:
                guard !state.didRunLaunchAutomation,
                      let automation = appLaunchAutomationClient.current()
                else { return .none }

                state.didRunLaunchAutomation = true
                return .run { send in
                    if let galleryURL = automation.galleryURL,
                       GalleryURLParser.parse(galleryURL) != nil {
                        await send(.presentation(.handleDeepLink(galleryURL)))
                    } else if let initialTab = automation.initialTab {
                        await send(.tabBar(.setTabBarItemType(initialTab)))
                    }
                }

            case .appDelegate(.onLaunchFinish):
                // Import any launch-automation cookies and load the persisted settings straight away.
                let loginCookies = appLaunchAutomationClient.current()?.loginCookies
                return .merge(
                    .send(.appLogsPump(.startPump)),
                    // Long-lived: the coordinator yields the current liveness on subscribe and every
                    // transition after it, for as long as the app runs.
                    .run { send in
                        for await isLive in downloadClient.observeContinuedSessionLiveness() {
                            await send(.continuedSessionLivenessChanged(isLive))
                        }
                    },
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

            case .presentation:
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
                } else {
                    // A genuine tab switch is the only thing that counts as a tab open. The equal-`type`
                    // branch above is refresh / pop-to-root, so emitting there would inflate the metric
                    // with scroll-to-top gestures that never changed which tab is showing (D-14, T-14-13).
                    effects.append(.run(operation: { _ in analyticsClient.send(.tabOpened(AppTab(type))) }))
                    // Presentation-driven lifecycle: tab roots are built once and live for the whole
                    // session, so "this tab became the visible one" is what replaces their former
                    // view `onAppear`. Their presentation actions are guarded, so re-activating a
                    // populated tab refetches nothing.
                    effects.append(tabPresentationEffect(for: type))
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
                            let isPad = await deviceClient.deviceType() == .pad
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
                return .send(.presentation(.presentGalleryDetail(gallery: gallery, downloaded: nil)))

            case let .downloads(.delegate(.presentGalleryDetail(gallery, download))):
                return .send(.presentation(.presentGalleryDetail(gallery: gallery, downloaded: download)))

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
                // This is the single cold-launch clipboard owner: the initial `.active` is ignored
                // until settings load, while the `.active` branch handles later foreground entries.
                if state.settingState.setting.detectLinksFromClipboard
                    || UITestAutomation.shouldDetectClipboardURL {
                    effects.append(.send(.presentation(.detectClipboardURL)))
                }
                state.isAwaitingIgneousForLaunchAutomation = shouldDelayLaunchAutomationUntilIgneous(
                    state: state
                )
                if !state.isAwaitingIgneousForLaunchAutomation {
                    effects.append(.send(.runLaunchAutomation))
                }
                // Cold-launch counterpart of the tab-activation hook below: the tab shown at launch
                // never gets a "became active" transition, so its presentation action fires here.
                // Settings are loaded by now, which is what the fetches need to pick a gallery host.
                effects.append(tabPresentationEffect(for: state.tabBarState.tabBarItemType))
                return effects.isEmpty ? .none : .merge(effects)

            case .setting(.igneousRefreshed):
                guard state.isAwaitingIgneousForLaunchAutomation,
                      !shouldDelayLaunchAutomationUntilIgneous(state: state)
                else { return .none }
                state.isAwaitingIgneousForLaunchAutomation = false
                return .send(.runLaunchAutomation)

            case .setting(.fetchGreetingDone(let result)):
                return .send(.presentation(.fetchGreetingDone(result)))

            case .setting:
                return .none

            case .appLogsPump:
                return .none
            }
        }

        Scope(\.presentationState, action: \.presentation, PresentationFeature.init)
        Scope(\.appDelegateState, action: \.appDelegate, AppDelegateReducer.init)
        Scope(\.tabBarState, action: \.tabBar, TabBarReducer.init)
        Scope(\.homeState, action: \.home, HomeReducer.init)
        Scope(\.favoritesState, action: \.favorites, FavoritesReducer.init)
        Scope(\.searchRootState, action: \.searchRoot, SearchRootReducer.init)
        Scope(\.downloadsState, action: \.downloads, DownloadsReducer.init)
        Scope(\.settingState, action: \.setting, SettingReducer.init)
        Scope(\.appLogsPumpState, action: \.appLogsPump, AppActivityLogsPumpReducer.init)
    }
}

private extension AppReducer {
    /// The tab root's presentation action — the reducer-side replacement for the view `onAppear` it
    /// used to run. Setting takes no action here: its root menu is a static list, and each Setting
    /// screen starts itself when `SettingReducer` pushes it.
    func tabPresentationEffect(for type: TabBarItemType) -> Effect<Action> {
        switch type {
        case .home:
            return .send(.home(.onPresented))
        case .favorites:
            return .send(.favorites(.onPresented))
        case .search:
            return .send(.searchRoot(.onPresented))
        case .downloads:
            return .send(.downloads(.onPresented))
        case .setting:
            return .none
        }
    }

    /// Flush actions for every reading session currently on top of a navigation host, so a background
    /// force-quit persists each reader's last debounced page. A reader is presented as a `.reading`
    /// destination of `.detail`/`.previews` (elements of the gallery stacks) or, for the Downloads tab
    /// and the iPad/deep-link modal, directly as a host destination. Any new host that can present a
    /// `.reading` destination must be registered here.
    func readingFlushEffects(_ state: State) -> [Effect<Action>] {
        var effects: [Effect<Action>] = []

        // GalleryPath stacks whose top element presents a reader.
        if let (id, action) = state.presentationState.path.topReadingFlush {
            effects.append(.send(.presentation(.path(.element(id: id, action: action)))))
        }
        if let (id, action) = state.favoritesState.path.topReadingFlush {
            effects.append(.send(.favorites(.path(.element(id: id, action: action)))))
        }
        if let (id, action) = state.downloadsState.path.topReadingFlush {
            effects.append(.send(.downloads(.path(.element(id: id, action: action)))))
        }

        // Home / SearchRoot nest the gallery stack under a `.gallery` element.
        if let id = state.homeState.path.ids.last,
           case .gallery(let gallery)? = state.homeState.path[id: id],
           let action = gallery.readingFlushAction {
            effects.append(.send(.home(.path(.element(id: id, action: .gallery(action))))))
        }
        if let id = state.searchRootState.path.ids.last,
           case .gallery(let gallery)? = state.searchRootState.path[id: id],
           let action = gallery.readingFlushAction {
            effects.append(.send(.searchRoot(.path(.element(id: id, action: .gallery(action))))))
        }

        // The iPad/deep-link modal detail and the Downloads tab present a reader directly.
        if state.presentationState.detail?.destination?.reading != nil {
            effects.append(.send(.presentation(.detail(.presented(
                .destination(.presented(.reading(.flushReadingProgress)))
            )))))
        }
        if state.downloadsState.destination?.reading != nil {
            effects.append(.send(.downloads(.destination(.presented(.reading(.flushReadingProgress))))))
        }

        return effects
    }

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
