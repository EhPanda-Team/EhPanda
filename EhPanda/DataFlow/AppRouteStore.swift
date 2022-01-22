//
//  AppRouteStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import ComposableArchitecture
import TTProgressHUD

struct AppRouteState: Equatable {
    enum Route: Equatable {
        case hud
        case filters
        case detail(String)
        case newDawn(Greeting)
    }

    @BindableState var route: Route?
    var hudConfig: TTProgressHUDConfig = .loading

    var filtersState = FiltersState()
    var detailState = DetailState()
}

enum AppRouteAction: BindableAction {
    case binding(BindingAction<AppRouteState>)
    case setNavigation(AppRouteState.Route?)
    case setHUDConfig(TTProgressHUDConfig)
    case clearSubStates

    case detectClipboardURL
    case handleDeepLink(URL)
    case handleGalleryLink(URL)

    case updateReadingProgress(String, Int)

    case fetchGallery(URL, Bool)
    case fetchGalleryDone(URL, Result<Gallery, AppError>)
    case fetchGreetingDone(Result<Greeting, AppError>)

    case filters(FiltersAction)
    case detail(DetailAction)
}

struct AppRouteEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let userDefaultsClient: UserDefaultsClient
    let uiApplicationClient: UIApplicationClient
}

let appRouteReducer = Reducer<AppRouteState, AppRouteAction, AppRouteEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .setHUDConfig(let config):
            state.hudConfig = config
            return .none

        case .clearSubStates:
            state.detailState = .init()
            state.filtersState = .init()
            return .init(value: .detail(.cancelFetching))

        case .detectClipboardURL:
            let currentChangeCount = environment.clipboardClient.changeCount()
            guard currentChangeCount != environment.userDefaultsClient
                    .getValue(.clipboardChangeCount) else { return .none }
            var effects: [Effect<AppRouteAction, Never>] = [
                environment.userDefaultsClient
                    .setValue(currentChangeCount, .clipboardChangeCount).fireAndForget()
            ]
            if let url = environment.clipboardClient.url() {
                effects.append(.init(value: .handleDeepLink(url)))
            }
            return .merge(effects)

        case .handleDeepLink(let url):
            var url = environment.urlClient.resolveAppSchemeURL(url) ?? url
            guard environment.urlClient.checkIfHandleable(url) else { return .none }
            let (isGalleryImageURL, _, _) = environment.urlClient.analyzeURL(url)
            let gid = environment.urlClient.parseGalleryID(url)
            guard !environment.databaseClient.checkGalleryExistence(gid: gid) else {
                return .init(value: .handleGalleryLink(url))
            }
            return .init(value: .fetchGallery(url, isGalleryImageURL))

        case .handleGalleryLink(let url):
            let (_, pageIndex, commentID) = environment.urlClient.analyzeURL(url)
            let gid = environment.urlClient.parseGalleryID(url)
            var effects = [Effect<AppRouteAction, Never>]()
            state.detailState = .init()
            effects.append(.init(value: .detail(.fetchDatabaseInfos(gid))))
            if let pageIndex = pageIndex {
                effects.append(.init(value: .updateReadingProgress(gid, pageIndex)))
                effects.append(
                    .init(value: .detail(.setNavigation(.reading)))
                        .delay(for: .milliseconds(500), scheduler: DispatchQueue.main).eraseToEffect()
                )
            } else if let commentID = commentID {
                state.detailState.commentsState.scrollCommentID = commentID
                effects.append(
                    .init(value: .detail(.setNavigation(.comments)))
                        .delay(for: .milliseconds(500), scheduler: DispatchQueue.main).eraseToEffect()
                )
            }
            effects.append(.init(value: .setNavigation(.detail(gid))))
            return .merge(effects)

        case .updateReadingProgress(let gid, let progress):
            guard !gid.isEmpty else { return .none }
            return environment.databaseClient
                .updateReadingProgress(gid: gid, progress: progress).fireAndForget()

        case .fetchGallery(let url, let isGalleryImageURL):
            state.route = .hud
            return GalleryReverseRequest(url: url, isGalleryImageURL: isGalleryImageURL)
                .effect.map({ AppRouteAction.fetchGalleryDone(url, $0) })

        case .fetchGalleryDone(let url, let result):
            state.route = nil
            switch result {
            case .success(let gallery):
                return .merge(
                    environment.databaseClient.cacheGalleries([gallery]).fireAndForget(),
                    .init(value: .handleGalleryLink(url))
                )
            case .failure:
                return .init(value: .setHUDConfig(.error))
                    .delay(for: .milliseconds(500), scheduler: DispatchQueue.main).eraseToEffect()
            }

        case .fetchGreetingDone(let result):
            if case .success(let greeting) = result, !greeting.gainedNothing {
                return .init(value: .setNavigation(.newDawn(greeting)))
            }
            return .none

        case .filters:
            return .none

        case .detail:
            return .none
        }
    }
    .binding(),
    filtersReducer.pullback(
        state: \.filtersState,
        action: /AppRouteAction.filters,
        environment: { _ in
            .init()
        }
    ),
    detailReducer.pullback(
        state: \.detailState,
        action: /AppRouteAction.detail,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
