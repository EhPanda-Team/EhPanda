//
//  CommentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/02.
//

import SwiftUI

struct CommentView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    
    let id: String
    var comments: [MangaComment] {
        store.appState.cachedList.items?[id]?.detail?.comments ?? []
    }
    var accentColor: Color? {
        store.appState.settings.setting?.accentColor
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
        ScrollView(showsIndicators: false) {
            VStack {
                ForEach(comments) { comment in
                    CommentCell(
                        editCommentContent: comment.content,
                        id: id, comment: comment
                    )
                }
            }
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
                            postAction: draftCommentViewPost,
                            cancelAction: draftCommentViewCancel
                        )
                        .accentColor(accentColor)
                        .preferredColorScheme(colorScheme)
                        .blur(radius: environment.blurRadius)
                        .allowsHitTesting(environment.isAppUnlocked)
                    }
                }
        )
    }
    
    
    func draftCommentViewPost() {
        if !commentContent.isEmpty {
            postComment()
            toggleNil()
        }
    }
    func draftCommentViewCancel() {
        toggleNil()
    }
    
    func postComment() {
        store.dispatch(.comment(id: id, content: commentContent))
        store.dispatch(.cleanCommentViewCommentContent)
    }
    
    func toggleDraft() {
        store.dispatch(.toggleCommentViewSheetState(state: .comment))
    }
    func toggleNil() {
        store.dispatch(.toggleCommentViewSheetNil)
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
            LinkedText(comment.content, onLinkTap)
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
    
    func onLinkTap(_ link: URL) {
        
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
