import AppModels
import Foundation
import Testing

// MARK: - The Generated State Family

// The generated family lives beside `DownloadManifestSSOTInvariantTests` rather than inside it
// because it is DATA the three property families read, and it grows with every regime phase 15
// establishes while the three tests do not. Splitting it out at the 1000-line limit kept the
// alternative — trimming a regime, or thinning a case's recorded reasoning — off the table, which is
// the wrong thing to trade for line count in the one suite whose whole job is covering the state
// space.

/// One reachable arrangement of (manifest claim × disk reality × validation history × queue
/// membership × process boundary), named so a failing assertion reports which regime produced it.
///
/// A named table rather than randomness: reproducibility beats volume for a standing falsifier, and
/// a case that fails must be re-runnable exactly. Every combination this table omits is omitted
/// because production choreography cannot reach it, and each omission is recorded in the plan's
/// summary with its reason — an unreachable shape documented is a boundary pinned.
///
/// The expectations are carried per case ON PURPOSE. A property suite whose expected values were
/// themselves derived would be comparing a derivation with itself; the piecewise table is what makes
/// each regime's own value a stated claim rather than a computed echo.
struct SSOTStateCase: Sendable, CustomTestStringConvertible {
    /// The classification family 3 derives from a live record, kept separate from `ForwardRegime` so
    /// the table's claim about a case and the derivation from the staged state are two statements
    /// that have to agree rather than one restated.
    enum RegimeKind: Sendable, Equatable {
        case terminalComplete
        case inMotion
        case nonTerminalIncomplete
    }

    /// What a state offers as a way forward, which is the classification family 3 is about.
    enum ForwardRegime: Sendable, Equatable {
        /// The record claims every page it needs and carries no operation-level signal. Terminal for
        /// the no-dead-end property: it is not asking for work.
        case terminalComplete
        /// Already moving — `.active` or `.queued`.
        case inMotion
        /// The record reads incomplete, or an operation-level entry stands over it. Must have a
        /// forward affordance that SUCCEEDS when driven, landing `.queued` under `queuedMode`.
        case nonTerminalIncomplete(queuedMode: DownloadStartMode)

        var kind: RegimeKind {
            switch self {
            case .terminalComplete: .terminalComplete
            case .inMotion: .inMotion
            case .nonTerminalIncomplete: .nonTerminalIncomplete
            }
        }
    }

    enum ExternalMutation: Sendable, Equatable {
        case deleteFile(page: Int)
        case corruptFile(page: Int)
        /// A file appearing where the app never put one — the opposite direction from a deletion,
        /// and the only external mutation available to a gallery with nothing on disk.
        case plantFile(page: Int)
        /// A claimed page's file truncated to ZERO bytes: still present, still listed, and the only
        /// mutation the asset probe positively REJECTS rather than yields or fails to classify.
        /// That rejection used to carry a deletion on every read, which is what makes this the one
        /// mutation that can prove a display read does not mutate.
        case truncateFile(page: Int)
    }

    enum PostMutationSensing: Sendable, Equatable {
        /// The record already states what a pass would find, so Validate is not offered at all.
        case gateClosed
        /// The pass classified every claimed page and wrote the correction they licensed, so the
        /// record states the finding by itself and the operation-level entry is dropped.
        case reconciled(completedPageCount: Int)
        /// The pass wrote nothing durable and kept its entry — the wholesale guard refusing, or a
        /// pass whose positive evidence set is empty. Nothing displayed moves either way.
        case refused
    }

    struct RelaunchReading: Sendable, Equatable {
        let displayStatus: DownloadDisplayStatus
        let completedPageCount: Int
    }

    let name: String
    let gid: String
    let pageCount: Int
    /// The manifest claims pages `1...claimedPageCount`, which is the shape `SessionGallery` writes.
    let claimedPageCount: Int
    let stagedPageFiles: [Int]
    /// Corrupted after the intact pages are hashed, so the file is present and probe-usable while
    /// only its CONTENT answer changes.
    let corruptedPageFiles: [Int]
    /// Replaced by a dangling symlink after the intact pages are hashed, so the listing yields the
    /// entry while the per-file probe classifies nothing at all — `PageFileScan.unprobedPages`,
    /// which is a different non-answer from `corruptedPageFiles`' readable-but-refuted bytes and
    /// from a content read that throws.
    let unprobeablePageFiles: [Int]
    let runsValidation: Bool
    let resumesThroughTogglePause: Bool
    let expectedDisplayStatus: DownloadDisplayStatus
    let expectedCompletedPageCount: Int
    let expectedPageStatuses: [DownloadPageStatus]
    let expectedRegime: ForwardRegime
    /// nil where the process boundary is not meaningful for this case.
    let relaunchReading: RelaunchReading?
    let externalMutations: [ExternalMutation]
    let expectedSensing: PostMutationSensing

    var testDescription: String { name }
}

extension SSOTStateCase {
    static let all: [SSOTStateCase] = [
        // Complete claim, disk intact, never validated. The baseline both other complete-claiming
        // cases are read against, and family 3's terminal negative boundary.
        .init(
            name: "completeRecordIntactFiles",
            gid: "216001",
            pageCount: 3,
            claimedPageCount: 3,
            stagedPageFiles: [1, 2, 3],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: false,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .completed,
            expectedCompletedPageCount: 3,
            expectedPageStatuses: [.downloaded, .downloaded, .downloaded],
            expectedRegime: .terminalComplete,
            relaunchReading: .init(displayStatus: .completed, completedPageCount: 3),
            externalMutations: [.deleteFile(page: 1), .corruptFile(page: 3)],
            // Absent {1} ∪ mismatched {3} = 2 of 3 claimed, under the wholesale guard, so the
            // reconciliation is licensed and page 2 alone survives it.
            expectedSensing: .reconciled(completedPageCount: 1)
        ),
        // The G-15-5 window itself, pre-validate: the record claims complete while files are gone.
        // The claim is what every display shows, deliberately and consistently.
        .init(
            name: "completeClaimWithMissingFilesNeverValidated",
            gid: "216002",
            pageCount: 3,
            claimedPageCount: 3,
            stagedPageFiles: [1, 3],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: false,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .completed,
            expectedCompletedPageCount: 3,
            expectedPageStatuses: [.downloaded, .downloaded, .downloaded],
            expectedRegime: .terminalComplete,
            relaunchReading: .init(displayStatus: .completed, completedPageCount: 3),
            externalMutations: [.deleteFile(page: 1), .plantFile(page: 2)],
            // Absent {1} ∪ mismatched {2, the planted file whose bytes match no recorded hash} = 2
            // of 3 claimed; page 3 is verified and survives.
            expectedSensing: .reconciled(completedPageCount: 1)
        ),
        // The presence arm's durable outcome (D-G5B-01), reached by running the sensor.
        .init(
            name: "durableAfterValidatingAMissingPage",
            gid: "216003",
            pageCount: 3,
            claimedPageCount: 3,
            stagedPageFiles: [1, 3],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: true,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .inactive,
            expectedCompletedPageCount: 2,
            expectedPageStatuses: [.downloaded, .pending, .downloaded],
            expectedRegime: .nonTerminalIncomplete(queuedMode: .repair),
            relaunchReading: .init(displayStatus: .inactive, completedPageCount: 2),
            externalMutations: [.deleteFile(page: 1), .corruptFile(page: 3)],
            expectedSensing: .gateClosed
        ),
        // The content arm's durable outcome (D-SSOT-01): the same end state reached from
        // present-but-refuted bytes, with the refuted file removed.
        .init(
            name: "durableAfterValidatingCorruptBytes",
            gid: "216004",
            pageCount: 3,
            claimedPageCount: 3,
            stagedPageFiles: [1, 2, 3],
            corruptedPageFiles: [2],
            unprobeablePageFiles: [],
            runsValidation: true,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .inactive,
            expectedCompletedPageCount: 2,
            expectedPageStatuses: [.downloaded, .pending, .downloaded],
            expectedRegime: .nonTerminalIncomplete(queuedMode: .repair),
            relaunchReading: .init(displayStatus: .inactive, completedPageCount: 2),
            externalMutations: [.deleteFile(page: 1), .plantFile(page: 2)],
            expectedSensing: .gateClosed
        ),
        // The refusal regime (D-SSOT-02): every claimed page would be blanked at once, so the
        // irreversibility defence refuses entirely and the operation-level entry is what stands.
        .init(
            name: "refusedWholesaleAfterValidating",
            gid: "216005",
            pageCount: 2,
            claimedPageCount: 2,
            stagedPageFiles: [],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: true,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .error,
            expectedCompletedPageCount: 2,
            expectedPageStatuses: [.downloaded, .downloaded],
            expectedRegime: .nonTerminalIncomplete(queuedMode: .repair),
            // The documented residual, pinned rather than hidden: the entry is session-scoped and
            // the refusal preserved the record, so a fresh process reads this gallery `.completed`.
            relaunchReading: .init(displayStatus: .completed, completedPageCount: 2),
            externalMutations: [.plantFile(page: 1)],
            // Absent {2} ∪ mismatched {1} still covers both claimed pages, so it refuses again.
            expectedSensing: .refused
        ),
        // An honestly-incomplete record that was never complete — the ordinary paused download.
        .init(
            name: "healthyPartialClaimInactive",
            gid: "216006",
            pageCount: 3,
            claimedPageCount: 1,
            stagedPageFiles: [1],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: false,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .inactive,
            expectedCompletedPageCount: 1,
            expectedPageStatuses: [.downloaded, .pending, .pending],
            expectedRegime: .nonTerminalIncomplete(queuedMode: .repair),
            relaunchReading: .init(displayStatus: .inactive, completedPageCount: 1),
            externalMutations: [.deleteFile(page: 1), .plantFile(page: 2)],
            expectedSensing: .gateClosed
        ),
        // The empty claim: nothing recorded and nothing on disk. Present because a zero-completed
        // record is the arithmetic edge every page-count site in this module guards (G-15-14).
        .init(
            name: "emptyClaimNothingOnDisk",
            gid: "216007",
            pageCount: 2,
            claimedPageCount: 0,
            stagedPageFiles: [],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: false,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .inactive,
            expectedCompletedPageCount: 0,
            expectedPageStatuses: [.pending, .pending],
            expectedRegime: .nonTerminalIncomplete(queuedMode: .repair),
            relaunchReading: .init(displayStatus: .inactive, completedPageCount: 0),
            externalMutations: [.plantFile(page: 1)],
            expectedSensing: .gateClosed
        ),
        // Totality in the other direction: a file sitting beside a blank hash reads `.pending`, so
        // no display anywhere is counting files.
        .init(
            name: "strayFileBesideBlankHash",
            gid: "216008",
            pageCount: 3,
            claimedPageCount: 2,
            stagedPageFiles: [1, 2, 3],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: false,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .inactive,
            expectedCompletedPageCount: 2,
            expectedPageStatuses: [.downloaded, .downloaded, .pending],
            expectedRegime: .nonTerminalIncomplete(queuedMode: .repair),
            relaunchReading: .init(displayStatus: .inactive, completedPageCount: 2),
            externalMutations: [.deleteFile(page: 1), .corruptFile(page: 3)],
            expectedSensing: .gateClosed
        ),
        // Queue membership as a regime of its own, entered through `togglePause` — the production
        // path — rather than installed. In motion, so family 3 requires no drive of it.
        .init(
            name: "queuedPartialClaimThroughTogglePause",
            gid: "216009",
            pageCount: 3,
            claimedPageCount: 1,
            stagedPageFiles: [1],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: false,
            resumesThroughTogglePause: true,
            expectedDisplayStatus: .queued,
            expectedCompletedPageCount: 1,
            expectedPageStatuses: [.downloaded, .pending, .pending],
            expectedRegime: .inMotion,
            // Pruned deliberately: queue membership is in-memory session state by construction, so a
            // fresh coordinator over the same storage has an empty queue and reads this case's
            // underlying record — which `healthyPartialClaimInactive` already pins.
            relaunchReading: nil,
            externalMutations: [.deleteFile(page: 1), .plantFile(page: 2)],
            expectedSensing: .gateClosed
        ),
        // The coverage-gap regime: one claimed page blanks durably while another claimed page's
        // presence probe cannot answer at all. The pass therefore corrected what it established AND
        // kept the operation-level entry, which is what leaves the single sensor reachable for the
        // page nobody could answer for — `canValidateImageData`'s error disjunct is the only one a
        // record reading `.inactive` at 2 of 3 would satisfy.
        .init(
            name: "unprobeablePageHeldBesideAReconciledOne",
            gid: "216010",
            pageCount: 3,
            claimedPageCount: 3,
            stagedPageFiles: [2, 3],
            corruptedPageFiles: [],
            unprobeablePageFiles: [2],
            runsValidation: true,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .error,
            expectedCompletedPageCount: 2,
            expectedPageStatuses: [.pending, .downloaded, .downloaded],
            expectedRegime: .nonTerminalIncomplete(queuedMode: .repair),
            // The entry is session-scoped, and the correction was written: a fresh process reads the
            // honest record with nothing over it.
            relaunchReading: .init(displayStatus: .inactive, completedPageCount: 2),
            externalMutations: [.plantFile(page: 1)],
            // A file landing at the blanked page's path is not evidence about any CLAIMED page, so
            // the pass positively establishes nothing, blanks nothing and keeps the entry.
            expectedSensing: .refused
        ),
        // The read-must-not-mutate regime: a claimed page's file truncated to zero bytes is the one
        // external mutation the asset probe positively REJECTS, and a rejection used to carry a
        // deletion on every path that classified it — including the index rescan and the inspector's
        // own resource resolution. Nothing displayed may move for it either, because the record
        // still claims the page.
        .init(
            name: "truncatedClaimedPageSurvivesEveryDisplayRead",
            gid: "216011",
            pageCount: 3,
            claimedPageCount: 3,
            stagedPageFiles: [1, 2, 3],
            corruptedPageFiles: [],
            unprobeablePageFiles: [],
            runsValidation: false,
            resumesThroughTogglePause: false,
            expectedDisplayStatus: .completed,
            expectedCompletedPageCount: 3,
            expectedPageStatuses: [.downloaded, .downloaded, .downloaded],
            expectedRegime: .terminalComplete,
            relaunchReading: .init(displayStatus: .completed, completedPageCount: 3),
            externalMutations: [.truncateFile(page: 2)],
            // Validate is the one path entitled to act on the rejection: it discards the empty file,
            // reads page 2 as the positive absence that leaves, and blanks exactly it.
            expectedSensing: .reconciled(completedPageCount: 2)
        )
    ]
}
