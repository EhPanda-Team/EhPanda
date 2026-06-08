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
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchDatabaseInfos(let gid):
                return handleFetchDatabaseInfos(gid: gid, state: &state)

            case .fetchDatabaseInfosDone(let galleryState):
                return handleFetchDatabaseInfosDone(galleryState: galleryState, state: &state)

            case .fetchGalleryDetail:
                return handleFetchGalleryDetail(state: &state)

            case .fetchGalleryDetailDone(let result):
                return handleFetchGalleryDetailDone(result: result, state: &state)

            case .fetchVersionMetadataIfNeeded:
                return handleFetchVersionMetadataIfNeeded(state: &state)

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

    private func handleFetchDatabaseInfos(gid: String, state: inout State) -> Effect<Action> {
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
    }

    private func handleFetchDatabaseInfosDone(galleryState: GalleryState, state: inout State) -> Effect<Action> {
        state.galleryTags = galleryState.tags
        state.galleryPreviewURLs = galleryState.previewURLs
        state.galleryComments = galleryState.comments
        if let previewConfig = galleryState.previewConfig {
            state.previewConfig = previewConfig
        }
        return .send(.fetchGalleryDetail)
    }

    private func handleFetchGalleryDetail(state: inout State) -> Effect<Action> {
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
    }

    private func handleFetchGalleryDetailDone(
        result: Result<GalleryDetailResponse, AppError>,
        state: inout State
    ) -> Effect<Action> {
        state.loadingState = .idle
        switch result {
        case .success(let response):
            return applyGalleryDetailResponse(response, state: &state)
        case .failure(let error):
            state.loadingState = .failed(error)
        }
        return .none
    }

    private func applyGalleryDetailResponse(
        _ response: GalleryDetailResponse,
        state: inout State
    ) -> Effect<Action> {
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
    }

    private func handleFetchVersionMetadataIfNeeded(state: inout State) -> Effect<Action> {
        guard state.shouldCheckForRemoteUpdates,
              !state.didRequestVersionMetadata,
              state.galleryDetail != nil
        else {
            return .none
        }
        state.didRequestVersionMetadata = true
        return .run { [gallery = state.gallery] send in
            let metadata: DownloadVersionMetadata?
            switch await downloadClient.fetchVersionMetadata(gallery.gid, gallery.token) {
            case .success(let fetchedMetadata):
                metadata = fetchedMetadata
            case .failure:
                metadata = nil
            }
            await send(.fetchVersionMetadataDone(.success(metadata)))
            guard let metadata else { return }
            let badge = await downloadClient.updateRemoteVersion(
                gallery.gid,
                metadata
            )
            await send(.fetchDownloadBadgeDone(badge))
        }
        .cancellable(id: CancelID.fetchVersionMetadata, cancelInFlight: true)
    }

    var galleryOpsReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .rateGallery:
                return handleRateGallery(state: state)
            case .favorGallery(let favIndex):
                return handleFavorGallery(favIndex: favIndex, state: state)
            case .unfavorGallery:
                return handleUnfavorGallery(state: state)
            case .postComment(let galleryURL):
                return handlePostComment(galleryURL: galleryURL, state: state)
            case .voteTag(let tag, let vote):
                return handleVoteTag(tag: tag, vote: vote, state: state)
            case .anyGalleryOpsDone(let result):
                return handleAnyGalleryOpsDone(result: result)
            default:
                return .none
            }
        }
    }

    private func handleRateGallery(state: State) -> Effect<Action> {
        guard let apiuid = Int(cookieClient.apiuid), let gid = Int(state.gallery.id)
        else { return .none }
        return .run { [apiKey = state.apiKey, token = state.gallery.token, rating = state.userRating] send in
            let response = await RateGalleryRequest(
                apiuid: apiuid, apikey: apiKey,
                gid: gid, token: token, rating: rating
            ).response()
            await send(.anyGalleryOpsDone(response))
        }.cancellable(id: CancelID.rateGallery)
    }

    private func handleFavorGallery(favIndex: Int, state: State) -> Effect<Action> {
        .run { [gid = state.gallery.id, token = state.gallery.token] send in
            let response = await FavorGalleryRequest(
                gid: gid, token: token, favIndex: favIndex
            ).response()
            await send(.anyGalleryOpsDone(response))
        }
        .cancellable(id: CancelID.favorGallery)
    }

    private func handleUnfavorGallery(state: State) -> Effect<Action> {
        .run { [galleryID = state.gallery.id] send in
            let response = await UnfavorGalleryRequest(gid: galleryID).response()
            await send(.anyGalleryOpsDone(response))
        }
        .cancellable(id: CancelID.unfavorGallery)
    }

    private func handlePostComment(galleryURL: URL, state: State) -> Effect<Action> {
        guard !state.commentContent.isEmpty else { return .none }
        return .run { [commentContent = state.commentContent] send in
            let response = await CommentGalleryRequest(
                content: commentContent, galleryURL: galleryURL
            ).response()
            await send(.anyGalleryOpsDone(response))
        }
        .cancellable(id: CancelID.postComment)
    }

    private func handleVoteTag(tag: String, vote: Int, state: State) -> Effect<Action> {
        guard let apiuid = Int(cookieClient.apiuid), let gid = Int(state.gallery.id)
        else { return .none }
        return .run { [apiKey = state.apiKey, token = state.gallery.token] send in
            let response = await VoteGalleryTagRequest(
                apiuid: apiuid, apikey: apiKey,
                gid: gid, token: token, tag: tag, vote: vote
            ).response()
            await send(.anyGalleryOpsDone(response))
        }
        .cancellable(id: CancelID.voteTag)
    }

    private func handleAnyGalleryOpsDone(result: Result<Void, AppError>) -> Effect<Action> {
        if case .success = result {
            return .merge(
                .send(.fetchGalleryDetail),
                .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
            )
        }
        return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
    }
}
