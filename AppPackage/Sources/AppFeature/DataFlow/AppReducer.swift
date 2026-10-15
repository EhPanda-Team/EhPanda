import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import DetailFeature
import DownloadClient
import DownloadsFeature
import FavoritesFeature
import HapticsClient
import HomeFeature
import OSLogExt
import ReadingFeature
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
        var libraryState = LibraryFeature.State()
        var favoritesState = FavoritesReducer.State()
        var searchRootState = SearchRootReducer.State()
        var downloadsState = DownloadsReducer.State()
        var settingState = SettingReducer.State()
        @Shared(.privacyMaskBlur) var privacyMaskBlur: Double
        var appLogsPumpState = AppActivityLogsPumpReducer.State()
        var scenePhase = ScenePhase.active
        /// `nil` until the root view first reports the window, which happens on its first render.
        var windowSizeClasses: WindowSizeClasses?
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
        case windowSizeClassesChanged(WindowSizeClasses)
        case continuedSessionLivenessChanged(Bool)
        case runLaunchAutomation

        case appDelegate(AppDelegateReducer.Action)
        case presentation(PresentationFeature.Action)

        case tabBar(TabBarReducer.Action)

        case home(HomeReducer.Action)
        case library(LibraryFeature.Action)
        case favorites(FavoritesReducer.Action)
        case searchRoot(SearchRootReducer.Action)
        case downloads(DownloadsReducer.Action)
        case setting(SettingReducer.Action)
        case appLogsPump(AppActivityLogsPumpReducer.Action)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.appLaunchAutomationClient) private var appLaunchAutomationClient

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.presentationState.destination) { oldValue, state in
                // A window regular in both dimensions presents Setting as a sheet; when it's
                // dismissed, reset its navigation stack so reopening starts at the root.
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

            case .windowSizeClassesChanged(let sizeClasses):
                let isFirstReport = state.windowSizeClasses == nil
                state.windowSizeClasses = sizeClasses
                return isFirstReport ? .send(.runLaunchAutomation) : .none

            case .continuedSessionLivenessChanged(let isLive):
                guard state.isContinuedSessionLive != isLive else { return .none }
                state.isContinuedSessionLive = isLive
                // The live session ended while the app is backgrounded: nothing keeps the process
                // alive any more, so drain the pump now — the expiry and its pause sweep were just
                // logged, and this is the last chance to get them onto disk.
                guard !isLive, state.scenePhase == .background else { return .none }
                return .send(.appLogsPump(.pausePump))

            case .runLaunchAutomation:
                // Sent by each event a launch automation waits on: the settings loading, the
                // igneous cookie an ExHentai route needs, and the root view's first report of the
                // window, whose size classes route the screens the automation opens. It runs once,
                // on whichever of them completes the set.
                guard !state.didRunLaunchAutomation,
                      state.settingState.hasLoadedInitialSetting,
                      !state.isAwaitingIgneousForLaunchAutomation,
                      state.windowSizeClasses != nil,
                      let automation = appLaunchAutomationClient.current()
                else { return .none }

                state.didRunLaunchAutomation = true
                if let captureRoute = automation.captureRoute {
                    return captureRouteEffect(captureRoute)
                }
                return .run { send in
                    if let galleryURL = automation.galleryURL,
                       GalleryURLParser.parse(galleryURL) != nil {
                        await send(.presentation(.handleDeepLink(galleryURL)))
                    } else if let initialTab = automation.initialTab {
                        await send(.tabBar(.setTabBarItemType(initialTab)))
                        if let group = automation.initialLibraryGroup {
                            await send(.library(.select(group)))
                        }
                    }
                }

            case .appDelegate(.onLaunchFinish):
                // Finish cookie maintenance before importing automation credentials or loading settings.
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
                        await cookieClient.prepareForLaunch()
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

            case .tabBar(.delegate(.openSetting)):
                return .send(
                    opensSettingAsSheet(state) ? .presentation(.presentSetting) : .tabBar(.selectSettingInline)
                )

            case .tabBar(.setTabBarItemType(let type)):
                guard type != .setting else { return .none }
                return tabSelectionEffect(type: type, state: &state)

            case .tabBar(.selectSettingInline):
                return tabSelectionEffect(type: .setting, state: &state)

            case .tabBar:
                return .none

            case .home(.path(.element(id: _, action: .watched(.onNotLoginViewButtonTapped)))),
                 .home(.delegate(.openAccount)),
                 .favorites(.onNotLoginViewButtonTapped):
                var effects: [Effect<Action>] = [
                    .run(operation: { _ in await hapticsClient.generateFeedback(.soft) }),
                    .send(.tabBar(.setTabBarItemType(.setting)))
                ]
                effects.append(.send(.setting(.settingRowTapped(.account))))
                if !cookieClient.didLogin {
                    // A Setting sheet has to finish presenting before it can push Login.
                    let delay = opensSettingAsSheet(state) ? 1200 : 200
                    effects.append(
                        .run { send in
                            try await Task.sleep(for: .milliseconds(delay))
                            await send(.setting(.pushLogin))
                        }
                    )
                }
                return .merge(effects)

            case .favorites(.setFavoritesIndex(let index)):
                state.libraryState.selection = .favorites(index)
                return .none

            case .downloads(.binding(\.folderFilter)), .downloads(.fetchFoldersDone):
                return .send(.library(.syncFromSources))

            case let .home(.delegate(.openGalleryDetail(gallery))):
                return openGalleryDetail(gallery, push: .home(.pushGalleryDetail(gallery)), state: state)

            case let .searchRoot(.delegate(.openGalleryDetail(gallery))):
                return openGalleryDetail(gallery, push: .searchRoot(.pushGalleryDetail(gallery)), state: state)

            case let .favorites(.delegate(.openGalleryDetail(gallery))):
                return openGalleryDetail(gallery, push: .favorites(.pushGalleryDetail(gallery)), state: state)

            case let .downloads(.delegate(.openGalleryDetail(download))):
                return openGalleryDetail(
                    download.gallery,
                    downloaded: download,
                    push: .downloads(.pushGalleryDetail(download)),
                    state: state
                )

            case .home:
                return .none

            case .favorites, .downloads:
                return .none

            case .library(.select(let selection)):
                let changed = state.libraryState.selection != selection
                state.libraryState.selection = selection
                return changed ? librarySelectionEffect(selection, state: &state) : .none

            case .library(.manageFolders):
                let selection: LibraryGroup = if case .downloads = state.libraryState.selection {
                    state.libraryState.selection ?? .downloads(.all)
                } else {
                    .downloads(.all)
                }
                return .run { send in
                    await send(.library(.select(selection)))
                    await send(.downloads(.folderManagerButtonTapped))
                }

            case .library(.syncFromSources):
                switch state.libraryState.selection {
                case .favorites:
                    state.libraryState.selection = .favorites(state.favoritesState.favoritesIndex)
                case .downloads:
                    state.libraryState.selection = .downloads(state.downloadsState.folderFilter)
                case .none:
                    break
                }
                return .none

            case .library(.binding):
                return .none

            case .searchRoot:
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
                effects.append(.send(.runLaunchAutomation))
                // Cold-launch counterpart of the tab-activation hook below: the tab shown at launch
                // never gets a "became active" transition, so its presentation action fires here.
                // Settings are loaded by now, which is what the fetches need to pick a gallery host.
                effects.append(tabPresentationEffect(for: state.tabBarState.tabBarItemType, state: &state))
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
        Scope(\.libraryState, action: \.library, LibraryFeature.init)
        Scope(\.favoritesState, action: \.favorites, FavoritesReducer.init)
        Scope(\.searchRootState, action: \.searchRoot, SearchRootReducer.init)
        Scope(\.downloadsState, action: \.downloads, DownloadsReducer.init)
        Scope(\.settingState, action: \.setting, SettingReducer.init)
        Scope(\.appLogsPumpState, action: \.appLogsPump, AppActivityLogsPumpReducer.init)
    }
}

private extension AppReducer {
    func tabSelectionEffect(type: TabBarItemType, state: inout State) -> Effect<Action> {
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
            case .library:
                guard let selection = state.libraryState.selection else { break }
                switch selection {
                case .favorites:
                    if !state.favoritesState.path.isEmpty {
                        state.favoritesState.path.removeAll()
                        effects.append(hapticEffect)
                    } else if cookieClient.didLogin {
                        effects.append(.send(.favorites(.fetchGalleries())))
                        effects.append(hapticEffect)
                    }
                case .downloads:
                    if !state.downloadsState.path.isEmpty {
                        state.downloadsState.path.removeAll()
                        effects.append(hapticEffect)
                    } else {
                        effects.append(.send(.downloads(.fetchDownloads)))
                        effects.append(hapticEffect)
                    }
                }
            case .search:
                if !state.searchRootState.path.isEmpty {
                    state.searchRootState.path.removeAll()
                } else {
                    // Keywords/quick-search words are live via @Shared now; re-tapping the
                    // Search tab at its root refreshes the recently-viewed galleries instead.
                    effects.append(.send(.searchRoot(.fetchHistoryGalleries)))
                }
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
            effects.append(tabPresentationEffect(for: type, state: &state))
        }
        return effects.isEmpty ? .none : .merge(effects)
    }

    /// The tab root's presentation action — the reducer-side replacement for the view `onAppear` it
    /// used to run. Setting takes no action here: its root menu is a static list, and each Setting
    /// screen starts itself when `SettingReducer` pushes it.
    func tabPresentationEffect(for type: TabBarItemType, state: inout State) -> Effect<Action> {
        switch type {
        case .home:
            return .send(.home(.onPresented))
        case .library:
            return librarySelectionEffect(state.libraryState.selection, state: &state)
        case .search:
            return .send(.searchRoot(.onPresented))
        case .setting:
            return .none
        }
    }

    func librarySelectionEffect(_ selection: LibraryGroup?, state: inout State) -> Effect<Action> {
        switch selection {
        case .favorites(let index):
            guard state.favoritesState.path.isEmpty else { return .none }
            return .merge(
                .send(.favorites(.setFavoritesIndex(index))),
                .send(.favorites(.onPresented))
            )
        case .downloads(let filter):
            guard state.downloadsState.path.isEmpty else { return .none }
            return .merge(
                .send(.downloads(.binding(.set(\.folderFilter, filter)))),
                .send(.downloads(.onPresented))
            )
        case .none:
            return .none
        }
    }

    /// Whether choosing the Setting tab presents Setting as a sheet over the current tab instead of
    /// selecting it. Only a window regular in both dimensions presents it, and never over the
    /// Setting tab itself: a narrower window may have left that tab selected, where a second
    /// choice pops it to its root rather than showing the same screens twice.
    func opensSettingAsSheet(_ state: State) -> Bool {
        state.windowSizeClasses?.presentsModally == true && state.tabBarState.tabBarItemType != .setting
    }

    /// Opens the gallery detail a tab host asked for: in a window regular in both dimensions as a
    /// sheet rooting its own gallery stack, seeded from the download when there is one, otherwise
    /// with the host's own `push`.
    func openGalleryDetail(
        _ gallery: Gallery,
        downloaded: DownloadedGallery? = nil,
        push: Action,
        state: State
    ) -> Effect<Action> {
        guard state.windowSizeClasses?.presentsModally == true else { return .send(push) }
        return .send(.presentation(.presentGalleryDetail(gallery: gallery, downloaded: downloaded)))
    }

    /// Flush actions for every reading session currently on top of a navigation host, so a background
    /// force-quit persists each reader's last debounced page. A reader is presented as a `.reading`
    /// destination of `.detail`/`.previews` (elements of the gallery stacks) or, for the Downloads tab
    /// and the modal detail, directly as a host destination. Any new host that can present a
    /// `.reading` destination must be registered here.
    func readingFlushEffects(_ state: State) -> [Effect<Action>] {
        var effects: [Effect<Action>] = []

        // GalleryPath stacks whose top element presents a reader.
        if let action = state.presentationState.gallery?.readingFlushAction {
            effects.append(.send(.presentation(.gallery(.presented(action)))))
        }
        if let action = state.homeState.sheet?.readingFlushAction {
            effects.append(.send(.home(.sheet(.presented(action)))))
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

        // The modal detail (a deep link, or a tab's gallery in a window regular in both
        // dimensions) and the Downloads tab present a reader directly.
        if state.downloadsState.destination?.reading != nil {
            effects.append(.send(.downloads(.destination(.presented(.reading(.flushReadingProgress))))))
        }

        return effects
    }

    /// Opens a capture route's screen the way a person does: the tab first, then the control that
    /// presents the screen, through the same actions those taps send, so each device presents it
    /// as it presents a tap. A screen inside a gallery starts with a tap on that gallery's card.
    func captureRouteEffect(_ route: AppLaunchAutomation.CaptureRoute) -> Effect<Action> {
        switch route {
        case .home:
            return .none
        case .detail(let gallery), .comments(let gallery),
             .reading(let gallery, _), .readingLiveText(let gallery, _):
            return .send(.home(.galleryTapped(gallery)))
        case .filters:
            return .run { send in
                await send(.tabBar(.setTabBarItemType(.search)))
                await send(.searchRoot(.filtersButtonTapped))
            }
        case .downloads:
            return .run { send in
                await send(.tabBar(.setTabBarItemType(.library)))
                await send(.library(.select(.downloads(.all))))
            }
        case .laboratory:
            return .run { send in
                await send(.tabBar(.setTabBarItemType(.setting)))
                await send(.setting(.settingRowTapped(.laboratory)))
            }
        }
    }

    func shouldDelayLaunchAutomationUntilIgneous(state: State) -> Bool {
        guard !state.didRunLaunchAutomation,
              cookieClient.shouldFetchIgneous,
              let automation = appLaunchAutomationClient.current()
        else { return false }

        if let galleryURL = automation.galleryURL,
           galleryURL.host(percentEncoded: false)?.contains("exhentai.org") == true {
            return true
        }

        return automation.autoDownloadGID != nil
            && state.settingState.setting.galleryHost == .exhentai
    }
}
