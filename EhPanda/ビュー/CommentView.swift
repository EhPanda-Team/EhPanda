//
//  CommentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/02.
//

import SwiftUI

struct CommentView: View {
    @EnvironmentObject var store: Store
    
    let id: String
    var comments: [MangaComment] {
        store.appState.cachedList.items?[id]?.detail?.comments ?? []
    }
    
    var detailInfo: AppState.DetailInfo {
        store.appState.detailInfo
    }
    var detailInfoBinding: Binding<AppState.DetailInfo> {
        $store.appState.detailInfo
    }
    var isDraftCommentViewPresentedBinding: Binding<Bool> {
        detailInfoBinding.isDraftCommentViewPresented_BarItem
    }
    var commentContent: String {
        detailInfo.commentContent_BarItem
    }
    var commentContentBinding: Binding<String> {
        detailInfoBinding.commentContent_BarItem
    }
    
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
                Button(action: toggleDraftCommentViewPresented, label: {
                    Image(systemName: "square.and.pencil")
                    Text("コメントを書く")
                })
                .sheet(isPresented: isDraftCommentViewPresentedBinding) {
                    DraftCommentView(
                        content: commentContentBinding,
                        title: "コメントを書く",
                        postAction: draftCommentViewPost,
                        cancelAction: draftCommentViewCancel
                    )
                }
        )
    }
    
    
    func draftCommentViewPost() {
        if !commentContent.isEmpty {
            postComment()
            toggleDraftCommentViewPresented()
        }
    }
    func draftCommentViewCancel() {
        toggleDraftCommentViewPresented()
    }
    
    func postComment() {
        store.dispatch(.comment(id: id, content: commentContent))
        store.dispatch(.cleanCommentContent_BarItem)
    }
    
    func toggleDraftCommentViewPresented() {
        store.dispatch(.toggleDraftCommentViewPresented_BarItem)
    }
}

private struct CommentCell: View {
    @EnvironmentObject var store: Store
    @State var editCommentContent: String
    @State var isPresented = false
    
    let id: String
    var comment: MangaComment
    
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
            Text(comment.content)
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
