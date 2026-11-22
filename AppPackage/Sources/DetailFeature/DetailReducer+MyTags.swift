import AppComponents
import AppModels
import ComposableArchitecture
import MyTagEditor
import MyTagsClient
import Resources

// MARK: - My Tags
extension DetailReducer {
    /// A tag's My Tags item (port of PR 462 item 10, design approved 2026-11-22). Add to My Tags opens Add Tag with the
    /// tag filled in, for the tag set last chosen on My Tags, and says so once the tag is added; Remove from My Tags
    /// removes the tag from that set at once and takes the page the site answered with into the cached My Tags.
    var myTagsReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addTagToMyTagsTapped(let name):
                guard let tagSet = state.user.myTags?.selectedTagSet else { return .none }
                state.destination = .myTagEditor(
                    MyTagEditorFeature.State(adding: name, isNameEditable: false, tagSet: tagSet)
                )
                return .none

            case .destination(.presented(.myTagEditor(.delegate(.saved)))):
                state.toast = .success(caption: .myTagsAdded)
                return .none

            case .removeTagFromMyTags(let tagID):
                guard let tagSetID = state.user.myTags?.selectedTagSet?.id else { return .none }
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await myTagsClient.removeTags(host, [tagID], tagSetID)
                    }
                    await send(.removeTagFromMyTagsDone(result))
                }
                .cancellable(id: CancelID.myTags(state.cancellationGalleryID))

            // The page the site answered with is the set as it now is, so the cache takes it even from a refusal.
            case .removeTagFromMyTagsDone(.success(let page)):
                state.$user.withLock({ $0.myTags = $0.myTags?.applying(page) })
                if let message = page.message {
                    state.alert = .failure(title: .RLocalizable.myTagsRemoveFailed, message: message)
                } else {
                    state.toast = .success(caption: .RLocalizable.myTagsRemoved)
                }
                return .none

            case .removeTagFromMyTagsDone(.failure(let error)):
                state.alert = .failure(title: .RLocalizable.myTagsRemoveFailed, message: error.alertText)
                return .none

            default:
                return .none
            }
        }
    }
}
