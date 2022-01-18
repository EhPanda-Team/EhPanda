//
//  DraftCommentView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/03.
//

import SwiftUI

struct DraftCommentView: View {
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
                TextEditor(text: $content).focused($isTextEditorFocused).padding()
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post", action: postAction).disabled(content.isEmpty)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(title.localized)
        }
        .synchronize($isFocused, $isTextEditorFocused)
        .onAppear(perform: onAppearAction)
    }
}
