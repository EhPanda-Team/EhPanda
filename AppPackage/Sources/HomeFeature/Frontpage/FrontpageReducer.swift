import ComposableArchitecture
import AppModels
import Foundation
import AppTools
import SwiftUINavigationExt
import HapticsClient
import DatabaseClient
import NetworkingFeature
import FiltersFeature
import DateSeekFeature
import DetailFeature
import ComposableArchitectureExt

@Reducer
public struct FrontpageReducer: Sendable {
    @CasePathable
    public enum Route: Equatable, Sendable {
        case detail(String)
    }

    @Reducer
    public enum Destination {
        case filters(FiltersReducer)
        case dateSeek(DateSeekReducer)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries, fetchDateSeekGalleries
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        @Presents public var destination: Destination.State?
        public var keyword = ""

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        public var galleries = [Gallery]()
        public var pageNumber = PageNumber()
        public var dateSeekNavigation: DateSeekNavigation?
        public var loadingState: LoadingState = .idle
        public var footerLoadingState: LoadingState = .idle

        public var detailState: Heap<DetailReducer.State?>

        public init() {
            detailState = .init(.init())
        }

        mutating func insertGalleries(_ galleries: [Gallery]) {
            galleries.forEach { gallery in
                if !self.galleries.contains(gallery) {
                    self.galleries.append(gallery)
                }
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates
        case filtersButtonTapped
        case dateSeekButtonTapped(DateSeekNavigation)
        case destination(PresentationAction<Destination.Action>)

        case teardown
        case fetchGalleries
        case fetchGalleriesDone(Result<GalleriesResult, AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<GalleriesResult, AppError>)
        case performDateSeekDone(Result<GalleriesResult, AppError>)

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

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                return .send(.detail(.teardown))

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                return .none

            case .dateSeekButtonTapped(let navigation):
                state.destination = .dateSeek(.init(navigation: navigation))
                return .none

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return .run { send in
                    let response = await FrontpageGalleriesRequest(filter: filter).response()
                    await send(.fetchGalleriesDone(response))
                }
                .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let response):
                    let galleries = response.galleries
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        guard response.pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.pageNumber = response.pageNumber
                    state.dateSeekNavigation = response.dateSeekNavigation
                    state.galleries = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                let pageNumber = state.pageNumber
                guard pageNumber.hasNextPage(),
                      state.footerLoadingState != .loading,
                      let lastID = state.galleries.last?.id
                else { return .none }
                state.footerLoadingState = .loading
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return .run { send in
                    let response = await MoreFrontpageGalleriesRequest(filter: filter, lastID: lastID).response()
                    await send(.fetchMoreGalleriesDone(response))
                }
                .cancellable(id: CancelID.fetchMoreGalleries)

            case .fetchMoreGalleriesDone(let result):
                state.footerLoadingState = .idle
                switch result {
                case .success(let response):
                    let galleries = response.galleries
                    state.pageNumber = response.pageNumber
                    state.dateSeekNavigation = response.dateSeekNavigation
                    state.insertGalleries(galleries)

                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                    ]
                    if galleries.isEmpty, response.pageNumber.hasNextPage() {
                        effects.append(.send(.fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.loadingState = .idle
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.footerLoadingState = .failed(error)
                }
                return .none

            case .destination(.presented(.dateSeek(.delegate(.performSeek(let url))))):
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                state.footerLoadingState = .idle
                state.pageNumber.resetPages()
                return .run { send in
                    let response = await DateSeekGalleriesRequest(url: url).response()
                    await send(.performDateSeekDone(response))
                }
                .cancellable(id: CancelID.fetchDateSeekGalleries)

            case .performDateSeekDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let response):
                    let galleries = response.galleries
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.pageNumber = response.pageNumber
                    state.dateSeekNavigation = response.dateSeekNavigation
                    state.galleries = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .destination:
                return .none

            case .detail:
                return .none
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.filters,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.destination,
            case: \.dateSeek,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)

        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}

extension FrontpageReducer.Destination.State: Equatable, Sendable {}
