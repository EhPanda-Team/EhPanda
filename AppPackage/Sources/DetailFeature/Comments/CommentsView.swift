import SwiftUI
import AppModels
import Resources
import Kingfisher
import ComposableArchitecture
import AppTools
import SystemNotification
import AppComponents
import SFSafeSymbolsExt
import CookieClient

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
                .opacity(
                    comment.commentID == store.scrollCommentID
                        ? store.scrollRowOpacity : 1
                )
                .swipeActions(edge: .leading) {
                    if comment.votable {
                        Button {
                            store.send(.voteComment(gid, token, apiKey, comment.commentID, -1))
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
                            store.send(.voteComment(gid, token, apiKey, comment.commentID, 1))
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
            .onAppear {
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
                        store.send(.postComment(galleryURL, commentID.wrappedValue))
                    } else {
                        store.send(.postComment(galleryURL))
                    }
                    store.send(.destination(.dismiss))
                },
                cancelAction: { store.send(.destination(.dismiss)) },
                onAppearAction: { store.send(.onPostCommentAppear) }
            )
            .privacyMask()
        }
        .toast($store.scope(\.$toast, action: \.toast))
        .animation(.default, value: store.scrollRowOpacity)
        .onAppear {
            store.send(.onAppear)
        }
        .toolbar(content: toolbar)
        .navigationTitle(.comments)
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
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

        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text(comment.author)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Group {
                        Image(systemSymbol: comment.votedUp ? .handThumbsupFill : .handThumbsdownFill)
                            .opacity(comment.votedUp || comment.votedDown ? 1 : 0)

                        comment.score.map(Text.init)
                        Text(comment.formattedDateString)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .minimumScaleFactor(0.75)
                .lineLimit(1)

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
                .commentDefaultModifier().scaledToFit()
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

#Preview("Initial") {
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
                    score: "+42", author: "Chihchy",
                    contents: [.init(type: .plainText, text: "Agreed. The later pages look excellent.")],
                    commentID: "1", commentDate: .now
                )
            ]
        )
    }
}
