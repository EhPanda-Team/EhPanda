import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import ComposableArchitecture
import AppComponents
import SFSafeSymbolsExt

public struct QuickSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store: StoreOf<QuickSearchReducer>
    private let searchAction: (String) -> Void

    @FocusState private var focusedField: QuickSearchReducer.FocusField?

    public init(store: StoreOf<QuickSearchReducer>, searchAction: @escaping (String) -> Void) {
        self.store = store
        self.searchAction = searchAction
    }

    public var body: some View {
        NavigationStack {
            List {
                // A leading list section, rather than a pinned top banner, keeps the navigation
                // title intact: the word list is capped and the add button disables at the limit.
                ListNoticeView(notice: .wordLimitDescription(limit: QuickSearchReducer.wordLimit))

                ForEach(store.quickSearchWords) { word in
                    Button {
                        searchAction(word.effectiveSearchText)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            if !word.name.isEmpty, !word.content.isEmpty {
                                Text(word.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
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
                            Label(.RLocalizable.delete, systemSymbol: .trash)
                                .labelStyle(.iconOnly)
                        }
                        .tint(.red)

                        Button {
                            store.send(.editWordButtonTapped(word))
                        } label: {
                            Label(.editWord, systemSymbol: .squareAndPencil)
                                .labelStyle(.iconOnly)
                        }
                    }
                    .withArrow(isVisible: !store.isListEditing).padding(5)
                }
                .onDelete { offsets in
                    store.send(.deleteWordWithOffsets(offsets))
                }
                .onMove { source, destination in
                    store.send(.moveWord(source: source, destination: destination))
                }
            }
            .animation(.default, value: store.quickSearchWords)
            .overlay {
                ErrorView(error: .notFound)
                    .animation(.default) {
                        $0.opacity(store.quickSearchWords.isEmpty ? 1 : 0)
                    }
            }
            .confirmationDialog(
                $store.scope(\.$confirmationDialog, action: \.confirmationDialog)
            )
            .synchronize($store.focusedField, $focusedField)
            .environment(\.editMode, $store.listEditMode)
            .animation(.default, value: store.listEditMode)
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
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel, action: dismiss.callAsFunction)
            }
            CustomToolbarItem {
                Button {
                    store.send(.newWordButtonTapped)
                } label: {
                    Label(.newWord, systemSymbol: .plus)
                }
                .disabled(store.isAtWordLimit)
                Button {
                    store.send(.toggleListEditing)
                } label: {
                    Label(.edit, systemSymbol: .pencilCircle)
                        .symbolVariant(store.isListEditing ? .fill : .none)
                }
            }
        }
    }
    @ViewBuilder private func editWordView(for kind: QuickSearchReducer.WordEditKind) -> some View {
        EditWordView(
            title: kind == .new
                ? .newWord
                : .editWord,
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
        private let title: LocalizedStringResource
        @Binding private var word: QuickSearchWord
        private let focusedField: FocusState<QuickSearchReducer.FocusField?>.Binding
        private let submitAction: () -> Void
        private let confirmAction: () -> Void

        init(
            title: LocalizedStringResource, word: Binding<QuickSearchWord>,
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
                Section(.name) {
                    TextField(.optionalPlaceholder, text: $word.name)
                        .submitLabel(.next).focused(focusedField, equals: .name)
                }
                Section(.content) {
                    TextEditor(text: $word.content)
                        .autocorrectionDisabled(true)
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

#Preview("Initial") {
    QuickSearchView(
        store: .init(
            initialState: {
                let state = QuickSearchReducer.State()
                state.$quickSearchWords.withLock {
                    $0 = [
                        .init(name: "English Doujinshi", content: "language:english category:doujinshi"),
                        .init(name: "High Rated", content: "rating:5")
                    ]
                }
                return state
            }(),
            reducer: QuickSearchReducer.init
        ),
        searchAction: { _ in }
    )
}
