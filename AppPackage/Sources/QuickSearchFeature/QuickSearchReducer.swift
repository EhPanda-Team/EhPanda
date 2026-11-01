import AnalyticsClient
import AppComponents
public import AppModels
public import ComposableArchitecture
import Resources
public import Sharing
public import SwiftUI

@Reducer
public struct QuickSearchReducer: Sendable {
    // Saved searches are deliberate user content, so they are never auto-evicted. Instead the
    // list is bounded by a UI limit: the add button is disabled at this count (with a guard here as
    // a backstop). Capping keeps the persisted `@Shared(.savedSearches)` value small.
    public static let savedSearchLimit = 1000
    // Which flavour of the saved search editor is pushed onto the stack; drives `.navigationDestination(item:)`.
    public enum SavedSearchEditKind: Hashable, Sendable {
        case new
        case edit
    }

    public enum Dialog: Equatable, Sendable {
        case confirmDelete(SavedSearch)
    }

    public enum FocusField: Sendable {
        case name
        case content
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var editKind: SavedSearchEditKind?
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var focusedField: FocusField?
        public var editingSavedSearch: SavedSearch = .empty
        public var listEditMode: EditMode = .inactive
        public var isListEditing: Bool {
            get { listEditMode == .active }
            set { listEditMode = newValue ? .active : .inactive }
        }

        @Shared(.savedSearches) public var savedSearches: [SavedSearch]

        public init() {}

        // The add button is disabled once this is true (see `savedSearchLimit`).
        public var isAtSavedSearchLimit: Bool { savedSearches.count >= QuickSearchReducer.savedSearchLimit }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<Dialog>)
        case deleteSavedSearchButtonTapped(SavedSearch)
        case newSavedSearchButtonTapped
        case editSavedSearchButtonTapped(SavedSearch)
        case savedSearchTapped

        case toggleListEditing

        case appendSavedSearch
        case editSavedSearch
        case deleteSavedSearch(SavedSearch)
        case deleteSavedSearchWithOffsets(IndexSet)
        case moveSavedSearch(source: IndexSet, destination: Int)
    }

    @Dependency(\.analyticsClient) private var analyticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        CombineReducers {
            BindingReducer()

            Reduce { state, action in
                switch action {
                case .binding:
                    return .none

                case .newSavedSearchButtonTapped:
                    state.editingSavedSearch = .empty
                    state.editKind = .new
                    return .none

                case .editSavedSearchButtonTapped(let savedSearch):
                    state.editingSavedSearch = savedSearch
                    state.editKind = .edit
                    return .none

                // The five host screens each translate a selected saved search into a different
                // follow-on search action, so this is the only place "a saved search was used"
                // is expressible once (D-14). It is payload-free by construction: the saved search's name and
                // content are user-authored text that D-06 forbids, so nothing about it is transmitted.
                case .savedSearchTapped:
                    return .run(operation: { _ in analyticsClient.send(.savedSearchUsed) })

                case .deleteSavedSearchButtonTapped(let savedSearch):
                    state.confirmationDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                        TextState(localized: .RLocalizable.delete)
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmDelete(savedSearch)) {
                            TextState(localized: .RLocalizable.delete)
                        }
                        ButtonState(role: .cancel) {
                            TextState(localized: .RLocalizable.cancel)
                        }
                    } message: {
                        TextState(localized: .deleteSavedSearchDescription)
                    }
                    return .none

                case .confirmationDialog(.presented(.confirmDelete(let savedSearch))):
                    return .send(.deleteSavedSearch(savedSearch))

                case .confirmationDialog:
                    return .none

                case .toggleListEditing:
                    state.isListEditing.toggle()
                    return .none

                case .appendSavedSearch:
                    guard !state.isAtSavedSearchLimit else { return .none }
                    let savedSearch = state.editingSavedSearch
                    state.$savedSearches.withLock({ $0.append(savedSearch) })
                    state.editKind = nil
                    return .none

                case .editSavedSearch:
                    if let index = state.savedSearches.firstIndex(where: { $0.id == state.editingSavedSearch.id }) {
                        let savedSearch = state.editingSavedSearch
                        state.$savedSearches.withLock({ $0[index] = savedSearch })
                    }
                    state.editKind = nil
                    return .none

                case .deleteSavedSearch(let savedSearch):
                    state.$savedSearches.withLock { $0.removeAll { $0 == savedSearch } }
                    return .none

                case .deleteSavedSearchWithOffsets(let offsets):
                    state.$savedSearches.withLock({ $0.remove(atOffsets: offsets) })
                    return .none

                case .moveSavedSearch(let source, let destination):
                    state.$savedSearches.withLock({ $0.move(fromOffsets: source, toOffset: destination) })
                    return .none
                }
            }
        }
        // Dismissing the editor (back-swipe or a confirmed save) resets the scratch saved search and focus.
        .onChange(of: \.editKind) { _, state in
            if state.editKind == nil {
                state.focusedField = nil
                state.editingSavedSearch = .empty
            }
            return .none
        }
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}
