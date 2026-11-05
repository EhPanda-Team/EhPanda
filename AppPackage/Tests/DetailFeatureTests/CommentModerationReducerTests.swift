import AnalyticsClient
import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
@testable import DetailFeature
import Foundation
import HapticsClient
import Resources
import Sharing
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
        var state = CommentModerationFeature.State(galleryURL: nil)
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

// MARK: Report (D-10, A-5)

extension CommentModerationReducerTests {
    // Report asks first, naming the site and the author, then opens the gallery's report page in the screen's sheet.
    @MainActor
    @Test
    func reportAsksThenOpensTheGallerysReportPage() async {
        let store = makeModerationCommentsStore()

        await store.send(.moderation(.reportTapped(Self.first))) {
            $0.moderation.alert = Self.reportAlert(site: "E-Hentai", author: Self.author)
        }
        await store.send(.moderation(.alert(.presented(.confirmReport(Self.reportURL))))) {
            $0.moderation.alert = nil
        }
        await store.receive(\.moderation.delegate.openReportPage, Self.reportURL) {
            $0.destination = .reportPage(Self.reportURL)
        }
    }

    @MainActor
    @Test
    func cancellingTheReportOpensNothing() async {
        let store = makeModerationCommentsStore()

        await store.send(.moderation(.reportTapped(Self.first))) {
            $0.moderation.alert = Self.reportAlert(site: "E-Hentai", author: Self.author)
        }
        await store.send(.moderation(.alert(.dismiss))) {
            $0.moderation.alert = nil
        }
    }

    // A gallery with no report target gets neither the alert nor the sheet.
    @MainActor
    @Test
    func aGalleryWithNoReportPagePresentsNothing() async throws {
        let galleryURL = try #require(URL(string: "https://example.com/g/42/abc123/"))
        let store = makeModerationCommentsStore(galleryURL: galleryURL)

        await store.send(.moderation(.reportTapped(Self.first)))
    }

    @MainActor
    @Test
    func detailReportOpensTheReportPageToo() async {
        let store = makeModerationDetailStore()

        await store.send(.moderation(.reportTapped(Self.first))) {
            $0.moderation.alert = Self.reportAlert(site: "E-Hentai", author: Self.author)
        }
        await store.send(.moderation(.alert(.presented(.confirmReport(Self.reportURL))))) {
            $0.moderation.alert = nil
        }
        await store.receive(\.moderation.delegate.openReportPage, Self.reportURL) {
            $0.destination = .reportPage(Self.reportURL)
        }
    }
}

// MARK: Block, unblock, show once (D-13)

extension CommentModerationReducerTests {
    // Block asks first; confirming collapses every comment by that author, and blocking again adds no second entry.
    @MainActor
    @Test
    func blockCollapsesEveryCommentByTheAuthorOnce() async {
        let store = makeModerationCommentsStore()

        await block(Self.author, from: Self.first, in: store)
        #expect(store.state.moderation.isCollapsed(Self.first))
        #expect(store.state.moderation.isCollapsed(Self.second))
        #expect(!store.state.moderation.isCollapsed(Self.other))

        await store.send(.moderation(.blockTapped(Self.second))) {
            $0.moderation.alert = Self.blockAlert(author: Self.author)
        }
        await store.send(.moderation(.alert(.presented(.confirmBlock(author: Self.author))))) {
            $0.moderation.alert = nil
        }
        await store.receive(\.moderation.delegate.didBlock, Self.author)
        #expect(store.state.moderation.blockedAuthors == [Self.author])
    }

    @MainActor
    @Test
    func cancellingTheBlockBlocksNobody() async {
        let store = makeModerationCommentsStore()

        await store.send(.moderation(.blockTapped(Self.first))) {
            $0.moderation.alert = Self.blockAlert(author: Self.author)
        }
        await store.send(.moderation(.alert(.dismiss))) {
            $0.moderation.alert = nil
        }
        #expect(store.state.moderation.blockedAuthors.isEmpty)
    }

    // Unblock takes effect at once, with no alert.
    @MainActor
    @Test
    func unblockIsImmediate() async {
        let store = makeModerationCommentsStore()
        await block(Self.author, from: Self.first, in: store)

        await store.send(.moderation(.unblock(author: Self.author))) {
            $0.moderation.$blockedAuthors.withLock({ $0 = [] })
        }
        #expect(!store.state.moderation.isCollapsed(Self.first))
        #expect(!store.state.moderation.isCollapsed(Self.second))
    }

    // Show reveals one comment; the author's other comment stays collapsed and the author stays blocked. Hide
    // collapses it again.
    @MainActor
    @Test
    func showRevealsOneCommentAndHideCollapsesIt() async {
        let store = makeModerationCommentsStore()
        await block(Self.author, from: Self.first, in: store)

        await store.send(.moderation(.show(commentID: Self.first.commentID))) {
            $0.moderation.revealedCommentIDs = [Self.first.commentID]
        }
        #expect(!store.state.moderation.isCollapsed(Self.first))
        #expect(store.state.moderation.isBlocked(Self.first))
        #expect(store.state.moderation.isCollapsed(Self.second))

        await store.send(.moderation(.hide(commentID: Self.first.commentID))) {
            $0.moderation.revealedCommentIDs = []
        }
        #expect(store.state.moderation.isCollapsed(Self.first))
    }

    // A reveal is never stored: the block persists, and the next screen starts with every comment collapsed.
    @MainActor
    @Test
    func aRevealDoesNotOutliveTheScreen() async {
        let storage = UserDefaults.inMemory
        let store = makeModerationCommentsStore(storage: storage)
        await block(Self.author, from: Self.first, in: store)
        await store.send(.moderation(.show(commentID: Self.first.commentID))) {
            $0.moderation.revealedCommentIDs = [Self.first.commentID]
        }

        let nextScreen = withDependencies {
            $0.defaultAppStorage = storage
        } operation: {
            CommentsReducer.State(galleryURL: Self.galleryURL, comments: Self.comments)
        }
        #expect(nextScreen.moderation.revealedCommentIDs.isEmpty)
        #expect(nextScreen.moderation.isCollapsed(Self.first))
    }

    // Blocking an author again after Unblock collapses a comment that was revealed before (C-4: every comment of
    // theirs collapses at once).
    @MainActor
    @Test
    func blockingAgainCollapsesARevealedComment() async {
        let store = makeModerationCommentsStore()
        await block(Self.author, from: Self.first, in: store)
        await store.send(.moderation(.show(commentID: Self.first.commentID))) {
            $0.moderation.revealedCommentIDs = [Self.first.commentID]
        }
        await store.send(.moderation(.unblock(author: Self.author))) {
            $0.moderation.$blockedAuthors.withLock({ $0 = [] })
        }

        await store.send(.moderation(.blockTapped(Self.first))) {
            $0.moderation.alert = Self.blockAlert(author: Self.author)
        }
        await store.send(.moderation(.alert(.presented(.confirmBlock(author: Self.author))))) {
            $0.moderation.alert = nil
            $0.moderation.$blockedAuthors.withLock({ $0 = [Self.author] })
        }
        await store.receive(\.moderation.delegate.didBlock, Self.author) {
            $0.moderation.revealedCommentIDs = []
        }
        #expect(store.state.moderation.isCollapsed(Self.first))
    }

    @MainActor
    @Test
    func detailBlockCollapsesTheStripsComments() async {
        let store = makeModerationDetailStore()

        await store.send(.moderation(.blockTapped(Self.first))) {
            $0.moderation.alert = Self.blockAlert(author: Self.author)
        }
        await store.send(.moderation(.alert(.presented(.confirmBlock(author: Self.author))))) {
            $0.moderation.alert = nil
            $0.moderation.$blockedAuthors.withLock({ $0 = [Self.author] })
        }
        await store.receive(\.moderation.delegate.didBlock, Self.author)
        #expect(store.state.galleryComments.filter(store.state.moderation.isCollapsed).map(\.commentID) == ["1", "2"])
    }
}

// MARK: Own comments (A-10) and analytics (D-02)

extension CommentModerationReducerTests {
    // The signed-in user's own comment, by its Edit link or by the signed-in name, gets no Report and no Block.
    @MainActor
    @Test
    func ownCommentsGetNoReportOrBlock() async {
        let storage = UserDefaults.inMemory
        withDependencies {
            $0.defaultAppStorage = storage
        } operation: {
            @Shared(.user) var user
            $user.withLock({ $0.displayName = Self.ownName })
        }
        let store = makeModerationCommentsStore(storage: storage, cookieClient: .previewLoggedIn)
        let editable = Self.comment(id: "7", author: "someone", editable: true)
        let byName = Self.comment(id: "8", author: Self.ownName)

        for comment in [editable, byName] {
            await store.send(.moderation(.reportTapped(comment)))
            await store.send(.moderation(.blockTapped(comment)))
        }
        #expect(store.state.moderation.blockedAuthors.isEmpty)
    }

    // No moderation action sends an analytics signal, so no author name or comment text can reach one.
    @MainActor
    @Test
    func moderationSendsNoAnalyticsSignal() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        var analyticsClient = AnalyticsClient.noop
        analyticsClient.send = { signal in recorded.withValue({ $0.append(signal) }) }
        let store = makeModerationCommentsStore(analyticsClient: analyticsClient)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.moderation(.reportTapped(Self.first)))
        await store.send(.moderation(.alert(.presented(.confirmReport(Self.reportURL)))))
        await store.send(.moderation(.blockTapped(Self.first)))
        await store.send(.moderation(.alert(.presented(.confirmBlock(author: Self.author)))))
        await store.send(.moderation(.show(commentID: Self.first.commentID)))
        await store.send(.moderation(.hide(commentID: Self.first.commentID)))
        await store.send(.moderation(.unblock(author: Self.author)))
        await store.send(.presentPostComment(commentID: ""))
        await store.send(.binding(.set(\.commentContent, Self.matchingText)))
        await store.send(.postTapped)
        await store.send(.moderation(.alert(.presented(.edit))))
        await store.skipReceivedActions()
        await store.skipInFlightEffects()

        #expect(recorded.value.isEmpty)
    }
}

// MARK: Moderation fixtures

extension CommentModerationReducerTests {
    static let author = "SENTINEL_AUTHOR"
    static let ownName = "SignedInUser"
    static let galleryURL = URL(string: "https://e-hentai.org/g/42/abc123/")!
    static let reportURL = URL(string: "https://e-hentai.org/g/42/abc123/?report=select")!
    static let first = comment(id: "1", author: author)
    static let second = comment(id: "2", author: author)
    static let other = comment(id: "3", author: "someone else")
    static let comments = [first, second, other]

    static func comment(id: String, author: String, editable: Bool = false) -> GalleryComment {
        GalleryComment(
            votedUp: false, votedDown: false, votable: !editable, editable: editable,
            author: author, contents: [], commentID: id, commentDate: Date(timeIntervalSince1970: 0)
        )
    }

    static func reportAlert(site: String, author: String) -> AppAlertState<CommentModerationFeature.Alert> {
        AppAlertState {
            TextState(localized: .commentReportConfirmTitle)
        } actions: {
            ButtonState(role: .cancel) {
                TextState(localized: .RLocalizable.cancel)
            }
            ButtonState(action: .confirmReport(reportURL)) {
                TextState(localized: .commentReportOpen)
            }
        } message: {
            TextState(localized: .commentReportConfirmBody(site, author))
        }
    }

    static func blockAlert(author: String) -> AppAlertState<CommentModerationFeature.Alert> {
        AppAlertState {
            TextState(localized: .commentBlockConfirmTitle(author))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(localized: .RLocalizable.cancel)
            }
            ButtonState(role: .destructive, action: .confirmBlock(author: author)) {
                TextState(localized: .commentBlockConfirm)
            }
        } message: {
            TextState(localized: .commentBlockConfirmBody)
        }
    }

    /// Blocks `author` through the menu and the confirmation.
    @MainActor
    func block(_ author: String, from comment: GalleryComment, in store: TestStoreOf<CommentsReducer>) async {
        await store.send(.moderation(.blockTapped(comment))) {
            $0.moderation.alert = Self.blockAlert(author: author)
        }
        await store.send(.moderation(.alert(.presented(.confirmBlock(author: author))))) {
            $0.moderation.alert = nil
            $0.moderation.$blockedAuthors.withLock({ $0 = [author] })
        }
        await store.receive(\.moderation.delegate.didBlock, author)
    }

    @MainActor
    func makeModerationCommentsStore(
        galleryURL: URL = galleryURL,
        storage: UserDefaults = .inMemory,
        cookieClient: CookieClient = .noop,
        analyticsClient: AnalyticsClient = .noop
    ) -> TestStoreOf<CommentsReducer> {
        let state = withDependencies {
            $0.defaultAppStorage = storage
        } operation: {
            CommentsReducer.State(galleryURL: galleryURL, comments: Self.comments)
        }
        return TestStore(initialState: state, reducer: CommentsReducer.init) {
            $0.defaultAppStorage = storage
            $0.analyticsClient = analyticsClient
            $0.cookieClient = cookieClient
            $0.hapticsClient = .noop
            $0.commentFilterTerms = Self.terms
        }
    }

    @MainActor
    func makeModerationDetailStore() -> TestStoreOf<DetailReducer> {
        var state = DetailReducer.State(
            gallery: Gallery(
                gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
                coverURL: nil, galleryURL: Self.galleryURL
            )
        )
        state.galleryComments = Self.comments
        return TestStore(initialState: state, reducer: DetailReducer.init) {
            $0.analyticsClient = .noop
            $0.cookieClient = .noop
            $0.hapticsClient = .noop
        }
    }
}
