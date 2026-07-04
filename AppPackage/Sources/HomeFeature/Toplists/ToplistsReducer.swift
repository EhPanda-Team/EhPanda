import ComposableArchitecture
import AppModels
import AppTools
import AppComponents
import Resources
import HapticsClient
import DatabaseClient
import NetworkingFeature

@Reducer
public struct ToplistsReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case pushDetail(String)
    }

    public enum Alert: Equatable, Sendable {
        case performJumpPage
    }

    private enum CancelID {
        case fetchGalleries, fetchMoreGalleries
    }

    @ObservableState
    public struct State: Equatable {
        public var keyword = ""
        public var jumpPageIndex = ""
        @Presents public var alert: AppAlertState<Alert>?

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

        public init() {}

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
        case delegate(Delegate)
        case setToplistsType(ToplistsType)

        case alert(PresentationAction<Alert>)
        case presentJumpPageAlert

        case fetchGalleries(Int? = nil)
        case fetchGalleriesDone(ToplistsType, Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(ToplistsType, Result<(PageNumber, [Gallery]), AppError>)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .setToplistsType(let type):
                state.type = type
                guard state.galleries?.isEmpty != false else { return .none }
                return .send(.fetchGalleries())

            case .alert(.presented(.performJumpPage)):
                guard let index = Int(state.jumpPageIndex),
                      let pageNumber = state.pageNumber,
                      index > 0, index <= pageNumber.maximum + 1 else {
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }
                return .send(.fetchGalleries(index - 1))

            case .alert:
                return .none

            case .presentJumpPageAlert:
                let maximumPage = (state.pageNumber?.maximum ?? 0) + 1
                state.alert = AppAlertState(
                    title: {
                        TextState(localized: .RLocalizable.jumpPage)
                    },
                    textField: .init(
                        placeholder: TextState(localized: .RLocalizable.jumpPage),
                        keyboard: .numberPad
                    ),
                    actions: {
                        ButtonState(action: .performJumpPage) {
                            TextState(localized: .confirm)
                        }
                        ButtonState(role: .cancel) {
                            TextState(localized: .RLocalizable.cancel)
                        }
                    },
                    message: {
                        TextState(localized: .jumpPageDescription(max: maximumPage))
                    }
                )
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

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
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
