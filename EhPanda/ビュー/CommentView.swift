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
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                ForEach(comments) { comment in
                    CommentCell(id: id, comment: comment)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct CommentCell: View {
    @EnvironmentObject var store: Store
    
    let id: String
    var comment: MangaComment
    
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
        .contextMenu {
            if !comment.isPublisher {
                Button(action: voteUp, label: {
                    Text("賛成")
                    if comment.votedUp {
                        Image(systemName: "hand.thumbsup.fill")
                    } else {
                        Image(systemName: "hand.thumbsup")
                    }
                })
                Button(action: voteDown, label: {
                    Text("反対")
                    if comment.votedDown {
                        Image(systemName: "hand.thumbsdown.fill")
                    } else {
                        Image(systemName: "hand.thumbsdown")
                    }
                })
            }
        }
    }
    
    func voteUp() {
        store.dispatch(.voteComment(id: id, commentID: comment.commentID, vote: 1))
    }
    func voteDown() {
        store.dispatch(.voteComment(id: id, commentID: comment.commentID, vote: -1))
    }
}
