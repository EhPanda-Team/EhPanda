//
//  QuickSearchView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/09/25.
//

import SwiftUI
import ComposableArchitecture

struct QuickSearchView: View {
    private let store: StoreOf<QuickSearchReducer>
    @ObservedObject private var viewStore: ViewStoreOf<QuickSearchReducer>
    private let searchAction: (String) -> Void

    @FocusState private var focusedField: QuickSearchReducer.FocusField?

    init(store: StoreOf<QuickSearchReducer>, searchAction: @escaping (String) -> Void) {
        self.store = store
        viewStore = ViewStore(store)
        self.searchAction = searchAction
    }

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(viewStore.quickSearchWords) { word in
                        Button {
                            searchAction(word.content)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                if !word.name.isEmpty {
                                    Text(word.name).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                                }
                                Text(word.content).fontWeight(.medium).font(.title3).lineLimit(2)
                            }
                            .tint(.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                viewStore.send(.setNavigation(.deleteWord(word)))
                            } label: {
                                Image(systemSymbol: .trash)
                            }
                            .tint(.red)
                            Button {
                                viewStore.send(.setEditingWord(word))
                                viewStore.send(.setNavigation(.editWord))
                            } label: {
                                Image(systemSymbol: .squareAndPencil)
                            }
                        }
                        .withArrow(isVisible: !viewStore.isListEditing).padding(5)
                        .confirmationDialog(
                            message: L10n.Localizable.ConfirmationDialog.Title.delete,
                            unwrapping: viewStore.binding(\.$route),
                            case: /QuickSearchReducer.Route.deleteWord,
                            matching: word
                        ) { route in
                            Button(L10n.Localizable.ConfirmationDialog.Button.delete, role: .destructive) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    viewStore.send(.deleteWord(route))
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        viewStore.send(.deleteWordWithOffsets(offsets))
                    }
                    .onMove { source, destination in
                        viewStore.send(.moveWord(source, destination))
                    }
                }
                LoadingView().opacity(
                    viewStore.loadingState == .loading
                    && viewStore.quickSearchWords.isEmpty ? 1 : 0
                )
                ErrorView(error: .notFound)
                .opacity(
                    viewStore.loadingState != .loading
                    && viewStore.quickSearchWords.isEmpty ? 1 : 0
                )
            }
            .synchronize(viewStore.binding(\.$focusedField), $focusedField)
            .environment(\.editMode, viewStore.binding(\.$listEditMode))
            .animation(.default, value: viewStore.quickSearchWords)
            .animation(.default, value: viewStore.listEditMode)
            .onAppear {
                if viewStore.quickSearchWords.isEmpty {
                    viewStore.send(.fetchQuickSearchWords)
                }
            }
            .toolbar(content: toolbar)
            .background(navigationLinks)
            .navigationTitle(L10n.Localizable.QuickSearchView.Title.quickSearch)
        }
    }

    private func onTextFieldSubmitted() {
        switch focusedField {
        case .name:
            focusedField = .content
        default:
            focusedField = nil
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Button {
                viewStore.send(.setEditingWord(.empty))
                viewStore.send(.setNavigation(.newWord))
            } label: {
                Image(systemSymbol: .plus)
            }
            Button {
                viewStore.send(.toggleListEditing)
            } label: {
                Image(systemSymbol: .pencilCircle)
                    .symbolVariant(viewStore.isListEditing ? .fill : .none)
            }
        }
    }
    @ViewBuilder private var navigationLinks: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /QuickSearchReducer.Route.newWord) { _ in
            EditWordView(
                title: L10n.Localizable.QuickSearchView.Title.newWord,
                word: viewStore.binding(\.$editingWord),
                focusedField: $focusedField,
                submitAction: onTextFieldSubmitted,
                confirmAction: {
                    viewStore.send(.appendWord)
                    viewStore.send(.setNavigation(nil))
                }
            )
        }
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /QuickSearchReducer.Route.editWord) { _ in
            EditWordView(
                title: L10n.Localizable.QuickSearchView.Title.editWord,
                word: viewStore.binding(\.$editingWord),
                focusedField: $focusedField,
                submitAction: onTextFieldSubmitted,
                confirmAction: {
                    viewStore.send(.editWord)
                    viewStore.send(.setNavigation(nil))
                }
            )
        }
    }
}

extension QuickSearchView {
    // MARK: EditWordView
    struct EditWordView: View {
        private let title: String
        @Binding private var word: QuickSearchWord
        private let focusedField: FocusState<QuickSearchReducer.FocusField?>.Binding
        private let submitAction: () -> Void
        private let confirmAction: () -> Void

        init(
            title: String, word: Binding<QuickSearchWord>,
            focusedField: FocusState<QuickSearchReducer.FocusField?>.Binding,
            submitAction: @escaping () -> Void, confirmAction: @escaping () -> Void
        ) {
            self.title = title
            _word = word
            self.focusedField = focusedField
            self.submitAction = submitAction
            self.confirmAction = confirmAction
        }

        var body: some View {
            Form {
                Section(L10n.Localizable.QuickSearchView.Title.name) {
                    TextField(L10n.Localizable.QuickSearchView.Placeholder.optional, text: $word.name)
                        .submitLabel(.next).focused(focusedField, equals: .name)
                }
                Section(L10n.Localizable.QuickSearchView.Title.content) {
                    TextEditor(text: $word.content)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .focused(focusedField, equals: .content)
                }
            }
            .toolbar(content: toolbar)
            .onSubmit(of: .text, submitAction)
            .navigationTitle(title)
        }

        private func toolbar() -> some ToolbarContent {
            CustomToolbarItem {
                Button(action: confirmAction) {
                    Text(L10n.Localizable.QuickSearchView.ToolbarItem.Button.confirm).bold()
                }
            }
        }
    }
}

struct QuickSearchView_Previews: PreviewProvider {
    static var previews: some View {
        QuickSearchView(
            store: .init(
                initialState: .init(),
                reducer: QuickSearchReducer()
            ),
            searchAction: { _ in }
        )
    }
}
