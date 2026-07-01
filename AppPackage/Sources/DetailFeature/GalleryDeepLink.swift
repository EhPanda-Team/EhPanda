import Foundation

// A deferred navigation intent carried onto a freshly-pushed Detail screen. It lets a gallery link
// tapped inside a comment open the linked gallery and then, once that detail finishes loading, jump
// to a specific reading page or scroll its comment list to a specific comment — behavior that the old
// recursive detail achieved by mutating the embedded child before pushing.
public enum GalleryDeepLink: Equatable, Sendable {
    case reading(page: Int)
    case comments(commentID: String)
}
