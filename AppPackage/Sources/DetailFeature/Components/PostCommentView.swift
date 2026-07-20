import AppComponents
import SwiftUI

struct PostCommentView: View {
    private let title: LocalizedStringResource
    @Binding private var content: String
    @Binding private var isFocused: Bool
    private let postAction: () -> Void
    private let cancelAction: () -> Void

    @FocusState private var isTextEditorFocused: Bool

    // Focus is driven by the `isFocused` binding, which the presenting reducer raises shortly after
    // it sets this sheet's destination — the editor no longer asks for focus from a lifecycle
    // callback of its own.
    init(
        title: LocalizedStringResource,
        content: Binding<String>,
        isFocused: Binding<Bool>,
        postAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) {
        self.title = title
        _content = content
        _isFocused = isFocused
        self.postAction = postAction
        self.cancelAction = cancelAction
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $content)
                .frame(maxHeight: .infinity, alignment: .top)
                .focused($isTextEditorFocused)
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close, action: cancelAction)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm, action: postAction)
                            .disabled(content.isEmpty)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(title)
        }
        .synchronize($isFocused, $isTextEditorFocused)
    }
}
