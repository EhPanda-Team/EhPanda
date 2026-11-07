import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import Kingfisher
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI
import SystemNotification

struct CommentsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @SharedReader(.didLogin) private var didLogin: Bool
    @SharedReader(.user) private var user: User
    @Bindable private var store: StoreOf<CommentsReducer>
    /// The comment whose Report or Block was chosen last: its row presents the moderation alert, and after a Block
    /// VoiceOver moves to its collapsed row (C-4).
    @State private var moderationTargetID: String?
    @AccessibilityFocusState private var focusedCommentID: String?
    private let gid: String
    private let token: String
    private let apiKey: String
    private let galleryURL: URL
    private let comments: [GalleryComment]

    init(
        store: StoreOf<CommentsReducer>,
        gid: String, token: String, apiKey: String, galleryURL: URL,
        comments: [GalleryComment]
    ) {
        self.store = store
        self.gid = gid
        self.token = token
        self.apiKey = apiKey
        self.galleryURL = galleryURL
        self.comments = comments
    }

    // MARK: CommentView
    var body: some View {
        ScrollViewReader { proxy in
            List(comments) { comment in
                row(comment)
                    .animation(.default) {
                        $0.opacity(
                            comment.commentID == store.scrollCommentID
                                ? store.scrollRowOpacity : 1
                        )
                    }
                    // The moderation alert sits on the row that asked for it (AGENTS.md alert placement).
                    .appAlert(moderationAlert(for: comment))
            }
            .accessibilityIdentifier("comments_view")
            // Blocking or unblocking collapses or expands every comment of the author at once (C-4, C-6).
            .animation(reduceMotion ? nil : .default, value: store.moderation.blockedMemberIDs)
            .onChange(of: store.moderation.blockedMemberIDs) {
                // After a Block, VoiceOver continues on the collapsed row of the comment acted on (C-4).
                if let moderationTargetID,
                   let comment = comments.first(where: { $0.commentID == moderationTargetID }),
                   store.moderation.isCollapsed(comment)
                {
                    focusedCommentID = moderationTargetID
                }
            }
            // View-local scrolling needs the `proxy`, so it stays in the view. `initial: true` gives
            // the first-render fire the former `onAppear` provided, for the deep-linked comment id
            // the screen is constructed with; later changes are no-ops because the id only clears.
            .onChange(of: store.scrollCommentID, initial: true) {
                if let scrollCommentID = store.scrollCommentID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        scroll(to: scrollCommentID, with: proxy)
                    }
                }
            }
        }
        .sheet(item: $store.destination.postComment, id: \.self) { commentID in
            let hasCommentID = !commentID.wrappedValue.isEmpty
            PostCommentView(
                title: hasCommentID ? .editComment : .postComment,
                content: $store.commentContent,
                isFocused: $store.postCommentFocused,
                // Over the editor, which stays open beneath it (C-5).
                postingWarning: $store.scope(\.moderation.$alert, action: \.moderation.alert),
                // The reducer posts and closes the editor, or holds both for the posting warning (D-12, P-8).
                postAction: { store.send(.postTapped) },
                cancelAction: { store.send(.destination(.dismiss)) }
            )
            .privacyMask()
        }
        // EhPanda's Report form; it presents the site's page itself when asked (18.1 D-01, P-7).
        .sheet(item: $store.scope(\.$destination, action: \.destination).reportForm) { store in
            ReportFormView(store: store)
                .privacyMask()
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toast($store.scope(\.$toast, action: \.toast))
        .animation(.default, value: store.scrollRowOpacity)
        .toolbar(content: toolbar)
        .navigationTitle(.comments)
    }

    /// Brings the deep-linked comment to the top of the list.
    ///
    /// The list aims a scroll at rows it has not built yet by their estimated heights, which at the largest text sizes
    /// fall far short of the real ones, so the travel can stop a row or more short of the comment. Once it ends, the
    /// rows around the comment are built at their real heights, and the scroll is made again without animation, on
    /// successive turns of the main queue while the list settles, so that it lands on the comment.
    ///
    /// The comment lands at the same anchor either way; only the travel there is motion, so Reduce Motion drops the
    /// animation, not the jump.
    private func scroll(to commentID: String, with proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .default) {
            proxy.scrollTo(commentID, anchor: .top)
        } completion: {
            land(on: commentID, with: proxy, passes: Self.landingPasses)
        }
    }

    private static let landingPasses = 3

    private func land(on commentID: String, with proxy: ScrollViewProxy, passes: Int) {
        guard passes > 0 else { return }
        proxy.scrollTo(commentID, anchor: .top)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            land(on: commentID, with: proxy, passes: passes - 1)
        }
    }

    /// A comment's row: the collapsed row for a blocked author (C-6), else the comment, with the C-7 line above it
    /// when it was revealed, its swipe actions and, unless it is the user's own, its moderation menu (C-4).
    @ViewBuilder private func row(_ comment: GalleryComment) -> some View {
        if store.moderation.isCollapsed(comment) {
            BlockedCommentRow(
                commentID: comment.commentID,
                showAction: { store.send(.moderation(.show(commentID: comment.commentID))) },
                unblockAction: {
                    if let memberID = comment.authorMemberID {
                        store.send(.moderation(.unblock(memberID: memberID)))
                    }
                }
            )
            .accessibilityFocused($focusedCommentID, equals: comment.commentID)
        } else {
            let actions = moderationActions(for: comment)
            CommentCell(
                gid: gid, comment: comment, moderation: actions,
                hideAction: store.moderation.isBlocked(comment)
                    ? { store.send(.moderation(.hide(commentID: comment.commentID))) } : nil,
                linkAction: { store.send(.handleCommentLink($0)) }
            )
            // Here, not on the row: on the row it would replace the collapsed row's own identifier.
            .accessibilityIdentifier("comment_cell_" + comment.commentID)
            .moderationContextMenu(actions)
            .swipeActions(edge: .leading) {
                if comment.votable {
                    Button {
                        store.send(.voteComment(
                            gid: gid, token: token, apiKey: apiKey, commentID: comment.commentID, vote: -1
                        ))
                    } label: {
                        Label(.voteDown, systemSymbol: .handThumbsdown)
                            .labelStyle(.iconOnly)
                    }
                    .tint(.red)
                }
            }
            .swipeActions(edge: .trailing) {
                if comment.votable {
                    Button {
                        store.send(.voteComment(
                            gid: gid, token: token, apiKey: apiKey, commentID: comment.commentID, vote: 1
                        ))
                    } label: {
                        Label(.voteUp, systemSymbol: .handThumbsup)
                            .labelStyle(.iconOnly)
                    }
                    .tint(.accentColor)
                }
                if comment.editable {
                    Button {
                        store.send(
                            .presentPostComment(commentID: comment.commentID, content: comment.plainTextContent)
                        )
                    } label: {
                        Label(.editComment, systemSymbol: .squareAndPencil)
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }

    /// The moderation alert as `comment`'s row sees it: present only for the row it was chosen on, and never while the
    /// editor is up, as the posting warning is presented over the editor.
    private func moderationAlert(for comment: GalleryComment) -> CommentModerationAlertBinding {
        let isPresented = moderationTargetID == comment.commentID && store.destination?.is(\.postComment) != true
        return $store.scope(\.moderation.$alert, action: \.moderation.alert)[presentedIf: isPresented]
    }

    private func moderationActions(for comment: GalleryComment) -> CommentModerationActions {
        store.moderation.actions(
            for: comment, on: .list, didLogin: didLogin, displayName: user.displayName
        ) { item in
            switch item {
            case .report:
                moderationTargetID = comment.commentID
                store.send(.moderation(.reportTapped(comment)))
            case .block:
                moderationTargetID = comment.commentID
                store.send(.moderation(.blockTapped(comment)))
            case .unblock:
                if let memberID = comment.authorMemberID {
                    store.send(.moderation(.unblock(memberID: memberID)))
                }
            case .hide:
                store.send(.moderation(.hide(commentID: comment.commentID)))
            }
        }
    }

    private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                store.send(.presentPostComment(commentID: ""))
            } label: {
                Label(.postComment, systemSymbol: .squareAndPencil)
            }
            .disabled(!didLogin)
        }
    }
}

extension CommentsView {
    struct CommentCell: View {
        private let gid: String
        private var comment: GalleryComment
        private let moderation: CommentModerationActions
        private let hideAction: (() -> Void)?
        private let linkAction: (URL) -> Void

        /// - Parameters:
        ///   - moderation: The comment's Report and Block (or Unblock) items; none for the user's own comment.
        ///   - hideAction: Set for a blocked author's comment shown once (C-7): the cell then opens with the
        ///     collapsed label and a Hide pill.
        init(
            gid: String, comment: GalleryComment,
            moderation: CommentModerationActions = .none, hideAction: (() -> Void)? = nil,
            linkAction: @escaping (URL) -> Void
        ) {
            self.gid = gid
            self.comment = comment
            self.moderation = moderation
            self.hideAction = hideAction
            self.linkAction = linkAction
        }

        /// The row is one accessibility element: a comment is read as a unit — author, vote,
        /// score, date, then its runs in order — instead of as one stop per run. The vote travels
        /// as the element's value, never as text (the thumb glyph is hidden below), and only while
        /// a vote exists. The links sit inside that one element, so every link the comment carries
        /// is also a named action on it, which is how VoiceOver and Voice Control reach them; taps
        /// on the text itself stay for sighted users. The swipe actions need nothing here: iOS
        /// surfaces them on the row's element already (`CONTEXTMENU=not-exposed` read, 16-CONTRAST-AUDIT).
        ///
        /// The context menu is not surfaced that way, so the moderation items (Report, then Block or
        /// Unblock; UI-SPEC C-4) follow the link actions as named actions of their own, and the `…`
        /// button that also holds them is hidden from accessibility. A revealed comment's C-7 line sits
        /// above the element, outside it, so its Hide stays an ordinary button.
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if let hideAction {
                    RevealedCommentLine(hideAction: hideAction)
                        .padding([.horizontal, .top])
                }
                commentContent
                    .padding([.horizontal, .bottom])
                    // 4pt under the C-7 line; the cell's usual top padding otherwise.
                    .padding(.top, hideAction == nil ? nil : 4)
            }
        }

        private var commentContent: some View {
            let links = links
            return VStack(alignment: .leading) {
                authorAndMetadata

                ForEach(comment.contents) { content in
                    switch content.type {
                    case .plainText:
                        if let text = content.text {
                            LinkedText(text: text, action: linkAction)
                        }
                    case .linkedText:
                        if let text = content.text, let link = content.link {
                            LinkedText(text: text, link: link, action: linkAction)
                        }
                    case .singleLink:
                        if let link = content.link {
                            LinkedText(text: AttributedString(link.absoluteString), link: link, action: linkAction)
                        }
                    case .singleImg, .doubleImg, .linkedImg, .doubleLinkedImg:
                        generateWebImages(
                            imgURL: content.imgURL, secondImgURL: content.secondImgURL,
                            link: content.link, secondLink: content.secondLink
                        )
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(.accessibilityVotedUp, isEnabled: comment.votedUp)
            .accessibilityValue(.accessibilityVotedDown, isEnabled: comment.votedDown)
            .accessibilityActions {
                // Declared last first: the block hands its actions over reversed, and the links lead, then the
                // moderation items in menu order.
                CommentModerationButtons(actions: moderation, isReversed: true)
                ForEach(links.reversed(), id: \.self) { link in
                    Button(openLinkActionName(link, distinguished: links.count > 1)) {
                        linkAction(link)
                    }
                }
            }
        }

        /// Every URL the comment's text runs carry, in reading order and without repeats: a
        /// `.linkedText` or `.singleLink` run names its own, and a `.plainText` run holds whatever
        /// the detector behind `LinkedText` finds in it. Linked images are left out: they are
        /// `Button`s already.
        private var links: [URL] {
            var seen: Set<URL> = []
            return comment.contents.flatMap(links(in:)).filter({ seen.insert($0).inserted })
        }

        private func links(in content: CommentContent) -> [URL] {
            switch content.type {
            case .plainText:
                content.text.map({ LinkedText.linkMatches(in: String($0.characters)).compactMap(\.url) }) ?? []
            case .linkedText, .singleLink:
                content.link.map({ [$0] }) ?? []
            case .singleImg, .doubleImg, .linkedImg, .doubleLinkedImg:
                []
            }
        }

        /// A comment with one link gets the plain "Open link"; with several, each action names
        /// its host so the rotor entries can be told apart. A URL without a host (`mailto:`) falls
        /// back to the whole URL.
        private func openLinkActionName(_ link: URL, distinguished: Bool) -> LocalizedStringResource {
            distinguished ? .accessibilityOpenLinkTo(link.host() ?? link.absoluteString) : .accessibilityOpenLink
        }

        /// The author and the vote/date group share the row for as long as both fit it whole, and
        /// take a line each once they do not — which is what stops the timestamp losing its minutes
        /// and then the author its characters, and what lets the banned 0.75 shrink go without the
        /// name going with it. The comment body beneath already wraps freely, so the header row was
        /// the one part of this cell that answered growing text by removing content.
        ///
        /// The candidates are written out rather than shared through `AdaptiveStack`, because the
        /// spacer that holds the pair apart and the `.lineLimit(1)` that keeps it to one line must
        /// belong to the horizontal candidate alone: in shared content the spacer would become a
        /// vertical expander once the pair stacks, and the line limit would clamp the stacked
        /// author to the very ellipsis the stacking exists to avoid.
        ///
        /// That spacer replaces the `.frame(maxWidth: .infinity, alignment: .leading)` the author
        /// used to carry, for two reasons. A flexible frame inside a candidate absorbs the
        /// overflow, so every candidate measures as fitting and the fallback can never win. And it
        /// is greedy: it claims the row's slack for the author's own frame and leaves the metadata
        /// beside it short, which is how a date starts ellipsising at the default size the moment
        /// the shrink that had been papering over it is removed. `minLength: 0` keeps the spacer
        /// from claiming width of its own, so the pair renders exactly where it does today.
        ///
        /// The `…` moderation button ends the row in both candidates: after the metadata on one line,
        /// and on the author's line, top-trailing, once the pair stacks (C-4). Its hit area overhangs
        /// the row's padding, so it adds no height.
        ///
        /// On one line the vote glyph keeps its slot while there is no vote, so voting does not move the
        /// score and date. Stacked, the metadata starts the line under the author, where an empty slot
        /// would only indent it, so the glyph is left out until there is a vote to show.
        private var authorAndMetadata: some View {
            ViewThatFits(in: .horizontal) {
                HStack {
                    authorText

                    Spacer(minLength: 0)

                    metadata(keepsVoteSlot: true)
                    moderationMenu
                }
                .lineLimit(1)

                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline) {
                        authorText

                        Spacer(minLength: 0)

                        moderationMenu
                    }
                    metadata(keepsVoteSlot: false)
                }
            }
        }

        @ViewBuilder private var moderationMenu: some View {
            if !moderation.items.isEmpty {
                CommentModerationMenuButton(actions: moderation)
            }
        }

        private var authorText: some View {
            Text(comment.author)
                .font(.subheadline.bold())
        }

        /// - Parameter keepsVoteSlot: Whether the vote glyph holds its place, invisible, while there is no vote.
        private func metadata(keepsVoteSlot: Bool) -> some View {
            let hasVote = comment.votedUp || comment.votedDown
            return HStack {
                if keepsVoteSlot || hasVote {
                    Image(systemSymbol: comment.votedUp ? .handThumbsupFill : .handThumbsdownFill)
                        .visible(hasVote)
                        .accessibilityHidden(true)
                }

                comment.score.map(Text.init)
                Text(comment.formattedDateString)
                    .accessibilityRepresentation {
                        Text(comment.accessibilityAttributedDateString)
                    }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        @ContentBuilder private func generateWebImages(
            imgURL: URL?, secondImgURL: URL?,
            link: URL?, secondLink: URL?
        ) -> some View {
            // Double
            if let imgURL = imgURL, let secondImgURL = secondImgURL {
                HStack(spacing: 0) {
                    if let link = link, let secondLink = secondLink {
                        imageContainer(url: imgURL, widthFactor: 4) {
                            linkAction(link)
                        }
                        imageContainer(url: secondImgURL, widthFactor: 4) {
                            linkAction(secondLink)
                        }
                    } else {
                        imageContainer(url: imgURL, widthFactor: 4)
                        imageContainer(url: secondImgURL, widthFactor: 4)
                    }
                }
            }
            // Single
            else if let imgURL = imgURL {
                if let link = link {
                    imageContainer(url: imgURL, widthFactor: 2) {
                        linkAction(link)
                    }
                } else {
                    imageContainer(url: imgURL, widthFactor: 2)
                }
            }
        }
        @ContentBuilder func imageContainer(
            url: URL, widthFactor: Double, action: (() -> Void)? = nil
        ) -> some View {
            let image = KFImage(url)
                .commentDefaultModifier()
                .scaledToFit()
                .containerRelativeFrame(.horizontal) { width, _ in
                    width / widthFactor
                }
            if let action = action {
                Button(action: action) {
                    image
                }
                .buttonStyle(.plain)
            } else {
                image
            }
        }
    }
}

private extension View {
    /// The comment's moderation items as a context menu (C-4); the user's own comment has none, so no menu at all.
    @ViewBuilder func moderationContextMenu(_ actions: CommentModerationActions) -> some View {
        if actions.items.isEmpty {
            self
        } else {
            contextMenu {
                CommentModerationButtons(actions: actions)
            }
        }
    }
}

private extension KFImage {
    func commentDefaultModifier() -> KFImage {
        defaultModifier()
            .placeholder {
                Placeholder(style: .activity(ratio: 1))
            }
    }
}

@MainActor private func previewCommentsView() -> some View {
    NavigationStack {
        CommentsView(
            store: .init(initialState: .init(galleryURL: .mock), reducer: CommentsReducer.init),
            gid: .init(),
            token: .init(),
            apiKey: .init(),
            galleryURL: .mock,
            comments: [
                .init(
                    votedUp: false, votedDown: false, votable: true, editable: false,
                    score: "+15", author: "Nreo",
                    contents: [.init(type: .plainText, text: "Thanks for the upload, great quality scans!")],
                    commentID: "0", commentDate: .now
                ),
                .init(
                    votedUp: true, votedDown: false, votable: true, editable: true,
                    score: "+42", author: "BaronArgyleSven",
                    contents: [.init(type: .plainText, text: "Agreed. The later pages look excellent.")],
                    commentID: "1", commentDate: .now
                )
            ]
        )
    }
}

#Preview("Initial") {
    previewCommentsView()
}

#Preview("Accessibility size") {
    previewCommentsView()
        .environment(\.dynamicTypeSize, .accessibility5)
}
