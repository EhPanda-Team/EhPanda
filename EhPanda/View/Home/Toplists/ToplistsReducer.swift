//
//  ToplistsReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import ComposableArchitecture

struct ToplistsReducer: ReducerProtocol {
    enum Route: Equatable {
        case detail(String)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var keyword = ""
        @BindingState var jumpPageIndex = ""
        @BindingState var jumpPageAlertFocused = false
        @BindingState var jumpPageAlertPresented = false

        var type: ToplistsType = .yesterday

        var filteredGalleries: [Gallery]? {
            guard !keyword.isEmpty else { return galleries }
            return galleries?.filter({ $0.title.caseInsensitiveContains(keyword) })
        }

        var rawGalleries = [ToplistsType: [Gallery]]()
        var rawPageNumber = [ToplistsType: PageNumber]()
        var rawLoadingState = [ToplistsType: LoadingState]()
        var rawFooterLoadingState = [ToplistsType: LoadingState]()

        var galleries: [Gallery]? {
            rawGalleries[type]
        }
        var pageNumber: PageNumber? {
            rawPageNumber[type]
        }
        var loadingState: LoadingState? {
            rawLoadingState[type]
        }
        var footerLoadingState: LoadingState? {
            rawFooterLoadingState[type]
        }

        @Heap var detailState: DetailReducer.State!

        init() {
            _detailState = .init(.init())
        }

        mutating func insertGalleries(type: ToplistsType, galleries: [Gallery]) {
            galleries.forEach { gallery in
                if rawGalleries[type]?.contains(gallery) == false {
                    rawGalleries[type]?.append(gallery)
                }
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case setToplistsType(ToplistsType)
        case clearSubStates

        case performJumpPage
        case presentJumpPageAlert
        case setJumpPageAlertFocused(Bool)

        case teardown
        case fetchGalleries(Int? = nil)
        case fetchGalleriesDone(ToplistsType, Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(ToplistsType, Result<(PageNumber, [Gallery]), AppError>)

        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
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

            case .setToplistsType(let type):
                state.type = type
                guard state.galleries?.isEmpty != false else { return .none }
                return .init(value: Action.fetchGalleries())

            case .clearSubStates:
                state.detailState = .init()
                return .init(value: .detail(.teardown))

            case .performJumpPage:
                guard let index = Int(state.jumpPageIndex),
                      let pageNumber = state.pageNumber,
                      index > 0, index <= pageNumber.maximum + 1 else {
                    return .fireAndForget({ hapticsClient.generateNotificationFeedback(.error) })
                }
                return .init(value: .fetchGalleries(index - 1))

            case .presentJumpPageAlert:
                state.jumpPageAlertPresented = true
                return .fireAndForget({ hapticsClient.generateFeedback(.light) })

            case .setJumpPageAlertFocused(let isFocused):
                state.jumpPageAlertFocused = isFocused
                return .none

            case .teardown:
                return .cancel(ids: CancelID.allCases)

            case .fetchGalleries(let pageNum):
                guard state.loadingState != .loading else { return .none }
                state.rawLoadingState[state.type] = .loading
                if state.pageNumber == nil {
                    state.rawPageNumber[state.type] = PageNumber()
                } else {
                    state.rawPageNumber[state.type]?.resetPages()
                }
                return ToplistsGalleriesRequest(catIndex: state.type.categoryIndex, pageNum: pageNum)
                    .effect.map({ [type = state.type] in Action.fetchGalleriesDone(type, $0) })
                    .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let type, let result):
                state.rawLoadingState[type] = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.rawLoadingState[type] = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .init(value: .fetchMoreGalleries)
                    }
                    state.rawPageNumber[type] = pageNumber
                    state.rawGalleries[type] = galleries
                    return databaseClient.cacheGalleries(galleries).fireAndForget()
                case .failure(let error):
                    state.rawLoadingState[type] = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                let pageNumber = state.pageNumber ?? .init()
                guard pageNumber.hasNextPage(),
                      state.footerLoadingState != .loading
                else { return .none }
                state.rawFooterLoadingState[state.type] = .loading
                let pageNum = pageNumber.current + 1
                return MoreToplistsGalleriesRequest(catIndex: state.type.categoryIndex, pageNum: pageNum)
                    .effect.map({ [type = state.type] in Action.fetchMoreGalleriesDone(type, $0) })
                    .cancellable(id: CancelID.fetchMoreGalleries)

            case .fetchMoreGalleriesDone(let type, let result):
                state.rawFooterLoadingState[type] = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    state.rawPageNumber[type] = pageNumber
                    state.insertGalleries(type: type, galleries: galleries)

                    var effects: [EffectTask<Action>] = [
                        databaseClient.cacheGalleries(galleries).fireAndForget()
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.init(value: .fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.rawLoadingState[type] = .idle
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.rawFooterLoadingState[type] = .failed(error)
                }
                return .none

            case .detail:
                return .none
            }
        }

        Scope(state: \.detailState, action: /Action.detail, child: DetailReducer.init)
    }
}
