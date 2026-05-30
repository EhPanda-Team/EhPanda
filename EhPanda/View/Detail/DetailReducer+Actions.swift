//
//  DetailReducer+Actions.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

// MARK: - Navigation & UI Action Handlers
extension DetailReducer {
    func handleNavigationActions(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
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
            return handleOnAppear(gid: gid, showsNewDawnGreeting: showsNewDawnGreeting, state: &state)

        default:
            return nil
        }
    }

    private func handleOnAppear(
        gid: String,
        showsNewDawnGreeting: Bool,
        state: inout State
    ) -> Effect<Action> {
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
    }

    func handleUIActions(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .toggleShowFullTitle:
            state.showsFullTitle.toggle()
            return .run(operation: { _ in await hapticsClient.generateFeedback(.soft) })

        case .toggleShowUserRating:
            state.showsUserRating.toggle()
            return .run(operation: { _ in await hapticsClient.generateFeedback(.soft) })

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
                .run(operation: { _ in await hapticsClient.generateFeedback(.soft) }),
                .run { send in
                    try await Task.sleep(for: .seconds(1))
                    await send(.confirmRatingDone)
                }
            )

        case .confirmRatingDone:
            state.showsUserRating = false
            return .none

        default:
            return nil
        }
    }

    func handleSyncActions(
        state: inout State,
        action: Action
    ) -> Effect<Action>? {
        switch action {
        case .syncGalleryTags:
            return .run { [gid = state.gallery.id, tags = state.galleryTags] _ in
                await databaseClient.updateGalleryTags(gid: gid, tags: tags)
            }

        case .syncGalleryDetail:
            guard let detail = state.galleryDetail else { return .none }
            return .run(operation: { _ in await databaseClient.cacheGalleryDetail(detail) })

        case .syncGalleryPreviewURLs:
            return .run { [gid = state.gallery.id, previewURLs = state.galleryPreviewURLs] _ in
                await databaseClient
                    .updatePreviewURLs(gid: gid, previewURLs: previewURLs)
            }

        case .syncGalleryComments:
            return .run { [gid = state.gallery.id, comments = state.galleryComments] _ in
                await databaseClient.updateComments(gid: gid, comments: comments)
            }

        case .syncGreeting(let greeting):
            return .run(operation: { _ in await databaseClient.updateGreeting(greeting) })

        case .syncPreviewConfig(let config):
            return .run { [gid = state.gallery.id] _ in
                await databaseClient.updatePreviewConfig(gid: gid, config: config)
            }

        case .saveGalleryHistory:
            return .run { [gid = state.gallery.id] _ in
                await databaseClient.updateLastOpenDate(gid: gid)
            }

        case .updateReadingProgress(let progress):
            return .run { [gid = state.gallery.id] _ in
                await databaseClient.updateReadingProgress(gid: gid, progress: progress)
            }

        default:
            return nil
        }
    }

    func handleChildActions(
        state: inout State,
        action: Action,
        self reducer: Reduce<State, Action>
    ) -> Effect<Action>? {
        switch action {
        case .reading(.onPerformDismiss):
            return .send(.setNavigation(nil))

        case .reading, .archives, .torrents, .previews, .galleryInfos:
            return .none

        case .comments(.performCommentActionDone(let result)):
            return .send(.anyGalleryOpsDone(result))

        case .comments(.detail(let recursiveAction)):
            guard state.commentsState.wrappedValue != nil else { return .none }
            let effect = reducer._reduce(
                // swiftlint:disable:next force_unwrapping
                into: &state.commentsState.wrappedValue!.detailState.wrappedValue!, action: recursiveAction
            )
            return .publisher({ _EffectPublisher(effect).map({ Action.comments(.detail($0)) }) })

        case .comments:
            return .none

        case .detailSearch(.detail(let recursiveAction)):
            guard state.detailSearchState.wrappedValue != nil else { return .none }
            let effect = reducer._reduce(
                // swiftlint:disable:next force_unwrapping
                into: &state.detailSearchState.wrappedValue!.detailState.wrappedValue!, action: recursiveAction
            )
            return .publisher({ _EffectPublisher(effect).map({ Action.comments(.detail($0)) }) })

        case .detailSearch:
            return .none

        default:
            return nil
        }
    }
}
