public import ComposableArchitecture
public import SwiftUI

/// The sheet a search results page presents to save its keyword: the same editor Quick Search
/// pushes, hosted as the root of its own stack so Cancel replaces the back button.
public struct NewSavedSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store: StoreOf<NewSavedSearchFeature>
    @FocusState private var focusedField: QuickSearchReducer.FocusField?

    public init(store: StoreOf<NewSavedSearchFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            QuickSearchView.EditSavedSearchView(
                title: .newSavedSearch,
                savedSearch: $store.savedSearch,
                focusedField: $focusedField,
                confirmAction: { store.send(.confirmButtonTapped) },
                tagTranslator: store.tagTranslator,
                setting: store.setting
            )
            .toolbar(content: toolbar)
        }
    }

    private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel, action: dismiss.callAsFunction)
        }
    }
}

#Preview("Prefilled") {
    NewSavedSearchView(
        store: .init(
            initialState: NewSavedSearchFeature.State(id: UUID(), keyword: "language:english"),
            reducer: NewSavedSearchFeature.init
        )
    )
}
