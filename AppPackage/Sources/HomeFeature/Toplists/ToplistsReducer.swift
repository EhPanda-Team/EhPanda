import ComposableArchitecture
import AppModels
import FoundationExt
import HapticsClient
import DatabaseClient
import NetworkingFeature
import DetailFeature
import ComposableArchitectureExt

@Reducer
public struct ToplistsReducer: Sendable {
    @dynamicMemberLookup @CasePathable
    public enum Route: Equatable, Sendable {
        case detail(String)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        public var keyword = ""
        public var jumpPageIndex = ""
        public var jumpPageAlertFocused = false
        public var jumpPageAlertPresented = false

        public var type: ToplistsType = .yesterday

        var filteredGalleries: [Gallery]? {
            guard !keyword.isEmpty else { return galleries }
            return galleries?.filter({ $0.title.caseInsensitiveContains(keyword) })
        }

        public var rawGalleries = [ToplistsType: [Gallery]]()
        public var rawPageNumber = [ToplistsType: PageNumber]()
        public var rawLoadingState = [ToplistsType: LoadingState]()
        public var rawFooterLoadingState = [ToplistsType: LoadingState]()

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

        public var detailState: Heap<DetailReducer.State?>

        public init() {
            detailState = .init(.init())
        }

        mutating func insertGalleries(type: ToplistsType, galleries: [Gallery]) {
            galleries.forEach { gallery in
                if rawGalleries[type]?.contains(gallery) == false {
                    rawGalleries[type]?.append(gallery)
                }
            }
        }
    }

    public enum Action: BindableAction {
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

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }
            .onChange(of: \.jumpPageAlertPresented) { _, state in
                if !state.jumpPageAlertPresented {
                    state.jumpPageAlertFocused = false
                }
                return .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .setToplistsType(let type):
                state.type = type
                guard state.galleries?.isEmpty != false else { return .none }
                return .send(.fetchGalleries())

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                return .send(.detail(.teardown))

            case .performJumpPage:
                guard let index = Int(state.jumpPageIndex),
                      let pageNumber = state.pageNumber,
                      index > 0, index <= pageNumber.maximum + 1 else {
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }
                return .send(.fetchGalleries(index - 1))

            case .presentJumpPageAlert:
                state.jumpPageAlertPresented = true
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

            case .setJumpPageAlertFocused(let isFocused):
                state.jumpPageAlertFocused = isFocused
                return .none

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchGalleries(let pageNum):
                guard state.loadingState != .loading else { return .none }
                state.rawLoadingState[state.type] = .loading
                if state.pageNumber == nil {
                    state.rawPageNumber[state.type] = PageNumber()
                } else {
                    state.rawPageNumber[state.type]?.resetPages()
                }
                return .run { [type = state.type] send in
                    let response = await ToplistsGalleriesRequest(
                        catIndex: type.categoryIndex, pageNum: pageNum
                    )
                    .response()
                    await send(.fetchGalleriesDone(type, response))
                }
                .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let type, let result):
                state.rawLoadingState[type] = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.rawLoadingState[type] = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.rawPageNumber[type] = pageNumber
                    state.rawGalleries[type] = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
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
                return .run { [type = state.type] send in
                    let response = await MoreToplistsGalleriesRequest(
                        catIndex: type.categoryIndex, pageNum: pageNum
                    )
                    .response()
                    await send(.fetchMoreGalleriesDone(type, response))
                }
                .cancellable(id: CancelID.fetchMoreGalleries)

            case .fetchMoreGalleriesDone(let type, let result):
                state.rawFooterLoadingState[type] = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    state.rawPageNumber[type] = pageNumber
                    state.insertGalleries(type: type, galleries: galleries)

                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.send(.fetchMoreGalleries))
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

        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}
