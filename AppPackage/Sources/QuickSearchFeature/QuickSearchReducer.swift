import SwiftUI
import AppModels
import ComposableArchitecture
import DatabaseClient

@Reducer
public struct QuickSearchReducer: Sendable {
    @CasePathable
    public enum Route: Equatable, Sendable {
        case newWord
        case editWord
        case deleteWord(QuickSearchWord)
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
        public var route: Route?
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
        case setNavigation(Route?)
        case clearSubStates

        case syncQuickSearchWords

        case toggleListEditing
        case setEditingWord(QuickSearchWord)

        case appendWord
        case editWord
        case deleteWord(QuickSearchWord)
        case deleteWordWithOffsets(IndexSet)
        case moveWord(IndexSet, Int)

        case teardown
        case fetchQuickSearchWords
        case fetchQuickSearchWordsDone([QuickSearchWord])
    }

    @Dependency(\.databaseClient) private var databaseClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.focusedField = nil
                state.editingWord = .empty
                return .none

            case .syncQuickSearchWords:
                return .run { [state] _ in
                    await databaseClient.updateQuickSearchWords(state.quickSearchWords)
                }

            case .toggleListEditing:
                state.isListEditing.toggle()
                return .none

            case .setEditingWord(let word):
                state.editingWord = word
                return .none

            case .appendWord:
                state.quickSearchWords.append(state.editingWord)
                return .send(.syncQuickSearchWords)

            case .editWord:
                if let index = state.quickSearchWords.firstIndex(where: { $0.id == state.editingWord.id }) {
                    state.quickSearchWords[index] = state.editingWord
                    return .send(.syncQuickSearchWords)
                }
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

            case .teardown:
                return .cancel(id: CancelID.fetchQuickSearchWords)

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
}
