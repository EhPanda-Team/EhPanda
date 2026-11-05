import AppModels

/// Whether a comment is the signed-in user's own (research §5.6 b, A-10). Own comments get no Report or Block action.
///
/// The site renders an Edit link only on the signed-in user's own comments, which the parser records as
/// `GalleryComment.editable`. The name check covers an own comment whose Edit link the site no longer shows: the
/// signed-in user's forum name (`User.displayName`) is the name the site prints as the author. Forum names are unique,
/// so the check cannot claim someone else's comment; the names must match exactly, and an empty name matches nothing.
enum CommentOwnership {
    static func isOwn(_ comment: GalleryComment, didLogin: Bool, displayName: String?) -> Bool {
        if comment.editable {
            return true
        }
        guard didLogin, let displayName, !displayName.isEmpty else { return false }
        return displayName == comment.author
    }
}
