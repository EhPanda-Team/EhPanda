import AppModels
import ComposableArchitecture
import CookieClient
import DownloadClient
import Foundation
import HapticsClient
import NetworkingFeature
import UIKit

// MARK: - Fetch & Gallery Ops Action Handlers
extension DetailReducer {
    var fetchReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchGalleryDetail:
                guard state.loadingState != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                let galleryID = state.gallery.id
                state.loadingState = .loading
                state.didRequestVersionMetadata = false
                state.galleryVersionMetadata = nil
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await GalleryDetailRequest(
                            gid: galleryID,
                            galleryURL: galleryURL
                        )
                        .response()
                    }
                    await send(.fetchGalleryDetailDone(result))
                }
                .cancellable(id: CancelID.fetchGalleryDetail(state.cancellationGalleryID))

            case .fetchGalleryDetailDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let response):
                    var effects: [Effect<Action>] = [
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
                        if !greeting.gainedNothing && state.setting.showNewDawnGreeting {
                            effects.append(.send(.presentNewDawn(greeting)))
                        }
                    }
                    if let deepLink = state.pendingDeepLink {
                        state.pendingDeepLink = nil
                        switch deepLink {
                        case .reading:
                            // The linking comment already wrote the reading progress synchronously to
                            // `@Shared(.galleryHistory)`, so the reader can open immediately.
                            effects.append(.send(.presentReading))
                        case .comments(let commentID):
                            if let galleryURL = state.gallery.galleryURL {
                                effects.append(.send(.delegate(.pushComments(
                                    gid: state.gallery.id, token: state.gallery.token, apiKey: state.apiKey,
                                    galleryURL: galleryURL, comments: state.galleryComments,
                                    scrollCommentID: commentID
                                ))))
                            }
                        }
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
                guard let apiuid = Int(cookieClient.apiuid(host: state.setting.galleryHost)),
                      let gid = Int(state.gallery.id)
                else { return .none }
                let host = state.setting.galleryHost
                let apiKey = state.apiKey
                let token = state.gallery.token
                let rating = state.userRating
                return .run { [host, apiKey, token, rating] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await RateGalleryRequest(
                            host: host,
                            apiuid: apiuid,
                            apikey: apiKey,
                            gid: gid,
                            token: token,
                            rating: rating
                        )
                        .response()
                    }
                    await send(.anyGalleryOpsDone(result))
                }
                .cancellable(id: CancelID.rateGallery(state.cancellationGalleryID))

            case .favorGallery(let favIndex):
                let host = state.setting.galleryHost
                let gid = state.gallery.id
                let token = state.gallery.token
                return .run { [host, gid, token] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await FavorGalleryRequest(
                            host: host,
                            gid: gid,
                            token: token,
                            favIndex: favIndex
                        )
                        .response()
                    }
                    await send(.anyGalleryOpsDone(result))
                }
                .cancellable(id: CancelID.favorGallery(state.cancellationGalleryID))

            case .unfavorGallery:
                return .run { [host = state.setting.galleryHost, galleryID = state.gallery.id] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await UnfavorGalleryRequest(host: host, gid: galleryID).response()
                    }
                    await send(.anyGalleryOpsDone(result))
                }
                .cancellable(id: CancelID.unfavorGallery(state.cancellationGalleryID))

            case .postComment(let galleryURL):
                guard !state.commentContent.isEmpty else { return .none }
                return .run { [commentContent = state.commentContent] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await CommentGalleryRequest(
                            content: commentContent,
                            galleryURL: galleryURL
                        )
                        .response()
                    }
                    await send(.anyGalleryOpsDone(result))
                }
                .cancellable(id: CancelID.postComment(state.cancellationGalleryID))

            case .voteTag(let tag, let vote):
                guard let apiuid = Int(cookieClient.apiuid(host: state.setting.galleryHost)),
                      let gid = Int(state.gallery.id)
                else { return .none }
                let host = state.setting.galleryHost
                let apiKey = state.apiKey
                let token = state.gallery.token
                return .run { [host, apiKey, token] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await VoteGalleryTagRequest(
                            host: host,
                            apiuid: apiuid,
                            apikey: apiKey,
                            gid: gid,
                            token: token,
                            tag: tag,
                            vote: vote
                        )
                        .response()
                    }
                    await send(.anyGalleryOpsDone(result))
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
