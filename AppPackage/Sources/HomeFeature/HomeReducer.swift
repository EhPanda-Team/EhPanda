import SwiftUI
import AppModels
import Kingfisher
import ComposableArchitecture
import AppTools
import LibraryClient
import DatabaseClient
import DeviceClient

@Reducer
public struct HomeReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case presentGalleryDetail(Gallery)
    }

    @ObservableState
    public struct State: Equatable {
        public var path = StackState<HomePath.State>()
        public var cardPageIndex = 1
        public var currentCardID = ""
        public var allowsCardHitTesting = true
        public var rawCardColors = [String: [Color]]()
        var cardColors: [Color] {
            rawCardColors[currentCardID] ?? [.clear]
        }

        public var popularGalleries = [Gallery]()
        public var popularLoadingState: LoadingState = .idle
        public var frontpageGalleries = [Gallery]()
        public var frontpageLoadingState: LoadingState = .idle
        public var toplistsGalleries = [Int: [Gallery]]()
        public var toplistsLoadingState = [Int: LoadingState]()

        public init() {}

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

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case galleryTapped(Gallery)
        case pushGalleryDetail(Gallery)
        case sectionTapped(HomeSectionType)
        case miscTapped(HomeMiscGridType)
        case path(StackActionOf<HomePath>)
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
    }

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.deviceClient) var deviceClient
    @Dependency(\.libraryClient) var libraryClient

    public init() {}

    public var body: some Reducer<State, Action> { reducerBody }
}
