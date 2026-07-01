import AppTools
import ComposableArchitecture
import AppModels
import Foundation
import SwiftUINavigationExt
import HapticsClient
import DatabaseClient
import NetworkingFeature
import DownloadClient
import FiltersFeature
import DateSeekFeature
import QuickSearchFeature
import DetailFeature
import ComposableArchitectureExt

@Reducer
public struct SearchReducer: Sendable {
    @CasePathable
    public enum Route: Equatable, Sendable {
        case detail(String)
    }

    @Reducer
    public enum Destination {
        case filters(FiltersReducer)
        case quickSearch(QuickSearchReducer)
        case dateSeek(DateSeekReducer)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries, observeDownloads, fetchDateSeekGalleries
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        @Presents public var destination: Destination.State?
        public var keyword = ""
        public var lastKeyword = ""

        public var galleries = [Gallery]()
        public var pageNumber = PageNumber()
        public var dateSeekNavigation: DateSeekNavigation?
        public var loadingState: LoadingState = .idle
        public var footerLoadingState: LoadingState = .idle
        public var downloadBadges = [String: DownloadBadge]()

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
        case onAppear
        case setNavigation(Route?)
        case clearSubStates
        case filtersButtonTapped
        case quickSearchButtonTapped
        case dateSeekButtonTapped(DateSeekNavigation)
        case destination(PresentationAction<Destination.Action>)

        case teardown
        case fetchGalleries(String? = nil)
        case fetchGalleriesDone(Result<GalleriesResult, AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<GalleriesResult, AppError>)
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case performDateSeekDone(Result<GalleriesResult, AppError>)

        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }
            .onChange(of: \.keyword) { _, state in
                if !state.keyword.isEmpty {
                    state.lastKeyword = state.keyword
                }
                return .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.observeDownloads)

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                return .send(.detail(.teardown))

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                return .none

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                return .none

            case .dateSeekButtonTapped(let navigation):
                state.destination = .dateSeek(.init(navigation: navigation))
                return .none

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchGalleries(let keyword):
                guard state.loadingState != .loading else { return .none }
                if let keyword = keyword {
                    state.keyword = keyword
                    state.lastKeyword = keyword
                }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = databaseClient.fetchFilterSynchronously(range: .search)
                return .run { [lastKeyword = state.lastKeyword] send in
                    let response = await SearchGalleriesRequest(keyword: lastKeyword, filter: filter).response()
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
                let filter = databaseClient.fetchFilterSynchronously(range: .search)
                return .run { [lastKeyword = state.lastKeyword] send in
                    let response = await MoreSearchGalleriesRequest(
                        keyword: lastKeyword, filter: filter, lastID: lastID
                    )
                    .response()
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

            case .observeDownloads:
                return .run { send in
                    for await downloads in downloadClient.observeDownloads() {
                        await send(.observeDownloadsDone(downloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone(let downloads):
                state.downloadBadges = Dictionary(
                    uniqueKeysWithValues: downloads.map { ($0.gid, $0.badge) }
                )
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
            case: \.quickSearch,
            hapticsClient: hapticsClient
        )
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

extension SearchReducer.Destination.State: Equatable, Sendable {}
