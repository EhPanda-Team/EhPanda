import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import HapticsClient
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct CommentsReducerTests {
    @MainActor
    @Test
    func galleryFetchFailureReplacesLoadingToastWithoutFollowUpAction() async throws {
        let url = try #require(URL(string: "https://e-hentai.org/g/123/abcdef0123/"))
        var initialState = CommentsReducer.State(galleryURL: .mock)
        initialState.toast = .loading()
        let store = TestStore(
            initialState: initialState,
            reducer: CommentsReducer.init,
            withDependencies: { $0.analyticsClient = .noop }
        )

        await store.send(.fetchGalleryDone(url: url, result: .failure(.networkingFailed))) {
            $0.toast = .error()
        }
        await store.finish()
    }

    // Regression: editing a comment then opening a new one used to leak the edited text, because the
    // compose state was reset only on dismiss (which a swipe-down never triggers). The reset now
    // happens on present, so a fresh compose always starts empty regardless of how the sheet closed.
    @MainActor
    @Test
    func presentingPostCommentResetsStaleComposeState() async {
        let store = TestStore(
            initialState: CommentsReducer.State(galleryURL: .mock),
            reducer: CommentsReducer.init
        ) {
            $0.analyticsClient = .noop
            $0.hapticsClient = .noop
        }

        // Editing carries the prefill through the present action.
        await store.send(.presentPostComment(commentID: "42", content: "existing text")) {
            $0.commentContent = "existing text"
            $0.destination = .postComment("42")
        }

        // Presenting also focuses the editor once the sheet has animated in — the reducer-side
        // replacement for the editor's former `onAppear`.
        await store.receive(\.setPostCommentFocused, timeout: .seconds(2)) {
            $0.postCommentFocused = true
        }

        // Dismissing (Cancel or swipe-down) intentionally leaves the compose state untouched.
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }

        // Opening a new comment clears the stale text and focus on present.
        await store.send(.presentPostComment(commentID: "")) {
            $0.commentContent = ""
            $0.postCommentFocused = false
            $0.destination = .postComment("")
        }
        await store.receive(\.setPostCommentFocused, timeout: .seconds(2)) {
            $0.postCommentFocused = true
        }
    }
}
