/// The page files a working folder was found to hold, together with the two things `pages` alone
/// cannot say: whether the folder could be listed at all, and which of the files it did list the
/// per-file probe could not answer for.
///
/// All three members exist for one consumer. `pages` alone cannot tell "this folder holds none of
/// the manifest's pages" apart from "this folder could not be read", nor "this page's file is gone"
/// apart from "this page's file is there and unprobeable". Every non-destructive caller is entitled
/// to collapse both pairs — a probe that finds nothing re-fetches, which is harmless either way —
/// but the working-seed reconciliation destroys recorded content hashes on that answer, and
/// destroying state on a non-answer is what G-15-9 and then G-15-13 reported.
///
/// **"Non-destructive" is a property of the ROUTE, not of the call (G-15-19).** A caller may
/// collapse the pairs only if its output can never become the input of a destructive decision — in
/// this folder or in any other, one step later or ten. `materializeRepairSeed` read as such a
/// caller and was not one: it collapsed the pairs while scanning a SOURCE folder, and the pages it
/// therefore did not copy became positive absences in the DESTINATION folder's own entirely honest
/// scan, where nothing downstream could recover the distinction. A caller whose answer crosses a
/// folder boundary must carry the classification with it, not the collapse.
///
/// - `scanSucceeded` answers at the DIRECTORY level: false means the enumeration itself failed, so
///   the whole answer is a non-answer (G-15-9).
/// - `unprobedPages` answers one level down, PER FILE: a claimed page whose file the enumeration
///   did list but whose probe could not classify (G-15-13). A page here is neither usable nor
///   positively absent, so it may be re-fetched but never blanked.
/// - `rejectedPageRelativePaths` answers at the same per-file level, on the opposite side: a claimed
///   page whose file the enumeration listed and the probe POSITIVELY refused — zero bytes, not a
///   regular file, or empty on a content read — and which is still on disk when the scan returns
///   (CR-01).
///
/// They are kept apart rather than collapsed deliberately: they are answers to different questions
/// at different granularities, the reconciliation consumes them independently, and merging them
/// would re-conflate exactly the levels those gaps separated.
///
/// **Why the rejected pages need an identity of their own, and why the identity is conditional on
/// the file SURVIVING.** A rejection used to be indistinguishable from an absence here, and that was
/// self-consistent only because the probe deleted the file it rejected: the page really had no file
/// by the time anyone read the answer. A caller that may not mutate — validation, before its own
/// guard has authorized anything — gets the same classification with the file left in place, and for
/// that caller "not in `pages`" would silently mean two different things: a page with nothing on
/// disk, and a page with a refuted file still on disk. The first is blankable on its own; the second
/// must have its file removed in the same authorized act, or the record ends up blank beside bytes
/// that `finalizeDownload`'s hash merge would re-record as truth (D-SSOT-04).
///
/// **So membership means "refuted AND still there", and a DISCARDING caller reaches it by two
/// routes rather than one (WR-02).** Its housekeeping deletion may have FAILED, which reports the
/// page here and gives it the same protection the non-discarding caller gets, arrived at from the
/// other direction. Or the refusal may have come from the exit that never deletes at all: when
/// `attributesOfItem` throws, `probeAssetFile` falls back to `probeAssetFileContent`, and an
/// immediate end-of-file there is a positive empty-content determination reported as
/// `.rejected(fileRemains: true)` UNCONDITIONALLY — deliberately, because metadata never confirmed
/// a zero-byte regular file, so the deletion the metadata path performs is not warranted for it.
///
/// That second route is why the sentence this paragraph replaced was false. It claimed a discarding
/// caller "reports nothing here … which keeps every pre-existing caller byte for byte", and the
/// consequence of believing it was not cosmetic: a page refused through the content read kept its
/// recorded hash beside its refuted bytes on every AUTOMATIC route, because the only remover was
/// the user-initiated validate pass. Both blanking entry points now classify, authorize and remove
/// in that order, so a surviving refutation is either removed under the same guard that licensed
/// the blanking of its hash, or kept whole — hash and file together.
public struct PageFileScan: Equatable, Sendable {
    public let pages: [Int: String]
    public let scanSucceeded: Bool
    public let unprobedPages: Set<Int>
    public let rejectedPageRelativePaths: [Int: String]

    /// - Parameter rejectedPageRelativePaths: defaulted, so the one place that rebuilds a scan from
    ///   another scan's parts stays source-compatible; that site threads the real value through
    ///   rather than taking the default.
    public init(
        pages: [Int: String],
        scanSucceeded: Bool,
        unprobedPages: Set<Int>,
        rejectedPageRelativePaths: [Int: String] = [:]
    ) {
        self.pages = pages
        self.scanSucceeded = scanSucceeded
        self.unprobedPages = unprobedPages
        self.rejectedPageRelativePaths = rejectedPageRelativePaths
    }
}
