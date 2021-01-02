//
//  CommentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/02.
//

import SwiftUI

struct CommentView: View {
    let comments: [MangaComment]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                ForEach(comments) { comment in
                    CommentCell(comment: comment)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct CommentCell: View {
    let comment: MangaComment
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(comment.author)
                    .fontWeight(.bold)
                    .font(.subheadline)
                Spacer()
                Text(comment.commentTime)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Text(comment.content)
                .padding(.top, 1)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}
