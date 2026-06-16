//
//  SearchReducer.swift
//  EhPanda
//

import ComposableArchitecture
import Foundation

@Reducer
struct SearchReducer {
    @CasePathable
    enum Route: Equatable {
        case filters(EquatableVoid = .init())
        case quickSearch(EquatableVoid = .init())
        case detail(String)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries, observeDownloads, fetchJumpGalleries
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var keyword = ""
        var lastKeyword = ""

        var galleries = [Gallery]()
        var pageNumber = PageNumber()
        var dateJumpDate = Date()
        var dateJumpSheetPresented = false
        var loadingState: LoadingState = .idle
        var footerLoadingState: LoadingState = .idle
        var downloadBadges = [String: DownloadBadge]()

        var filtersState = FiltersReducer.State()
        var detailState: Heap<DetailReducer.State?>
        var quickSearchState = QuickSearchReducer.State()

        init() {
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

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case setNavigation(Route?)
        case clearSubStates

        case teardown
        case fetchGalleries(String? = nil)
        case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case presentDateJump
        case jumpToDate(PageJumpDirection)
        case jumpToDateDone(Result<(PageNumber, [Gallery]), AppError>)

        case detail(DetailReducer.Action)
        case filters(FiltersReducer.Action)
        case quickSearch(QuickSearchReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some Reducer<State, Action> {
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
                state.filtersState = .init()
                state.quickSearchState = .init()
                return .merge(
                    .send(.detail(.teardown)),
                    .send(.quickSearch(.teardown))
                )

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
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.pageNumber = pageNumber
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
                case .success(let (pageNumber, galleries)):
                    state.pageNumber = pageNumber
                    state.insertGalleries(galleries)

                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
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

            case .presentDateJump:
                guard let navigation = state.pageNumber.jumpNavigation, navigation.isEnabled else {
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }
                state.dateJumpDate = navigation.clampedDate(state.dateJumpDate)
                state.dateJumpSheetPresented = true
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

            case .jumpToDate(let direction):
                guard state.loadingState != .loading,
                      let url = state.pageNumber.jumpNavigation?.seekURL(
                        date: state.dateJumpDate, direction: direction
                      )
                else { return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) }) }

                state.dateJumpSheetPresented = false
                state.loadingState = .loading
                state.footerLoadingState = .idle
                state.pageNumber.resetPages()
                return .run { send in
                    let response = await JumpGalleriesRequest(url: url).response()
                    await send(.jumpToDateDone(response))
                }
                .cancellable(id: CancelID.fetchJumpGalleries)

            case .jumpToDateDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.pageNumber = pageNumber
                    if let navigation = pageNumber.jumpNavigation {
                        state.dateJumpDate = navigation.clampedDate(state.dateJumpDate)
                    }
                    state.galleries = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .detail:
                return .none

            case .filters:
                return .none

            case .quickSearch:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: \.quickSearch,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: \.filters,
            hapticsClient: hapticsClient
        )

        Scope(state: \.filtersState, action: \.filters, child: FiltersReducer.init)
        Scope(state: \.quickSearchState, action: \.quickSearch, child: QuickSearchReducer.init)
        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}
