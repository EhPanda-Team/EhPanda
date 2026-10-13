import AnalyticsClient
public import AppModels
import AppTools
public import ComposableArchitecture
public import Kingfisher
import LibraryClient
public import Sharing
public import SwiftUI

@Reducer
public struct HomeReducer: Sendable {
    @CasePathable
    public enum Delegate: Equatable, Sendable {
        /// Asks the app root to open a gallery's detail. The root knows the window's size classes,
        /// so it decides between a modal and `pushGalleryDetail` back to this host.
        case openGalleryDetail(Gallery)
    }

    @ObservableState
    public struct State: Equatable {
        /// The carousel card Home first shows: the second, so a neighbor shows on each side.
        public static let initialCardPageIndex = 1

        @SharedReader(.globalFilter) public var globalFilter: AppModels.Filter
        @SharedReader(.setting) public var setting: Setting
        public var path = StackState<HomePath.State>()
        public var cardPageIndex = Self.initialCardPageIndex
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

        /// Shows `galleries` in the order received: ``HomeClient`` arranges the carousel, so the
        /// order is the client's to decide.
        mutating func setPopularGalleries(_ galleries: [Gallery]) {
            popularGalleries = galleries
            cardPageIndex = min(cardPageIndex, galleries.count - 1)
            currentCardID = galleries[cardPageIndex].gid
        }

        mutating func setFrontpageGalleries(_ galleries: [Gallery]) {
            frontpageGalleries = Array(galleries.prefix(min(galleries.count, 25)))
                .removeDuplicates(by: \.trimmedTitle)
        }

    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onPresented
        case delegate(Delegate)
        case galleryTapped(Gallery)
        case pushGalleryDetail(Gallery)
        case sectionTapped(HomeSectionType)
        case miscTapped(HomeMiscGridType)
        case path(StackActionOf<HomePath>)
        case setAllowsCardHitTesting(Bool)
        case analyzeImageColors(gid: String, result: RetrieveImageResult)
        case analyzeImageColorsDone(gid: String, colors: [Color]?)

        case fetchAllGalleries
        case fetchAllToplistsGalleries
        case fetchPopularGalleries
        case fetchPopularGalleriesDone(Result<[Gallery], AppError>)
        case fetchFrontpageGalleries
        case fetchFrontpageGalleriesDone(Result<(pageNumber: PageNumber, galleries: [Gallery]), AppError>)
        case fetchToplistsGalleries(index: Int, pageNum: Int? = nil)
        case fetchToplistsGalleriesDone(
            index: Int, result: Result<(pageNumber: PageNumber, galleries: [Gallery]), AppError>
        )
    }

    // Not `private`: this reducer's body lives in `HomeReducer+Body.swift`, so its dependencies
    // are file-crossing `internal`.
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.homeClient) var homeClient
    @Dependency(\.libraryClient) var libraryClient

    public init() {}

    public var body: some Reducer<State, Action> { reducerBody }
}
