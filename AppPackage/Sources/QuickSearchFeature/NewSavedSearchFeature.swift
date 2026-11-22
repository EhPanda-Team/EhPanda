public import AppModels
public import ComposableArchitecture
public import Foundation
public import Sharing

/// The New Saved Search editor presented on its own from a search results page, prefilled with the
/// page's keyword. Unlike the editor pushed inside Quick Search, it has no list underneath: Cancel
/// and Confirm both close the sheet and return to the results (owner decision, 261123-1ep D-02).
@Reducer
public struct NewSavedSearchFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var savedSearch: SavedSearch
        @Shared(.savedSearches) public var savedSearches: [SavedSearch]
        @SharedReader(.tagTranslator) public var tagTranslator: TagTranslator
        @SharedReader(.setting) public var setting: Setting

        /// The name starts empty because it is optional; the keyword becomes the search terms. The
        /// presenter supplies the identifier from its `uuid` dependency so the draft is deterministic.
        public init(id: UUID, keyword: String) {
            savedSearch = SavedSearch(id: id, name: "", content: keyword)
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case confirmButtonTapped
    }

    @Dependency(\.dismiss) private var dismiss

    public init() {}

    /// Whether a results page may offer to save `keyword`. The keyword must be non-empty, no saved
    /// search may already run the same text, and the list must be below its limit. Whitespace at
    /// either end is ignored when comparing, and an existing saved search is compared by
    /// `effectiveSearchText`, the text that tapping it searches for.
    public static func canSave(keyword: String, into savedSearches: [SavedSearch]) -> Bool {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty, savedSearches.count < QuickSearchReducer.savedSearchLimit else { return false }
        return !savedSearches.contains(where: {
            $0.effectiveSearchText.trimmingCharacters(in: .whitespacesAndNewlines) == keyword
        })
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            // The limit is checked again here because the list can fill from another screen while
            // the sheet is open; the sheet still closes, as Quick Search's own editor does.
            case .confirmButtonTapped:
                if state.savedSearches.count < QuickSearchReducer.savedSearchLimit {
                    let savedSearch = state.savedSearch
                    state.$savedSearches.withLock({ $0.append(savedSearch) })
                }
                return .run { _ in await dismiss() }
            }
        }
    }
}
