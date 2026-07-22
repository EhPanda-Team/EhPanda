/// The proof-of-clearance pair captured when a challenge web view solves a Cloudflare wall.
///
/// The two fields travel together and are useless apart: Cloudflare binds a `cf_clearance` cookie to
/// the exact User-Agent of the client that earned it, so replaying the cookie under a different UA is
/// rejected as a fresh challenge. Keeping them in one value makes it impossible to attach one without
/// the other.
///
/// The pair lives only for the app session and is deliberately **never persisted** — not to app
/// storage, not to a file, and not to `HTTPCookieStorage.shared`. It is held by the
/// `SharedKey.cloudflareClearance` in-memory key, which starts at `nil` on every launch with no
/// cleanup code to forget or get wrong. Never log either field.
public struct CloudflareClearance: Equatable, Hashable, Sendable {
    /// The value of the captured `cf_clearance` cookie, without its name or attributes.
    public let cookieValue: String
    /// The exact User-Agent string of the web view that solved the challenge.
    public let userAgent: String

    public init(cookieValue: String, userAgent: String) {
        self.cookieValue = cookieValue
        self.userAgent = userAgent
    }
}
