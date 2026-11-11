import Foundation

// The probe every reduction suite in this target leans on.
//
// The reduction types are this phase's primary privacy control, and a control is worth exactly as
// much as the test that proves it. Asserting on public properties would only prove that the
// properties a reviewer already read are clean; reflecting over a constructed value reaches every
// stored property, including ones the public API never exposes and ones a later change adds. A
// leak parked in a private field is then caught the same way a public one is.
extension Mirror {
    /// Every leaf value reachable from the reflected value, rendered with `String(describing:)`.
    ///
    /// A child that has children of its own is walked rather than rendered, so a nested struct, an
    /// enum payload or a dictionary entry contributes its own leaves instead of one summary
    /// string. Leaves are what a sentinel search has to inspect: a summary can omit the very field
    /// that carries the leak, and a passing search over that summary would prove nothing.
    var leafRenderings: [String] {
        children.flatMap({ child in
            let nested = Mirror(reflecting: child.value).leafRenderings
            return nested.isEmpty ? [String(describing: child.value)] : nested
        })
    }
}

/// Probe strings for the 3.0 moderation flows (20-12, 20-13): one per piece of content a comment, a
/// report or a block touches, each distinctive enough that no signal name, key or value can contain
/// it by chance. A flow's test places them in its state; a signal that carries any of them has leaked.
enum ModerationLeakProbe {
    static let commentText = "zqxprobecommenttext7731"
    static let posterName = "zqxprobepostername7731"
    static let memberID = "zqxprobememberid7731"
    static let reportDetails = "zqxprobereportdetails7731"
    static let email = "zqxprobe7731@example.invalid"
    static let galleryTitle = "zqxprobegallerytitle7731"
    static let url = "https://zqxprobe7731.example.invalid/g/7731/zqxprobetoken/"

    static let all = [commentText, posterName, memberID, reportDetails, email, galleryTitle, url]
}
