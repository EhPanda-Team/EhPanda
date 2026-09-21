import AppComponents
import AppModels
import ComposableArchitecture
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

public struct QuickSearchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable private var store: StoreOf<QuickSearchReducer>
    private let searchAction: (String) -> Void

    @FocusState private var focusedField: QuickSearchReducer.FocusField?

    public init(store: StoreOf<QuickSearchReducer>, searchAction: @escaping (String) -> Void) {
        self.store = store
        self.searchAction = searchAction
    }

    /// A saved word's name is user-authored, so above the default size it carries no cap and wraps;
    /// at and below it the designed single line is kept. Edit mode is where the cap bit first — the
    /// reorder and delete controls take the width the name was living on — and the row's two
    /// members are already stacked, so lifting the cap is all the reflow either mode needs.
    private var nameLineLimit: Int? {
        dynamicTypeSize <= .large ? 1 : nil
    }

    /// The search text is the word: it is what tapping the row runs, so above the default size it
    /// keeps every character instead of losing the tail of a long query. At and below the default
    /// size the designed two-line budget is kept verbatim.
    private var contentLineLimit: Int? {
        dynamicTypeSize <= .large ? 2 : nil
    }

    /// Words are inserted, deleted and reordered as whole rows, and edit mode slides the reorder and
    /// delete controls into every row — position motion, so both land instantly under Reduce Motion
    /// (D-29).
    private var listAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.quickSearchWords.isEmpty {
                    ViewThatFits(in: .vertical) {
                        VStack(spacing: 0) {
                            ListNoticeView(notice: .wordLimitDescription(limit: QuickSearchReducer.wordLimit))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                            ErrorView(error: .notFound)
                                .frame(maxWidth: .infinity)
                        }
                        ScrollView {
                            VStack(spacing: 0) {
                                ListNoticeView(notice: .wordLimitDescription(limit: QuickSearchReducer.wordLimit))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                ErrorView(error: .notFound)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        // A leading list section, rather than a pinned top banner, keeps the navigation
                        // title intact: the word list is capped and the add button disables at the limit.
                        ListNoticeView(notice: .wordLimitDescription(limit: QuickSearchReducer.wordLimit))

                        ForEach(store.quickSearchWords) { word in
                            Button {
                                // Record the word-usage signal at the reducer seam, then run the host's search
                                // callback exactly as before — the callback and its argument are unchanged.
                                store.send(.wordTapped)
                                searchAction(word.effectiveSearchText)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    if !word.name.isEmpty, !word.content.isEmpty {
                                        Text(word.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(nameLineLimit)
                                    }
                                    Text(word.effectiveSearchText)
                                        .fontWeight(.medium)
                                        .font(.title3)
                                        .lineLimit(contentLineLimit)
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
                            .withArrow(isVisible: !store.isListEditing)
                            .padding(5)
                        }
                        .onDelete { offsets in
                            store.send(.deleteWordWithOffsets(offsets))
                        }
                        .onMove { source, destination in
                            store.send(.moveWord(source: source, destination: destination))
                        }
                    }
                }
            }
            .animation(listAnimation, value: store.quickSearchWords)
            .confirmationDialog(
                $store.scope(\.$confirmationDialog, action: \.confirmationDialog)
            )
            .synchronize($store.focusedField, $focusedField)
            .environment(\.editMode, $store.listEditMode)
            .animation(listAnimation, value: store.listEditMode)
            .scrollEdgeEffectStyle(.soft, for: .top)
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
            ToolbarItemGroup(placement: .topBarTrailing) {
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
    @ContentBuilder private func editWordView(for kind: QuickSearchReducer.WordEditKind) -> some View {
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
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar(content: toolbar)
            .onSubmit(of: .text, submitAction)
            .navigationTitle(title)
        }

        private func toolbar() -> some ToolbarContent {
            ToolbarItemGroup(placement: .topBarTrailing) {
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
