import AppModels
import BackgroundProcessingClient
import Foundation
import IssueReporting
import LibraryClient
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

public typealias ScheduledDownloadOperation = @Sendable () async -> Void

public enum ScheduledDownloadRunResult: Equatable, Sendable {
    case ranOperation
    case skippedOperation
}

public struct DownloadTaskRunner: Sendable {
    public var beforeActiveTaskCheck: @Sendable () async -> Void
    public var recordScheduledGallery: @Sendable (String) async -> Void
    public var runScheduledDownload: @Sendable (
        String,
        @escaping ScheduledDownloadOperation
    ) async -> ScheduledDownloadRunResult
    public var beforeFailurePersistence: @Sendable () async -> Void

    public init(
        beforeActiveTaskCheck: @escaping @Sendable () async -> Void = {},
        recordScheduledGallery: @escaping @Sendable (String) async -> Void = { _ in },
        runScheduledDownload: @escaping @Sendable (
            String,
            @escaping ScheduledDownloadOperation
        ) async -> ScheduledDownloadRunResult = { _, operation in
            await operation()
            return .ranOperation
        },
        beforeFailurePersistence: @escaping @Sendable () async -> Void = {}
    ) {
        self.beforeActiveTaskCheck = beforeActiveTaskCheck
        self.recordScheduledGallery = recordScheduledGallery
        self.runScheduledDownload = runScheduledDownload
        self.beforeFailurePersistence = beforeFailurePersistence
    }
}

/// The brain of the download subsystem: the in-memory read model (`downloadIndex`,
/// `userFolders`) fused with scheduling (`activeGalleryID`, `activeTask`, queued
/// modes / selections). It is one of three types split by invariant ownership,
/// alongside `DownloadStore` (pure disk I/O) and
/// `DownloadObserverHub` (observer fan-out), all behind the unchanged `DownloadClient`
/// facade. Read model and scheduling stay fused on purpose: only one gallery downloads at
/// a time (E-Hentai rate-limits gallery downloads, so concurrency is unwanted), and
/// scheduling reads and writes the index on every step, so splitting them would buy nothing
/// and reintroduce the cross-actor races this single actor exists to prevent.
public actor DownloadCoordinator {
    public static let retryLimit = 3
    public static let progressFlushPageInterval = 8
    public static let progressFlushMinimumInterval: TimeInterval = 0.4
    public static let responseInspectionPrefixLength = 4096
    public static let kokomadeImageURLSuffixes = [
        "exhentai.org/img/kokomade.jpg"
    ]
    public static let quotaExceededImageURLSuffixes = [
        "exhentai.org/img/509.gif",
        "ehgt.org/g/509.gif"
    ]

    public struct PageResult: Sendable {
        public let index: Int
        public let relativePath: String
        public let imageURL: URL?

        public init(index: Int, relativePath: String, imageURL: URL?) {
            self.index = index
            self.relativePath = relativePath
            self.imageURL = imageURL
        }
    }

    public struct PageFailure: Error, Sendable {
        public let index: Int
        public let relativePath: String?
        public let error: AppError

        public init(index: Int, relativePath: String?, error: AppError) {
            self.index = index
            self.relativePath = relativePath
            self.error = error
        }
    }

    public struct DownloadBatchResult: Sendable {
        public let pages: [PageResult]
        public let failedPages: [PageFailure]
        public init(
            pages: [PageResult],
            failedPages: [PageFailure]
        ) {
            self.pages = pages
            self.failedPages = failedPages
        }
    }

    public enum PageTaskOutcome: Sendable {
        case success(PageResult)
        case failure(PageFailure)
        case cancelled
    }

    /// One run's own measurement of the page progress it covers for its gallery — the quantity the
    /// session numerator reads for as long as the run is in flight.
    ///
    /// This value exists so the numerator can be MEASURED where it used to be inferred. The index
    /// record reads the gallery's cumulative on-disk state, which is a different quantity from the
    /// current run's progress whenever the two disagree — most sharply for the refusal family,
    /// where `reconcileWorkingManifestAgainstPageFiles` hands a lying complete manifest back
    /// verbatim and the record reads N-of-N for an entire re-download. Every earlier basis rule
    /// reconstructed run progress FROM that record and corrected the inference — a trust set, a
    /// subtracted page debt, a guarded subtraction — and each correction's boundary became the
    /// next defect's home: the pinned-zero family (G-15-5, G-15-23, G-15-26), the pinned-ceiling
    /// family (G-15-30), and the non-monotonic crossover of the guarded form (G-15-34). Measuring
    /// removes the reconstruction instead of correcting it again: while a run is live, its
    /// gallery's credit never consults the record.
    ///
    /// `creditedPageCount` is monotone by construction — `inheritedPages` is fixed at the
    /// announcement and `outstandingPages` only ever shrinks, at the single point every landed
    /// page passes — and continuous across the record completing, because no part of it reads the
    /// record. Those are the two properties whose absence G-15-34 named, held structurally rather
    /// than argued branch by branch.
    ///
    /// **`inheritedPages` is valued by the best evidence the preparation's one scan produced, and
    /// only positive absence zeroes a page** — the same positive-signal rule the blanking loop
    /// follows, applied to credit. A page outside the run's own to-do list is inherited when the
    /// scan yielded its file, when the scan could not answer for it (an unprobeable file, or a
    /// listing that failed outright) while the record claims it, and never when a successful
    /// listing positively did not yield it. One asymmetry is deliberate: a COMPLETE-reading record
    /// undergoing a run additionally forfeits the claims the run was asked to fetch, because a
    /// repair or retry of a "finished" gallery is itself the assertion that those claimed pages
    /// are bad — which is the verifier-prescribed intersection, subtract only the owed pages the
    /// record still claims. An incomplete record's claims carry no such refutation: its to-do
    /// overlap comes only from the scan's own failure, so the claims stand.
    struct RunProgressBasis: Equatable, Sendable {
        /// Pages the run inherits rather than performs, per the evidence rule above. May overlap
        /// the to-do list when a claim stood on a failed scan; the credited count unions rather
        /// than adds, so the overlap can never count twice.
        let inheritedPages: Set<Int>
        /// The run's own to-do list at preparation, before any page landed.
        let initialPendingPages: Set<Int>
        /// The subset of the to-do list that has not landed yet. It shrinks at every manifest page
        /// flush by exactly the pages that flush recorded, and never grows.
        var outstandingPages: Set<Int>

        /// What the run has covered so far: inherited work plus its own landed pages, as one set.
        var creditedPageCount: Int {
            inheritedPages.union(initialPendingPages.subtracting(outstandingPages)).count
        }
    }

    public struct RepairSeed: Sendable {
        public let folderURL: URL
        public let manifest: DownloadManifest
        public init(
            folderURL: URL,
            manifest: DownloadManifest
        ) {
            self.folderURL = folderURL
            self.manifest = manifest
        }
    }

    public struct WorkingSeed: Sendable {
        public let folderURL: URL
        public let manifest: DownloadManifest
        public let existingPages: [Int: String]
        public let coverRelativePath: String?
        /// The claimed pages the preparation's one scan could not answer for — the destination's
        /// own unprobeable files plus the classifications a repair-seed copy carried (G-15-19).
        /// Surfaced so the announcement's inherited-work rule reads the same probe the blanking
        /// rule read, instead of re-deriving evidence from a second scan.
        public let unprobedPages: Set<Int>
        /// Whether the preparation's directory listing itself succeeded. False means the whole
        /// scan is a non-answer, which the announcement treats exactly as the reconciliation
        /// does: no positive signal, so recorded claims stand.
        public let scanSucceeded: Bool
        public init(
            folderURL: URL,
            manifest: DownloadManifest,
            existingPages: [Int: String],
            coverRelativePath: String? = nil,
            unprobedPages: Set<Int> = [],
            scanSucceeded: Bool = true
        ) {
            self.folderURL = folderURL
            self.manifest = manifest
            self.existingPages = existingPages
            self.coverRelativePath = coverRelativePath
            self.unprobedPages = unprobedPages
            self.scanSucceeded = scanSucceeded
        }
    }

    /// The working seed a run starts from, paired with the pages that run will actually fetch.
    ///
    /// One value rather than two returns, because the two halves must be derived ONCE and travel
    /// together. `prepareWorkingSeedAnnouncingProgress` gates its trust admission on the pending
    /// list being non-empty and `performDownload` feeds the very same list to the page loop, so a
    /// second evaluation at the caller is precisely the shape that lets a later fix move one and not
    /// the other — granting trust for a set the loop never fetches (G-15-27). The count of
    /// evaluations is pinned by `DownloadSourceInventoryTests`, not left to review.
    ///
    /// A named struct rather than a labelled tuple: it crosses a public testing forwarder, and this
    /// module's `labeled_tuple_elements` lint rule bans a multi-element tuple type in a return
    /// position outright. It sits beside `WorkingSeed` because it is that value plus one field.
    public struct PreparedWorkingRun: Sendable {
        public let workingSeed: WorkingSeed
        public let pendingPageIndices: [Int]
        public init(
            workingSeed: WorkingSeed,
            pendingPageIndices: [Int]
        ) {
            self.workingSeed = workingSeed
            self.pendingPageIndices = pendingPageIndices
        }
    }

    public enum ResolvedSource: Sendable {
        case normal([Int: URL])
        case mpv(key: String, imageKeys: [Int: String])
    }

    public struct ResolvedImageSource: Sendable {
        public let imageURL: URL
        public var mpvSkipServerIdentifier: String?
        public init(
            imageURL: URL,
            mpvSkipServerIdentifier: String? = nil
        ) {
            self.imageURL = imageURL
            self.mpvSkipServerIdentifier = mpvSkipServerIdentifier
        }
    }

    public struct PartialDownloadError: Error, Sendable {
        public let failedPages: [PageFailure]
        public init(
            failedPages: [PageFailure]
        ) {
            self.failedPages = failedPages
        }
    }

    public struct IncompleteDownloadError: Error, Sendable {
        public let missingPageIndices: [Int]
        public init(
            missingPageIndices: [Int]
        ) {
            self.missingPageIndices = missingPageIndices
        }
    }

    public struct FailureContext: Sendable {
        public let gid: String
        public let originalDownload: DownloadedGallery
        public let mode: DownloadStartMode
        public init(
            gid: String,
            originalDownload: DownloadedGallery,
            mode: DownloadStartMode
        ) {
            self.gid = gid
            self.originalDownload = originalDownload
            self.mode = mode
        }
    }

    public struct ProgressFlushContext: Sendable {
        public let gid: String
        public let folderURL: URL

        public init(gid: String, folderURL: URL) {
            self.gid = gid
            self.folderURL = folderURL
        }
    }

    public struct PageDownloadContext: Sendable {
        public let payload: DownloadRequestPayload
        public let options: DownloadRequestOptions
        public let source: ResolvedSource?
        public let folderURL: URL
        public init(
            payload: DownloadRequestPayload,
            options: DownloadRequestOptions,
            source: ResolvedSource? = nil,
            folderURL: URL
        ) {
            self.payload = payload
            self.options = options
            self.source = source
            self.folderURL = folderURL
        }
    }

    public struct CacheRestoreSource: Sendable {
        public let gid: String
        public let token: String
        public let cacheURLs: [URL?]
        public let referenceURL: URL?
        public let imageURL: URL?
        public init(
            gid: String,
            token: String,
            cacheURLs: [URL?],
            referenceURL: URL? = nil,
            imageURL: URL? = nil
        ) {
            self.gid = gid
            self.token = token
            self.cacheURLs = cacheURLs
            self.referenceURL = referenceURL
            self.imageURL = imageURL
        }
    }

    public struct CaptureTargetResult: Sendable {
        public let folderURL: URL
        public let preferredRelativePath: String?
        public init(
            folderURL: URL,
            preferredRelativePath: String? = nil
        ) {
            self.folderURL = folderURL
            self.preferredRelativePath = preferredRelativePath
        }
    }

    public struct HTMLResponseContext {
        public let prefixData: Data
        public let fullData: Data?
        public let response: URLResponse
        public let requestURL: URL?
        public let mimeType: String?
        public init(
            prefixData: Data,
            fullData: Data? = nil,
            response: URLResponse,
            requestURL: URL? = nil,
            mimeType: String? = nil
        ) {
            self.prefixData = prefixData
            self.fullData = fullData
            self.response = response
            self.requestURL = requestURL
            self.mimeType = mimeType
        }
    }

    public struct DownloadExecutionContext: Sendable {
        public let payload: DownloadRequestPayload
        public let options: DownloadRequestOptions
        public let existingDownload: DownloadedGallery
        public init(
            payload: DownloadRequestPayload,
            options: DownloadRequestOptions,
            existingDownload: DownloadedGallery
        ) {
            self.payload = payload
            self.options = options
            self.existingDownload = existingDownload
        }
    }

    public struct FinalizeContext: Sendable {
        public let coverRelativePath: String?
        public let batchResult: DownloadBatchResult
        public let existingDownload: DownloadedGallery
        public init(
            coverRelativePath: String? = nil,
            batchResult: DownloadBatchResult,
            existingDownload: DownloadedGallery
        ) {
            self.coverRelativePath = coverRelativePath
            self.batchResult = batchResult
            self.existingDownload = existingDownload
        }
    }

    public let storage: DownloadStore
    public let urlSession: URLSession
    public let pageDownloader: DownloadPageDownloader
    public let backgroundTaskStore: DownloadBackgroundTaskStore
    /// Starts and drives the continued-processing session that keeps a backgrounded queue running.
    ///
    /// `DownloadClient.live` supplies the live value directly when it constructs this manager, and
    /// tests supply clients of their own through the same initializer. The no-argument client
    /// carries macro-generated unimplemented endpoints that report an issue when called.
    ///
    /// Direct composition here is intentional: download-start calls flow synchronously from user
    /// actions into this actor, and this is the only place that knows real queue progress.
    public let backgroundProcessingClient: BackgroundProcessingClient
    public let storedCookiesProvider: @Sendable (URL) -> [HTTPCookie]
    public let libraryClient: LibraryClient
    /// Supplies the latest runtime settings immediately before a queued download starts.
    ///
    /// Options are not stored in manifests or request payloads so settings changed while
    /// a gallery is queued apply to the eventual detail fetch and page workers.
    public let downloadOptionsProvider: @Sendable () async -> DownloadRequestOptions
    public let queueStore: DownloadQueueStore
    public let taskRunner: DownloadTaskRunner
    /// Reads the wall clock the progress-flush throttle compares against, defaulting to the
    /// real one. Injectable so a test can freeze it: with a frozen clock the throttle's
    /// elapsed-time branch is provably dead, leaving the page-count branch as the only
    /// trigger, which is what makes a coalescing assertion independent of machine load.
    public let now: @Sendable () -> Date
    public let observerHub = DownloadObserverHub()
    /// Write-through cache of the on-disk download tree and the read authority between the
    /// explicit scan boundaries (see `indexedDownload(gid:)`). The filesystem stays the
    /// source of truth, so this is rebuilt from disk only at those boundaries, never on a
    /// hot lookup.
    public var downloadIndex = [String: DownloadFolderRecord]()
    public var hasLoadedIndex = false
    public var userFolders = [String]()
    /// Transient, session-scoped status: deliberately in-memory only, never written to disk.
    /// Download-level errors, per-page failures, validation results, and the update-available
    /// set are status *about* a download, not durable properties of it; they are cheap to
    /// re-derive and re-derivation yields the *current* truth (e.g. a lifted quota simply
    /// succeeds on the next attempt). Durable facts (downloaded pages, hashes, metadata)
    /// live in the manifest. The accepted cost is that after relaunch a failed download
    /// surfaces as inactive ("Paused") until its error re-surfaces on the next manual retry.
    public var downloadErrors = [String: DownloadFailure]()
    /// An **operation-level** signal about the last validation, and nothing else (D-SSOT-05).
    ///
    /// An entry says one thing: that pass could not produce trustworthy evidence for every page the
    /// record claims. It never says anything about the record. Wherever the pass did classify every
    /// claimed page, the correction it licensed is written into the manifest — durable,
    /// relaunch-stable, and the single basis the count, the status and the start gates all read —
    /// and this dictionary is cleared, because the record can now state the finding by itself. Both
    /// kinds of positive per-page evidence go that way: a claimed page whose file a successful
    /// listing did not yield, and a claimed page whose bytes were read and disagreed with the
    /// recorded hash (D-SSOT-01).
    ///
    /// What keeps an entry is therefore an operation-level property, never one of the gallery's: the
    /// directory listing failed, a page's bytes could not be probed or read at all, the file a
    /// refuted page's correction depended on could not be removed, the all-or-nothing guard refused
    /// the whole reconciliation, or the manifest write itself threw. In each the pass has a question
    /// it could not answer, and a question the manifest legitimately cannot record is exactly what
    /// session-scoped state is for.
    ///
    /// Clearing is load-bearing rather than tidy: this dictionary outranks the queue and the
    /// manifest in `displayStatus`, so an entry left behind would pin `.error` over an honest record
    /// and leave it unstartable — which is why anything that enqueues must clear it at or before the
    /// enqueue.
    public var validationErrors = [String: DownloadFailure]()
    public var failedPageErrors = [String: [Int: PageFailure]]()
    public var updatedGalleryIDs = Set<String>()
    public var queuedModes = [String: DownloadStartMode]()
    public var queuedPageSelections = [String: [Int]]()
    /// ACTIVE-OWNERSHIP CONVERGENCE
    ///
    /// Every path that clears `activeGalleryID` or `activeTask` must notify observers and reach
    /// `scheduleNextIfNeeded()` before returning on every exit, including failure. Once ownership
    /// is cleared, `finishActiveTaskIfOwned` rejects the cancelled task's deferred cleanup, so the
    /// clearing path owns the queue's last scheduling opportunity. Missing it leaves downloads
    /// silently stuck and a continued-processing session with no progress.
    ///
    /// Forbidden: returning after ownership is cleared, or converging while the affected gallery
    /// remains scheduling-blocked. Clearing paths release their block before convergence.
    ///
    /// Reachable by design: convergence can suspend while another user action lands; two racing
    /// failures can converge twice; and the scheduler can select the still-queued gallery whose
    /// removal failed. These are existing, idempotent scheduling windows protected by the
    /// scheduler's ownership and generation guards. A failed expiration pause also converges
    /// unconditionally: its surrounding exits already do, the unpaused gallery must not be
    /// stranded, and this schedules work without starting a new continued-processing session.
    public var activeGalleryID: String?
    public var activeTask: Task<Void, Never>?
    public var activeTaskGeneration = 0
    /// Stamps the most recent user action that wrote queue intent for each gallery.
    ///
    /// `activeTaskGeneration` is the established scheduled-task stamp; this generation instead
    /// names user intent. An expiration-owned pause needs both identities and its session id to
    /// prove that its work is still current. Missing entries are generation zero and remain
    /// comparable forever, so this dictionary needs no cleanup path.
    public var queueIntentGenerations = [String: Int]()
    /// How many live operations currently hold a scheduling block on each gallery.
    ///
    /// **G-15-8 — no exit may leave a gid blocked or the queue unconverged.** Every operation that
    /// blocks pairs each of its exits with exactly one `releaseScheduling(gid:)` followed by
    /// convergence (`notifyObservers()` then `scheduleNextIfNeeded()`). `commitPause` splits that
    /// convergence by exit CATEGORY rather than owning all of it or delegating all of it: every
    /// `.settled` exit releases and then converges inline, and every `.superseded` exit releases and
    /// hands the convergence one frame up to `pause(gid:expiration:)`, which converges on every
    /// `.superseded` value it receives. Phrased as a rule over the two outcomes, not as a count of
    /// sites: its exits are a set someone will add to, and a new one is covered the moment it picks
    /// an outcome, with nothing here to drift out of date. A gid left blocked is invisible to every
    /// `schedulableDownloads()` reader — the pending-work gate, the continued-session card's snapshot
    /// and the expiration sweep — because `isSchedulableDownload` fails on a held block before it
    /// asks anything else. `scheduleNextIfNeededCore` does not read through that function, but it
    /// applies the same predicate to its own queue-scoped read, so the blocked gid is skipped there
    /// too. A convergence landing inside that window can therefore declare the queue drained over
    /// work that is merely hidden, and an exit that releases without converging leaves the gallery
    /// queued and idle with no fallback tier to restart it (D-03).
    ///
    /// **WR-03 — a count, not a `Set`.** All four blocking operations suspend while holding the
    /// block and this actor is reentrant, so two operations on the same gallery routinely overlap.
    /// Under set membership the first to finish removed the entry and unblocked a gallery the
    /// second still held. A count is released per operation, so the block survives until its last
    /// holder is gone. Absence of a key — never a stored zero — means schedulable:
    /// `releaseScheduling(gid:)` removes the entry rather than storing zero, so the readers'
    /// `== nil` / `!= nil` tests cannot disagree with the count.
    var schedulingBlockedGalleryCounts = [String: Int]()
    /// Whether this coordinator currently believes a continued-processing session is live.
    ///
    /// Set together with `continuedSessionID` in the same synchronous run as the guard in
    /// `ensureContinuedSession()`, before that path's first suspension, so two callers racing the
    /// guard cannot both reach the start call. That is what it guards against: registering a
    /// second session under the same identifier terminates the app, and two live sessions would
    /// put two progress cards on screen. The client store carries an independent re-entry guard
    /// as a second line of defense behind it.
    ///
    /// It is rolled back, though — the teardown clears it — and `ensureContinuedSession()` suspends
    /// at the client start after setting it, so a concurrent caller can legitimately see it false
    /// while a start is still in flight. The flag alone therefore cannot say *which* session it
    /// refers to, and this actor is reentrant: that is what `continuedSessionID` is for.
    var hasLiveContinuedSession = false
    /// Identifies the session `hasLiveContinuedSession` refers to, minted per session by
    /// `ensureContinuedSession()` and nil exactly when no session is live.
    ///
    /// Stamping the session is what makes teardown and event delivery safe against staleness: a
    /// superseded session's trailing teardown routinely lands late, and on a reentrant actor a
    /// queue-mobilizing tap can legitimately have started a successor by then. It pairs with the
    /// client-side identity in `continuedClientSessionID`.
    var continuedSessionID: UUID?
    /// The client-side identity of the live continued-processing session.
    ///
    /// Recorded by `ensureContinuedSession()` only after its ownership re-check passes, nil while
    /// a start is still in flight and after teardown, and the only value the coordinator may pass
    /// to the client's completion verb.
    var continuedClientSessionID: UUID?
    /// Whether the session named by `continuedSessionID` owes a reconciliation after its client
    /// identity lands.
    ///
    /// Set only when a reconcile still owns the live coordinator session but cannot name the
    /// client session it would complete. The client's start verb suspends, so a queue drain that
    /// crosses that suspension is early rather than authoritative. The debt is cleared before it
    /// is discharged and whenever the session it belongs to is torn down.
    var continuedSessionNeedsReconciliation = false
    /// The task consuming the live session's event stream, nil exactly when no session is live.
    ///
    /// Awaiting it is how a suite settles an expiration exactly: the expiration handler's whole
    /// policy runs inside it. Suites reach it through `testingContinuedSessionTask()` rather than
    /// directly, which is what keeps this property module-internal like every other session-state
    /// declaration in this section: reaching one of them from a suite would widen its access for the
    /// test's sake, so each is reached through a testing forwarder instead. Stated as that rule
    /// rather than as a position in the list — an unchecked count is the shape this file has already
    /// had to correct.
    var continuedSessionTask: Task<Void, Never>?
    /// The monotonic floor under the numerator this session pushes to the card.
    ///
    /// Five writers, verified exhaustive at this HEAD by grepping every assignment to this property
    /// across `AppPackage/Sources/DownloadClient`:
    ///
    /// 1. `ensureContinuedSession`'s synchronous reset to zero, at the start of a session.
    /// 2. That same function's additive seed merge, once the client start returns.
    /// 3. `markContinuedSessionEnded`'s teardown zero, at the end of a session.
    /// 4. The re-latch at the end of every accepted `pushContinuedSessionProgress`.
    /// 5. The **D-G7-01** withdrawal inside `withdrawingCountedBasisMovement`, which gives back
    ///    exactly the portion of a deliberate basis movement the numerator was actually counting.
    ///    That bracket has four call sites — `prepareWorkingSeed`'s whole preparation and the
    ///    basis announcement in `prepareWorkingSeedAnnouncingProgress`, both in
    ///    `DownloadClient+ExecutionSupport.swift`, `writeInitialManifest`'s body in
    ///    `DownloadClient+PublicAPI.swift`, and the validate-time `blankingPass` in
    ///    `DownloadClient+PersistenceNormalize.swift` — but one implementation, so this writer is
    ///    one rule rather than a list of mechanisms. The count is owned by
    ///    `DownloadSourceInventoryTests`' bracket census rather than by this sentence, because the
    ///    floor census below cannot see it: it counts ASSIGNMENTS to this property, and the
    ///    bracket's single implementation keeps that at five however many callers it grows.
    ///
    /// The floor's own premise (why a deliberate movement must be excused rather than masked) is
    /// written on `pushContinuedSessionProgress`, and the withdrawal's exact-portion rule on the
    /// bracket itself. This list does not ask to be re-grepped: `DownloadSourceInventoryTests`
    /// asserts the same census per file and fails the build when a writer is added or removed, which
    /// is the difference between an inventory that is owned and one that was true once. An
    /// exhaustive-sounding inventory that source quietly answers with one more entry is what this
    /// phase has already lost rounds to.
    ///
    /// One deliberate transient: inside the client start's main-actor hop this value can read
    /// NEGATIVE. The reset has already run, so a withdrawal landing in that window leaves "zero
    /// minus corrections the seed has not yet absorbed", and the seed's merge is what folds them
    /// into the pre-hop snapshot. Elsewhere a negative value is inert — the push compares it
    /// against a `displayCompletedPageCount` that is never negative. A reader finding a negative
    /// value must not "fix" it by clamping the withdrawal: that silently re-opens the seed
    /// overwrite, which is the second half of G-15-6.
    ///
    /// Session-scoped: cleared when a session starts (writer 1) and when one ends (writer 3), so no
    /// floor survives into the next session. The rule and the inventory name the same two writers,
    /// which is what keeps them from drifting apart.
    var lastPushedCompletedPageCount = 0
    /// Pages this session finished for galleries that have since left the schedulable set.
    ///
    /// Added to both the numerator and the denominator of every later push, which is what stops a
    /// completed gallery from taking its own pages out of both sides of the fraction at once. The
    /// retirement rule itself (D-G2-01) is written down on
    /// `reconcileRetiredSessionPages(snapshot:)`, where it is implemented.
    ///
    /// Keyed by gallery rather than accumulated into a scalar, deliberately: a scalar could not be
    /// corrected when a paused gallery is resumed back into the queue, and would then count that
    /// gallery's finished pages twice — once in the ledger and once in the live sum.
    ///
    /// Session-scoped, like `lastPushedCompletedPageCount`: cleared when a session starts and when
    /// one ends, so no ledger survives into the next session.
    var retiredSessionPages = [String: Int]()
    /// The schedulable galleries the last snapshot counted, and how many pages each had finished at
    /// that moment.
    ///
    /// The ledger above is derived from this by difference: a gallery recorded here and absent from
    /// the next snapshot has departed. Observing membership at the point that already reads the
    /// schedulable set covers every departure path by construction — completion settle, the
    /// incomplete-error dequeue, pause, delete, the queued-work-item cancel and the expiration
    /// pause-all — rather than only the paths someone remembered to instrument.
    var observedSchedulablePages = [String: Int]()
    /// For each gallery whose RECORD this session has observed reading incomplete while it was
    /// schedulable, the QUEUE-INTENT GENERATION that observation belongs to.
    ///
    /// A pure observation map: its only writers are this session's own snapshot merges, which read
    /// `isIncomplete` and stamp `queueIntentGeneration(for:)` in the same actor-isolated read, and
    /// its only meaning is "the record honestly told this session it was mid-work, under THAT
    /// queue intent". It decides exactly one question — what a COMPLETE-reading record with no run
    /// in flight contributes (`sessionCreditedPages`). A gallery watched incomplete that now reads
    /// complete earned that movement through landed pages this session covered, so its count is
    /// real covered work and it counts and retires whole. One never watched incomplete is a redo
    /// target whose pages predate the session, so it counts zero — D-G4-01's queued window.
    ///
    /// **The generation is the whole of the key, and a bare gallery id was CR-02.** Observation is
    /// evidence about one queue intent, not a durable property of a gallery identifier. A gallery
    /// can complete, retire and be re-queued inside a single session — the queue-wide session is
    /// one session per D-06, and a keeper gallery holds it open — and every fresh queue intent
    /// (`performRetry`, `performRetryPages`, `resume`, `enqueue`) advances the generation before
    /// its snapshot is taken. Keyed by id alone, the predecessor's observation then credited the
    /// successor's untouched complete manifest at its full recorded count, so the card opened at
    /// the redo's own target before the run had announced a single page. Generation equality is
    /// the single invalidation mechanism: the mismatch is atomic from the actor's perspective, it
    /// touches no other gallery and no retirement ledger entry, and it needs no clear on any retry
    /// path — a per-path clear would be one more incomplete census to keep exhaustive.
    ///
    /// It used to be more than an observation. The pre-basis design seeded it from the run debts
    /// and withdrew members at run exits, because the credited-pages rule needed a trust grant to
    /// reach the refusal family at all — and that pollution is what made G-15-30 reachable: a
    /// granted membership unlocked a count the session never earned. `runProgressBases` is
    /// consulted ahead of this map now, so a live run's gallery never reaches the branch this map
    /// decides, and the refusal family — whose record never reads incomplete — structurally
    /// cannot enter it. Within one session and one generation a record moves from incomplete to
    /// complete only through landed pages, which is precisely the work the count describes, so the
    /// branch this map opens has no route to an unearned number.
    ///
    /// Session-scoped: emptied when a session starts and cleared when one ends. Nothing seeds it —
    /// a run in flight across a session start is credited through its basis, not through this map.
    var observedIncompleteSessionGenerations = [String: Int]()
    /// Each gallery's CURRENT RUN's own progress measurement, keyed by gallery identifier. The
    /// derivation for why a measurement rather than a corrected record inference lives on
    /// `RunProgressBasis` itself.
    ///
    /// **The lifetime rule.** An entry is recorded at the run's own preparation
    /// (`prepareWorkingSeedAnnouncingProgress`) when that run's pending page list is non-empty;
    /// its `outstandingPages` shrink at every manifest page flush (`flushManifestPageProgress`,
    /// the one point every landed page passes) by exactly the pages that flush recorded; it is
    /// read through the credited-pages definition the snapshot, the departure retirement, the
    /// run-exit freeze and the D-G7-01 withdrawal all share; and it is retired when the run ends,
    /// at `processDownload`'s `defer`, the one point every exit of a run passes through.
    ///
    /// **Why a session boundary is not a run boundary (G-15-26).** The measurement is a fact about
    /// the RUN, and nothing about a session starting or ending makes it less true. Session-scoping
    /// its predecessor lost it on two orderings production reaches: an `.unavailable` teardown,
    /// whose arm ends the session and leaves the queue running foreground-only, and a run started
    /// before any session existed, because the live client resumes the persisted queue at launch
    /// and D-07 forbids that path from starting one. In both, an in-flight repair went uncredited
    /// for an entire re-download — the maximally stalled reading D-11's expiration policy punishes
    /// by pausing every schedulable download.
    ///
    /// **Why the retirement is not optional.** Keyed by gallery id and never retired, an entry
    /// would credit the NEXT redo of the same gallery with a finished predecessor's arithmetic.
    /// The retirement is gated on the run still owning the gallery's active slot, so a superseded
    /// predecessor cannot drop a live successor's measurement, and it freezes the run's final
    /// credited count first; both are derived on `retireRunProgressBasis`.
    ///
    /// Not session-scoped, deliberately, and the clears that scope the set above must never be
    /// extended to this map. `DownloadSourceInventoryTests` owns the site census that keeps this
    /// lifetime honest, which is what a comment asking to be believed could not do.
    var runProgressBases = [String: RunProgressBasis]()

    public init(
        storage: DownloadStore,
        urlSession: URLSession,
        pageDownloader: DownloadPageDownloader? = nil,
        backgroundTaskStore: DownloadBackgroundTaskStore? = nil,
        backgroundProcessingClient: BackgroundProcessingClient = .noop,
        storedCookiesProvider: @escaping @Sendable (URL) -> [HTTPCookie] = {
            HTTPCookieStorage.shared.cookies(for: $0) ?? []
        },
        libraryClient: LibraryClient = .live,
        downloadOptionsProvider: @escaping @Sendable () async -> DownloadRequestOptions = {
            DownloadRequestOptions()
        },
        queueStore: DownloadQueueStore? = nil,
        taskRunner: DownloadTaskRunner = .init(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storage = storage
        self.urlSession = urlSession
        self.pageDownloader = pageDownloader ?? .foreground(urlSession: urlSession)
        self.backgroundTaskStore = backgroundTaskStore ?? DownloadBackgroundTaskStore(
            fileURL: storage.backgroundTaskRegistryURL()
        )
        self.backgroundProcessingClient = backgroundProcessingClient
        self.storedCookiesProvider = storedCookiesProvider
        self.libraryClient = libraryClient
        self.downloadOptionsProvider = downloadOptionsProvider
        self.queueStore = queueStore ?? DownloadQueueStore(fileURL: storage.queueURL())
        self.taskRunner = taskRunner
        self.now = now
    }

    public var fileManager: DownloadFileManager {
        storage.fileManager
    }
}

/// Owns the observer continuations and the last snapshot broadcast to them, kept apart from
/// the coordinator's state so notification can never interleave with a state mutation. The
/// coordinator computes a snapshot and hands it here to fan out; this type holds no download
/// state of its own.
public actor DownloadObserverHub {
    private var lastObservedDownloads = [DownloadedGallery]()
    private var observers = [UUID: AsyncStream<[DownloadedGallery]>.Continuation]()
    private var notifyGeneration = 0

    public init() {}

    public func observe(
        snapshot: @Sendable () async -> [DownloadedGallery]
    ) async -> AsyncStream<[DownloadedGallery]> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: [DownloadedGallery].self
        )
        // Register before the snapshot resolves so a `notify` landing while the
        // snapshot is in flight reaches this observer instead of being missed.
        observers[identifier] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.removeObserver(id: identifier)
            }
        }

        let generationBeforeSnapshot = notifyGeneration
        let initialDownloads = await snapshot()
        if notifyGeneration == generationBeforeSnapshot {
            // No notify reached this observer during resolution; deliver the snapshot.
            continuation.yield(initialDownloads)
        }
        // Otherwise a fresher value already arrived via notify; skipping the now-stale
        // snapshot keeps emissions ordered newest-last.
        return stream
    }

    public func notify(_ downloads: [DownloadedGallery]) {
        guard downloads != lastObservedDownloads else { return }
        lastObservedDownloads = downloads
        notifyGeneration += 1
        observers.values.forEach({ $0.yield(downloads) })
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }
}

extension DownloadCoordinator {
    /// Takes one operation's scheduling block on `gid`, balanced by exactly one
    /// `releaseScheduling(gid:)` on every exit of the operation that called this.
    func blockScheduling(gid: String) {
        schedulingBlockedGalleryCounts[gid, default: 0] += 1
    }

    /// Gives back one operation's scheduling block on `gid`, unblocking the gallery only once no
    /// other live operation still holds it.
    ///
    /// A release with no matching block is a contract violation rather than a tolerated no-op: the
    /// former `Set` made a double-remove harmless, so the conversion away from it cannot assume the
    /// old insert / `defer` / explicit-remove shapes were balanced. It is logged rather than
    /// trapped, and it leaves the dictionary untouched, because the alternative — decrementing
    /// anyway — would consume a *different* live operation's hold and strand the download that
    /// operation is protecting.
    ///
    /// The violation is reported as an issue as well as logged, so it is visible where balance is
    /// actually decided. A device-only log line is read by nobody while a suite passes over it,
    /// whereas an issue report surfaces in Swift Testing as a recorded issue, so any case that
    /// trips an imbalance fails loudly. The report carries no gallery identity — the gid stays in
    /// the hash-masked log line below — and it is purely additive: this still returns without
    /// touching the dictionary, in release builds exactly as before.
    func releaseScheduling(gid: String) {
        guard let count = schedulingBlockedGalleryCounts[gid] else {
            reportIssue("Scheduling release without a matching block.")
            logger.error(
                """
                Scheduling release without a matching block, \
                gid: \(gid, privacy: .private(mask: .hash)).
                """
            )
            return
        }
        if count > 1 {
            schedulingBlockedGalleryCounts[gid] = count - 1
        } else {
            schedulingBlockedGalleryCounts[gid] = nil
        }
    }

    public func queueIntentGeneration(for gid: String) -> Int {
        queueIntentGenerations[gid, default: 0]
    }

    public func advanceQueueIntentGeneration(for gid: String) {
        queueIntentGenerations[gid, default: 0] += 1
    }

    public func clearDownloadFailureState(
        gid: String,
        includePageFailures: Bool = true
    ) {
        downloadErrors[gid] = nil
        validationErrors[gid] = nil
        if includePageFailures {
            failedPageErrors[gid] = nil
        }
    }

    public func clearDownloadQueueIntent(gid: String) {
        queuedModes[gid] = nil
        queuedPageSelections[gid] = nil
    }

    public func clearDownloadSessionState(
        gid: String,
        includePageFailures: Bool = true,
        includeUpdateFlag: Bool = false
    ) {
        clearDownloadFailureState(
            gid: gid,
            includePageFailures: includePageFailures
        )
        clearDownloadQueueIntent(gid: gid)
        if includeUpdateFlag {
            updatedGalleryIDs.remove(gid)
        }
    }
}
