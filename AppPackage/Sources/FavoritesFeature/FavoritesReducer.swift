import AppTools
import SwiftUI
import AppModels
import IdentifiedCollections
import ComposableArchitecture
import HapticsClient
import NetworkingFeature
import DownloadClient
import DeviceClient
import DateSeekFeature
import QuickSearchFeature
import DetailFeature

@Reducer
public struct FavoritesReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case presentGalleryDetail(Gallery)
    }

    private enum CancelID {
        case observeDownloads
    }

    @Reducer
    public enum Destination {
        case quickSearch(QuickSearchReducer)
        case dateSeek(DateSeekReducer)
    }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.tagTranslator) public var tagTranslator: TagTranslator
        @SharedReader(.user) public var user: User
        @SharedReader(.setting) public var setting: Setting
        public var path = StackState<GalleryPath.State>()
        @Presents public var destination: Destination.State?
        public var keyword = ""

        public var index = -1
        public var sortOrder: FavoritesSortOrder?

        public var rawGalleries = [Int: [Gallery]]()
        public var rawPageNumber = [Int: PageNumber]()
        public var rawDateSeekNavigation = [Int: DateSeekNavigation]()
        public var rawLoadingState = [Int: LoadingState]()
        public var rawFooterLoadingState = [Int: LoadingState]()
        public var downloadBadges = [String: DownloadBadge]()

        var galleries: [Gallery]? {
            rawGalleries[index]
        }
        var pageNumber: PageNumber? {
            rawPageNumber[index]
        }
        var dateSeekNavigation: DateSeekNavigation? {
            rawDateSeekNavigation[index]
        }
        var loadingState: LoadingState? {
            rawLoadingState[index]
        }
        var footerLoadingState: LoadingState? {
            rawFooterLoadingState[index]
        }

        public init() {}

        mutating func insertGalleries(index: Int, galleries: [Gallery]) {
            galleries.forEach { gallery in
                if rawGalleries[index]?.contains(gallery) == false {
                    rawGalleries[index]?.append(gallery)
                }
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case delegate(Delegate)
        case galleryTapped(Gallery)
        case pushGalleryDetail(Gallery)
        case path(StackActionOf<GalleryPath>)
        case setFavoritesIndex(Int)
        case quickSearchButtonTapped
        case dateSeekButtonTapped(DateSeekNavigation)
        case destination(PresentationAction<Destination.Action>)
        case onNotLoginViewButtonTapped

        case fetchGalleries(String? = nil, FavoritesSortOrder? = nil)
        case fetchGalleriesDone(Int, Result<FavoritesGalleriesResult, AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Int, Result<FavoritesGalleriesResult, AppError>)
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case performDateSeekDone(Int, Result<GalleriesResult, AppError>)
    }

    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.observeDownloads)

            case .galleryTapped(let gallery):
                return GalleryNavigation.routeGalleryDetail(
                    isPad: deviceClient.isPad,
                    present: { .delegate(.presentGalleryDetail(gallery)) },
                    push: { .pushGalleryDetail(gallery) }
                )

            case .pushGalleryDetail(let gallery):
                state.path.appendGuardingDuplicate(.detail(.init(gallery: gallery)))
                return .none

            case .delegate:
                return .none

            case let .path(.element(id: _, action: .comments(.delegate(.performedCommentAction(gid))))):
                guard let id = state.path.detailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .detail(.fetchGalleryDetail))))

            case let .path(.element(id: _, action: elementAction)):
                if let next = GalleryNavigation.nextScreen(for: elementAction) {
                    state.path.appendGuardingDuplicate(next)
                }
                return .none

            case .path:
                return .none

            case .setFavoritesIndex(let index):
                state.index = index
                guard state.galleries?.isEmpty != false else { return .none }
                return .send(.fetchGalleries())

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                return .none

            case .dateSeekButtonTapped(let navigation):
                state.destination = .dateSeek(.init(navigation: navigation))
                return .none

            case .onNotLoginViewButtonTapped:
                return .none

            case .fetchGalleries(let keyword, let sortOrder):
                guard state.loadingState != .loading else { return .none }
                state.rawLoadingState[state.index] = .loading
                if let keyword = keyword {
                    state.keyword = keyword
                }
                if state.pageNumber == nil {
                    state.rawPageNumber[state.index] = PageNumber()
                } else {
                    state.rawPageNumber[state.index]?.resetPages()
                }
                return .run { [index = state.index, keyword = state.keyword] send in
                    do throws(AppError) {
                        let response = try await FavoritesGalleriesRequest(
                            favIndex: index,
                            keyword: keyword,
                            sortOrder: sortOrder
                        )
                        .response()
                        await send(.fetchGalleriesDone(index, .success(response)))
                    } catch {
                        await send(.fetchGalleriesDone(index, .failure(error)))
                    }
                }

            case .fetchGalleriesDone(let targetFavIndex, let result):
                state.rawLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let fetchResult):
                    let pageNumber = fetchResult.pageNumber
                    let galleries = fetchResult.galleries
                    guard !galleries.isEmpty else {
                        state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.rawDateSeekNavigation[targetFavIndex] = fetchResult.dateSeekNavigation
                    state.rawGalleries[targetFavIndex] = galleries
                    state.sortOrder = fetchResult.sortOrder
                    return .none
                case .failure(let error):
                    state.rawLoadingState[targetFavIndex] = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                let pageNumber = state.pageNumber ?? .init()
                guard pageNumber.hasNextPage(),
                      state.footerLoadingState != .loading,
                      let lastID = state.galleries?.last?.id,
                      let lastItemTimestamp = pageNumber.lastItemTimestamp
                else { return .none }
                state.rawFooterLoadingState[state.index] = .loading
                return .run { [index = state.index, keyword = state.keyword] send in
                    do throws(AppError) {
                        let response = try await MoreFavoritesGalleriesRequest(
                            favIndex: index,
                            lastID: lastID,
                            lastTimestamp: lastItemTimestamp,
                            keyword: keyword
                        )
                        .response()
                        await send(.fetchMoreGalleriesDone(index, .success(response)))
                    } catch {
                        await send(.fetchMoreGalleriesDone(index, .failure(error)))
                    }
                }

            case .fetchMoreGalleriesDone(let targetFavIndex, let result):
                state.rawFooterLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let fetchResult):
                    let pageNumber = fetchResult.pageNumber
                    let galleries = fetchResult.galleries
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.rawDateSeekNavigation[targetFavIndex] = fetchResult.dateSeekNavigation
                    state.insertGalleries(index: targetFavIndex, galleries: galleries)
                    state.sortOrder = fetchResult.sortOrder

                    var effects: [Effect<Action>] = []
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.send(.fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.rawLoadingState[targetFavIndex] = .idle
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.rawFooterLoadingState[targetFavIndex] = .failed(error)
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
                state.rawLoadingState[state.index] = .loading
                state.rawFooterLoadingState[state.index] = .idle
                state.rawPageNumber[state.index]?.resetPages()
                return .run { [index = state.index] send in
                    do throws(AppError) {
                        let response = try await DateSeekGalleriesRequest(url: url).response()
                        await send(.performDateSeekDone(index, .success(response)))
                    } catch {
                        await send(.performDateSeekDone(index, .failure(error)))
                    }
                }

            case .performDateSeekDone(let targetFavIndex, let result):
                state.rawLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let response):
                    let galleries = response.galleries
                    guard !galleries.isEmpty else {
                        state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                        return .none
                    }
                    state.rawPageNumber[targetFavIndex] = response.pageNumber
                    state.rawDateSeekNavigation[targetFavIndex] = response.dateSeekNavigation
                    state.rawGalleries[targetFavIndex] = galleries
                    return .none
                case .failure(let error):
                    state.rawLoadingState[targetFavIndex] = .failed(error)
                }
                return .none

            case .destination:
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
            case: \.dateSeek,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .forEach(\.path, action: \.path)
    }
}

extension FavoritesReducer.Destination.State: Equatable, Sendable {}
