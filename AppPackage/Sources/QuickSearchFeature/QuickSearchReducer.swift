import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import DatabaseClient

@Reducer
public struct QuickSearchReducer: Sendable {
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

    private enum CancelID {
        case fetchQuickSearchWords
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

        public var loadingState: LoadingState = .idle
        public var quickSearchWords = [QuickSearchWord]()

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<Dialog>)
        case deleteWordButtonTapped(QuickSearchWord)
        case newWordButtonTapped
        case editWordButtonTapped(QuickSearchWord)

        case syncQuickSearchWords

        case toggleListEditing

        case appendWord
        case editWord
        case deleteWord(QuickSearchWord)
        case deleteWordWithOffsets(IndexSet)
        case moveWord(IndexSet, Int)

        case fetchQuickSearchWords
        case fetchQuickSearchWordsDone([QuickSearchWord])
    }

    @Dependency(\.databaseClient) private var databaseClient

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
                    state.confirmationDialog = ConfirmationDialogState {
                        TextState("")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmDelete(word)) {
                            TextState(L10n.Localizable.ConfirmationDialog.Button.delete)
                        }
                        ButtonState(role: .cancel) {
                            TextState(L10n.Localizable.Common.Button.cancel)
                        }
                    } message: {
                        TextState(L10n.Localizable.ConfirmationDialog.Title.delete)
                    }
                    return .none

                case .confirmationDialog(.presented(.confirmDelete(let word))):
                    return .send(.deleteWord(word))

                case .confirmationDialog:
                    return .none

                case .syncQuickSearchWords:
                    return .run { [state] _ in
                        await databaseClient.updateQuickSearchWords(state.quickSearchWords)
                    }

                case .toggleListEditing:
                    state.isListEditing.toggle()
                    return .none

                case .appendWord:
                    state.quickSearchWords.append(state.editingWord)
                    state.editKind = nil
                    return .send(.syncQuickSearchWords)

                case .editWord:
                    if let index = state.quickSearchWords.firstIndex(where: { $0.id == state.editingWord.id }) {
                        state.quickSearchWords[index] = state.editingWord
                        state.editKind = nil
                        return .send(.syncQuickSearchWords)
                    }
                    state.editKind = nil
                    return .none

                case .deleteWord(let word):
                    state.quickSearchWords = state.quickSearchWords.filter({ $0 != word })
                    return .send(.syncQuickSearchWords)

                case .deleteWordWithOffsets(let offsets):
                    state.quickSearchWords.remove(atOffsets: offsets)
                    return .send(.syncQuickSearchWords)

                case .moveWord(let source, let destination):
                    state.quickSearchWords.move(fromOffsets: source, toOffset: destination)
                    return .send(.syncQuickSearchWords)

                case .fetchQuickSearchWords:
                    state.loadingState = .loading
                    return .run { send in
                        let quickSearchWords = await databaseClient.fetchQuickSearchWords()
                        await send(.fetchQuickSearchWordsDone(quickSearchWords))
                    }
                    .cancellable(id: CancelID.fetchQuickSearchWords)

                case .fetchQuickSearchWordsDone(let words):
                    state.loadingState = .idle
                    state.quickSearchWords = words
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
