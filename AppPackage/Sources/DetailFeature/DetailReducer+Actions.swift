import Foundation
import AppModels
import Sharing
import ComposableArchitecture
import ReadingFeature

// MARK: - Navigation & UI Action Handlers
extension DetailReducer {
    var navigationReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .destination(.presented(.reading(.onPerformDismiss))):
                return .send(.destination(.dismiss))

            case .destination:
                return .none

            case .presentReading:
                state.destination = .reading(.init(
                    gallery: state.gallery, previewConfig: state.previewConfig,
                    language: state.galleryDetail?.language
                ))
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
                // Reset on present (not on dismiss): the sheet is a raw case binding, so a swipe-down
                // never sends `.destination(.dismiss)`. This is the new-comment flow only, so clearing
                // is always correct.
                state.commentContent = .init()
                state.postCommentFocused = false
                state.destination = .postComment(.init())
                return .none

            case .presentNewDawn(let greeting):
                state.destination = .newDawn(greeting)
                return .none

            case .tagDetailButtonTapped(let tagDetail):
                state.destination = .tagDetail(tagDetail)
                return .none

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
        // The gallery is already seeded from the pushing context, so we record the visit and fetch
        // the (always network-sourced) detail directly.
        return .merge(
            .send(.saveGalleryHistory),
            .send(.fetchGalleryDetail),
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
            case .syncGreeting(let greeting):
                // Greeting is session-only (not persisted with `User`). Merge through the shared user's
                // newer-only rule so a stale detail-page greeting can't clobber a fresher Setting fetch.
                @Shared(.user) var user
                $user.withLock { $0.mergeGreeting(greeting) }
                return .none

            case .saveGalleryHistory:
                @Shared(.galleryHistory) var galleryHistory
                $galleryHistory.withLock {
                    $0.recordGalleryOpen(gid: state.gallery.id, token: state.gallery.token, date: date.now)
                }
                return .none

            case .updateReadingProgress(let progress):
                @Shared(.galleryHistory) var galleryHistory
                $galleryHistory.withLock {
                    $0.updateReadingProgress(
                        gid: state.gallery.id, token: state.gallery.token, progress: progress, date: date.now
                    )
                }
                return .none

            default:
                return .none
            }
        }
    }

}
