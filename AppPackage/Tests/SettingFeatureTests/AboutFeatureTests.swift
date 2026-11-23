import AppModels
import ComposableArchitecture
import Foundation
@testable import SettingFeature
import Testing
import TestingSupport

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite(.isolatedAppStorage)
struct AboutFeatureTests {
    private func contributor(_ login: String, accountType: String = "User", id: Int = 0) throws -> GitHubContributor {
        let base = try #require(URL(string: "https://github.com"))
        return GitHubContributor(
            id: id,
            login: login,
            htmlURL: base.appending(path: login),
            accountType: accountType
        )
    }

    /// GitHub's list on 2026-11-23, most contributions first.
    private func contributorsFixture() throws -> [GitHubContributor] {
        let users = [
            "chihchy", "github-actions[bot]", "aalberrty", "xioxin", "Jimmy-Prime", "vvbbnn00", "NeKoOuO",
            "remlostime", "nyaanim", "Nebulosa-Cat", "leng-yue", "caxerx", "dependabot[bot]", "Kaed3mi"
        ]
        return try users.enumerated().map({ offset, login in
            try contributor(login, accountType: login.hasSuffix("[bot]") ? "Bot" : "User", id: offset)
        })
    }

    // MARK: Selection

    @Test
    func featuredContributorsSkipBotsMaintainersAndTranslators() throws {
        let featured = AboutFeature.featuredCodeContributors(from: try contributorsFixture())

        #expect(featured.map(\.login) == ["aalberrty", "xioxin", "Jimmy-Prime", "vvbbnn00", "remlostime"])
    }

    @Test
    func exclusionIgnoresLoginCase() throws {
        let excluded = try ["ChihChy", "TATSUZ0U", "nebulosa-cat", "PAULHAEUSSLER", "CaXeRx", "nekoouo"]
            .map({ try contributor($0) })
        let unrelated = try contributor("someone-else")

        #expect(AboutFeature.featuredCodeContributors(from: excluded + [unrelated]) == [unrelated])
    }

    @Test
    func anyBotAccountIsDroppedWhateverItsLogin() throws {
        let bot = try contributor("renovate", accountType: "Bot")
        let user = try contributor("alice", accountType: "User")
        let organization = try contributor("some-org", accountType: "Organization")

        #expect(AboutFeature.featuredCodeContributors(from: [bot, user, organization]) == [user, organization])
    }

    @Test
    func fewerThanFiveEligibleReturnsAllInInputOrder() throws {
        let eligible = try ["zed", "amy", "bob"].map({ try contributor($0) })
        let input = try [contributor("chihchy")] + eligible

        #expect(AboutFeature.featuredCodeContributors(from: input) == eligible)
    }

    // The two lists describe the same four people, once as fixed rows and once as exclusions. `AboutView` is
    // main-actor isolated, so reading its fixed list needs the main actor.
    @MainActor
    @Test
    func translationExclusionsMatchTheFixedTranslationSection() {
        let fixedLogins = AboutView.translationContributors.compactMap({ link in
            URL(string: link.urlString)?.lastPathComponent.lowercased()
        })

        #expect(fixedLogins.count == 4)
        #expect(Set(fixedLogins) == AboutFeature.translationContributorLogins)
    }

    // MARK: Fetch

    @MainActor
    @Test
    func fetchLoadsTheFeaturedContributors() async throws {
        let all = try contributorsFixture()
        let store = TestStore(initialState: AboutFeature.State(), reducer: AboutFeature.init) {
            $0.codeContributorsClient.fetch = { all }
        }

        await store.send(.fetchCodeContributors) {
            $0.codeContributorsLoadingState = .loading
        }
        await store.receive(\.fetchCodeContributorsDone) {
            $0.codeContributors = AboutFeature.featuredCodeContributors(from: all)
            $0.codeContributorsLoadingState = .idle
        }
        #expect(store.state.codeContributors?.count == 5)
    }

    @MainActor
    @Test
    func failedFetchLeavesNothingLoadedAndKeepsTheError() async {
        let store = TestStore(initialState: AboutFeature.State(), reducer: AboutFeature.init) {
            $0.codeContributorsClient.fetch = { () async throws(AppError) -> [GitHubContributor] in
                throw .networkingFailed
            }
        }

        await store.send(.fetchCodeContributors) {
            $0.codeContributorsLoadingState = .loading
        }
        await store.receive(\.fetchCodeContributorsDone) {
            $0.codeContributorsLoadingState = .failed(.networkingFailed)
        }
        #expect(store.state.codeContributors == nil)
    }

    // Retry is the same action the presentation sends: from a failure it loads again.
    @MainActor
    @Test
    func retryAfterFailureLoadsTheFeaturedContributors() async throws {
        let all = try contributorsFixture()
        var state = AboutFeature.State()
        state.codeContributorsLoadingState = .failed(.networkingFailed)
        let store = TestStore(initialState: state, reducer: AboutFeature.init) {
            $0.codeContributorsClient.fetch = { all }
        }

        await store.send(.fetchCodeContributors) {
            $0.codeContributorsLoadingState = .loading
        }
        await store.receive(\.fetchCodeContributorsDone) {
            $0.codeContributors = AboutFeature.featuredCodeContributors(from: all)
            $0.codeContributorsLoadingState = .idle
        }
    }

    // The default `unimplemented` client reports an issue if the guard lets a second fetch run.
    @MainActor
    @Test
    func fetchWhileLoadingChangesNothing() async {
        var state = AboutFeature.State()
        state.codeContributorsLoadingState = .loading
        let store = TestStore(initialState: state, reducer: AboutFeature.init)

        await store.send(.fetchCodeContributors)
    }

    @MainActor
    @Test
    func fetchAfterSuccessChangesNothing() async throws {
        var state = AboutFeature.State()
        state.codeContributors = [try contributor("alice")]
        let store = TestStore(initialState: state, reducer: AboutFeature.init)

        await store.send(.fetchCodeContributors)
    }
}
