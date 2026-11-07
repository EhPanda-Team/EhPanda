import Foundation

/// Synthetic words for the 19-07 scenarios: a comment draft, the posting filter's term, and what the Report form is
/// filled with. Every string is invented for the public baselines (D-06); none is a real comment, member or address.
public enum GalleryFixtures {
    /// A new comment as typed into Post Comment.
    public static let commentDraft = "A visual fixture comment, written for the public sample."

    /// A comment that trips the posting filter, and the one term the scenario's filter list holds. The term is an
    /// invented neutral word, so the warning is shown without the bundled list's words.
    public static let filteredTerm = "visualfilterword"
    public static let filteredDraft = "A visual fixture comment with visualfilterword in it."

    /// The member ID of the comment author the blocked-row scenarios block (the first synthetic member).
    public static let blockedMemberID = "900001"
    public static let blockedMemberName = "Visual Member 1"

    /// The Report form as a user fills it: an email on a reserved example domain and a line of details.
    public static let reportEmail = "visual.fixture@example.com"
    public static let reportDetails = "Visual fixture details for the public sample."
}
