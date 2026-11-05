import AnalyticsClient
import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import HapticsClient
import Testing

// Moderation in the reducers (UGC-18-01). The filter list is injected (`commentFilterTerms`), so these cases test the
// decision, not the bundled terms.
//
// Posting reaches a real request type, so the gallery URL uses a scheme no URL session loads: the request fails at
// once without touching the network, and the test still sees the request action and its result.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated
// (see 11-22-SUMMARY.md).
@Suite
struct CommentModerationReducerTests {

    // MARK: Posting warning (D-12, P-8)

    // Comments screen, new comment and edit: a match presents the warning and sends nothing; Edit keeps the text and
    // the editor and gives it focus back.
    @MainActor
    @Test(arguments: ["", "42"])
    func aMatchingCommentWaitsForTheWarningAndEditKeepsIt(commentID: String) async {
        let store = makeCommentsStore(commentID: commentID, content: Self.matchingText)

        await store.send(.postTapped) {
            $0.moderation.presentPostingWarning()
        }
        await store.send(.moderation(.alert(.presented(.edit)))) {
            $0.moderation.alert = nil
        }
        await store.receive(\.moderation.delegate.resumeEditing) {
            $0.postCommentFocused = true
        }

        #expect(store.state.commentContent == Self.matchingText)
        #expect(store.state.destination == .postComment(commentID))
    }

    // Post Anyway sends the comment (an edit keeps its comment ID), then closes the editor.
    @MainActor
    @Test(arguments: ["", "42"])
    func postAnywaySendsThenCloses(commentID: String) async {
        let store = makeCommentsStore(commentID: commentID, content: Self.matchingText)

        await store.send(.postTapped) {
            $0.moderation.presentPostingWarning()
        }
        await store.send(.moderation(.alert(.presented(.postAnyway)))) {
            $0.moderation.alert = nil
        }
        await store.receive(\.moderation.delegate.post)
        await store.receive({ action in
            guard case .postComment(let galleryURL, let postedID) = action else { return false }
            return galleryURL == Self.offlineGalleryURL && postedID == (commentID.isEmpty ? nil : commentID)
        })
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
        await store.receive(\.performCommentActionDone, timeout: .seconds(10))
    }

    // Text the filter doesn't match posts exactly as before: request, then dismissal, no alert.
    @MainActor
    @Test(arguments: ["", "42"])
    func aCommentWithNoMatchPostsAndCloses(commentID: String) async {
        let store = makeCommentsStore(commentID: commentID, content: Self.cleanText)

        await store.send(.postTapped)
        await store.receive(\.postComment)
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
        await store.receive(\.performCommentActionDone, timeout: .seconds(10))
        #expect(store.state.moderation.alert == nil)
    }

    // Detail's new-comment path behaves the same: no request before the decision, Edit keeps the text and the sheet.
    @MainActor
    @Test
    func detailHoldsAMatchingCommentForTheWarning() async {
        let store = makeDetailStore(content: Self.matchingText)

        await store.send(.postTapped) {
            $0.moderation.presentPostingWarning()
        }
        await store.send(.moderation(.alert(.presented(.edit)))) {
            $0.moderation.alert = nil
        }
        await store.receive(\.moderation.delegate.resumeEditing) {
            $0.postCommentFocused = true
        }

        #expect(store.state.commentContent == Self.matchingText)
        // The sheet's `EquatableVoid` carries a fresh id per value, so the case is what's compared.
        #expect(store.state.destination.flatMap({ if case .postComment = $0 { true } else { nil } }) == true)
    }

    @MainActor
    @Test
    func detailPostAnywaySendsThenCloses() async {
        let store = makeDetailStore(content: Self.matchingText)

        await store.send(.postTapped) {
            $0.moderation.presentPostingWarning()
        }
        await store.send(.moderation(.alert(.presented(.postAnyway)))) {
            $0.moderation.alert = nil
        }
        await store.receive(\.moderation.delegate.post)
        await store.receive(\.postComment, Self.offlineGalleryURL)
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
        await store.receive(\.anyGalleryOpsDone, timeout: .seconds(10))
    }

    @MainActor
    @Test
    func detailPostsACommentWithNoMatch() async {
        let store = makeDetailStore(content: Self.cleanText)

        await store.send(.postTapped)
        await store.receive(\.postComment, Self.offlineGalleryURL)
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
        await store.receive(\.anyGalleryOpsDone, timeout: .seconds(10))
        #expect(store.state.moderation.alert == nil)
    }

    // The warning's buttons and texts (UI-SPEC C-5): Edit is the cancel-role default, Post Anyway has no role, and
    // nothing in the alert names the matched word.
    @Test
    func theWarningOffersEditAsTheDefaultAndNamesNoWord() {
        var state = CommentModerationFeature.State()
        state.presentPostingWarning()
        let alert = state.alert

        #expect(alert?.title == TextState(localized: .commentFilterTitle))
        #expect(alert?.message == TextState(localized: .commentFilterBody))
        let buttons: [ButtonState<CommentModerationFeature.Alert>] = [
            ButtonState(role: .cancel, action: .edit) {
                TextState(localized: .commentFilterEdit)
            },
            ButtonState(action: .postAnyway) {
                TextState(localized: .commentFilterPostAnyway)
            }
        ]
        #expect(alert?.buttons == buttons)
        var texts: [String] = buttons.map({ String(state: $0.label) })
        texts.append(String(state: TextState(localized: .commentFilterTitle)))
        texts.append(String(state: TextState(localized: .commentFilterBody)))
        #expect(!texts.contains(where: { $0.localizedCaseInsensitiveContains(Self.term) }))
    }
}

// MARK: Fixtures and stores

extension CommentModerationReducerTests {
    static let term = "badword"
    static let matchingText = "This has a BadWord in it."
    static let cleanText = "A perfectly kind comment."
    static let terms = CommentFilterTerms(groups: ["en": [term]])
    /// A gallery page URL no URL session loads, so a post fails at once without the network.
    static let offlineGalleryURL = URL(string: "ehpanda-test://e-hentai.org/g/42/abc123/")!

    @MainActor
    func makeCommentsStore(commentID: String, content: String) -> TestStoreOf<CommentsReducer> {
        var state = CommentsReducer.State(galleryURL: Self.offlineGalleryURL)
        state.destination = .postComment(commentID)
        state.commentContent = content
        return TestStore(initialState: state, reducer: CommentsReducer.init) {
            $0.analyticsClient = .noop
            $0.hapticsClient = .noop
            $0.commentFilterTerms = Self.terms
        }
    }

    @MainActor
    func makeDetailStore(content: String) -> TestStoreOf<DetailReducer> {
        var state = DetailReducer.State(
            gallery: Gallery(
                gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
                coverURL: nil, galleryURL: Self.offlineGalleryURL
            )
        )
        state.destination = .postComment(.init())
        state.commentContent = content
        return TestStore(initialState: state, reducer: DetailReducer.init) {
            $0.analyticsClient = .noop
            $0.hapticsClient = .noop
            $0.commentFilterTerms = Self.terms
        }
    }
}
