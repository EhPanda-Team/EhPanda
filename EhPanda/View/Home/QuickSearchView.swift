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
    @State private var refreshID = UUID().uuidString

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
                            submitID: $refreshID, searchAction: searchAction,
                            submitAction: { store.dispatch(.modifyQuickSearchWord(newWord: $0)) }
                        )
                    }
                    .onDelete { store.dispatch(.deleteQuickSearchWord(offsets: $0)) }
                    .onMove(perform: move)
                }
                .id(refreshID)
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
        refreshID = UUID().uuidString
        store.dispatch(.moveQuickSearchWord(source: source, destination: destination))
    }
}

// MARK: QuickSearchWordRow
private struct QuickSearchWordRow: View {
    @FocusState private var isFocused
    @State private var editableContent: String
    private var plainWord: QuickSearchWord
    @Binding private var isEditting: Bool
    @Binding private var submitID: String
    private var searchAction: (String) -> Void
    private var submitAction: (QuickSearchWord) -> Void

    init(
        word: QuickSearchWord,
        isEditting: Binding<Bool>,
        submitID: Binding<String>,
        searchAction: @escaping (String) -> Void,
        submitAction: @escaping (QuickSearchWord) -> Void
    ) {
        _editableContent = State(initialValue: word.content)

        plainWord = word
        _isEditting = isEditting
        _submitID = submitID
        self.searchAction = searchAction
        self.submitAction = submitAction
    }

    var body: some View {
        ZStack {
            Button(plainWord.content) {
                searchAction(plainWord.content)
            }
            .withArrow().foregroundColor(.primary)
            .opacity(isEditting ? 0 : 1)
            TextEditor(text: $editableContent)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
                .opacity(isEditting ? 1 : 0)
                .focused($isFocused)
        }
        .onChange(of: isFocused, perform: trySubmit)
        .onChange(of: submitID, perform: trySubmit)
        .onChange(of: isEditting) { _ in
            trySubmit()
            isFocused = false
        }
    }

    private func trySubmit(_: Any? = nil) {
        guard editableContent != plainWord.content else { return }
        submitAction(QuickSearchWord(id: plainWord.id, content: editableContent))
    }
}

struct QuickSearchView_Previews: PreviewProvider {
    static var previews: some View {
        QuickSearchView(searchAction: { _ in })
            .preferredColorScheme(.dark)
            .environmentObject(Store.preview)
    }
}
