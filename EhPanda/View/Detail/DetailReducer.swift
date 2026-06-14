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
        case folderManager(EquatableVoid = .init())
    }

    enum CancelID: Hashable {
        case fetchDatabaseInfos(String)
        case fetchGalleryDetail(String)
        case fetchVersionMetadata(String)
        case fetchDownloadBadge(String)
        case fetchDownloadFolders(String)
        case observeDownload(String)
        case loadLocalPreviewURLs(String)
        case rateGallery(String)
        case favorGallery(String)
        case unfavorGallery(String)
        case postComment(String)
        case voteTag(String)

        // Teardown cancels this whole set; keep it in sync with the cases above.
        // Dropping `CaseIterable` (associated values) means the compiler can't check the list for us.
        static func all(for gid: String) -> [Self] {
            [
                .fetchDatabaseInfos(gid),
                .fetchGalleryDetail(gid),
                .fetchVersionMetadata(gid),
                .fetchDownloadBadge(gid),
                .fetchDownloadFolders(gid),
                .observeDownload(gid),
                .loadLocalPreviewURLs(gid),
                .rateGallery(gid),
                .favorGallery(gid),
                .unfavorGallery(gid),
                .postComment(gid),
                .voteTag(gid)
            ]
        }
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
        var downloadBadge: DownloadBadge?
        var downloadFailureCode: DownloadFailureCode?
        var downloadFolders = [String]()
        var isPreparingDownload = false
        var hasLoadedDownloadBadge = false

        var cancellationGalleryID: String {
            gid.isEmpty ? gallery.id : gid
        }

        var downloadNeedsRepair: Bool {
            guard let badge = downloadBadge, badge.status == .error else { return false }
            return badge.progress.completedPageCount == 0
                && downloadFailureCode == .fileOperationFailed
        }
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
        var folderManagerState = FolderManagerReducer.State()
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
        case fetchDownloadBadgeDone(DownloadedGallery?)
        case fetchDownloadFolders
        case fetchDownloadFoldersDone([String])
        case observeDownload
        case observeDownloadDone(DownloadedGallery?)
        case loadLocalPreviewURLs
        case loadLocalPreviewURLsDone(UUID, [Int: URL])
        case openReading
        case openReadingDone(Result<(DownloadedGallery, DownloadManifest), AppError>)
        case runLaunchAutomationIfNeeded
        case startDownload(String)
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
        case folderManager(FolderManagerReducer.Action)
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
            Scope(state: \.folderManagerState, action: \.folderManager, child: FolderManagerReducer.init)
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
    func applyDownload(_ download: DownloadedGallery?, state: inout State) -> Bool {
        let badge = download?.badge
        let didChangeBadge = badge != state.downloadBadge || !state.hasLoadedDownloadBadge
        state.downloadBadge = badge
        state.downloadFailureCode = download?.lastError?.code
        if badge != nil { state.isPreparingDownload = false }
        state.hasLoadedDownloadBadge = true
        state.shouldCheckForRemoteUpdates = badge != nil
        if badge == nil {
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
