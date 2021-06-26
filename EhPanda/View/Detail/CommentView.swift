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

    @State private var editCommentContent = ""
    @State private var editCommentID = ""
    @State private var commentJumpID: String?
    @State private var isNavLinkActive = false

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    private let gid: String
    private let depth: Int

    init(gid: String, depth: Int) {
        self.gid = gid
        self.depth = depth
    }

    // MARK: CommentView
    var body: some View {
        ZStack {
            NavigationLink(
                "",
                destination: DetailView(
                    gid: commentJumpID ?? gid,
                    depth: depth + 1
                ),
                isActive: $isNavLinkActive
            )
            List {
                ForEach(comments) { comment in
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
            }
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: toggleNewComment, label: {
                    Image(systemName: "square.and.pencil")
                })
            }
        }
        .sheet(item: environmentBinding.commentViewSheetState) { item in
            Group {
                switch item {
                case .newComment:
                    DraftCommentView(
                        content: commentContentBinding,
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
            of: environment.mangaItemReverseID,
            perform: onJumpIDChange
        )
        .onChange(
            of: environment.mangaItemReverseLoading,
            perform: onJumpDetailFetchFinish
        )
    }
}

// MARK: Private Extension
private extension CommentView {
    var comments: [MangaComment] {
        store.appState.cachedList.items?[gid]?.detail?.comments ?? []
    }

    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var commentInfoBinding: Binding<AppState.CommentInfo> {
        $store.appState.commentInfo
    }
    var commentContent: String {
        commentInfo.commentContent
    }
    var commentContentBinding: Binding<String> {
        commentInfoBinding.commentContent
    }

    func onAppear() {
        replaceMangaCommentJumpID(gid: nil)
    }
    func onJumpDetailFetchFinish(value: Bool) {
        if !value {
            dismissHUD()
        }
    }
    func onLinkTap(link: URL) {
        if isValidDetailURL(url: link) {
            let gid = link.pathComponents[2]
            if cachedList.hasCached(gid: gid) {
                replaceMangaCommentJumpID(gid: gid)
            } else {
                store.dispatch(
                    .fetchMangaItemReverse(
                        detailURL: link.absoluteString
                    )
                )
                showHUD()
            }
        } else {
            UIApplication.shared.open(link, options: [:], completionHandler: nil)
        }
    }
    func onJumpIDChange(value: String?) {
        if value != nil {
            commentJumpID = value
            isNavLinkActive = true

            replaceMangaCommentJumpID(gid: nil)
        }
    }

    func showHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .loading,
            title: "Loading...".localized()
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

    func voteUp(comment: MangaComment) {
        store.dispatch(
            .voteComment(
                gid: gid, commentID: comment.commentID,
                vote: 1
            )
        )
    }
    func voteDown(comment: MangaComment) {
        store.dispatch(
            .voteComment(
                gid: gid, commentID: comment.commentID,
                vote: -1
            )
        )
    }
    func edit(comment: MangaComment) {
        editCommentID = comment.commentID
        editCommentContent = trim(contents: comment.contents)
        store.dispatch(.toggleCommentViewSheet(state: .editComment))
    }
    func postNewComment() {
        store.dispatch(.comment(gid: gid, content: commentContent))
        store.dispatch(.clearCommentViewCommentContent)
        toggleCommentViewSheetNil()
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
    func replaceMangaCommentJumpID(gid: String?) {
        store.dispatch(.replaceMangaCommentJumpID(gid: gid))
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
    private var comment: MangaComment
    private let linkAction: (URL) -> Void

    init(
        gid: String,
        comment: MangaComment,
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
            .padding(.top, 1)
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
                        .loadImmediately()
                        .resizable()
                        .scaledToFit()
                        .frame(width: screenW / 4)
                        .onTapGesture {
                            linkAction(link.safeURL())
                        }
                    KFImage(URL(string: secondImgURL))
                        .loadImmediately()
                        .resizable()
                        .scaledToFit()
                        .frame(width: screenW / 4)
                        .onTapGesture {
                            linkAction(secondLink.safeURL())
                        }
                } else {
                    KFImage(URL(string: imgURL))
                        .loadImmediately()
                        .resizable()
                        .scaledToFit()
                        .frame(width: screenW / 4)
                    KFImage(URL(string: secondImgURL))
                        .loadImmediately()
                        .resizable()
                        .scaledToFit()
                        .frame(width: screenW / 4)
                }
            }
        }
        // Single
        else if let imgURL = imgURL {
            if let link = link {
                KFImage(URL(string: imgURL))
                    .loadImmediately()
                    .resizable()
                    .scaledToFit()
                    .frame(width: screenW / 2)
                    .onTapGesture {
                        linkAction(link.safeURL())
                    }
            } else {
                KFImage(URL(string: imgURL))
                    .loadImmediately()
                    .resizable()
                    .scaledToFit()
                    .frame(width: screenW / 2)
            }
        }
    }
}

// MARK: Definition
enum CommentViewSheetState: Identifiable {
    var id: Int { hashValue }

    case newComment
    case editComment
}
