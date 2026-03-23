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

    private enum CancelID: CaseIterable {
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
        var isDownloadContext = false
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

        init(download: DownloadedGallery) {
            self.init()
            gid = download.gid
            gallery = download.gallery
            galleryDetail = GalleryDetail(
                gid: download.gid,
                title: download.title,
                jpnTitle: download.jpnTitle,
                isFavorited: false,
                visibility: .yes,
                rating: download.rating,
                userRating: 0,
                ratingCount: 0,
                category: download.category,
                language: .japanese,
                uploader: download.uploader ?? "",
                postedDate: download.postedDate,
                coverURL: download.coverURL,
                favoritedCount: 0,
                pageCount: download.pageCount,
                sizeCount: 0,
                sizeType: "",
                torrentCount: 0
            )
            downloadBadge = download.badge
            hasLoadedDownloadBadge = download.badge != .none
            isDownloadContext = true
            shouldCheckForRemoteUpdates = true
            didRequestVersionMetadata = false
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
        case runLaunchAutomationIfNeeded(DownloadOptionsSnapshot)
        case startDownload(DownloadOptionsSnapshot)
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
        case fetchGalleryDetailDone(
            Result<(GalleryDetail, GalleryState, String, Greeting?), AppError>
        )
        case fetchVersionMetadataIfNeeded
        case fetchVersionMetadataDone(Result<DownloadVersionMetadata?, AppError>)

        case rateGallery
        case favorGallery(Int)
        case unfavorGallery
        case postComment(URL)
        case voteTag(String, Int)
        case anyGalleryOpsDone(Result<Any, AppError>)

        case reading(ReadingReducer.Action)
        case archives(ArchivesReducer.Action)
        case torrents(TorrentsReducer.Action)
        case previews(PreviewsReducer.Action)
        case comments(CommentsReducer.Action)
        case galleryInfos(GalleryInfosReducer.Action)
        case detailSearch(DetailSearchReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    func coreReducer(self: Reduce<State, Action>) -> some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.readingState = .init()
                state.archivesState = .init()
                state.torrentsState = .init()
                state.previewsState = .init()
                state.commentsState.wrappedValue = .init()
                state.commentContent = .init()
                state.postCommentFocused = false
                state.galleryInfosState = .init()
                state.detailSearchState.wrappedValue = .init()
                return .merge(
                    .send(.reading(.teardown)),
                    .send(.archives(.teardown)),
                    .send(.torrents(.teardown)),
                    .send(.previews(.teardown)),
                    .send(.comments(.teardown)),
                    .send(.detailSearch(.teardown))
                )

            case .onPostCommentAppear:
                return .run { send in
                    try await Task.sleep(for: .milliseconds(750))
                    await send(.setPostCommentFocused(true))
                }

            case .onAppear(let gid, let showsNewDawnGreeting):
                state.gid = gid
                state.showsNewDawnGreeting = showsNewDawnGreeting
                state.isPreparingDownload = false
                state.hasLoadedDownloadBadge = false
                state.didRunLaunchAutomation = false
                state.localPreviewURLs = .init()
                if state.detailSearchState.wrappedValue == nil {
                    state.detailSearchState.wrappedValue = .init()
                }
                if state.commentsState.wrappedValue == nil {
                    state.commentsState.wrappedValue = .init()
                }
                return .merge(
                    .send(.fetchDatabaseInfos(gid)),
                    .send(.fetchDownloadBadge),
                    .send(.observeDownload),
                    .send(.loadLocalPreviewURLs)
                )

            case .toggleShowFullTitle:
                state.showsFullTitle.toggle()
                return .run(operation: { _ in hapticsClient.generateFeedback(.soft) })

            case .toggleShowUserRating:
                state.showsUserRating.toggle()
                return .run(operation: { _ in hapticsClient.generateFeedback(.soft) })

            case .setCommentContent(let content):
                state.commentContent = content
                return .none

            case .setPostCommentFocused(let isFocused):
                state.postCommentFocused = isFocused
                return .none

            case .updateRating(let value):
                state.updateRating(value: value)
                return .none

            case .confirmRating(let value):
                state.updateRating(value: value)
                return .merge(
                    .send(.rateGallery),
                    .run(operation: { _ in hapticsClient.generateFeedback(.soft) }),
                    .run { send in
                        try await Task.sleep(for: .seconds(1))
                        await send(.confirmRatingDone)
                    }
                )

            case .confirmRatingDone:
                state.showsUserRating = false
                return .none

            case .syncGalleryTags:
                return .run { [state] _ in
                    await databaseClient.updateGalleryTags(gid: state.gallery.id, tags: state.galleryTags)
                }

            case .syncGalleryDetail:
                guard let detail = state.galleryDetail else { return .none }
                return .run(operation: { _ in await databaseClient.cacheGalleryDetail(detail) })

            case .syncGalleryPreviewURLs:
                return .run { [state] _ in
                    await databaseClient
                        .updatePreviewURLs(gid: state.gallery.id, previewURLs: state.galleryPreviewURLs)
                }

            case .syncGalleryComments:
                return .run { [state] _ in
                    await databaseClient.updateComments(gid: state.gallery.id, comments: state.galleryComments)
                }

            case .syncGreeting(let greeting):
                return .run(operation: { _ in await databaseClient.updateGreeting(greeting) })

            case .syncPreviewConfig(let config):
                return .run { [state] _ in
                    await databaseClient.updatePreviewConfig(gid: state.gallery.id, config: config)
                }

            case .saveGalleryHistory:
                return .run { [state] _ in
                    await databaseClient.updateLastOpenDate(gid: state.gallery.id)
                }

            case .updateReadingProgress(let progress):
                return .run { [state] _ in
                    await databaseClient.updateReadingProgress(gid: state.gallery.id, progress: progress)
                }

            case .fetchDownloadBadge:
                guard state.gid.isValidGID else { return .none }
                return .run { [galleryID = state.gid] send in
                    let badge = await downloadClient.badges([galleryID])[galleryID] ?? .none
                    await send(.fetchDownloadBadgeDone(badge))
                }
                .cancellable(id: CancelID.fetchDownloadBadge, cancelInFlight: true)

            case .fetchDownloadBadgeDone(let badge):
                _ = applyDownloadBadge(badge, state: &state)

                var effects: [Effect<Action>] = [
                    .send(.loadLocalPreviewURLs)
                ]
                if shouldRequestVersionMetadata(state: state) {
                    effects.append(.send(.fetchVersionMetadataIfNeeded))
                }
                return .merge(effects)

            case .observeDownload:
                guard state.gid.isValidGID else { return .none }
                return .run { [galleryID = state.gid] send in
                    for await downloads in downloadClient.observeDownloads() {
                        let badge = downloads.first(where: { $0.gid == galleryID })?.badge ?? .none
                        await send(.observeDownloadDone(badge))
                    }
                }
                .cancellable(id: CancelID.observeDownload, cancelInFlight: true)

            case .observeDownloadDone(let badge):
                let didChangeBadge = applyDownloadBadge(badge, state: &state)
                guard didChangeBadge else { return .none }

                var effects: [Effect<Action>] = [
                    .send(.loadLocalPreviewURLs)
                ]
                if shouldRequestVersionMetadata(state: state) {
                    effects.append(.send(.fetchVersionMetadataIfNeeded))
                }
                return .merge(effects)

            case .loadLocalPreviewURLs:
                guard state.gid.isValidGID else {
                    state.localPreviewRequestID = UUID()
                    state.localPreviewURLs = .init()
                    return .none
                }
                let requestID = UUID()
                state.localPreviewRequestID = requestID
                return .run { [galleryID = state.gid] send in
                    let localPreviewURLs: [Int: URL]
                    switch await downloadClient.loadLocalPageURLs(galleryID) {
                    case .success(let pageURLs):
                        localPreviewURLs = pageURLs
                    case .failure:
                        localPreviewURLs = [:]
                    }
                    await send(.loadLocalPreviewURLsDone(requestID, localPreviewURLs))
                }
                .cancellable(id: CancelID.loadLocalPreviewURLs, cancelInFlight: true)

            case .loadLocalPreviewURLsDone(let requestID, let localPreviewURLs):
                guard state.localPreviewRequestID == requestID else { return .none }
                guard state.localPreviewURLs != localPreviewURLs else { return .none }
                state.localPreviewURLs = localPreviewURLs
                return .none

            case .openReading:
                state.readingState = .init(contentSource: .remote)
                return .run { [galleryID = state.gallery.id] send in
                    guard galleryID.isValidGID else {
                        await send(.openReadingDone(.failure(.notFound)))
                        return
                    }
                    await send(.openReadingDone(await downloadClient.loadManifest(galleryID)))
                }

            case .openReadingDone(let result):
                if case .success(let (download, manifest)) = result {
                    state.readingState = .init(contentSource: .local(download, manifest))
                } else {
                    state.readingState.contentSource = .remote
                    state.readingState.localPageURLs = state.localPreviewURLs
                }
                state.route = .reading()
                return .none

            case .runLaunchAutomationIfNeeded(let options):
                guard !state.didRunLaunchAutomation,
                      AppLaunchAutomation.current?.autoDownloadGID == state.gallery.id,
                      state.galleryDetail != nil,
                      state.hasLoadedDownloadBadge
                else { return .none }

                state.didRunLaunchAutomation = true
                guard state.downloadBadge == .none else { return .none }
                return .send(.startDownload(options))

            case .startDownload(let options):
                guard !state.isPreparingDownload else { return .none }
                state.didRunLaunchAutomation = true
                guard let detail = state.galleryDetail else { return .none }
                state.isPreparingDownload = true
                let payload = DownloadRequestPayload(
                    gallery: state.gallery,
                    galleryDetail: detail,
                    previewURLs: state.galleryPreviewURLs,
                    previewConfig: state.previewConfig,
                    host: AppUtil.galleryHost,
                    versionMetadata: state.galleryVersionMetadata,
                    options: options,
                    mode: .initial
                )
                return .run { send in
                    await send(.startDownloadDone(await downloadClient.enqueue(payload)))
                }

            case .startDownloadDone(let result):
                state.isPreparingDownload = false
                if case .success = result {
                    state.downloadBadge = .queued
                    state.hasLoadedDownloadBadge = true
                    return .merge(
                        .run(operation: { _ in hapticsClient.generateNotificationFeedback(.success) }),
                        .send(.fetchDownloadBadge)
                    )
                }
                return .run(operation: { _ in hapticsClient.generateNotificationFeedback(.error) })

            case .toggleDownloadPause:
                guard !state.isPreparingDownload else { return .none }
                state.isPreparingDownload = true
                return .run { [galleryID = state.gallery.id] send in
                    await send(.toggleDownloadPauseDone(await downloadClient.togglePause(galleryID)))
                }

            case .toggleDownloadPauseDone(let result):
                state.isPreparingDownload = false
                if case .success = result {
                    switch state.downloadBadge {
                    case .downloading(let completed, let total):
                        state.downloadBadge = .paused(completed, total)
                    case .paused:
                        state.downloadBadge = .queued
                    default:
                        break
                    }
                    state.hasLoadedDownloadBadge = state.downloadBadge != .none
                    return .merge(
                        .run(operation: { _ in hapticsClient.generateNotificationFeedback(.success) }),
                        .send(.fetchDownloadBadge)
                    )
                }
                return .run(operation: { _ in hapticsClient.generateNotificationFeedback(.error) })

            case .retryDownload(let mode):
                guard !state.isPreparingDownload else { return .none }
                state.isPreparingDownload = true
                return .run { [galleryID = state.gallery.id] send in
                    await send(.retryDownloadDone(await downloadClient.retry(galleryID, mode)))
                }

            case .retryDownloadDone(let result):
                state.isPreparingDownload = false
                if case .success = result {
                    state.downloadBadge = .queued
                    state.hasLoadedDownloadBadge = true
                    return .merge(
                        .run(operation: { _ in hapticsClient.generateNotificationFeedback(.success) }),
                        .send(.fetchDownloadBadge)
                    )
                }
                return .run(operation: { _ in hapticsClient.generateNotificationFeedback(.error) })

            case .deleteDownload:
                return .run { [galleryID = state.gallery.id] send in
                    await send(.deleteDownloadDone(await downloadClient.delete(galleryID)))
                }

            case .deleteDownloadDone(let result):
                if case .success = result {
                    state.galleryVersionMetadata = nil
                    state.didRequestVersionMetadata = false
                    state.isDownloadContext = false
                    state.shouldCheckForRemoteUpdates = false
                    return .merge(
                        .run(operation: { _ in hapticsClient.generateNotificationFeedback(.success) }),
                        .send(.fetchDownloadBadge)
                    )
                }
                return .run(operation: { _ in hapticsClient.generateNotificationFeedback(.error) })

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchDatabaseInfos(let gid):
                if let gallery = databaseClient.fetchGallery(gid: gid) {
                    state.gallery = gallery
                } else if state.gallery.id != gid {
                    return .none
                }
                if let detail = databaseClient.fetchGalleryDetail(gid: gid) {
                    state.galleryDetail = detail
                }
                return .merge(
                    .send(.fetchDownloadBadge),
                    .send(.saveGalleryHistory),
                    .run { [galleryID = state.gallery.id] send in
                        guard let dbState = await databaseClient.fetchGalleryState(gid: galleryID) else { return }
                        await send(.fetchDatabaseInfosDone(dbState))
                    }
                        .cancellable(id: CancelID.fetchDatabaseInfos)
                )

            case .fetchDatabaseInfosDone(let galleryState):
                state.galleryTags = galleryState.tags
                state.galleryPreviewURLs = galleryState.previewURLs
                state.galleryComments = galleryState.comments
                if let previewConfig = galleryState.previewConfig {
                    state.previewConfig = previewConfig
                }
                return .send(.fetchGalleryDetail)

            case .fetchGalleryDetail:
                guard state.loadingState != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                state.loadingState = .loading
                state.didRequestVersionMetadata = false
                state.galleryVersionMetadata = nil
                return .run { [galleryID = state.gallery.id] send in
                    let response = await GalleryDetailRequest(gid: galleryID, galleryURL: galleryURL).response()
                    await send(.fetchGalleryDetailDone(response))
                }
                .cancellable(id: CancelID.fetchGalleryDetail)

            case .fetchGalleryDetailDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let (galleryDetail, galleryState, apiKey, greeting)):
                    var effects: [Effect<Action>] = [
                        .send(.syncGalleryTags),
                        .send(.syncGalleryDetail),
                        .send(.syncGalleryPreviewURLs),
                        .send(.syncGalleryComments),
                        .send(.fetchDownloadBadge)
                    ]
                    state.apiKey = apiKey
                    state.galleryDetail = galleryDetail
                    state.galleryTags = galleryState.tags
                    state.galleryPreviewURLs = galleryState.previewURLs
                    state.galleryComments = galleryState.comments
                    if let config = galleryState.previewConfig {
                        state.previewConfig = config
                    }
                    state.userRating = Int(galleryDetail.userRating) * 2
                    if shouldRequestVersionMetadata(state: state) {
                        effects.append(.send(.fetchVersionMetadataIfNeeded))
                    }
                    if let greeting = greeting {
                        effects.append(.send(.syncGreeting(greeting)))
                        if !greeting.gainedNothing && state.showsNewDawnGreeting {
                            effects.append(.send(.setNavigation(.newDawn(greeting))))
                        }
                    }
                    if let config = galleryState.previewConfig {
                        effects.append(.send(.syncPreviewConfig(config)))
                    }
                    return .merge(effects)
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchVersionMetadataIfNeeded:
                guard state.shouldCheckForRemoteUpdates,
                      !state.didRequestVersionMetadata,
                      let detail = state.galleryDetail
                else {
                    return .none
                }
                state.didRequestVersionMetadata = true
                return .run { [gallery = state.gallery, previewURLs = state.galleryPreviewURLs, detail] send in
                    let metadata: DownloadVersionMetadata?
                    switch await GalleryVersionMetadataRequest(gid: gallery.gid, token: gallery.token).response() {
                    case .success(let fetchedMetadata):
                        metadata = fetchedMetadata
                    case .failure:
                        metadata = nil
                    }

                    await send(.fetchVersionMetadataDone(.success(metadata)))

                    guard let metadata else { return }
                    let latestSignature = DownloadSignatureBuilder.make(
                        gallery: gallery,
                        detail: detail,
                        host: AppUtil.galleryHost,
                        previewURLs: previewURLs,
                        versionMetadata: metadata
                    )
                    let badge = await downloadClient.updateRemoteSignature(
                        gallery.gid,
                        latestSignature
                    )
                    await send(.fetchDownloadBadgeDone(badge))
                }
                .cancellable(id: CancelID.fetchVersionMetadata, cancelInFlight: true)

            case .fetchVersionMetadataDone(let result):
                if case .success(let metadata) = result {
                    state.galleryVersionMetadata = metadata
                }
                return .none

            case .rateGallery:
                guard let apiuid = Int(cookieClient.apiuid), let gid = Int(state.gallery.id)
                else { return .none }
                return .run { [state] send in
                    let response = await RateGalleryRequest(
                        apiuid: apiuid,
                        apikey: state.apiKey,
                        gid: gid,
                        token: state.gallery.token,
                        rating: state.userRating
                    )
                        .response()
                    await send(.anyGalleryOpsDone(response))
                }.cancellable(id: CancelID.rateGallery)

            case .favorGallery(let favIndex):
                return .run { [state] send in
                    let response = await FavorGalleryRequest(
                        gid: state.gallery.id,
                        token: state.gallery.token,
                        favIndex: favIndex
                    )
                        .response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.favorGallery)

            case .unfavorGallery:
                return .run { [galleryID = state.gallery.id] send in
                    let response = await UnfavorGalleryRequest(gid: galleryID).response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.unfavorGallery)

            case .postComment(let galleryURL):
                guard !state.commentContent.isEmpty else { return .none }
                return .run { [commentContent = state.commentContent] send in
                    let response = await CommentGalleryRequest(
                        content: commentContent, galleryURL: galleryURL
                    )
                        .response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.postComment)

            case .voteTag(let tag, let vote):
                guard let apiuid = Int(cookieClient.apiuid), let gid = Int(state.gallery.id)
                else { return .none }
                return .run { [state] send in
                    let response = await VoteGalleryTagRequest(
                        apiuid: apiuid,
                        apikey: state.apiKey,
                        gid: gid,
                        token: state.gallery.token,
                        tag: tag,
                        vote: vote
                    )
                        .response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.voteTag)

            case .anyGalleryOpsDone(let result):
                if case .success = result {
                    return .merge(
                        .send(.fetchGalleryDetail),
                        .run(operation: { _ in hapticsClient.generateNotificationFeedback(.success) })
                    )
                }
                return .run(operation: { _ in hapticsClient.generateNotificationFeedback(.error) })

            case .reading(.onPerformDismiss):
                return .send(.setNavigation(nil))

            case .reading:
                return .none

            case .archives:
                return .none

            case .torrents:
                return .none

            case .previews:
                return .none

            case .comments(.performCommentActionDone(let result)):
                return .send(.anyGalleryOpsDone(result))

            case .comments(.detail(let recursiveAction)):
                guard state.commentsState.wrappedValue != nil else { return .none }
                return self.reduce(
                    into: &state.commentsState.wrappedValue!.detailState.wrappedValue!, action: recursiveAction
                )
                .map({ Action.comments(.detail($0)) })

            case .comments:
                return .none

            case .galleryInfos:
                return .none

            case .detailSearch(.detail(let recursiveAction)):
                guard state.detailSearchState.wrappedValue != nil else { return .none }
                return self.reduce(
                    into: &state.detailSearchState.wrappedValue!.detailState.wrappedValue!, action: recursiveAction
                )
                .map({ Action.detailSearch(.detail($0)) })

            case .detailSearch:
                return .none
            }
        }
        .ifLet(
            \.commentsState.wrappedValue,
             action: \.comments,
             then: CommentsReducer.init
        )
        .ifLet(
            \.detailSearchState.wrappedValue,
             action: \.detailSearch,
             then: DetailSearchReducer.init
        )
    }

    func hapticsReducer(
        @ReducerBuilder<State, Action> reducer: () -> some Reducer<State, Action>
    ) -> some Reducer<State, Action> {
        reducer()
            .haptics(
                unwrapping: \.route,
                case: \.detailSearch,
                hapticsClient: hapticsClient,
                style: .soft
            )
            .haptics(
                unwrapping: \.route,
                case: \.postComment,
                hapticsClient: hapticsClient
            )
            .haptics(
                unwrapping: \.route,
                case: \.tagDetail,
                hapticsClient: hapticsClient
            )
            .haptics(
                unwrapping: \.route,
                case: \.torrents,
                hapticsClient: hapticsClient
            )
            .haptics(
                unwrapping: \.route,
                case: \.archives,
                hapticsClient: hapticsClient
            )
            .haptics(
                unwrapping: \.route,
                case: \.reading,
                hapticsClient: hapticsClient
            )
            .haptics(
                unwrapping: \.route,
                case: \.share,
                hapticsClient: hapticsClient
            )
    }

    var body: some Reducer<State, Action> {
        RecurseReducer { (self) in
            BindingReducer()
                .onChange(of: \.route) { _, newValue in
                    Reduce({ _, _ in newValue == nil ? .send(.clearSubStates) : .none })
                }

            coreReducer(self: self)

            Scope(state: \.readingState, action: \.reading, child: ReadingReducer.init)
            Scope(state: \.archivesState, action: \.archives, child: ArchivesReducer.init)
            Scope(state: \.torrentsState, action: \.torrents, child: TorrentsReducer.init)
            Scope(state: \.previewsState, action: \.previews, child: PreviewsReducer.init)
            Scope(state: \.galleryInfosState, action: \.galleryInfos, child: GalleryInfosReducer.init)
        }
    }

    private func applyDownloadBadge(
        _ badge: DownloadBadge,
        state: inout State
    ) -> Bool {
        let didChangeBadge = badge != state.downloadBadge || !state.hasLoadedDownloadBadge

        state.downloadBadge = badge
        if badge != .none {
            state.isPreparingDownload = false
        }
        state.hasLoadedDownloadBadge = true
        state.shouldCheckForRemoteUpdates = state.isDownloadContext || badge != .none

        if badge == .none && !state.isDownloadContext {
            state.galleryVersionMetadata = nil
            state.didRequestVersionMetadata = false
        }

        return didChangeBadge
    }

    private func shouldRequestVersionMetadata(state: State) -> Bool {
        state.galleryDetail != nil
            && state.shouldCheckForRemoteUpdates
            && !state.didRequestVersionMetadata
    }
}
