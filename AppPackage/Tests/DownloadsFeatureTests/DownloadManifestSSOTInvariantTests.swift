import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The executable form of the manifest-SSOT invariant AGENTS.md records: the persisted download
/// manifest is the **single source of truth** for a gallery's completeness, and *live file-presence
/// scans are reconciliation inputs, never a competing display basis*.
///
/// Every other suite in this target pins INSTANCES — this record, that verdict, this window. G-15-5
/// shipped green through 888 of them because the dead-end state fell BETWEEN the instances: each
/// individual pin was satisfied and the property none of them stated was violated. This suite states
/// the properties, over a deterministic generated family of record states that crosses every regime
/// boundary phase 15 established, so the next change that re-opens a hole between two scenario pins
/// fails here instead of on a device.
///
/// Three families, each naming the clause it enforces:
///
/// 1. **Count-basis agreement** — every displayed record-completeness quantity is the same
///    manifest-derived value, in-session and on a fresh coordinator over the same storage.
/// 2. **Derivation totality** — `displayStatus` and every affordance predicate are functions of
///    (persisted record, queue membership, operation-level transient signal) and of nothing else.
///    That is made *executable* rather than argued: the filesystem is mutated behind the app's back,
///    a full production rescan is run, and nothing displayed is allowed to move until `Validate`
///    senses it. Any display or predicate that consults the disk fails this by construction.
/// 3. **No dead end** — no non-terminal incomplete state lacks a forward affordance that actually
///    succeeds when driven, which is precisely the property whose absence let G-15-5 ship.
///
/// **D-SSOT-09 — the scope of "displayed completeness quantity", and what is deliberately outside
/// it.** These families cover RECORD-completeness displays: the badge's progress pair, the
/// inspector's page states and counts, and the gates derived from them. The continued-processing
/// card's `X / Y` series is **out of scope on purpose**. Its numerator is a run-owned MEASURED
/// quantity (`RunProgressBasis`, the round-18 redesign) and its denominator a session-scoped ledger:
/// those are progress-of-this-run, not completeness-of-this-record. Unifying them into the manifest
/// basis would reintroduce the inference that redesign deleted and that nine rounds of corrections
/// were spent on. The exclusion is also STRUCTURAL here, not merely stated — every fixture below is
/// built with `BackgroundProcessingClient.noop`, so no push is observable from this suite at all and
/// no future edit can quietly start asserting on one.
///
/// **Contract-faithful choreography, everywhere.** No state is installed through a non-production
/// seam: an operation-level `validationErrors` entry arrives only by running `validateImageData`,
/// the target's queue membership only through `togglePause` or `retryPages`, the process boundary
/// only as a fresh coordinator over the same storage root, and every external mutation is a direct
/// file operation with no client call. The one fixture seam used is the BLOCKER gallery's queue
/// entry, which is scaffolding rather than the regime under test: it parks a runner on
/// `BlockingRunnerControl.park()`'s named suspension point so `activeTask != nil` refuses every
/// promotion, which is what makes a driven `.queued` stable rather than momentarily true.
struct DownloadManifestSSOTInvariantTests: DownloadFeatureTestCase {
    /// Family 1 — count-basis agreement.
    ///
    /// The EXPECTED values differ per regime and the table names each one; the AGREEMENT is what
    /// must hold in all of them. Both halves matter: agreement alone is satisfied by a derivation
    /// that returns zero everywhere, and the per-regime values alone say nothing about whether two
    /// displays share a basis.
    ///
    /// The relaunch half is a separate assertion rather than a repetition. A fresh coordinator over
    /// the same storage holds none of this session's in-memory state, so whatever it still reads
    /// correctly was carried by the record alone — which is the durability half of the invariant.
    @Test(arguments: SSOTStateCase.all)
    func testEveryDisplayedCompletenessQuantityIsTheSameManifestDerivedValue(
        _ testCase: SSOTStateCase
    ) async throws {
        let staged = try await stage(testCase)
        defer { staged.tearDown() }

        let download = try #require(await staged.fixture.manager.fetchDownload(gid: testCase.gid))
        let inspection = try await staged.fixture.manager.loadInspection(gid: testCase.gid).get()

        #expect(download.displayStatus == testCase.expectedDisplayStatus, "\(testCase.name)")
        #expect(download.completedPageCount == testCase.expectedCompletedPageCount, "\(testCase.name)")
        #expect(inspection.pages.map(\.status) == testCase.expectedPageStatuses, "\(testCase.name)")
        expectOneCompletenessBasis(download: download, inspection: inspection, regime: testCase.name)

        guard let relaunchReading = testCase.relaunchReading else { return }
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: staged.fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: testCase.gid))
        let rereadInspection = try await relaunched.loadInspection(gid: testCase.gid).get()

        #expect(reread.displayStatus == relaunchReading.displayStatus, "\(testCase.name), relaunched")
        #expect(
            reread.completedPageCount == relaunchReading.completedPageCount,
            "\(testCase.name), relaunched"
        )
        expectOneCompletenessBasis(
            download: reread,
            inspection: rereadInspection,
            regime: "\(testCase.name), relaunched"
        )
    }

    /// Family 2 — derivation totality, proven by probe rather than by reading the code.
    ///
    /// The clause under test is "live file-presence scans are reconciliation inputs, never a
    /// competing display basis". Stated as prose it is unfalsifiable; stated as this probe it is a
    /// standing falsifier. Files are deleted, corrupted and planted behind the app's back, a full
    /// production rescan (`reloadDownloadIndex` — the pull-to-refresh and foreground-return route,
    /// deliberately the STRONGEST form of the claim rather than a passive re-read) is run, and every
    /// displayed quantity and every affordance predicate must be bit-identical afterwards.
    ///
    /// The mutation's own observability is pinned from the other side, because an invariance
    /// assertion over a mutation that did not happen is vacuous: the rendering resource — the one
    /// thing the directory listing is still allowed to answer for after D-SSOT-07 — must have
    /// followed the disk in exactly the pages the mutation touched.
    ///
    /// Then `Validate` is run, and the boundary is pinned from BOTH sides: where its gate is open the
    /// state must move to the regime 15-58's rules predict, and where its gate is closed — an
    /// honestly-incomplete record, which has nothing left to sense — the state must not move at all.
    @Test(arguments: SSOTStateCase.all)
    func testAnExternalFilesystemMutationMovesNothingDisplayedUntilValidateSensesIt(
        _ testCase: SSOTStateCase
    ) async throws {
        let staged = try await stage(testCase)
        defer { staged.tearDown() }
        let manager = staged.fixture.manager

        let before = try await probe(testCase.gid, in: staged)
        for mutation in testCase.externalMutations {
            try apply(mutation, to: staged)
        }
        await manager.reloadDownloadIndex()
        let after = try await probe(testCase.gid, in: staged)

        #expect(
            after.displayed == before.displayed,
            """
            \(testCase.name): a filesystem mutation moved a displayed quantity before Validate \
            sensed it, so something displayed is deriving from the disk.
            """
        )
        expectRenderingResourcesFollowedTheDisk(testCase, before: before, after: after)

        let validation = await manager.validateImageData(gid: testCase.gid)
        let sensed = try await probe(testCase.gid, in: staged)
        switch testCase.expectedSensing {
        case .gateClosed:
            // The sensor's own boundary: an honestly-incomplete record is not offered Validate,
            // because the record already states what a pass would find.
            #expect(validation == nil, "\(testCase.name): the Validate gate should be closed here.")
            #expect(sensed.displayed == before.displayed, "\(testCase.name): a closed gate moved state.")

        case .reconciled(let completedPageCount):
            #expect(validation != nil, "\(testCase.name): the Validate gate should be open here.")
            #expect(sensed.displayed.completedPageCount == completedPageCount, "\(testCase.name)")
            #expect(sensed.displayed.displayStatus == .inactive, "\(testCase.name)")
            #expect(sensed.displayed.lastErrorCode == nil, "\(testCase.name)")
            // The whole difference between a sensor and a display basis: only this call may move it.
            #expect(sensed.displayed != before.displayed, "\(testCase.name): Validate sensed nothing.")
            let download = try #require(await manager.fetchDownload(gid: testCase.gid))
            let inspection = try await manager.loadInspection(gid: testCase.gid).get()
            expectOneCompletenessBasis(
                download: download,
                inspection: inspection,
                regime: "\(testCase.name), reconciled"
            )

        case .refused:
            #expect(validation != nil, "\(testCase.name): the Validate gate should be open here.")
            // The irreversibility defence, re-pinned over a state the probe itself produced: a
            // refusal moves nothing at all, and the guard precedes the first destructive act, so the
            // file the reconciliation would have removed is still on disk.
            #expect(sensed.displayed == before.displayed, "\(testCase.name): a refusal moved state.")
            #expect(sensed.displayed.displayStatus == .error, "\(testCase.name)")
            #expect(sensed.displayed.lastErrorCode == .fileOperationFailed, "\(testCase.name)")
            #expect(sensed.pagesWithFile == after.pagesWithFile, "\(testCase.name): a refusal removed a file.")
        }
    }
}

// MARK: - The Generated State Family

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
    }

    enum ExternalMutation: Sendable, Equatable {
        case deleteFile(page: Int)
        case corruptFile(page: Int)
        /// A file appearing where the app never put one — the opposite direction from a deletion,
        /// and the only external mutation available to a gallery with nothing on disk.
        case plantFile(page: Int)
    }

    enum PostMutationSensing: Sendable, Equatable {
        case gateClosed
        case reconciled(completedPageCount: Int)
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
        )
    ]
}

// MARK: - Staging (production choreography only)

/// The fixture one generated case was staged into, plus the blocker's release token.
struct StagedSSOTState {
    let fixture: SessionFixture
    let gallery: SessionGallery
    let blockerControl: BlockingRunnerControl

    /// Unblocks the parked runner before removing the directory it may still touch.
    func tearDown() {
        blockerControl.release()
        removeTemporaryItem(at: fixture.rootURL)
    }
}

/// Everything one probe reads at the client seam, split by what the invariant says about it.
struct SSOTStateProbe: Sendable {
    /// Must not move when the filesystem does. Note that `lastErrorCode` is carried rather than the
    /// whole `DownloadFailure`: the failure's MESSAGE is the operation's own report of what a pass
    /// found and is allowed to change when a pass is re-run, while the code is what every gate and
    /// every mode resolution reads.
    let displayed: DisplayedRecordState
    /// May move when the filesystem does — after D-SSOT-07 the directory listing resolves rendering
    /// resources and nothing else, so this is the demotion's visible half.
    let pagesWithFile: Set<Int>
}

struct DisplayedRecordState: Equatable, Sendable {
    let displayStatus: DownloadDisplayStatus
    let completedPageCount: Int
    let pageCount: Int
    let badgeCompletedPageCount: Int
    let pageStatuses: [DownloadPageStatus]
    let canTogglePause: Bool
    let canRetryPages: Bool
    let canValidateImageData: Bool
    let retryablePageIndices: [Int]
    let hasDownloadedPages: Bool
    let isIncomplete: Bool
    let lastErrorCode: DownloadFailureCode?
}

extension DownloadManifestSSOTInvariantTests {
    /// Stages one generated case, reaching every regime through the production route that produces
    /// it in the app.
    ///
    /// The blocker gallery is scaffolding, not the regime: it takes the active slot first and never
    /// gives it back, so `scheduleNextIfNeededCore`'s `activeTask == nil` guard refuses every later
    /// promotion. Without it a driven resume would read `.active` for an actor turn — `togglePause` →
    /// `resume` → `scheduleNextIfNeeded` assigns `activeGalleryID` before returning, and
    /// `displayStatus` reads `activeGalleryID` ahead of queue membership — which is a pin on a value
    /// whose derivation basis is still moving. `control.started()` is awaited so the occupancy is a
    /// production-issued fact rather than an assumption.
    func stage(_ testCase: SSOTStateCase) async throws -> StagedSSOTState {
        let gallery = SessionGallery(
            gid: testCase.gid,
            title: "Generated",
            pageCount: testCase.pageCount,
            completedPageCount: testCase.claimedPageCount
        )
        let blocker = SessionGallery(gid: "9\(testCase.gid)", title: "Blocking", pageCount: 2)
        let control = BlockingRunnerControl()
        let fixture = try await makeQueuedCoordinator(
            galleries: [blocker, gallery],
            queuedGIDs: [blocker.gid],
            // D-SSOT-09 made structural: with a noop client no session push is observable from this
            // suite, so the run-owned measured series cannot be asserted on even by accident.
            client: .noop,
            taskRunner: DownloadTaskRunner(
                runScheduledDownload: { _, _ in
                    await control.park()
                    return .skippedOperation
                }
            )
        )

        try writePageFiles(for: gallery, in: fixture, indices: testCase.stagedPageFiles)
        // Only pages the manifest already claims may be re-hashed; hashing a blank-hash page would
        // promote it to claimed and silently change the regime this case is supposed to be.
        let claimedFiles = testCase.stagedPageFiles.filter({ $0 <= testCase.claimedPageCount })
        if !claimedFiles.isEmpty {
            try recordRealPageHashes(for: gallery, in: fixture, indices: claimedFiles)
        }
        for page in testCase.corruptedPageFiles {
            try corruptPageFile(for: gallery, in: fixture, index: page)
        }
        await fixture.manager.reloadDownloadIndex()

        await fixture.manager.scheduleNextIfNeeded()
        await control.started()

        if testCase.runsValidation {
            _ = await fixture.manager.validateImageData(gid: gallery.gid)
        }
        if testCase.resumesThroughTogglePause {
            try await fixture.manager.togglePause(gid: gallery.gid).get()
        }
        return StagedSSOTState(fixture: fixture, gallery: gallery, blockerControl: control)
    }

    func probe(_ gid: String, in staged: StagedSSOTState) async throws -> SSOTStateProbe {
        let download = try #require(await staged.fixture.manager.fetchDownload(gid: gid))
        let inspection = try await staged.fixture.manager.loadInspection(gid: gid).get()
        return SSOTStateProbe(
            displayed: DisplayedRecordState(
                displayStatus: download.displayStatus,
                completedPageCount: download.completedPageCount,
                pageCount: download.pageCount,
                badgeCompletedPageCount: download.badge.progress.completedPageCount,
                pageStatuses: inspection.pages.map(\.status),
                canTogglePause: download.canTogglePause,
                canRetryPages: inspection.canRetryPages,
                canValidateImageData: inspection.canValidateImageData,
                retryablePageIndices: inspection.retryablePageIndices,
                hasDownloadedPages: inspection.hasDownloadedPages,
                isIncomplete: download.isIncomplete,
                lastErrorCode: download.lastError?.code
            ),
            pagesWithFile: Set(
                inspection.pages
                    .filter({ $0.fileURL != nil })
                    .map(\.index)
            )
        )
    }

    /// A direct file operation, with no client call anywhere — which is what "outside the app" means.
    func apply(
        _ mutation: SSOTStateCase.ExternalMutation,
        to staged: StagedSSOTState
    ) throws {
        switch mutation {
        case .deleteFile(let page):
            try FileManager.default.removeItem(
                at: pageFileURL(for: staged.gallery, in: staged.fixture, index: page)
            )
        case .corruptFile(let page):
            try corruptPageFile(for: staged.gallery, in: staged.fixture, index: page)
        case .plantFile(let page):
            // A file appearing at a page's path with bytes no recorded hash names. `writePageFiles`
            // is the same direct write the fixture stages with; nothing about it is a client call.
            try writePageFiles(for: staged.gallery, in: staged.fixture, indices: [page])
        }
    }

    /// Every displayed record-completeness quantity, asserted to be the one manifest-derived value.
    ///
    /// The inventory is the full set of consumers reachable at the client seam. `DownloadBadgeLabel`
    /// renders `badge.progress`, the inspector's page groups partition `inspection.pages`, the
    /// header cell takes `inspection.download.badge`, `hasDownloadedPages` gates the Validate row and
    /// `isIncomplete` decides `resumeMode`. Detail's `isPartialDownloadError` and `downloadNeedsRepair`
    /// are pure functions of `badge.progress` with no independent basis of their own, so pinning the
    /// pair the badge carries is what covers them.
    ///
    /// `displayCompletedPageCount` is the numerator actually rendered. Its clamp is inert over this
    /// family — `completedPageCount` counts non-empty hashes among a record's own pages, so it is
    /// always within range — and that is a claim about the family, not a claim that the clamp is
    /// unnecessary.
    func expectOneCompletenessBasis(
        download: DownloadedGallery,
        inspection: DownloadInspection,
        regime: String
    ) {
        let recorded = download.completedPageCount
        #expect(
            inspection.pages.filter({ $0.status == .downloaded }).count == recorded,
            "\(regime): the inspector's downloaded set is not the set the badge counts."
        )
        #expect(inspection.download.completedPageCount == recorded, "\(regime): inspector header.")
        #expect(download.badge.progress.completedPageCount == recorded, "\(regime): badge numerator.")
        #expect(download.badge.progress.pageCount == download.pageCount, "\(regime): badge denominator.")
        #expect(
            download.badge.progress.displayCompletedPageCount == recorded,
            "\(regime): the rendered numerator disagrees with the recorded one."
        )
        #expect(
            inspection.hasDownloadedPages == (recorded > 0),
            "\(regime): the Validate gate's basis disagrees with the record."
        )
        #expect(
            download.isIncomplete == (recorded < download.pageCount),
            "\(regime): the resume-mode basis disagrees with the record."
        )
    }

    /// The other side of the invariance assertion: the mutation really happened, and the rendering
    /// resource followed the disk in exactly the pages it touched.
    ///
    /// Without this, an invariance claim over a mutation that silently failed would pass vacuously —
    /// which is the shape of a barrier that stops observing when a fix holds its value constant.
    func expectRenderingResourcesFollowedTheDisk(
        _ testCase: SSOTStateCase,
        before: SSOTStateProbe,
        after: SSOTStateProbe
    ) {
        for mutation in testCase.externalMutations {
            switch mutation {
            case .deleteFile(let page):
                #expect(before.pagesWithFile.contains(page), "\(testCase.name): page \(page) had no file.")
                #expect(
                    !after.pagesWithFile.contains(page),
                    "\(testCase.name): page \(page)'s file survived its deletion."
                )
            case .plantFile(let page):
                #expect(
                    !before.pagesWithFile.contains(page),
                    "\(testCase.name): page \(page) already had a file."
                )
                #expect(
                    after.pagesWithFile.contains(page),
                    "\(testCase.name): the planted file at page \(page) was not resolved."
                )
            case .corruptFile(let page):
                // A rewrite in place changes no resource, so this arm only pins that the file the
                // mutation targeted is there on both sides of it.
                #expect(before.pagesWithFile.contains(page), "\(testCase.name): page \(page) had no file.")
                #expect(after.pagesWithFile.contains(page), "\(testCase.name): page \(page) lost its file.")
            }
        }
    }
}
