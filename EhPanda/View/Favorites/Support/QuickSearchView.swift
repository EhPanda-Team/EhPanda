//
//  QuickSearchView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/09/25.
//

import SwiftUI

struct QuickSearchView: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @State private var isEditting = false
    @State private var refreshTrigger = UUID().uuidString

    private let searchAction: (String) -> Void

    init(searchAction: @escaping (String) -> Void) {
        self.searchAction = searchAction
    }

    // MARK: QuickSearchView
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(words) { word in
                        QuickSearchWordRow(
                            word: word, isEditting: $isEditting,
                            refreshTrigger: $refreshTrigger, searchAction: searchAction,
                            submitAction: { store.dispatch(.modifyQuickSearchWord(newWord: $0)) }
                        )
                    }
                    .onDelete { store.dispatch(.deleteQuickSearchWord(offsets: $0)) }
                    .onMove(perform: move)
                }
                .id(refreshTrigger)
                ErrorView(error: .notFound, retryAction: nil).opacity(words.isEmpty ? 1 : 0)
            }
            .environment(\.editMode, .constant(isEditting ? .active : .inactive))
            .toolbar(content: toolbar).navigationTitle("Quick search")
        }
    }

    // MARK: Toolbar
    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    store.dispatch(.appendQuickSearchWord)
                } label: {
                    Image(systemName: "plus")
                }
                .opacity(isEditting ? 1 : 0)
                Button {
                    isEditting.toggle()
                } label: {
                    Image(systemName: "pencil.circle")
                        .symbolVariant(isEditting ? .fill : .none)
                }
            }
        }
    }
}

private extension QuickSearchView {
    var words: [QuickSearchWord] {
        homeInfo.quickSearchWords
    }
    func move(from source: IndexSet, to destination: Int) {
        refreshTrigger = UUID().uuidString
        store.dispatch(.moveQuickSearchWord(source: source, destination: destination))
    }
}

// MARK: QuickSearchWordRow
private struct QuickSearchWordRow: View {
    @FocusState private var focusField: FocusField?
    @State private var editableAlias: String
    @State private var editableContent: String
    private var plainWord: QuickSearchWord
    @Binding private var isEditting: Bool
    @Binding private var refreshTrigger: String
    private var searchAction: (String) -> Void
    private var submitAction: (QuickSearchWord) -> Void

    enum FocusField {
        case alias
        case content
    }

    init(
        word: QuickSearchWord,
        isEditting: Binding<Bool>,
        refreshTrigger: Binding<String>,
        searchAction: @escaping (String) -> Void,
        submitAction: @escaping (QuickSearchWord) -> Void
    ) {
        _editableAlias = State(initialValue: word.alias ?? "")
        _editableContent = State(initialValue: word.content)

        plainWord = word
        _isEditting = isEditting
        _refreshTrigger = refreshTrigger
        self.searchAction = searchAction
        self.submitAction = submitAction
    }

    private var title: String {
        if let alias = plainWord.alias, !alias.isEmpty {
            return alias
        } else {
            return plainWord.content
        }
    }

    var body: some View {
        ZStack {
            if isEditting {
                VStack {
                    TextField(editableAlias, text: $editableAlias, prompt: Text("Alias"))
                        .submitLabel(.next).lineLimit(1).focused($focusField, equals: .alias)
                    Divider().foregroundColor(.secondary.opacity(0.2))
                    TextEditor(text: $editableContent).textInputAutocapitalization(.none)
                        .disableAutocorrection(true).focused($focusField, equals: .content)
                }
            } else {
                Button(title) {
                    searchAction(plainWord.content)
                }
                .withArrow().foregroundColor(.primary)
            }
        }
        .onChange(of: isEditting) { _ in focusField = nil }
        .onChange(of: refreshTrigger, perform: trySubmit)
        .onChange(of: focusField, perform: trySubmit)
        .onSubmit {
            switch focusField {
            case .alias:
                focusField = .content
            default:
                focusField = nil
            }
        }
    }

    private func trySubmit(_: Any? = nil) {
        var newWord = QuickSearchWord(id: plainWord.id, content: editableContent)
        if !editableAlias.isEmpty { newWord.alias = editableAlias }
        guard newWord != plainWord else { return }
        submitAction(newWord)
    }
}

struct QuickSearchView_Previews: PreviewProvider {
    static var previews: some View {
        QuickSearchView(searchAction: { _ in })
            .environmentObject(Store.preview)
    }
}
