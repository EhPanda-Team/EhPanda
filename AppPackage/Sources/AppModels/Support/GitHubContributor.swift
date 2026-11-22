public import Foundation

/// The part of GitHub's contributor entry that the About page reads.
///
/// `accountType` stays a `String` so a future GitHub account type can never fail decoding the whole list.
public struct GitHubContributor: Decodable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let login: String
    public let htmlURL: URL
    public let accountType: String

    /// Whether GitHub reports the account as a bot, such as `dependabot[bot]`.
    public var isBot: Bool { accountType == "Bot" }

    public init(id: Int, login: String, htmlURL: URL, accountType: String) {
        self.id = id
        self.login = login
        self.htmlURL = htmlURL
        self.accountType = accountType
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case login
        case htmlURL = "html_url"
        case accountType = "type"
    }
}
