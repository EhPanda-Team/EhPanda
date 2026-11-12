import AppComponents
import ComposableArchitecture
import SwiftUI

/// A screen's moderation alert, scoped from its store, as an alert modifier takes it.
typealias CommentModerationAlertBinding = Binding<
    Store<AppAlertState<CommentModerationFeature.Alert>, CommentModerationFeature.Alert>?
>

/// The comment editor sheet. Post sends the presenting reducer's post intent, which either posts and closes the sheet
/// or, when the text matches the comment filter, keeps it open with the text as typed and raises the posting warning
/// (D-12, P-8). The warning is presented from inside the sheet, over the editor (UI-SPEC C-5).
struct PostCommentView: View {
    private let title: LocalizedStringResource
    @Binding private var content: String
    @Binding private var isFocused: Bool
    private let postingWarning: CommentModerationAlertBinding
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
        postingWarning: CommentModerationAlertBinding,
        postAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) {
        self.title = title
        _content = content
        _isFocused = isFocused
        self.postingWarning = postingWarning
        self.postAction = postAction
        self.cancelAction = cancelAction
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $content)
                .frame(maxHeight: .infinity, alignment: .top)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .focused($isTextEditorFocused)
                .accessibilityLabel(.accessibilityComment)
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
                .toolbarTitleDisplayMode(.inline)
                .navigationTitle(title)
                // Edit (`.cancel`) leaves the text as typed; the reducer gives the editor its focus back.
                .appAlert(postingWarning)
        }
        .synchronize($isFocused, $isTextEditorFocused)
    }
}
