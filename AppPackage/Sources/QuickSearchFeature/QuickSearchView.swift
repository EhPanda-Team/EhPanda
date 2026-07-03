import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import ComposableArchitecture
import AppComponents

public struct QuickSearchView: View {
    @Bindable private var store: StoreOf<QuickSearchReducer>
    private let searchAction: (String) -> Void

    @FocusState private var focusedField: QuickSearchReducer.FocusField?

    public init(store: StoreOf<QuickSearchReducer>, searchAction: @escaping (String) -> Void) {
        self.store = store
        self.searchAction = searchAction
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(store.quickSearchWords) { word in
                        Button {
                            searchAction(word.effectiveSearchText)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                if !word.name.isEmpty, !word.content.isEmpty {
                                    Text(word.name).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                                }
                                Text(word.effectiveSearchText)
                                    .fontWeight(.medium)
                                    .font(.title3)
                                    .lineLimit(2)
                            }
                            .tint(.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                store.send(.deleteWordButtonTapped(word))
                            } label: {
                                Image(systemSymbol: .trash)
                            }
                            .tint(.red)
                            Button {
                                store.send(.editWordButtonTapped(word))
                            } label: {
                                Image(systemSymbol: .squareAndPencil)
                            }
                        }
                        .withArrow(isVisible: !store.isListEditing).padding(5)
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
            .confirmationDialog(
                $store.scope(state: \.confirmationDialog, action: \.confirmationDialog)
            )
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
            .navigationDestination(item: $store.editKind) { editWordView(for: $0) }
            .navigationTitle(.RLocalizable.quickSearch)
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
                store.send(.newWordButtonTapped)
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
    @ViewBuilder private func editWordView(for kind: QuickSearchReducer.WordEditKind) -> some View {
        EditWordView(
            title: kind == .new
                ? String(localized: .newWord)
                : String(localized: .editWord),
            word: $store.editingWord,
            focusedField: $focusedField,
            submitAction: onTextFieldSubmitted,
            confirmAction: {
                store.send(kind == .new ? .appendWord : .editWord)
            }
        )
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
                Section(String(localized: .name)) {
                    TextField(String(localized: .optional), text: $word.name)
                        .submitLabel(.next).focused(focusedField, equals: .name)
                }
                Section(String(localized: .content)) {
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
