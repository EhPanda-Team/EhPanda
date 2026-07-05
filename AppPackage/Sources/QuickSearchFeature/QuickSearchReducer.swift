import SwiftUI
import AppModels
import Sharing
import Resources
import ComposableArchitecture
import AppComponents

@Reducer
public struct QuickSearchReducer: Sendable {
    // Quick-search words are deliberate user content, so they are never auto-evicted. Instead the
    // list is bounded by a UI limit: the add button is disabled at this count (with a guard here as
    // a backstop). Capping keeps the persisted `@Shared(.quickSearchWords)` value small.
    public static let wordLimit = 1000
    // Which flavour of the word editor is pushed onto the stack; drives `.navigationDestination(item:)`.
    public enum WordEditKind: Hashable, Sendable {
        case new
        case edit
    }

    public enum Dialog: Equatable, Sendable {
        case confirmDelete(QuickSearchWord)
    }

    public enum FocusField: Sendable {
        case name
        case content
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var editKind: WordEditKind?
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var focusedField: FocusField?
        public var editingWord: QuickSearchWord = .empty
        public var listEditMode: EditMode = .inactive
        public var isListEditing: Bool {
            get { listEditMode == .active }
            set { listEditMode = newValue ? .active : .inactive }
        }

        @Shared(.quickSearchWords) public var quickSearchWords: [QuickSearchWord]

        public init() {}

        // The add button is disabled once this is true (see `wordLimit`).
        public var isAtWordLimit: Bool { quickSearchWords.count >= QuickSearchReducer.wordLimit }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<Dialog>)
        case deleteWordButtonTapped(QuickSearchWord)
        case newWordButtonTapped
        case editWordButtonTapped(QuickSearchWord)

        case toggleListEditing

        case appendWord
        case editWord
        case deleteWord(QuickSearchWord)
        case deleteWordWithOffsets(IndexSet)
        case moveWord(IndexSet, Int)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        CombineReducers {
            BindingReducer()

            Reduce { state, action in
                switch action {
                case .binding:
                    return .none

                case .newWordButtonTapped:
                    state.editingWord = .empty
                    state.editKind = .new
                    return .none

                case .editWordButtonTapped(let word):
                    state.editingWord = word
                    state.editKind = .edit
                    return .none

                case .deleteWordButtonTapped(let word):
                    state.confirmationDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                        TextState(localized: .RLocalizable.delete)
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmDelete(word)) {
                            TextState(localized: .RLocalizable.delete)
                        }
                        ButtonState(role: .cancel) {
                            TextState(localized: .RLocalizable.cancel)
                        }
                    } message: {
                        TextState(localized: .RLocalizable.deleteDescription)
                    }
                    return .none

                case .confirmationDialog(.presented(.confirmDelete(let word))):
                    return .send(.deleteWord(word))

                case .confirmationDialog:
                    return .none

                case .toggleListEditing:
                    state.isListEditing.toggle()
                    return .none

                case .appendWord:
                    guard !state.isAtWordLimit else { return .none }
                    let word = state.editingWord
                    state.$quickSearchWords.withLock { $0.append(word) }
                    state.editKind = nil
                    return .none

                case .editWord:
                    if let index = state.quickSearchWords.firstIndex(where: { $0.id == state.editingWord.id }) {
                        let word = state.editingWord
                        state.$quickSearchWords.withLock { $0[index] = word }
                    }
                    state.editKind = nil
                    return .none

                case .deleteWord(let word):
                    state.$quickSearchWords.withLock { $0.removeAll { $0 == word } }
                    return .none

                case .deleteWordWithOffsets(let offsets):
                    state.$quickSearchWords.withLock { $0.remove(atOffsets: offsets) }
                    return .none

                case .moveWord(let source, let destination):
                    state.$quickSearchWords.withLock { $0.move(fromOffsets: source, toOffset: destination) }
                    return .none
                }
            }
        }
        // Dismissing the editor (back-swipe or a confirmed save) resets the scratch word and focus.
        .onChange(of: \.editKind) { _, state in
            if state.editKind == nil {
                state.focusedField = nil
                state.editingWord = .empty
            }
            return .none
        }
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}
