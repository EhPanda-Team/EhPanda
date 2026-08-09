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

        let before = try await snapshot(testCase.gid, in: staged)
        for mutation in testCase.externalMutations {
            try apply(mutation, to: staged)
        }
        await manager.reloadDownloadIndex()
        let after = try await snapshot(testCase.gid, in: staged)

        #expect(
            after.displayed == before.displayed,
            """
            \(testCase.name): a filesystem mutation moved a displayed quantity before Validate \
            sensed it, so something displayed is deriving from the disk.
            """
        )
        expectRenderingResourcesFollowedTheDisk(testCase, in: staged, before: before, after: after)

        let validation = await manager.validateImageData(gid: testCase.gid)
        let sensed = try await snapshot(testCase.gid, in: staged)
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
            // A pass that established nothing it could write, re-pinned over a state the probe
            // itself produced. Two shapes reach here — the irreversibility guard refusing a
            // wholesale blanking, and a pass whose positive evidence set is simply empty — and both
            // owe the same thing: nothing displayed moves, the operation-level entry stands, and no
            // file was destroyed, because every destructive step sits behind the guard.
            #expect(sensed.displayed == before.displayed, "\(testCase.name): a refusal moved state.")
            #expect(sensed.displayed.displayStatus == .error, "\(testCase.name)")
            #expect(sensed.displayed.lastErrorCode == .fileOperationFailed, "\(testCase.name)")
            #expect(sensed.pagesWithFile == after.pagesWithFile, "\(testCase.name): a refusal removed a file.")
        }
    }

    /// Family 3 — no dead end, enforced by DRIVING rather than by reading predicates.
    ///
    /// A state is non-terminal incomplete when its persisted record reads incomplete, or an
    /// operation-level `validationErrors` entry stands over it, and it is not already moving
    /// (`.active`/`.queued` are in motion; a clean complete record is terminal, because it is not
    /// asking for work). For every such state at least one forward affordance must SUCCEED when
    /// actually called: `togglePause`, `retryPages` over `retryablePageIndices`, or
    /// `validateImageData` followed by one of those on the state it produces.
    ///
    /// Predicates alone are not enough, and that is the whole lesson of G-15-5: its dead end had
    /// predicates that each looked reasonable in isolation — the button was on the screen with an
    /// empty selection behind it — so nothing short of reaching `.queued` proves the way out exists.
    /// The outranking hazard (`validationErrors` outranks both `activeGalleryID` and queue
    /// membership in `displayStatus`) is covered the same way: only a drive that actually lands
    /// `.queued` proves the entry was cleared at enqueue.
    ///
    /// The negative boundary is pinned from the other side in the same run: a terminal state must
    /// offer no resume-shaped start at all, and `togglePause` must refuse it at the production entry
    /// point rather than merely reading as disabled.
    @Test(arguments: SSOTStateCase.all)
    func testEveryNonTerminalIncompleteStateKeepsAForwardAffordanceThatSucceeds(
        _ testCase: SSOTStateCase
    ) async throws {
        let staged = try await stage(testCase)
        defer { staged.tearDown() }
        let manager = staged.fixture.manager

        let download = try #require(await manager.fetchDownload(gid: testCase.gid))
        let inspection = try await manager.loadInspection(gid: testCase.gid).get()
        #expect(
            classify(download) == testCase.expectedRegime.kind,
            "\(testCase.name): the staged state is not the regime the table claims it is."
        )

        switch testCase.expectedRegime {
        case .inMotion:
            #expect(
                [.active, .queued].contains(download.displayStatus),
                "\(testCase.name): an in-motion regime that is not moving."
            )

        case .terminalComplete:
            #expect(download.canTogglePause == false, "\(testCase.name): a terminal record offers a resume.")
            #expect(inspection.canRetryPages == false, "\(testCase.name): a terminal record offers a retry.")
            #expect(inspection.retryablePageIndices.isEmpty, "\(testCase.name): a terminal retry basis.")
            guard case .failure = await manager.togglePause(gid: testCase.gid) else {
                Issue.record("\(testCase.name): togglePause started a record that claims every page.")
                return
            }
            // What keeps a complete-CLAIMING record off the dead-end list even when its files are
            // gone: the single sensor is reachable from the screen that reports the problem, and
            // family 2 pins that running it moves the record into the startable regime.
            #expect(
                inspection.canValidateImageData,
                "\(testCase.name): the sensor is unreachable from a complete-claiming record."
            )

        case .nonTerminalIncomplete(let queuedMode):
            try await driveForward(testCase, in: staged, expecting: queuedMode)
        }
    }

    /// Family 3's FIFTH entrance, driven separately because the table's regimes reach the queue
    /// through `togglePause` and `retryPages` only.
    ///
    /// `validationErrors` outranks queue membership in `displayStatus`, so the rule on its
    /// declaration — anything that enqueues must clear it at or before the enqueue — is what stops a
    /// queued gallery from deriving `.error` and failing both arms of `shouldSchedule` forever.
    /// `enqueue(payload:)` is the one entrance that never called `clearDownloadFailureState`, and it
    /// is reachable with an entry standing: it explicitly supports an already-known gallery, and
    /// Detail presents its download menu on `downloadBadge == nil` rather than on
    /// `hasLoadedDownloadBadge`, so the menu is up before the badge lands for an existing record.
    ///
    /// The entry is installed by running the sensor rather than by a seam, so what this drives is
    /// the state production actually produces: the wholesale-refusal regime the table already
    /// stages. Reaching `.queued` is the assertion — a predicate reading clear would pass over a
    /// gallery that never becomes schedulable, which is the dead end under another name.
    @Test
    func testEnqueueingARecordUnderAnOperationLevelEntryStillReachesTheQueue() async throws {
        let testCase = try #require(
            SSOTStateCase.all.first(where: { $0.name == "refusedWholesaleAfterValidating" })
        )
        let staged = try await stage(testCase)
        defer { staged.tearDown() }
        let manager = staged.fixture.manager

        // The premise, asserted rather than assumed: the operation-level entry really is standing,
        // and it got there through the sensor.
        let refused = try #require(await manager.fetchDownload(gid: testCase.gid))
        #expect(refused.displayStatus == .error, "\(testCase.name): no entry to enqueue under.")
        #expect(refused.lastError?.code == .fileOperationFailed, "\(testCase.name)")

        let enqueueResult = await manager.enqueue(
            payload: makeStartPayload(for: staged.gallery, mode: .initial)
        )
        try enqueueResult.get()

        let enqueued = try #require(await manager.fetchDownload(gid: testCase.gid))
        #expect(
            enqueued.displayStatus == .queued,
            "enqueue left an operation-level entry standing, so the gallery is queued and can never run."
        )
        #expect(enqueued.lastError == nil)
    }
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

/// One snapshot of everything the client seam displays for a record, split by what the invariant
/// says about each half. The invariance family takes one before an external mutation and one after,
/// and the whole `displayed` half has to compare equal.
struct SSOTStateSnapshot: Sendable {
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
        // After the hashing, for the same reason the corruption is: the recorded hash must be the
        // one the intact file produced, or the regime under test would be a placeholder mismatch.
        for page in testCase.unprobeablePageFiles {
            try makeAssetFileUnprobeable(at: pageFileURL(for: gallery, in: fixture, index: page))
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

    /// Captures the full displayed state of one record, which is what the invariance family compares
    /// across an external mutation.
    func snapshot(_ gid: String, in staged: StagedSSOTState) async throws -> SSOTStateSnapshot {
        let download = try #require(await staged.fixture.manager.fetchDownload(gid: gid))
        let inspection = try await staged.fixture.manager.loadInspection(gid: gid).get()
        return SSOTStateSnapshot(
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
        case .truncateFile(let page):
            // An empty write rather than a delete-and-recreate: the directory entry never goes away,
            // so the listing keeps yielding it and the probe is the thing that has to answer.
            try Data().write(
                to: pageFileURL(for: staged.gallery, in: staged.fixture, index: page),
                options: .atomic
            )
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

    /// The live classification, derived from what a production reader can see: queue membership and
    /// the active slot say "in motion", the record's own honesty and the operation-level entry say
    /// "still owed work", and everything else is terminal.
    func classify(_ download: DownloadedGallery) -> SSOTStateCase.RegimeKind {
        if [.active, .queued].contains(download.displayStatus) {
            return .inMotion
        }
        let hasOperationLevelEntry = download.displayStatus == .error
            && download.lastError?.code == .fileOperationFailed
        if download.isIncomplete || hasOperationLevelEntry {
            return .nonTerminalIncomplete
        }
        return .terminalComplete
    }

    /// Drives the affordances in production order and requires the state to reach `.queued` — which
    /// is what "forward" means here, since a start that does not become schedulable is the dead end
    /// under another name.
    ///
    /// The validate-then-start arm is deliberately kept even though no case in the current table
    /// needs it: the property is about the state space, not about this table, and a future case that
    /// can only sense its way out must find the arm already here rather than be quietly reclassified
    /// as a dead end.
    func driveForward(
        _ testCase: SSOTStateCase,
        in staged: StagedSSOTState,
        expecting queuedMode: DownloadStartMode
    ) async throws {
        let manager = staged.fixture.manager
        let download = try #require(await manager.fetchDownload(gid: testCase.gid))
        let inspection = try await manager.loadInspection(gid: testCase.gid).get()

        if try await driveStart(testCase, in: staged, download: download, inspection: inspection) {
            // Started directly.
        } else if inspection.canValidateImageData {
            _ = await manager.validateImageData(gid: testCase.gid)
            let sensed = try #require(await manager.fetchDownload(gid: testCase.gid))
            let sensedInspection = try await manager.loadInspection(gid: testCase.gid).get()
            guard try await driveStart(
                testCase,
                in: staged,
                download: sensed,
                inspection: sensedInspection
            ) else {
                recordDeadEnd(testCase, download: sensed, inspection: sensedInspection, sensed: true)
                return
            }
        } else {
            recordDeadEnd(testCase, download: download, inspection: inspection, sensed: false)
            return
        }

        let started = try #require(await manager.fetchDownload(gid: testCase.gid))
        #expect(
            started.displayStatus == .queued,
            "\(testCase.name): the affordance succeeded without making the gallery schedulable."
        )
        #expect(started.lastError == nil, "\(testCase.name): a started record still carries a failure.")
        #expect(
            await manager.queuedMode(for: started) == queuedMode,
            "\(testCase.name): the start resolved a mode the record's shape does not predict."
        )
    }

    /// Calls the first start affordance whose gate is open, in the order the inspector presents
    /// them, and reports whether one was called.
    func driveStart(
        _ testCase: SSOTStateCase,
        in staged: StagedSSOTState,
        download: DownloadedGallery,
        inspection: DownloadInspection
    ) async throws -> Bool {
        let manager = staged.fixture.manager
        if download.canTogglePause {
            try await manager.togglePause(gid: testCase.gid).get()
            return true
        }
        if inspection.canRetryPages {
            // Asserted BEFORE driving: a basis that silently collapses leaves the control present
            // and every downstream assertion passing except the one that matters.
            #expect(
                !inspection.retryablePageIndices.isEmpty,
                "\(testCase.name): canRetryPages is open over an empty selection."
            )
            let retried = await manager.retryPages(
                gid: testCase.gid,
                pageIndices: inspection.retryablePageIndices
            )
            try retried.get()
            #expect(
                await manager.queuedPageSelections[testCase.gid] == inspection.retryablePageIndices,
                "\(testCase.name): the retry carried a different selection than the basis offered."
            )
            return true
        }
        return false
    }

    /// Names the state's full shape, so a future failure diagnoses itself instead of reporting only
    /// that some generated case had no way out.
    func recordDeadEnd(
        _ testCase: SSOTStateCase,
        download: DownloadedGallery,
        inspection: DownloadInspection,
        sensed: Bool
    ) {
        Issue.record(
            """
            \(testCase.name) is a dead end\(sensed ? " even after Validate" : ""): \
            displayStatus \(download.displayStatus), \
            completedPageCount \(download.completedPageCount) of \(download.pageCount), \
            lastError \(String(describing: download.lastError?.code)), \
            canTogglePause \(download.canTogglePause), \
            canRetryPages \(inspection.canRetryPages), \
            retryablePageIndices \(inspection.retryablePageIndices), \
            canValidateImageData \(inspection.canValidateImageData).
            """
        )
    }

    /// The other side of the invariance assertion: the mutation really happened, and the rendering
    /// resource followed the disk in exactly the pages it touched.
    ///
    /// Without this, an invariance claim over a mutation that silently failed would pass vacuously —
    /// which is the shape of a barrier that stops observing when a fix holds its value constant.
    func expectRenderingResourcesFollowedTheDisk(
        _ testCase: SSOTStateCase,
        in staged: StagedSSOTState,
        before: SSOTStateSnapshot,
        after: SSOTStateSnapshot
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
            case .truncateFile(let page):
                // Two halves, and the second is the one this mutation exists for. The RESOURCE goes
                // away, because the probe positively rejects an empty file — that is the mutation
                // being observable at all. The FILE must not, because everything that ran between
                // the two snapshots was a read: a full production rescan and two `loadInspection`
                // calls. A rejection used to carry a deletion on every one of those paths, so a page
                // would go on reading `.downloaded` over a file the display had destroyed, with
                // nothing displayed moving to say so and nothing licensed to do it.
                #expect(before.pagesWithFile.contains(page), "\(testCase.name): page \(page) had no file.")
                #expect(
                    !after.pagesWithFile.contains(page),
                    "\(testCase.name): an empty file at page \(page) still resolved a resource."
                )
                #expect(
                    FileManager.default.fileExists(
                        atPath: pageFileURL(for: staged.gallery, in: staged.fixture, index: page).path
                    ),
                    "\(testCase.name): a display read deleted page \(page)'s file."
                )
            }
        }
    }
}
