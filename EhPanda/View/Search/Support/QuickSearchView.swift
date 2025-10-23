//
//  QuickSearchView.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

struct QuickSearchView: View {
    @Bindable private var store: StoreOf<QuickSearchReducer>
    private let searchAction: (String) -> Void

    @FocusState private var focusedField: QuickSearchReducer.FocusField?

    init(store: StoreOf<QuickSearchReducer>, searchAction: @escaping (String) -> Void) {
        self.store = store
        self.searchAction = searchAction
    }

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(store.quickSearchWords) { word in
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
                                store.send(.setNavigation(.deleteWord(word)))
                            } label: {
                                Image(systemSymbol: .trash)
                            }
                            .tint(.red)
                            Button {
                                store.send(.setEditingWord(word))
                                store.send(.setNavigation(.editWord))
                            } label: {
                                Image(systemSymbol: .squareAndPencil)
                            }
                        }
                        .withArrow(isVisible: !store.isListEditing).padding(5)
                        .confirmationDialog(
                            message: L10n.Localizable.ConfirmationDialog.Title.delete,
                            unwrapping: $store.route,
                            case: \.deleteWord,
                            matching: word
                        ) { route in
                            Button(L10n.Localizable.ConfirmationDialog.Button.delete, role: .destructive) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    store.send(.deleteWord(route))
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        store.send(.deleteWordWithOffsets(offsets))
                    }
                    .onMove { source, destination in
                        store.send(.moveWord(source, destination))
                    }
                }
                LoadingView().opacity(
                    store.loadingState == .loading
                    && store.quickSearchWords.isEmpty ? 1 : 0
                )
                ErrorView(error: .notFound)
                .opacity(
                    store.loadingState != .loading
                    && store.quickSearchWords.isEmpty ? 1 : 0
                )
            }
            .synchronize($store.focusedField, $focusedField)
            .environment(\.editMode, $store.listEditMode)
            .animation(.default, value: store.quickSearchWords)
            .animation(.default, value: store.listEditMode)
            .onAppear {
                if store.quickSearchWords.isEmpty {
                    store.send(.fetchQuickSearchWords)
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
                store.send(.setEditingWord(.empty))
                store.send(.setNavigation(.newWord))
            } label: {
                Image(systemSymbol: .plus)
            }
            Button {
                store.send(.toggleListEditing)
            } label: {
                Image(systemSymbol: .pencilCircle)
                    .symbolVariant(store.isListEditing ? .fill : .none)
            }
        }
    }
    @ViewBuilder private var navigationLinks: some View {
        NavigationLink(unwrapping: $store.route, case: \.newWord) { _ in
            EditWordView(
                title: L10n.Localizable.QuickSearchView.Title.newWord,
                word: $store.editingWord,
                focusedField: $focusedField,
                submitAction: onTextFieldSubmitted,
                confirmAction: {
                    store.send(.appendWord)
                    store.send(.setNavigation(nil))
                }
            )
        }
        NavigationLink(unwrapping: $store.route, case: \.editWord) { _ in
            EditWordView(
                title: L10n.Localizable.QuickSearchView.Title.editWord,
                word: $store.editingWord,
                focusedField: $focusedField,
                submitAction: onTextFieldSubmitted,
                confirmAction: {
                    store.send(.editWord)
                    store.send(.setNavigation(nil))
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
                Button(role: .confirm, action: confirmAction)
            }
        }
    }
}

struct QuickSearchView_Previews: PreviewProvider {
    static var previews: some View {
        QuickSearchView(
            store: .init(initialState: .init(), reducer: QuickSearchReducer.init),
            searchAction: { _ in }
        )
    }
}
