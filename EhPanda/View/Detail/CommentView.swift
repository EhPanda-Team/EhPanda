//
//  CommentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/02.
//

import SwiftUI
import Kingfisher
import TTProgressHUD

struct CommentView: View, StoreAccessor {
    @EnvironmentObject var store: Store

    @State private var commentContent = ""
    @State private var editCommentContent = ""
    @State private var editCommentID = ""
    @State private var commentJumpID: String?
    @State private var isNavLinkActive = false

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    private let gid: String
    private let comments: [GalleryComment]

    init(gid: String, comments: [GalleryComment]) {
        self.gid = gid
        self.comments = comments
    }

    // MARK: CommentView
    var body: some View {
        ZStack {
            List(comments) { comment in
                CommentCell(
                    gid: gid,
                    comment: comment,
                    linkAction: onLinkTap
                )
                .swipeActions(edge: .leading) {
                    if comment.votable {
                        Button {
                            voteDown(comment: comment)
                        } label: {
                            Image(systemName: "hand.thumbsdown")
                        }
                        .tint(.red)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if comment.votable {
                        Button {
                            voteUp(comment: comment)
                        } label: {
                            Image(systemName: "hand.thumbsup")
                        }
                        .tint(.green)
                    }
                    if comment.editable {
                        Button {
                            edit(comment: comment)
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .background {
            NavigationLink(
                "",
                destination: DetailView(
                    gid: commentJumpID ?? gid
                ),
                isActive: $isNavLinkActive
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleNewComment, label: {
                    Image(systemName: "square.and.pencil")
                })
                .disabled(!didLogin)
            }
        }
        .sheet(item: environmentBinding.commentViewSheetState) { item in
            Group {
                switch item {
                case .newComment:
                    DraftCommentView(
                        content: $commentContent,
                        title: "Post Comment",
                        postAction: postNewComment,
                        cancelAction: toggleCommentViewSheetNil
                    )
                case .editComment:
                    DraftCommentView(
                        content: $editCommentContent,
                        title: "Edit Comment",
                        postAction: postEditComment,
                        cancelAction: toggleCommentViewSheetNil
                    )
                }
            }
            .accentColor(accentColor)
            .blur(radius: environment.blurRadius)
            .allowsHitTesting(environment.isAppUnlocked)
        }
        .onAppear(perform: onAppear)
        .onChange(
            of: environment.galleryItemReverseID,
            perform: onJumpIDChange
        )
        .onChange(
            of: environment.galleryItemReverseLoading,
            perform: onJumpDetailFetchFinish
        )
    }
}

// MARK: Private Extension
private extension CommentView {
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }

    func onAppear() {
        replaceGalleryCommentJumpID(gid: nil)
    }
    func onJumpDetailFetchFinish(value: Bool) {
        if !value {
            dismissHUD()
        }
    }
    func onLinkTap(link: URL) {
        handleIncomingURL(link) { shouldParseGalleryURL, incomingURL, pageIndex, commentID in
            guard let incomingURL = incomingURL else { return }

            let gid = parseGID(url: incomingURL, isGalleryURL: shouldParseGalleryURL)
            store.dispatch(.updatePendingJumpInfos(
                gid: gid, pageIndex: pageIndex, commentID: commentID
            ))

            if PersistenceController.galleryCached(gid: gid) {
                replaceGalleryCommentJumpID(gid: gid)
            } else {
                store.dispatch(.fetchGalleryItemReverse(
                    url: incomingURL.absoluteString,
                    shouldParseGalleryURL: shouldParseGalleryURL
                ))
                showHUD()
            }
        }
    }
    func onJumpIDChange(value: String?) {
        if value != nil {
            commentJumpID = value
            isNavLinkActive = true

            replaceGalleryCommentJumpID(gid: nil)
        }
    }

    func showHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .loading,
            title: "Loading...".localized
        )
        hudVisible = true
    }
    func dismissHUD() {
        hudVisible = false
        hudConfig = TTProgressHUDConfig()
    }

    func trim(contents: [CommentContent]) -> String {
        contents
            .filter {
                [.plainText, .linkedText, .singleLink]
                    .contains($0.type)
            }
            .compactMap {
                if $0.type == .singleLink {
                    return $0.link
                } else {
                    return $0.text
                }
            }
            .joined()
    }

    func voteUp(comment: GalleryComment) {
        store.dispatch(
            .voteComment(
                gid: gid, commentID: comment.commentID,
                vote: 1
            )
        )
    }
    func voteDown(comment: GalleryComment) {
        store.dispatch(
            .voteComment(
                gid: gid, commentID: comment.commentID,
                vote: -1
            )
        )
    }
    func edit(comment: GalleryComment) {
        editCommentID = comment.commentID
        editCommentContent = trim(contents: comment.contents)
        store.dispatch(.toggleCommentViewSheet(state: .editComment))
    }
    func postNewComment() {
        store.dispatch(.comment(gid: gid, content: commentContent))
        toggleCommentViewSheetNil()
        commentContent = ""
    }
    func postEditComment() {
        store.dispatch(
            .editComment(
                gid: gid,
                commentID: editCommentID,
                content: editCommentContent
            )
        )
        editCommentID = ""
        editCommentContent = ""
        toggleCommentViewSheetNil()
    }
    func replaceGalleryCommentJumpID(gid: String?) {
        store.dispatch(.replaceGalleryCommentJumpID(gid: gid))
    }

    func toggleNewComment() {
        store.dispatch(.toggleCommentViewSheet(state: .newComment))
    }
    func toggleCommentViewSheetNil() {
        store.dispatch(.toggleCommentViewSheet(state: nil))
    }
}

// MARK: CommentCell
private struct CommentCell: View {
    private let gid: String
    private var comment: GalleryComment
    private let linkAction: (URL) -> Void

    init(
        gid: String,
        comment: GalleryComment,
        linkAction: @escaping (URL) -> Void
    ) {
        self.gid = gid
        self.comment = comment
        self.linkAction = linkAction
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(comment.author)
                    .fontWeight(.bold)
                    .font(.subheadline)
                Spacer()
                Group {
                    ZStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .opacity(comment.votedUp ? 1 : 0)
                        Image(systemName: "hand.thumbsdown.fill")
                            .opacity(comment.votedDown ? 1 : 0)
                    }
                    Text(comment.score ?? "")
                    Text(comment.formattedDateString)
                        .lineLimit(1)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            ForEach(comment.contents) { content in
                switch content.type {
                case .plainText:
                    if let text = content.text {
                        LinkedText(text: text, action: linkAction)
                    }
                case .linkedText:
                    if let text = content.text,
                       let link = content.link
                    {
                        Text(text)
                            .foregroundStyle(.tint)
                            .onTapGesture {
                                linkAction(link.safeURL())
                            }
                    }
                case .singleLink:
                    if let link = content.link {
                        Text(link)
                            .foregroundStyle(.tint)
                            .onTapGesture {
                                linkAction(link.safeURL())
                            }
                    }
                case .singleImg, .doubleImg, .linkedImg, .doubleLinkedImg:
                    generateWebImages(
                        imgURL: content.imgURL,
                        secondImgURL: content.secondImgURL,
                        link: content.link,
                        secondLink: content.secondLink
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }

    @ViewBuilder
    private func generateWebImages(
        imgURL: String?,
        secondImgURL: String?,
        link: String?,
        secondLink: String?
    ) -> some View {
        // Double
        if let imgURL = imgURL,
           let secondImgURL = secondImgURL
        {
            HStack(spacing: 0) {
                if let link = link,
                   let secondLink = secondLink
                {
                    KFImage(URL(string: imgURL))
                        .commentDefaultModifier()
                        .scaledToFit()
                        .frame(width: windowW / 4)
                        .onTapGesture {
                            linkAction(link.safeURL())
                        }
                    KFImage(URL(string: secondImgURL))
                        .commentDefaultModifier()
                        .scaledToFit()
                        .frame(width: windowW / 4)
                        .onTapGesture {
                            linkAction(secondLink.safeURL())
                        }
                } else {
                    KFImage(URL(string: imgURL))
                        .commentDefaultModifier()
                        .scaledToFit()
                        .frame(width: windowW / 4)
                    KFImage(URL(string: secondImgURL))
                        .commentDefaultModifier()
                        .scaledToFit()
                        .frame(width: windowW / 4)
                }
            }
        }
        // Single
        else if let imgURL = imgURL {
            if let link = link {
                KFImage(URL(string: imgURL))
                    .commentDefaultModifier()
                    .scaledToFit()
                    .frame(width: windowW / 2)
                    .onTapGesture {
                        linkAction(link.safeURL())
                    }
            } else {
                KFImage(URL(string: imgURL))
                    .commentDefaultModifier()
                    .scaledToFit()
                    .frame(width: windowW / 2)
            }
        }
    }
}

private extension KFImage {
    func commentDefaultModifier() -> KFImage {
        defaultModifier()
        .placeholder {
            Placeholder(
                style: .activity(ratio: 1)
            )
        }
    }
}

// MARK: Definition
enum CommentViewSheetState: Identifiable {
    var id: Int { hashValue }

    case newComment
    case editComment
}
