import SwiftUI
import AppModels
import Kingfisher
import ComposableArchitecture
import FoundationExt
import LibraryClient
import DatabaseClient

@Reducer
struct HomeReducer {
    @CasePathable
    enum Route: Equatable, Hashable {
        case detail(String)
        case misc(HomeMiscGridType)
        case section(HomeSectionType)
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var cardPageIndex = 1
        var currentCardID = ""
        var allowsCardHitTesting = true
        var rawCardColors = [String: [Color]]()
        var cardColors: [Color] {
            rawCardColors[currentCardID] ?? [.clear]
        }

        var popularGalleries = [Gallery]()
        var popularLoadingState: LoadingState = .idle
        var frontpageGalleries = [Gallery]()
        var frontpageLoadingState: LoadingState = .idle
        var toplistsGalleries = [Int: [Gallery]]()
        var toplistsLoadingState = [Int: LoadingState]()

        var frontpageState = FrontpageReducer.State()
        var toplistsState = ToplistsReducer.State()
        var popularState = PopularReducer.State()
        var watchedState = WatchedReducer.State()
        var historyState = HistoryReducer.State()
        var detailState: Heap<DetailReducer.State?>

        init() {
            detailState = .init(.init())
        }

        mutating func setPopularGalleries(_ galleries: [Gallery]) {
            let sortedGalleries = galleries.sorted { lhs, rhs in
                lhs.title.count > rhs.title.count
            }
            var trimmedGalleries = Array(sortedGalleries.prefix(min(sortedGalleries.count, 10)))
                .removeDuplicates(by: \.trimmedTitle)
            if trimmedGalleries.count >= 6 {
                trimmedGalleries = Array(trimmedGalleries.prefix(6))
            }
            trimmedGalleries.shuffle()
            popularGalleries = trimmedGalleries
            currentCardID = trimmedGalleries[cardPageIndex].gid
        }

        mutating func setFrontpageGalleries(_ galleries: [Gallery]) {
            frontpageGalleries = Array(galleries.prefix(min(galleries.count, 25)))
                .removeDuplicates(by: \.trimmedTitle)
        }

    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates
        case setAllowsCardHitTesting(Bool)
        case analyzeImageColors(String, RetrieveImageResult)
        case analyzeImageColorsDone(String, [Color]?)

        case fetchAllGalleries
        case fetchAllToplistsGalleries
        case fetchPopularGalleries
        case fetchPopularGalleriesDone(Result<[Gallery], AppError>)
        case fetchFrontpageGalleries
        case fetchFrontpageGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchToplistsGalleries(Int, Int? = nil)
        case fetchToplistsGalleriesDone(Int, Result<(PageNumber, [Gallery]), AppError>)

        case frontpage(FrontpageReducer.Action)
        case toplists(ToplistsReducer.Action)
        case popular(PopularReducer.Action)
        case watched(WatchedReducer.Action)
        case history(HistoryReducer.Action)
        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.libraryClient) var libraryClient

    var body: some Reducer<State, Action> { reducerBody }
}
