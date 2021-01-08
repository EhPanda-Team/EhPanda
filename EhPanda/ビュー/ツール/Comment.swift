//
//  Comment.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/03.
//

import SwiftUI

struct CommentButton: View {
    let action: () -> ()
    
    var body: some View {
        Button(action: action) {
            Spacer()
            Image(systemName: "square.and.pencil")
            Text("コメントを書く")
                .fontWeight(.bold)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct DraftCommentView: View {
    @Binding var content: String
    
    let title: String
    let postAction: () -> ()
    let cancelAction: () -> ()
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $content)
                    .padding()
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .navigationBarTitle(title.lString(), displayMode: .inline)
                    .navigationBarItems(
                        leading:
                            Button(action: cancelAction) {
                                Text("キャンセル")
                                    .fontWeight(.regular)
                            },
                        trailing:
                            Button(action: postAction) {
                                Text("投稿")
                                    .foregroundColor(content.isEmpty ? .gray : .blue)
                            }
                    )
                Spacer()
            }
        }
    }
}
