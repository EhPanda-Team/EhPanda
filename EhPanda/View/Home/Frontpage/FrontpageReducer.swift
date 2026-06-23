//
//  FrontpageReducer.swift
//  EhPanda
//

import ComposableArchitecture
import Foundation

@Reducer
struct FrontpageReducer {
    @CasePathable
    enum Route: Equatable {
        case filters(EquatableVoid = .init())
        case detail(String)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries, fetchDateSeekGalleries
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var keyword = ""

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        var galleries = [Gallery]()
        var pageNumber = PageNumber()
        var dateSeekDate = Date()
        var dateSeekSheetPresented = false
        var loadingState: LoadingState = .idle
        var footerLoadingState: LoadingState = .idle

        var filtersState = FiltersReducer.State()
        var detailState: Heap<DetailReducer.State?>

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
        case setNavigation(Route?)
        case clearSubStates

        case teardown
        case fetchGalleries
        case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case presentDateSeek
        case performDateSeek(DateSeekDirection)
        case performDateSeekDone(Result<(PageNumber, [Gallery]), AppError>)

        case filters(FiltersReducer.Action)
        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some Reducer<State, Action> {
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
                state.filtersState = .init()
                return .send(.detail(.teardown))

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
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return .run { send in
                    let response = await MoreFrontpageGalleriesRequest(filter: filter, lastID: lastID).response()
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

            case .presentDateSeek:
                guard let navigation = state.pageNumber.dateSeekNavigation, navigation.isEnabled else {
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }
                state.dateSeekDate = navigation.clampedDate(state.dateSeekDate)
                state.dateSeekSheetPresented = true
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

            case .performDateSeek(let direction):
                guard state.loadingState != .loading,
                      let url = state.pageNumber.dateSeekNavigation?.seekURL(
                        date: state.dateSeekDate, direction: direction
                      )
                else { return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) }) }

                state.dateSeekSheetPresented = false
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
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.pageNumber = pageNumber
                    if let navigation = pageNumber.dateSeekNavigation {
                        state.dateSeekDate = navigation.clampedDate(state.dateSeekDate)
                    }
                    state.galleries = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .filters:
                return .none

            case .detail:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: \.filters,
            hapticsClient: hapticsClient
        )

        Scope(state: \.filtersState, action: \.filters, child: FiltersReducer.init)
        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}
