import AppTools
import SwiftUI
import AppModels
import Foundation
import ComposableArchitecture
import AppComponents
import HapticsClient
import DatabaseClient
import NetworkingFeature
import DownloadClient
import CookieClient
import AppLaunchAutomationClient
import ReadingFeature

@Reducer
public struct DetailReducer: Sendable {
    // The gallery sub-screens are now standalone elements on the host's navigation stack. Detail asks
    // the host to push them via these delegate actions instead of owning nested child state itself.
    public enum Delegate: Equatable, Sendable {
        case pushPreviews(Gallery)
        case pushComments(
            gid: String, token: String, apiKey: String,
            galleryURL: URL, comments: [GalleryComment], scrollCommentID: String?
        )
        case pushDetailSearch(String)
        case pushGalleryInfos(Gallery, GalleryDetail)
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
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var destination: Destination.State?
        @Presents public var alert: AppAlertState<Alert>?
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
        // A deep-link intent to act on once this detail finishes loading (see GalleryDeepLink).
        public var pendingDeepLink: GalleryDeepLink?

        public init(gid: String = "", pendingDeepLink: GalleryDeepLink? = nil) {
            self.gid = gid
            self.pendingDeepLink = pendingDeepLink
        }

        // Seeded from the pushing context (a tapped list item or a freshly-fetched gallery) so the
        // detail header renders immediately and `fetchGalleryDetail` has a `galleryURL` without any
        // database lookup. Gallery data lives only here and dies when the screen pops.
        public init(gallery: Gallery, pendingDeepLink: GalleryDeepLink? = nil) {
            self.gid = gallery.id
            self.gallery = gallery
            self.pendingDeepLink = pendingDeepLink
        }

        mutating func updateRating(value: DragGesture.Value) {
            let rating = Int(value.location.x / 31 * 2) + 1
            userRating = min(max(rating, 1), 10)
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
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
        case onPostCommentAppear
        case onAppear(String, Bool)
        case toggleShowFullTitle
        case toggleShowUserRating
        case setPostCommentFocused(Bool)
        case updateRating(DragGesture.Value)
        case confirmRating(DragGesture.Value)
        case confirmRatingDone
        case syncGreeting(Greeting)
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
    }

    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.downloadClient) var downloadClient
    @Dependency(\.hapticsClient) var hapticsClient
    @Dependency(\.cookieClient) var cookieClient
    @Dependency(\.appLaunchAutomationClient) var appLaunchAutomationClient
    @Dependency(\.date) var date

    public init() {}

    public var body: some Reducer<State, Action> { detailBody }
}

// MARK: - Reducer Body
extension DetailReducer {
    @ReducerBuilder<State, Action>
    var detailBody: some Reducer<State, Action> {
        BindingReducer()
        navigationReducer
        uiReducer
        syncReducer
        downloadReducer
        fetchReducer
        galleryOpsReducer
            .ifLet(\.$destination, action: \.destination)
            .ifLet(\.$alert, action: \.alert)
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

extension DetailReducer.State {
    // Pre-populated from a local download so a downloaded gallery renders instantly and offline;
    // the live download observation keeps the state in sync afterwards. Shared by the Downloads
    // tab's inline push and the app-level modal presentation (iPad / deep link).
    public init(gid: String, seededFrom download: DownloadedGallery?) {
        self.init(gid: gid)
        if let download {
            gallery = download.gallery
            _ = DetailReducer().applyDownload(download, state: &self)
        }
    }
}

extension DetailReducer.Destination.State: Equatable {}
