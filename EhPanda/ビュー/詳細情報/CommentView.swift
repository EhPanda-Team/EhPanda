//
//  CommentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/02.
//

import SwiftUI
import TTProgressHUD

struct CommentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    
    @State var commentJumpID: String?
    @State var isNavActive = false
    
    @State var hudVisible = false
    @State var hudConfig = TTProgressHUDConfig(
        hapticsEnabled: false
    )
    
    let id: String
    let depth: Int
    var comments: [MangaComment] {
        store.appState.cachedList.items?[id]?.detail?.comments ?? []
    }
    var accentColor: Color? {
        store.appState.settings.setting?.accentColor
    }
    
    var cachedList: AppState.CachedList {
        store.appState.cachedList
    }
    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }
    var environment: AppState.Environment {
        store.appState.environment
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var commentInfo: AppState.CommentInfo {
        store.appState.commentInfo
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
    
    // MARK: CommentView本体
    var body: some View {
        ZStack {
            NavigationLink(
                "",
                destination: DetailView(
                    id: commentJumpID ?? id,
                    depth: depth + 1
                ),
                isActive: $isNavActive
            )
            ScrollView(showsIndicators: false) {
                VStack {
                    ForEach(comments) { comment in
                        CommentCell(
                            editCommentContent: comment.content,
                            id: id,
                            comment: comment,
                            linkAction: onLinkTap
                        )
                    }
                }
            }
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .padding(.horizontal)
        .navigationBarItems(
            trailing:
                Button(action: toggleDraft, label: {
                    Image(systemName: "square.and.pencil")
                    Text("コメントを書く")
                })
                .sheet(item: environmentBinding.commentViewSheetState) { item in
                    switch item {
                    case .comment:
                        DraftCommentView(
                            content: commentContentBinding,
                            title: "コメントを書く",
                            postAction: onDraftCommentViewPost,
                            cancelAction: onDraftCommentViewCancel
                        )
                        .accentColor(accentColor)
                        .preferredColorScheme(colorScheme)
                        .blur(radius: environment.blurRadius)
                        .allowsHitTesting(environment.isAppUnlocked)
                    }
                }
        )
        .onAppear(perform: onAppear)
        .onChange(
            of: detailInfo.mangaItemReverseID,
            perform: onJumpIDChange
        )
        .onChange(
            of: detailInfo.mangaItemReverseLoading,
            perform: onFetchFinished
        )
        
    }
    
    func onAppear() {
        replaceCommentJumpIDNil()
    }
    func onFetchFinished<E: Equatable>(_ value: E) {
        if let loading = value as? Bool,
           loading == false
        {
            dismissHUD()
            onJumpIDChange(detailInfo.mangaItemReverseID)
        }
    }
    func onLinkTap(_ link: URL) {
        if isValidDetailURL(url: link) && exx {
            if cachedList.hasCached(url: link) {
                replaceMangaCommentJumpID(fromID: id, toID: link.pathComponents[2])
            } else {
                fetchMangaWithDetailURL(link.absoluteString)
                showHUD()
            }
        } else {
            UIApplication.shared.open(link, options: [:], completionHandler: nil)
        }
    }
    func onJumpIDChange(_ value: String?) {
        if value != nil {
            commentJumpID = value
            isNavActive = true
        }
    }
    func onDraftCommentViewPost() {
        if !commentContent.isEmpty {
            postComment()
            toggleCommentViewSheetNil()
        }
    }
    func onDraftCommentViewCancel() {
        toggleCommentViewSheetNil()
    }
    
    func showHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .Loading,
            title: "読み込み中...".lString()
        )
        hudVisible = true
    }
    func dismissHUD() {
        hudVisible = false
        hudConfig = TTProgressHUDConfig(
            hapticsEnabled: false
        )
    }
    
    func postComment() {
        store.dispatch(.comment(id: id, content: commentContent))
        store.dispatch(.cleanCommentViewCommentContent)
    }
    func fetchMangaWithDetailURL(_ detailURL: String) {
        store.dispatch(.fetchMangaItemReverse(id: id, detailURL: detailURL))
    }
    func replaceMangaCommentJumpID(fromID: String, toID: String) {
        store.dispatch(.replaceMangaCommentJumpID(id: toID))
    }
    
    func toggleDraft() {
        store.dispatch(.toggleCommentViewSheetState(state: .comment))
    }
    func toggleCommentViewSheetNil() {
        store.dispatch(.toggleCommentViewSheetNil)
    }
    func replaceCommentJumpIDNil() {
        store.dispatch(.replaceMangaCommentJumpID(id: nil))
    }
}

// MARK: CommentCell
private struct CommentCell: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    @State var editCommentContent: String
    @State var isPresented = false
    
    let id: String
    var comment: MangaComment
    let linkAction: (URL) -> ()
    var accentColor: Color? {
        store.appState.settings.setting?.accentColor
    }
    
    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(comment.author)
                    .fontWeight(.bold)
                    .font(.subheadline)
                Spacer()
                Group {
                    if comment.votedUp {
                        Image(systemName: "hand.thumbsup.fill")
                    } else if comment.votedDown {
                        Image(systemName: "hand.thumbsdown.fill")
                    }
                    if let score = comment.score {
                        Text(score)
                    }
                    Text(comment.commentTime)
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            LinkedText(comment.content, linkAction)
                .padding(.top, 1)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .contentShape(
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous)
        )
        .sheet(isPresented: $isPresented) {
            DraftCommentView(
                content: $editCommentContent,
                title: "コメントを編集",
                postAction: draftCommentViewPost,
                cancelAction: draftCommentViewCancel
            )
            .accentColor(accentColor)
            .preferredColorScheme(colorScheme)
        }
        .contextMenu {
            if comment.votable {
                Button(action: voteUp) {
                    Text("賛成")
                    if comment.votedUp {
                        Image(systemName: "hand.thumbsup.fill")
                    } else {
                        Image(systemName: "hand.thumbsup")
                    }
                }
                Button(action: voteDown) {
                    Text("反対")
                    if comment.votedDown {
                        Image(systemName: "hand.thumbsdown.fill")
                    } else {
                        Image(systemName: "hand.thumbsdown")
                    }
                }
            }
            if comment.editable {
                Button(action: togglePresented) {
                    Text("編集")
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }
    
    func draftCommentViewPost() {
        if !editCommentContent.isEmpty {
            editComment()
            togglePresented()
        }
    }
    func draftCommentViewCancel() {
        togglePresented()
    }
    
    func voteUp() {
        store.dispatch(.voteComment(id: id, commentID: comment.commentID, vote: 1))
    }
    func voteDown() {
        store.dispatch(.voteComment(id: id, commentID: comment.commentID, vote: -1))
    }
    func editComment() {
        store.dispatch(.editComment(id: id, commentID: comment.commentID, content: editCommentContent))
    }
    func togglePresented() {
        isPresented.toggle()
    }
}

// MARK: 定義
enum CommentViewSheetState: Identifiable {
    var id: Int { hashValue }
    
    case comment
}
