//
//  QuickSearchStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/20.
//

import SwiftUI
import ComposableArchitecture

struct QuickSearchState: Equatable {
    enum Route: Equatable {
        case newWord
        case editWord
        case deleteWord(QuickSearchWord)
    }
    enum FocusField {
        case name
        case content
    }
    struct CancelID: Hashable {
        let id = String(describing: QuickSearchState.self)
    }

    @BindableState var route: Route?
    @BindableState var focusedField: FocusField?
    @BindableState var editingWord: QuickSearchWord = .empty
    @BindableState var listEditMode: EditMode = .inactive
    var isListEditing: Bool {
        get { listEditMode == .active }
        set { listEditMode = newValue ? .active : .inactive }
    }

    var loadingState: LoadingState = .idle
    var quickSearchWords = [QuickSearchWord]()
}

enum QuickSearchAction: BindableAction {
    case binding(BindingAction<QuickSearchState>)
    case setNavigation(QuickSearchState.Route?)
    case clearSubStates

    case syncQuickSearchWords

    case toggleListEditing
    case onTextFieldSubmitted
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

struct QuickSearchEnvironment {
    let databaseClient: DatabaseClient
}

let quickSearchReducer = Reducer<QuickSearchState, QuickSearchAction, QuickSearchEnvironment>
{ state, action, environment in
    switch action {
    case .binding(\.$route):
        return state.route == nil ? .init(value: .clearSubStates) : .none

    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return route == nil ? .init(value: .clearSubStates) : .none

    case .clearSubStates:
        state.focusedField = nil
        state.editingWord = .empty
        return .none

    case .syncQuickSearchWords:
        return environment.databaseClient.updateQuickSearchWords(state.quickSearchWords).fireAndForget()

    case .toggleListEditing:
        state.isListEditing.toggle()
        return .none

    case .onTextFieldSubmitted:
        switch state.focusedField {
        case .name:
            state.focusedField = .content
        default:
            state.focusedField = nil
        }
        return .none

    case .setEditingWord(let word):
        state.editingWord = word
        return .none

    case .appendWord:
        state.quickSearchWords.append(state.editingWord)
        return .init(value: .syncQuickSearchWords)

    case .editWord:
        if let index = state.quickSearchWords.firstIndex(where: { $0.id == state.editingWord.id }) {
            state.quickSearchWords[index] = state.editingWord
            return .init(value: .syncQuickSearchWords)
        }
        return .none

    case .deleteWord(let word):
        state.quickSearchWords = state.quickSearchWords.filter({ $0 != word })
        return .init(value: .syncQuickSearchWords)

    case .deleteWordWithOffsets(let offsets):
        state.quickSearchWords.remove(atOffsets: offsets)
        return .init(value: .syncQuickSearchWords)

    case .moveWord(let source, let destination):
        state.quickSearchWords.move(fromOffsets: source, toOffset: destination)
        return .init(value: .syncQuickSearchWords)

    case .teardown:
        return .cancel(id: QuickSearchState.CancelID())

    case .fetchQuickSearchWords:
        state.loadingState = .loading
        return environment.databaseClient
            .fetchQuickSearchWords().map(QuickSearchAction.fetchQuickSearchWordsDone)
            .cancellable(id: QuickSearchState.CancelID())

    case .fetchQuickSearchWordsDone(let words):
        state.loadingState = .idle
        state.quickSearchWords = words
        return .none
    }
}
.binding()
