/// The comment block list's operations (DD-10, D-13, research §5.4), on the `[String]` that
/// `@Shared(.blockedCommentAuthors)` holds.
///
/// The list keeps the order users were blocked in, so the Blocked Users list in Account settings is stable, and holds
/// each name once. Names are the exact author strings the site prints: no case folding and no trimming, so blocking
/// one user never blocks another whose name differs only in case. The list stays on this device.
extension Array where Element == String {
    /// Adds `author` at the end unless it is already blocked. An empty name is never added.
    public mutating func block(author: String) {
        guard !author.isEmpty, !isBlocked(author: author) else { return }
        append(author)
    }

    /// Removes `author`, keeping the order of the rest.
    public mutating func unblock(author: String) {
        removeAll(where: { $0 == author })
    }

    /// Whether `author` is blocked, by exact name.
    public func isBlocked(author: String) -> Bool {
        !author.isEmpty && contains(author)
    }
}
