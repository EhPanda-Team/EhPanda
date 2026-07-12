import ComposableArchitecture
import AppModels
import Sharing
import Foundation
import AppTools
import HapticsClient
import NetworkingFeature
import FiltersFeature
import DateSeekFeature

@Reducer
public struct FrontpageReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case pushDetail(Gallery)
    }

    @Reducer
    public enum Destination {
        case filters(FiltersReducer)
        case dateSeek(DateSeekReducer)
    }

    private enum CancelID {
        case fetchGalleries, fetchMoreGalleries, fetchDateSeekGalleries
    }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.globalFilter) public var globalFilter: Filter
        @SharedReader(.tagTranslator) public var tagTranslator: TagTranslator
        @SharedReader(.setting) public var setting: Setting
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

        public init() {}

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
        case delegate(Delegate)
        case filtersButtonTapped
        case dateSeekButtonTapped(DateSeekNavigation)
        case destination(PresentationAction<Destination.Action>)

        case fetchGalleries
        case fetchGalleriesDone(Result<GalleriesResult, AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<GalleriesResult, AppError>)
        case performDateSeekDone(Result<GalleriesResult, AppError>)
    }

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

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                return .none

            case .dateSeekButtonTapped(let navigation):
                state.destination = .dateSeek(.init(navigation: navigation))
                return .none

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = state.globalFilter
                return .run { send in
                    do throws(AppError) {
                        let response = try await FrontpageGalleriesRequest(filter: filter).response()
                        await send(.fetchGalleriesDone(.success(response)))
                    } catch {
                        await send(.fetchGalleriesDone(.failure(error)))
                    }
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
                    return .none
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
                let filter = state.globalFilter
                return .run { send in
                    do throws(AppError) {
                        let response = try await MoreFrontpageGalleriesRequest(
                            filter: filter,
                            lastID: lastID
                        )
                        .response()
                        await send(.fetchMoreGalleriesDone(.success(response)))
                    } catch {
                        await send(.fetchMoreGalleriesDone(.failure(error)))
                    }
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

                    var effects: [Effect<Action>] = []
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
                    do throws(AppError) {
                        let response = try await DateSeekGalleriesRequest(url: url).response()
                        await send(.performDateSeekDone(.success(response)))
                    } catch {
                        await send(.performDateSeekDone(.failure(error)))
                    }
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
                    return .none
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .destination:
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
    }
}

extension FrontpageReducer.Destination.State: Equatable, Sendable {}
