public import AppModels
public import ComposableArchitecture

@Reducer
public struct AboutFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        /// `nil` until a fetch succeeds, which keeps "not loaded yet" apart from "loaded, nobody eligible".
        public var codeContributors: [GitHubContributor]?
        public var codeContributorsLoadingState: LoadingState = .idle

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case fetchCodeContributors
        case fetchCodeContributorsDone(Result<[GitHubContributor], AppError>)
    }

    @Dependency(\.codeContributorsClient) private var codeContributorsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .fetchCodeContributors:
                guard state.codeContributors == nil, state.codeContributorsLoadingState != .loading else {
                    return .none
                }
                state.codeContributorsLoadingState = .loading
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await codeContributorsClient.fetch()
                    }
                    await send(.fetchCodeContributorsDone(result))
                }

            case .fetchCodeContributorsDone(let result):
                switch result {
                case .success(let contributors):
                    state.codeContributors = Self.featuredCodeContributors(from: contributors)
                    state.codeContributorsLoadingState = .idle
                case .failure(let error):
                    state.codeContributorsLoadingState = .failed(error)
                }
                return .none
            }
        }
    }
}

extension AboutFeature {
    /// The repository's maintainers. They own the project rather than contribute to it, so the Code Contributors
    /// section does not list them. Stored lowercased: logins compare case-insensitively.
    static let maintainerLogins: Set<String> = ["chihchy", "tatsuz0u"]

    /// The people the fixed Translation Contributors section already credits, so nobody is listed twice.
    /// Stored lowercased, and kept equal to `AboutView.translationContributors` by `AboutFeatureTests`.
    static let translationContributorLogins: Set<String> = [
        "nebulosa-cat", "paulhaeussler", "caxerx", "nekoouo"
    ]

    /// How many contributors the Code Contributors section lists.
    static let featuredCodeContributorCount = 5

    /// The contributors the About page credits for code: GitHub's order (most contributions first) is kept, bots,
    /// maintainers and translation contributors are dropped, and the first ``featuredCodeContributorCount`` remain.
    static func featuredCodeContributors(from contributors: [GitHubContributor]) -> [GitHubContributor] {
        let excludedLogins = maintainerLogins.union(translationContributorLogins)
        let eligible = contributors.filter({ contributor in
            !contributor.isBot && !excludedLogins.contains(contributor.login.lowercased())
        })
        return Array(eligible.prefix(featuredCodeContributorCount))
    }
}
