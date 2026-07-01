import Foundation
import ComposableArchitecture
import ReadingFeature

// MARK: - Navigation & UI Action Handlers
extension DetailReducer {
    var navigationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .destination(.dismiss):
                if case .postComment = state.destination {
                    state.commentContent = .init()
                    state.postCommentFocused = false
                }
                return .none

            case .destination:
                return .none

            case .presentReading:
                state.destination = .reading(ReadingReducer.State())
                return .none

            case .archivesButtonTapped:
                state.destination = .archives(ArchivesReducer.State())
                return .none

            case .torrentsButtonTapped:
                state.destination = .torrents(TorrentsReducer.State())
                return .none

            case .folderManagerButtonTapped:
                state.destination = .folderManager(FolderManagerReducer.State())
                return .none

            case .shareButtonTapped(let url):
                state.destination = .share(url)
                return .none

            case .postCommentButtonTapped:
                state.destination = .postComment(.init())
                return .none

            case .presentNewDawn(let greeting):
                state.destination = .newDawn(greeting)
                return .none

            case .tagDetailButtonTapped(let tagDetail):
                state.destination = .tagDetail(tagDetail)
                return .none

            case .clearSubStates:
                state.previewsState = .init()
                state.commentsState.wrappedValue = .init()
                state.commentContent = .init()
                state.postCommentFocused = false
                state.galleryInfosState = .init()
                state.detailSearchState.wrappedValue = .init()
                return .merge(
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
                return .none
            }
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
            .send(.fetchDownloadFolders),
            .send(.observeDownload),
            .send(.loadLocalPreviewURLs)
        )
    }

    var uiReducer: some ReducerOf<Self> {
        Reduce { state, action in
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
                return .none
            }
        }
    }

    var syncReducer: some ReducerOf<Self> {
        Reduce { state, action in
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
                return .none
            }
        }
    }

    func childReducer(_ reducer: Reduce<State, Action>) -> some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .destination(.presented(.reading(.onPerformDismiss))):
                return .send(.destination(.dismiss))

            case .previews, .galleryInfos:
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
                return .none
            }
        }
    }
}
