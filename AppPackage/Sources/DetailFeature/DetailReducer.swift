import AnalyticsClient
import AppComponents
import AppLaunchAutomationClient
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import DownloadClient
import Foundation
import HapticsClient
import NetworkingFeature
import ReadingFeature
import SwiftUI

@Reducer
public struct DetailReducer: Sendable {
    // The gallery sub-screens are now standalone elements on the host's navigation stack. Detail asks
    // the host to push them via these delegate actions instead of owning nested child state itself.
    public enum Delegate: Equatable, Sendable {
        case pushPreviews(gallery: Gallery, previewConfig: PreviewConfig, language: Language?)
        case pushComments(
            gid: String, token: String, apiKey: String,
            galleryURL: URL, comments: [GalleryComment], scrollCommentID: String?
        )
        case pushDetailSearch(String)
        case pushGalleryInfos(gallery: Gallery, galleryDetail: GalleryDetail)
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
        @SharedReader(.tagTranslator) public var tagTranslator: TagTranslator
        @SharedReader(.user) public var user: User
        @SharedReader(.setting) public var setting: Setting
        @Presents public var destination: Destination.State?
        @Presents public var alert: AppAlertState<Alert>?
        public var commentContent = ""
        public var postCommentFocused = false
        public var showsUserRating = false
        public var showsFullTitle = false
        public var userRating = 0
        public var apiKey = ""
        public var gid: String
        public var loadingState: LoadingState = .idle
        public var gallery: Gallery
        public var galleryDetail: GalleryDetail?
        public var galleryVersionMetadata: DownloadVersionMetadata?
        public var galleryTags = [GalleryTag]()
        public var galleryPreviewURLs = [Int: URL]()
        public var localPreviewURLs = [Int: URL]()
        public var galleryComments = [GalleryComment]()
        public var previewConfig: PreviewConfig = .normal(rows: 4)
        public var downloadBadge: DownloadBadge?
        public var downloadFailureCode: DownloadFailureCode?
        /// The RECORD's own honesty — `DownloadedGallery.isIncomplete` — carried beside the failure
        /// code it is always read with.
        ///
        /// Kept apart from `downloadBadge` because since D-SSOT-10 the badge's numerator is a
        /// DISPLAY quantity: while a run's measurement stands it counts that run's credited pages,
        /// not the record's. `downloadNeedsRepair` asks whether the record still claims every page,
        /// which is a question only the record can answer, so it reads this instead of subtracting
        /// two badge numbers. Written by `applyDownload` alongside `downloadFailureCode`, so the two
        /// conjuncts always describe the same observation.
        public var downloadIsIncomplete = false
        public var downloadFolders = [String]()
        public var isPreparingDownload = false
        public var hasLoadedDownloadBadge = false

        var cancellationGalleryID: String {
            gid.isEmpty ? gallery.id : gid
        }

        /// D-G5D-01: whether the header's error button offers the non-destructive `.repair` instead
        /// of the destructive `.redownload`, decided on the record's own HONESTY.
        ///
        /// A record that says it is incomplete beside a file-shaped failure has landed pages worth
        /// keeping, and a repair fetches exactly the absent ones — destroying that work to start over
        /// was never an acceptable default. The conjunct used to demand a ZERO completed count, which
        /// could only hold after a repair run's blanking loop had already emptied the record: never at
        /// the moment a user faces this button, so a mid-run file failure with 26 of 36 pages on disk
        /// was routed to the wipe as its only option. Zero-completed records satisfy the widened
        /// conjunct trivially, so nothing that used to offer the repair stopped offering it.
        ///
        /// A COMPLETE-claiming record keeps `.redownload` deliberately, and this is the boundary
        /// between Detail's two affordances rather than an omission. What can still arrive here
        /// claiming every page is exactly two families now: the wholesale-unverifiable one, where
        /// the validate-time reconciliation refused to blank anything and the manifest still claims
        /// its pages, and the operation-level one, where a pass could not produce trustworthy
        /// evidence for every claimed page and left its session-scoped signal standing over an
        /// otherwise complete record. A presence-based repair finds nothing absent to fetch and
        /// fixes neither, so the surgical route for both is the downloads inspector's widened retry
        /// (D-SSOT-08, which superseded D-G5C-01's union basis with the full page set), which
        /// carries its page selection explicitly and therefore does not depend on the record's
        /// claims; the wipe stays as the whole-gallery answer.
        ///
        /// Present-but-mismatched bytes used to be a third member of that family and are not one
        /// any more: they are now reconciled durably at validate time (D-SSOT-01), so such a gallery
        /// reads honestly incomplete, derives `.inactive`, and never faces this button at all. The
        /// PREDICATE is unchanged by that — the boundary it draws is still the record's own honesty
        /// — but the reason a complete-claiming record is offered the wipe no longer rests on a
        /// shape that can no longer reach it.
        ///
        /// **Why the incompleteness conjunct is not read off the badge (D-SSOT-10).** It used to be
        /// `badge.progress.completedPageCount < badge.progress.pageCount`. Since the badge's
        /// numerator became a DISPLAY quantity — the live run's credited page count while one stands
        /// — that expression asks "has this run finished its work", which is a different question
        /// from "does the record still claim every page" and answers it differently for exactly the
        /// wholesale-refusal family this boundary exists to route. The two readings coexist only in
        /// narrow interleavings, so the button would have flipped intermittently rather than
        /// reliably; reading `downloadIsIncomplete`, which is the record's own `isIncomplete`, makes
        /// the predicate independent of the display basis by construction instead.
        var downloadNeedsRepair: Bool {
            guard let badge = downloadBadge, badge.status == .error else { return false }
            return downloadIsIncomplete && downloadFailureCode == .fileOperationFailed
        }
        public var didRunLaunchAutomation = false
        public var shouldCheckForRemoteUpdates = false
        public var didRequestVersionMetadata = false
        public var localPreviewRequestID = UUID()
        // A deep-link intent to act on once this detail finishes loading (see GalleryDeepLink).
        public var pendingDeepLink: GalleryDeepLink?

        // Seeded from the pushing context (a tapped list item or a freshly-fetched gallery) so the
        // detail header renders immediately and `fetchGalleryDetail` has a `galleryURL`. Gallery data
        // lives only here and dies when the screen pops. This is the only initializer, so a Detail
        // always holds a real `Gallery` — there is no empty-gallery construction path.
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
        case tagSearchTapped(keyword: String, namespace: TagNamespace?)
        case alert(PresentationAction<Alert>)
        case deleteDownloadButtonTapped
        case retryDownloadButtonTapped(DownloadStartMode)
        case onPresented
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
        case loadLocalPreviewURLsDone(requestID: UUID, urls: [Int: URL])
        case openReading
        case openReadingDone(Result<(download: DownloadedGallery, manifest: DownloadManifest), AppError>)
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
        case voteTag(tag: String, weight: Int)
        case anyGalleryOpsDone(Result<Void, AppError>)
    }

    // Not `private`: the reducer body is split across sibling extension files (`+Actions`,
    // `+Download`), and `private` type members are invisible to extensions in other files. Every
    // dependency this reducer vends is declared internal for exactly that reason; the analytics
    // emission sites live in `navigationReducer` and `downloadReducer`, both in other files.
    @Dependency(\.analyticsClient) var analyticsClient
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
        state.downloadIsIncomplete = download?.isIncomplete ?? false
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
    public init(seededFrom download: DownloadedGallery) {
        self.init(gallery: download.gallery)
        _ = DetailReducer().applyDownload(download, state: &self)
    }
}

extension DetailReducer.Destination.State: Equatable {}
