import AppTools
import SwiftUI
import AppModels
import Foundation
import ComposableArchitecture
import ComposableArchitectureExt
import SwiftUINavigationExt
import HapticsClient
import DatabaseClient
import NetworkingFeature
import DownloadClient
import CookieClient
import AppLaunchAutomationClient
import ReadingFeature

@Reducer
public struct DetailReducer: Sendable {
    @CasePathable
    public enum Route: Equatable, Sendable {
        case previews
        case comments(URL)
        case detailSearch(String)
        case galleryInfos(Gallery, GalleryDetail)
    }

    @Reducer
    public enum Destination {
        case reading(ReadingReducer)
        case archives(ArchivesReducer)
        case torrents(TorrentsReducer)
        case folderManager(FolderManagerReducer)
        @ReducerCaseIgnored case share(URL)
        @ReducerCaseIgnored case postComment(EquatableVoid)
        @ReducerCaseIgnored case newDawn(Greeting)
        @ReducerCaseIgnored case tagDetail(TagDetail)
    }

    public enum Alert: Equatable, Sendable {
        case confirmDeleteDownload
        case confirmRetryDownload(DownloadStartMode)
    }

    public enum CancelID: Hashable, Sendable {
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
    public struct State: Equatable {
        public var route: Route?
        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Alert>?
        public var commentContent = ""
        public var postCommentFocused = false
        public var showsNewDawnGreeting = false
        public var showsUserRating = false
        public var showsFullTitle = false
        public var userRating = 0
        public var apiKey = ""
        public var gid = ""
        public var loadingState: LoadingState = .idle
        public var gallery: Gallery = .empty
        public var galleryDetail: GalleryDetail?
        public var galleryVersionMetadata: DownloadVersionMetadata?
        public var galleryTags = [GalleryTag]()
        public var galleryPreviewURLs = [Int: URL]()
        public var localPreviewURLs = [Int: URL]()
        public var galleryComments = [GalleryComment]()
        public var previewConfig: PreviewConfig = .normal(rows: 4)
        public var downloadBadge: DownloadBadge?
        public var downloadFailureCode: DownloadFailureCode?
        public var downloadFolders = [String]()
        public var isPreparingDownload = false
        public var hasLoadedDownloadBadge = false

        var cancellationGalleryID: String {
            gid.isEmpty ? gallery.id : gid
        }

        var downloadNeedsRepair: Bool {
            guard let badge = downloadBadge, badge.status == .error else { return false }
            return badge.progress.completedPageCount == 0
                && downloadFailureCode == .fileOperationFailed
        }
        public var didRunLaunchAutomation = false
        public var shouldCheckForRemoteUpdates = false
        public var didRequestVersionMetadata = false
        public var localPreviewRequestID = UUID()
        public var previewsState = PreviewsReducer.State()
        public var commentsState: Heap<CommentsReducer.State?>
        public var galleryInfosState = GalleryInfosReducer.State()
        public var detailSearchState: Heap<DetailSearchReducer.State?>

        public init() {
            commentsState = .init(nil)
            detailSearchState = .init(nil)
        }

        mutating func updateRating(value: DragGesture.Value) {
            let rating = Int(value.location.x / 31 * 2) + 1
            userRating = min(max(rating, 1), 10)
        }
    }

    public indirect enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case destination(PresentationAction<Destination.Action>)
        case presentReading
        case archivesButtonTapped
        case torrentsButtonTapped
        case folderManagerButtonTapped
        case shareButtonTapped(URL)
        case postCommentButtonTapped
        case presentNewDawn(Greeting)
        case tagDetailButtonTapped(TagDetail)
        case alert(PresentationAction<Alert>)
        case deleteDownloadButtonTapped
        case retryDownloadButtonTapped(DownloadStartMode)
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
        case createDefaultFolder
        case createDefaultFolderDone(Result<Void, AppError>)
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

    public init() {}

    public var body: some Reducer<State, Action> { detailBody }
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
                .ifLet(\.$destination, action: \.destination)
                .ifLet(\.$alert, action: \.alert)
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

// MARK: - Helpers
extension DetailReducer {
    public func applyDownload(_ download: DownloadedGallery?, state: inout State) -> Bool {
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

extension DetailReducer.Destination.State: Equatable {}
