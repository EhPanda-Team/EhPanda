//
//  PostCommentView.swift
//  EhPanda
//

import SwiftUI

struct PostCommentView: View {
    private let title: String
    @Binding private var content: String
    @Binding private var isFocused: Bool
    private let postAction: () -> Void
    private let cancelAction: () -> Void
    private let onAppearAction: () -> Void

    @FocusState private var isTextEditorFocused: Bool

    init(
        title: String,
        content: Binding<String>,
        isFocused: Binding<Bool>,
        postAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void,
        onAppearAction: @escaping () -> Void
    ) {
        self.title = title
        _content = content
        _isFocused = isFocused
        self.postAction = postAction
        self.cancelAction = cancelAction
        self.onAppearAction = onAppearAction
    }

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $content)
                    .focused($isTextEditorFocused)
                    .padding()

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close, action: cancelAction)
                    } else {
                        Button(action: cancelAction) {
                            Text(L10n.Localizable.PostCommentView.Button.cancel)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm, action: postAction)
                            .disabled(content.isEmpty)
                    } else {
                        Button(action: postAction) {
                            Text(L10n.Localizable.PostCommentView.Button.post)
                        }
                        .disabled(content.isEmpty)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(title)
        }
        .synchronize($isFocused, $isTextEditorFocused)
        .onAppear(perform: onAppearAction)
    }
}
