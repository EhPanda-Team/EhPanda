import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import Kingfisher
import Resources
import SFSafeSymbolsExt
import SwiftUI
import SystemNotification

struct CommentsView: View {
    @SharedReader(.didLogin) private var didLogin: Bool
    @Bindable private var store: StoreOf<CommentsReducer>
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
                CommentCell(
                    gid: gid, comment: comment,
                    linkAction: { store.send(.handleCommentLink($0)) }
                )
                .accessibilityIdentifier("comment_cell_" + comment.commentID)
                .animation(.default) {
                    $0.opacity(
                        comment.commentID == store.scrollCommentID
                            ? store.scrollRowOpacity : 1
                    )
                }
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
            .accessibilityIdentifier("comments_view")
            // View-local scrolling needs the `proxy`, so it stays in the view. `initial: true` gives
            // the first-render fire the former `onAppear` provided, for the deep-linked comment id
            // the screen is constructed with; later changes are no-ops because the id only clears.
            .onChange(of: store.scrollCommentID, initial: true) {
                if let scrollCommentID = store.scrollCommentID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        withAnimation {
                            proxy.scrollTo(scrollCommentID, anchor: .top)
                        }
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
                postAction: {
                    if hasCommentID {
                        store.send(.postComment(galleryURL: galleryURL, commentID: commentID.wrappedValue))
                    } else {
                        store.send(.postComment(galleryURL: galleryURL))
                    }
                    store.send(.destination(.dismiss))
                },
                cancelAction: { store.send(.destination(.dismiss)) }
            )
            .privacyMask()
        }
        .toast($store.scope(\.$toast, action: \.toast))
        .animation(.default, value: store.scrollRowOpacity)
        .toolbar(content: toolbar)
        .navigationTitle(.comments)
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
        private let linkAction: (URL) -> Void

        init(gid: String, comment: GalleryComment, linkAction: @escaping (URL) -> Void) {
            self.gid = gid
            self.comment = comment
            self.linkAction = linkAction
        }

        /// The row is one accessibility element: a comment is read as a unit — author, vote,
        /// score, date, then its runs in order — instead of as one stop per run. The vote travels
        /// as the element's value, never as text (the thumb glyph is hidden below), and only while
        /// a vote exists. The link runs are reached by tap gestures VoiceOver and Voice Control
        /// cannot see, so every link the comment carries is also a named action on the element;
        /// the tap gestures stay for sighted users. The swipe actions need nothing here: iOS
        /// surfaces them on the row's element already (`CONTEXTMENU=not-exposed` read, 16-CONTRAST-AUDIT).
        var body: some View {
            let links = links
            VStack(alignment: .leading) {
                authorAndMetadata

                ForEach(comment.contents) { content in
                    switch content.type {
                    case .plainText:
                        if let text = content.text {
                            LinkedText(text: text, action: linkAction)
                        }
                    case .linkedText:
                        if let text = content.text, let link = content.link {
                            Text(text).foregroundStyle(.tint)
                                .onTapGesture { linkAction(link) }
                        }
                    case .singleLink:
                        if let link = content.link {
                            Text(link.absoluteString).foregroundStyle(.tint)
                                .onTapGesture { linkAction(link) }
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
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityValue(.accessibilityVotedUp, isEnabled: comment.votedUp)
            .accessibilityValue(.accessibilityVotedDown, isEnabled: comment.votedDown)
            .accessibilityActions {
                ForEach(links, id: \.self) { link in
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
                content.text.map({ LinkedText.linkMatches(in: $0).compactMap(\.url) }) ?? []
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
        private var authorAndMetadata: some View {
            ViewThatFits(in: .horizontal) {
                HStack {
                    authorText

                    Spacer(minLength: 0)

                    metadata
                }
                .lineLimit(1)

                VStack(alignment: .leading) {
                    authorText
                    metadata
                }
            }
        }

        private var authorText: some View {
            Text(comment.author)
                .font(.subheadline.bold())
        }

        private var metadata: some View {
            HStack {
                Image(systemSymbol: comment.votedUp ? .handThumbsupFill : .handThumbsdownFill)
                    .visible(comment.votedUp || comment.votedDown)
                    .accessibilityHidden(true)

                comment.score.map(Text.init)
                Text(comment.formattedDateString)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        @ViewBuilder private func generateWebImages(
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
        @ViewBuilder func imageContainer(
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
