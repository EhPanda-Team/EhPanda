//
//  FrontpageStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import ComposableArchitecture

struct FrontpageState: Equatable {
    enum Route: Equatable {
        case detail(String)
    }
    struct CancelID: Hashable {
        let id = String(describing: FrontpageState.self)
    }

    init() {
        _detailState = .init(.init())
    }

    @BindableState var route: Route?
    @BindableState var keyword = ""
    @BindableState var jumpPageIndex = ""
    @BindableState var jumpPageAlertFocused = false
    @BindableState var jumpPageAlertPresented = false

    var filteredGalleries: [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
    }
    var galleries = [Gallery]()
    var pageNumber = PageNumber()
    var loadingState: LoadingState = .idle
    var footerLoadingState: LoadingState = .idle

    @Heap var detailState: DetailState!

    mutating func insertGalleries(_ galleries: [Gallery]) {
        galleries.forEach { gallery in
            if !self.galleries.contains(gallery) {
                self.galleries.append(gallery)
            }
        }
    }
}

enum FrontpageAction: BindableAction {
    case binding(BindingAction<FrontpageState>)
    case setNavigation(FrontpageState.Route?)
    case clearSubStates
    case onFiltersButtonTapped

    case performJumpPage
    case presentJumpPageAlert
    case setJumpPageAlertFocused(Bool)

    case teardown
    case fetchGalleries(Int? = nil)
    case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreGalleries
    case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)

    case detail(DetailAction)
}

struct FrontpageEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
    let uiApplicationClient: UIApplicationClient
}

let frontpageReducer = Reducer<FrontpageState, FrontpageAction, FrontpageEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding(\.$jumpPageAlertPresented):
            if !state.jumpPageAlertPresented {
                state.jumpPageAlertFocused = false
            }
            return .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .clearSubStates:
            state.detailState = .init()
            return .init(value: .detail(.teardown))

        case .onFiltersButtonTapped:
            return .none

        case .performJumpPage:
            guard let index = Int(state.jumpPageIndex), index > 0, index <= state.pageNumber.maximum + 1 else {
                return environment.hapticClient.generateNotificationFeedback(.error).fireAndForget()
            }
            return .init(value: .fetchGalleries(index - 1))

        case .presentJumpPageAlert:
            state.jumpPageAlertPresented = true
            return environment.hapticClient.generateFeedback(.light).fireAndForget()

        case .setJumpPageAlertFocused(let isFocused):
            state.jumpPageAlertFocused = isFocused
            return .none

        case .teardown:
            return .cancel(id: FrontpageState.CancelID())

        case .fetchGalleries(let pageNum):
            guard state.loadingState != .loading else { return .none }
            state.loadingState = .loading
            state.pageNumber.current = 0
            let filter = environment.databaseClient.fetchFilterSynchronously(range: .global)
            return FrontpageGalleriesRequest(filter: filter, pageNum: pageNum)
                .effect.map(FrontpageAction.fetchGalleriesDone).cancellable(id: FrontpageState.CancelID())

        case .fetchGalleriesDone(let result):
            state.loadingState = .idle
            switch result {
            case .success(let (pageNumber, galleries)):
                guard !galleries.isEmpty else {
                    guard pageNumber.current < pageNumber.maximum else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    return .init(value: .fetchMoreGalleries)
                }
                state.pageNumber = pageNumber
                state.galleries = galleries
                return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
            case .failure(let error):
                state.loadingState = .failed(error)
            }
            return .none

        case .fetchMoreGalleries:
            let pageNumber = state.pageNumber
            guard pageNumber.current + 1 <= pageNumber.maximum,
                  state.footerLoadingState != .loading,
                  let lastID = state.galleries.last?.id
            else { return .none }
            state.footerLoadingState = .loading
            let pageNum = pageNumber.current + 1
            let filter = environment.databaseClient.fetchFilterSynchronously(range: .global)
            return MoreFrontpageGalleriesRequest(filter: filter, lastID: lastID, pageNum: pageNum)
                .effect.map(FrontpageAction.fetchMoreGalleriesDone).cancellable(id: FrontpageState.CancelID())

        case .fetchMoreGalleriesDone(let result):
            state.footerLoadingState = .idle
            switch result {
            case .success(let (pageNumber, galleries)):
                state.pageNumber = pageNumber
                state.insertGalleries(galleries)

                var effects: [Effect<FrontpageAction, Never>] = [
                    environment.databaseClient.cacheGalleries(galleries).fireAndForget()
                ]
                if galleries.isEmpty, pageNumber.current < pageNumber.maximum {
                    effects.append(.init(value: .fetchMoreGalleries))
                }
                return .merge(effects)

            case .failure(let error):
                state.footerLoadingState = .failed(error)
            }
            return .none

        case .detail:
            return .none
        }
    }
    .binding(),
    detailReducer.pullback(
        state: \.detailState,
        action: /FrontpageAction.detail,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
