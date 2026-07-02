import Testing
import Foundation
import AppModels
import HapticsClient
@testable import DetailFeature
import ComposableArchitecture

@Suite
struct CommentsReducerTests {
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
            $0.hapticsClient = .noop
        }

        // Editing carries the prefill through the present action.
        await store.send(.presentPostComment(commentID: "42", content: "existing text")) {
            $0.commentContent = "existing text"
            $0.destination = .postComment("42")
        }

        // Dismissing (Cancel or swipe-down) intentionally leaves the compose state untouched.
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }

        // Mimic the focus the editor's onAppear would have set.
        await store.send(.setPostCommentFocused(true)) {
            $0.postCommentFocused = true
        }

        // Opening a new comment clears the stale text and focus on present.
        await store.send(.presentPostComment(commentID: "")) {
            $0.commentContent = ""
            $0.postCommentFocused = false
            $0.destination = .postComment("")
        }
    }
}
