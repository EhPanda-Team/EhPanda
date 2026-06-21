//
//  DetailReducer+Fetch.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

// MARK: - Fetch & Gallery Ops Action Handlers
extension DetailReducer {
    func fetchReducer(_ reducer: Reduce<State, Action>) -> some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .teardown:
                return .merge(
                    CancelID
                        .all(for: state.cancellationGalleryID)
                        .map(Effect.cancel(id:))
                )

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
                    .cancellable(id: CancelID.fetchDatabaseInfos(state.cancellationGalleryID))
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
                let galleryID = state.gallery.id
                state.loadingState = .loading
                state.didRequestVersionMetadata = false
                state.galleryVersionMetadata = nil
                return .run { send in
                    let response = await GalleryDetailRequest(gid: galleryID, galleryURL: galleryURL).response()
                    await send(.fetchGalleryDetailDone(response))
                }
                .cancellable(id: CancelID.fetchGalleryDetail(state.cancellationGalleryID))

            case .fetchGalleryDetailDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let response):
                    var effects: [Effect<Action>] = [
                        .send(.syncGalleryTags),
                        .send(.syncGalleryDetail),
                        .send(.syncGalleryPreviewURLs),
                        .send(.syncGalleryComments),
                        .send(.fetchDownloadBadge)
                    ]
                    state.apiKey = response.apiKey
                    state.galleryDetail = response.galleryDetail
                    state.galleryTags = response.galleryState.tags
                    state.galleryPreviewURLs = response.galleryState.previewURLs
                    state.galleryComments = response.galleryState.comments
                    if let config = response.galleryState.previewConfig {
                        state.previewConfig = config
                    }
                    state.userRating = Int(response.galleryDetail.userRating) * 2
                    if shouldRequestVersionMetadata(state: state) {
                        effects.append(.send(.fetchVersionMetadataIfNeeded))
                    }
                    if let greeting = response.greeting {
                        effects.append(.send(.syncGreeting(greeting)))
                        if !greeting.gainedNothing && state.showsNewDawnGreeting {
                            effects.append(.send(.setNavigation(.newDawn(greeting))))
                        }
                    }
                    if let config = response.galleryState.previewConfig {
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
                      state.galleryDetail != nil
                else {
                    return .none
                }
                state.didRequestVersionMetadata = true
                let gallery = state.gallery
                return .run { send in
                    let metadata = await downloadClient.fetchVersionMetadata(gallery.gid, gallery.token)
                    await send(.fetchVersionMetadataDone(.success(metadata)))
                    guard let metadata else { return }
                    let download = await downloadClient.updateRemoteVersion(gallery.gid, metadata)
                    await send(.fetchDownloadBadgeDone(download))
                }
                .cancellable(id: CancelID.fetchVersionMetadata(state.cancellationGalleryID), cancelInFlight: true)

            case .fetchVersionMetadataDone(let result):
                if case .success(let metadata) = result {
                    state.galleryVersionMetadata = metadata
                }
                return .none

            default:
                return .none
            }
        }
    }

    var galleryOpsReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .rateGallery:
                guard let apiuid = Int(cookieClient.apiuid), let gid = Int(state.gallery.id)
                else { return .none }
                return .run { [apiKey = state.apiKey, token = state.gallery.token, rating = state.userRating] send in
                    let response = await RateGalleryRequest(
                        apiuid: apiuid, apikey: apiKey,
                        gid: gid, token: token, rating: rating
                    ).response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.rateGallery(state.cancellationGalleryID))

            case .favorGallery(let favIndex):
                return .run { [gid = state.gallery.id, token = state.gallery.token] send in
                    let response = await FavorGalleryRequest(
                        gid: gid, token: token, favIndex: favIndex
                    ).response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.favorGallery(state.cancellationGalleryID))

            case .unfavorGallery:
                return .run { [galleryID = state.gallery.id] send in
                    let response = await UnfavorGalleryRequest(gid: galleryID).response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.unfavorGallery(state.cancellationGalleryID))

            case .postComment(let galleryURL):
                guard !state.commentContent.isEmpty else { return .none }
                return .run { [commentContent = state.commentContent] send in
                    let response = await CommentGalleryRequest(
                        content: commentContent, galleryURL: galleryURL
                    ).response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.postComment(state.cancellationGalleryID))

            case .voteTag(let tag, let vote):
                guard let apiuid = Int(cookieClient.apiuid), let gid = Int(state.gallery.id)
                else { return .none }
                return .run { [apiKey = state.apiKey, token = state.gallery.token] send in
                    let response = await VoteGalleryTagRequest(
                        apiuid: apiuid, apikey: apiKey,
                        gid: gid, token: token, tag: tag, vote: vote
                    ).response()
                    await send(.anyGalleryOpsDone(response))
                }
                .cancellable(id: CancelID.voteTag(state.cancellationGalleryID))

            case .anyGalleryOpsDone(let result):
                if case .success = result {
                    return .merge(
                        .send(.fetchGalleryDetail),
                        .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
                    )
                }
                return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })

            default:
                return .none
            }
        }
    }
}
