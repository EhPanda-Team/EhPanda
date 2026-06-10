//
//  DetailReducer.swift
//  EhPanda
//

import SwiftUI
import Foundation
import ComposableArchitecture

@Reducer
struct DetailReducer {
    @CasePathable
    enum Route: Equatable {
        case reading(EquatableVoid = .init())
        case archives(URL, URL)
        case torrents(EquatableVoid = .init())
        case previews
        case comments(URL)
        case share(URL)
        case postComment(EquatableVoid = .init())
        case newDawn(Greeting)
        case detailSearch(String)
        case tagDetail(TagDetail)
        case galleryInfos(Gallery, GalleryDetail)
    }

    enum CancelID: CaseIterable {
        case fetchDatabaseInfos
        case fetchGalleryDetail
        case fetchVersionMetadata
        case fetchDownloadBadge
        case observeDownload
        case loadLocalPreviewURLs
        case rateGallery
        case favorGallery
        case unfavorGallery
        case postComment
        case voteTag
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var commentContent = ""
        var postCommentFocused = false
        var showsNewDawnGreeting = false
        var showsUserRating = false
        var showsFullTitle = false
        var userRating = 0
        var apiKey = ""
        var gid = ""
        var loadingState: LoadingState = .idle
        var gallery: Gallery = .empty
        var galleryDetail: GalleryDetail?
        var galleryVersionMetadata: DownloadVersionMetadata?
        var galleryTags = [GalleryTag]()
        var galleryPreviewURLs = [Int: URL]()
        var localPreviewURLs = [Int: URL]()
        var galleryComments = [GalleryComment]()
        var previewConfig: PreviewConfig = .normal(rows: 4)
        var downloadBadge: DownloadBadge = .none
        var isPreparingDownload = false
        var hasLoadedDownloadBadge = false
        var didRunLaunchAutomation = false
        var shouldCheckForRemoteUpdates = false
        var didRequestVersionMetadata = false
        var localPreviewRequestID = UUID()
        var readingState = ReadingReducer.State()
        var archivesState = ArchivesReducer.State()
        var torrentsState = TorrentsReducer.State()
        var previewsState = PreviewsReducer.State()
        var commentsState: Heap<CommentsReducer.State?>
        var galleryInfosState = GalleryInfosReducer.State()
        var detailSearchState: Heap<DetailSearchReducer.State?>

        init() {
            commentsState = .init(nil)
            detailSearchState = .init(nil)
        }

        mutating func updateRating(value: DragGesture.Value) {
            let rating = Int(value.location.x / 31 * 2) + 1
            userRating = min(max(rating, 1), 10)
        }
    }

    indirect enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates
        case onPostCommentAppear
        case onAppear(String, Bool)
        case toggleShowFullTitle
        case toggleShowUserRating
        case setCommentContent(String)
        case setPostCommentFocused(Bool)
        case updateRating(DragGesture.Value)
        case confirmRating(DragGesture.Value)
        case confirmRatingDone
        case syncGalleryTags
        case syncGalleryDetail
        case syncGalleryPreviewURLs
        case syncGalleryComments
        case syncGreeting(Greeting)
        case syncPreviewConfig(PreviewConfig)
        case saveGalleryHistory
        case updateReadingProgress(Int)
        case fetchDownloadBadge
        case fetchDownloadBadgeDone(DownloadBadge)
        case observeDownload
        case observeDownloadDone(DownloadBadge)
        case loadLocalPreviewURLs
        case loadLocalPreviewURLsDone(UUID, [Int: URL])
        case openReading
        case openReadingDone(Result<(DownloadedGallery, DownloadManifest), AppError>)
        case runLaunchAutomationIfNeeded(DownloadRequestOptions)
        case startDownload(DownloadRequestOptions)
        case startDownloadDone(Result<Void, AppError>)
        case toggleDownloadPause
        case toggleDownloadPauseDone(Result<Void, AppError>)
        case retryDownload(DownloadStartMode)
        case retryDownloadDone(Result<Void, AppError>)
        case deleteDownload
        case deleteDownloadDone(Result<Void, AppError>)
        case teardown
        case fetchDatabaseInfos(String)
        case fetchDatabaseInfosDone(GalleryState)
        case fetchGalleryDetail
        case fetchGalleryDetailDone(Result<GalleryDetailResponse, AppError>)
        case fetchVersionMetadataIfNeeded
        case fetchVersionMetadataDone(Result<DownloadVersionMetadata?, AppError>)
        case rateGallery
        case favorGallery(Int)
        case unfavorGallery
        case postComment(URL)
        case voteTag(String, Int)
        case anyGalleryOpsDone(Result<Void, AppError>)
        case reading(ReadingReducer.Action)
        case archives(ArchivesReducer.Action)
        case torrents(TorrentsReducer.Action)
        case previews(PreviewsReducer.Action)
        case comments(CommentsReducer.Action)
        case galleryInfos(GalleryInfosReducer.Action)
        case detailSearch(DetailSearchReducer.Action)
    }

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.downloadClient) var downloadClient
    @Dependency(\.hapticsClient) var hapticsClient
    @Dependency(\.cookieClient) var cookieClient
    @Dependency(\.appLaunchAutomationClient) var appLaunchAutomationClient

    var body: some Reducer<State, Action> { detailBody }
}

// MARK: - Reducer Body
extension DetailReducer {
    var detailBody: some Reducer<State, Action> {
        RecurseReducer { (self) in
            BindingReducer()
                .onChange(of: \.route) { _, state in
                    state.route == nil ? .send(.clearSubStates) : .none
                }
            navigationReducer
            uiReducer
            syncReducer
            downloadReducer
            fetchReducer(self)
            galleryOpsReducer
            childReducer(self)
            optionalChildReducers
            Scope(state: \.readingState, action: \.reading, child: ReadingReducer.init)
            Scope(state: \.archivesState, action: \.archives, child: ArchivesReducer.init)
            Scope(state: \.torrentsState, action: \.torrents, child: TorrentsReducer.init)
            Scope(state: \.previewsState, action: \.previews, child: PreviewsReducer.init)
            Scope(state: \.galleryInfosState, action: \.galleryInfos, child: GalleryInfosReducer.init)
        }
    }

    var optionalChildReducers: some ReducerOf<Self> {
        Reduce { _, _ in .none }
            .ifLet(\.commentsState.wrappedValue, action: \.comments, then: CommentsReducer.init)
            .ifLet(\.detailSearchState.wrappedValue, action: \.detailSearch, then: DetailSearchReducer.init)
    }
}

// MARK: - Haptics
extension DetailReducer {
    func hapticsReducer(
        @ReducerBuilder<State, Action> reducer: () -> some Reducer<State, Action>
    ) -> some Reducer<State, Action> {
        reducer()
            .haptics(unwrapping: \.route, case: \.detailSearch, hapticsClient: hapticsClient, style: .soft)
            .haptics(unwrapping: \.route, case: \.postComment, hapticsClient: hapticsClient)
            .haptics(unwrapping: \.route, case: \.tagDetail, hapticsClient: hapticsClient)
            .haptics(unwrapping: \.route, case: \.torrents, hapticsClient: hapticsClient)
            .haptics(unwrapping: \.route, case: \.archives, hapticsClient: hapticsClient)
            .haptics(unwrapping: \.route, case: \.reading, hapticsClient: hapticsClient)
            .haptics(unwrapping: \.route, case: \.share, hapticsClient: hapticsClient)
    }
}

// MARK: - Helpers
extension DetailReducer {
    func applyDownloadBadge(_ badge: DownloadBadge, state: inout State) -> Bool {
        let didChangeBadge = badge != state.downloadBadge || !state.hasLoadedDownloadBadge
        state.downloadBadge = badge
        if badge != .none { state.isPreparingDownload = false }
        state.hasLoadedDownloadBadge = true
        state.shouldCheckForRemoteUpdates = badge != .none
        if badge == .none {
            state.galleryVersionMetadata = nil
            state.didRequestVersionMetadata = false
        }
        return didChangeBadge
    }

    func shouldRequestVersionMetadata(state: State) -> Bool {
        state.galleryDetail != nil
            && state.shouldCheckForRemoteUpdates
            && !state.didRequestVersionMetadata
    }
}
