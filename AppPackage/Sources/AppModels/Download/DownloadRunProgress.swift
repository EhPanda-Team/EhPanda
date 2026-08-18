/// D-SSOT-10: the row-published form of ONE run's own measurement of the pages it has covered —
/// the work it inherited plus the pages it has landed (`RunProgressBasis.creditedPageIndices`).
///
/// It is present on a `DownloadedGallery` only while that run's measurement stands, and `nil`
/// otherwise. It is progress-of-this-RUN, never completeness-of-this-RECORD: `completedPageCount`,
/// `isIncomplete`, `displayStatus`, the retry basis and every scheduling gate go on deriving from
/// the manifest exactly as before, and this value never enters any of them.
///
/// **Why the record cannot carry it.** Per AGENTS.md's manifest-SSOT clause, session-scoped state
/// is permitted as an OPERATION-level signal for what the record legitimately cannot record. That is
/// this value's whole warrant, and the wholesale-refusal family is the case: a record claiming every
/// page whose files are gone reads N-of-N for the ENTIRE re-download, because the irreversibility
/// guard refuses to blank a manifest's whole claim on one scan. The record is not lying about what
/// it has evidence for — it is simply unable to describe the work a repair is doing. So the Download
/// Status sheet read "Downloaded (27) / Pending (0)" over a from-zero re-download while the
/// continued-processing card, fed by this same measurement, was right (G-15-2F).
///
/// **What it is not.** It writes nothing, consults no disk, and never outranks queue membership. It
/// is retired with the run that announced it, at the one point every run exit passes through. For an
/// honest record it equals the record's own reading at every flush, so adopting it changes nothing
/// visible for the ordinary family.
public struct DownloadRunProgress: Equatable, Sendable {
    /// The page numbers this run has covered so far: inherited work unioned with its landed pages.
    public let creditedPageIndices: Set<Int>

    public init(creditedPageIndices: Set<Int>) {
        self.creditedPageIndices = creditedPageIndices
    }

    /// The set's size, which is the badge's numerator while this value stands. The SET is the one
    /// definition and the count is its size, so the header's number and the page groups' membership
    /// cannot describe different work.
    public var creditedPageCount: Int {
        creditedPageIndices.count
    }
}
