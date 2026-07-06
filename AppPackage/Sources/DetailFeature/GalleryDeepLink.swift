import Foundation

// A deferred navigation intent carried onto a freshly-pushed Detail screen. It lets a gallery link
// tapped inside a comment open the linked gallery and then, once that detail finishes loading, jump
// to a specific reading page or scroll its comment list to a specific comment — behavior that the old
// recursive detail achieved by mutating the embedded child before pushing.
public enum GalleryDeepLink: Equatable, Sendable {
    case reading(page: Int)
    case comments(commentID: String)

    /// The deep-link intent encoded by a parsed gallery URL: a resume page takes precedence over a
    /// target comment. Returns `nil` when the link carries neither. Shared by every gallery-link
    /// handler so the precedence can't drift between call sites.
    public init?(pageIndex: Int?, commentID: String?) {
        if let pageIndex {
            self = .reading(page: pageIndex)
        } else if let commentID {
            self = .comments(commentID: commentID)
        } else {
            return nil
        }
    }
}
