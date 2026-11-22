import AppModels
import ComposableArchitecture
import Foundation
@testable import QuickSearchFeature
import Sharing
import Testing

// Each case reads and writes `@Shared(.savedSearches)` through its own in-memory defaults, so the
// suite runs in parallel. Reads stay on the `@Shared` reference, never on raw defaults.
@Suite
struct NewSavedSearchFeatureTests {
    // MARK: Prefill

    @Test
    func theDraftCarriesTheKeywordAsSearchTermsAndNoName() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let state = NewSavedSearchFeature.State(id: UUID(0), keyword: "language:english")
            #expect(state.savedSearch.id == UUID(0))
            #expect(state.savedSearch.name.isEmpty)
            #expect(state.savedSearch.content == "language:english")
        }
    }

    // MARK: Eligibility

    @Test(arguments: ["", " ", "\n\t "])
    func anEmptyKeywordCannotBeSaved(keyword: String) {
        #expect(!NewSavedSearchFeature.canSave(keyword: keyword, into: []))
    }

    @Test
    func aNewKeywordCanBeSaved() {
        let savedSearches = [SavedSearch(name: "", content: "rating:5")]
        #expect(NewSavedSearchFeature.canSave(keyword: "language:english", into: savedSearches))
    }

    @Test
    func aKeywordAnExistingSavedSearchRunsCannotBeSavedAgain() {
        let savedSearches = [SavedSearch(name: "English", content: "language:english")]
        #expect(!NewSavedSearchFeature.canSave(keyword: "language:english", into: savedSearches))
        #expect(!NewSavedSearchFeature.canSave(keyword: "  language:english \n", into: savedSearches))
    }

    // A saved search with no search terms runs its name, so the name is what a keyword duplicates.
    @Test
    func aNameOnlySavedSearchIsComparedByTheTextItRuns() {
        let savedSearches = [SavedSearch(name: "female:glasses", content: "")]
        #expect(!NewSavedSearchFeature.canSave(keyword: "female:glasses", into: savedSearches))
        let named = [SavedSearch(name: "female:glasses", content: "female:glasses$ language:english")]
        #expect(NewSavedSearchFeature.canSave(keyword: "female:glasses", into: named))
    }

    @Test
    func nothingCanBeSavedAtTheLimit() {
        let full = (0..<QuickSearchReducer.savedSearchLimit).map({ SavedSearch(name: "", content: "tag\($0)") })
        #expect(!NewSavedSearchFeature.canSave(keyword: "new", into: full))
        #expect(NewSavedSearchFeature.canSave(keyword: "new", into: Array(full.dropLast())))
    }

    // MARK: Confirm

    @MainActor
    @Test
    func confirmingAppendsTheEditedDraftAndDismisses() async {
        let dismissed = LockIsolated(false)
        let existing = SavedSearch(name: "High Rated", content: "rating:5")
        let store = makeStore(keyword: "language:english", existing: [existing], dismissed: dismissed)

        await store.send(.binding(.set(\.savedSearch.name, "English"))) {
            $0.savedSearch.name = "English"
        }
        let draft = store.state.savedSearch
        await store.send(.confirmButtonTapped) {
            $0.$savedSearches.withLock({ $0 = [existing, draft] })
        }
        await store.finish()
        #expect(dismissed.value)
    }

    @MainActor
    @Test
    func confirmingAtTheLimitSavesNothingButStillDismisses() async {
        let dismissed = LockIsolated(false)
        let full = (0..<QuickSearchReducer.savedSearchLimit).map({ SavedSearch(name: "", content: "tag\($0)") })
        let store = makeStore(keyword: "language:english", existing: full, dismissed: dismissed)

        await store.send(.confirmButtonTapped)
        await store.finish()
        #expect(store.state.savedSearches == full)
        #expect(dismissed.value)
    }

    @MainActor
    private func makeStore(
        keyword: String, existing: [SavedSearch], dismissed: LockIsolated<Bool>
    ) -> TestStoreOf<NewSavedSearchFeature> {
        let appStorage = UserDefaults.inMemory
        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            let state = NewSavedSearchFeature.State(id: UUID(0), keyword: keyword)
            state.$savedSearches.withLock({ $0 = existing })
            return TestStore(initialState: state, reducer: NewSavedSearchFeature.init) {
                $0.defaultAppStorage = appStorage
                $0.dismiss = DismissEffect({ dismissed.setValue(true) })
            }
        }
    }
}
