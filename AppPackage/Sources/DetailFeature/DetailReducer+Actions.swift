import AppModels
import ComposableArchitecture
import Foundation
import ReadingFeature
import Sharing

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
                return .send(.destination(.presented(.reading(.onPresented))))

            // Presenting each of these sheets is what starts its fetch, replacing the sheet views'
            // former `onAppear`. The archive request needs both URLs the sheet renders from, so a
            // tap without them presents an empty sheet exactly as it did before.
            case .archivesButtonTapped:
                state.destination = .archives(ArchivesReducer.State())
                guard let galleryURL = state.gallery.galleryURL,
                      let archiveURL = state.galleryDetail?.archiveURL
                else { return .none }
                return .send(.destination(.presented(.archives(.fetchArchive(
                    gid: state.gid, galleryURL: galleryURL, archiveURL: archiveURL
                )))))

            case .torrentsButtonTapped:
                state.destination = .torrents(TorrentsReducer.State())
                return .send(.destination(.presented(.torrents(.fetchGalleryTorrents(
                    gid: state.gid, token: state.gallery.token
                )))))

            case .folderManagerButtonTapped:
                state.destination = .folderManager(FolderManagerReducer.State())
                return .send(.destination(.presented(.folderManager(.fetchFolders))))

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
                // Presenting the editor is what focuses it. The delay lets the sheet finish its
                // presentation animation before the keyboard is raised, which is what the editor's
                // former `onAppear` hook waited for.
                return .run { send in
                    try await Task.sleep(for: .milliseconds(750))
                    await send(.setPostCommentFocused(true))
                }

            case .presentNewDawn(let greeting):
                state.destination = .newDawn(greeting)
                return .none

            case .tagDetailButtonTapped(let tagDetail):
                state.destination = .tagDetail(tagDetail)
                return .none

            case .onPresented:
                return handleOnPresented(state: &state)

            default:
                return .none
            }
        }
    }

    // Presentation-driven lifecycle: every host sends `.onPresented` in the same state transition
    // that installs this screen (a stack push or the app-level modal), replacing the former view
    // `onAppear`. Presentation fires once per screen instead of once per appearance, so the
    // per-visit reset below is the reset for the whole screen's life; `state.gid` no longer needs
    // passing in because `State.init` derives it from the seeded gallery.
    private func handleOnPresented(state: inout State) -> Effect<Action> {
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
                // Greeting is a session-only in-memory shared slot (resets each launch). Merge through
                // the newer-only rule so a stale detail-page greeting can't clobber a fresher Setting
                // fetch.
                @Shared(.greeting) var sharedGreeting
                $sharedGreeting.withLock { $0.mergeNewer(greeting) }
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
