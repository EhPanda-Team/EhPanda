public import AppComponents
public import ComposableArchitecture

/// Comment moderation for one screen (UGC-18-01): the posting warning (D-12). `CommentsReducer` and
/// `DetailReducer` each scope one in, so posting behaves the same in the comments list and in Detail; the views
/// only send these actions and read this state.
///
/// Nothing here sends an analytics signal (D-02): no comment text leaves the device this way.
@Reducer
public struct CommentModerationFeature: Sendable {
    /// The buttons of the screen's moderation alerts.
    @CasePathable
    public enum Alert: Equatable, Sendable {
        /// Posting warning: back to the editor with the text as typed (UI-SPEC C-5, the cancel-role default).
        case edit
        /// Posting warning: send the comment anyway.
        case postAnyway
    }

    /// What the host screen does with a moderation decision; it owns the editor and the sheets.
    @CasePathable
    public enum Delegate: Equatable, Sendable {
        /// Send the comment in the editor, then close the editor (the warning was overridden).
        case post
        /// Give the editor its focus back; the editor and its text stay as they are.
        case resumeEditing
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var alert: AppAlertState<Alert>?

        public init() {}

        /// The posting warning (C-5); the screen presents it instead of sending when the filter matches.
        mutating func presentPostingWarning() {
            alert = AppAlertState {
                TextState(localized: .commentFilterTitle)
            } actions: {
                ButtonState(role: .cancel, action: .edit) {
                    TextState(localized: .commentFilterEdit)
                }
                ButtonState(action: .postAnyway) {
                    TextState(localized: .commentFilterPostAnyway)
                }
            } message: {
                TextState(localized: .commentFilterBody)
            }
        }
    }

    public enum Action: Equatable, Sendable {
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .alert(.presented(.edit)):
                return .send(.delegate(.resumeEditing))

            case .alert(.presented(.postAnyway)):
                return .send(.delegate(.post))

            case .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

// MARK: - Posting filter

/// The posting filter's term list, a dependency so tests can match against a list of their own instead of the
/// bundled one.
enum CommentFilterTermsKey: DependencyKey {
    static let liveValue = CommentFilterTerms.bundled
    static let testValue = CommentFilterTerms.bundled
}

extension DependencyValues {
    var commentFilterTerms: CommentFilterTerms {
        get { self[CommentFilterTermsKey.self] }
        set { self[CommentFilterTermsKey.self] = newValue }
    }
}
