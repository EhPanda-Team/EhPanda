---
phase: 15-continued-background-downloads
plan: 30
subsystem: downloads
tags: [download-client, filesystem-probe, error-handling, oslog-privacy, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-25's D-G5-01 reconciliation (the blanking that this plan makes conditional), 15-29's D-G7-01 delta-keyed withdrawal bracket (which makes the no-withdrawal guarantee fall out by construction), 15-28's testing forwarders"
provides:
  - "PageFileScan: a page-file scan result that carries whether the folder could be listed at all, so a destructive consumer can tell 'no files' from 'no answer'"
  - "existingAssetFileURLs surfaces enumeration failure as nil instead of flattening it into []"
  - "reconcileWorkingManifestAgainstPageFiles refuses to blank on a failed scan, and refuses a wholesale blank of a successfully-read manifest's folder"
  - "A .notice log at the blanking site (blanked count public, gid hash-masked) so a real blanking and a refused one are distinguishable in a device archive"
  - "The wholesale-scan-failure regression, staged through a real EACCES on an execute-only folder"
affects: [continued-background-downloads, download-repair, download-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Positive-signal rule: a best-effort probe's non-answer is never authority for destroying durable state; the probe keeps its empty fallback and the destructive consumer gets an explicit success flag"
    - "Probe/consumer split at one call: existingPageRelativePaths forwards to pageFileScan(...).pages so non-destructive callers are byte-identical"
    - "Filesystem-failure staging in tests via POSIX permissions (execute-only folder defeats contentsOfDirectory while path-addressed opens and writes still work)"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift

key-decisions:
  - "15-30: Enumeration failure is surfaced as an optional from existingAssetFileURLs; the ~10 non-destructive probe callers keep their [] fallback through existingPageRelativePaths, which becomes a pages-only forward to pageFileScan."
  - "15-30: The wholesale-blank refusal is spelled `blankedPageCount < manifest.completedPageCount`, because only claimed pages are blanked, so equality means every claimed page would go — the signature of per-file probe failure en masse rather than proof of loss."
  - "15-30: An all-pages-vanished repair deliberately falls back to the pre-D-G5-01 arc (the seed's empty existingPages makes the run re-fetch; honesty catches up at flush time; resumeMode's storage.validate branch still classifies the record), accepted against letting one transient enumeration failure destroy every recorded hash."
  - "15-30: The no-withdrawal guarantee needs no code — a refusal moves no index record, so 15-29's delta-keyed D-G7-01 bracket subtracts zero by construction."

patterns-established:
  - "Surface-then-refuse: an I/O helper reports its own failure and the caller that acts irreversibly decides, rather than the helper choosing a fallback for everyone"
  - "Irreversible mutations carry an observability line at .notice with the module's hash-masked identity pattern"

requirements-completed: []

coverage:
  - id: D1
    description: "A failed directory enumeration can no longer blank the working manifest's recorded content hashes, rewrite the manifest, re-index the record, or move the session floor"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift#testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing"
        status: pass
    human_judgment: false
  - id: D2
    description: "Partial blanking is untouched: a successful scan missing SOME claimed files blanks exactly those hashes"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift#testABlankedGalleryPausedPartWayDoesNotFreezeTheSurvivorsPushes"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift#testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull"
        status: pass
    human_judgment: false
  - id: D3
    description: "A blanking that proceeds is observable in a device archive without disclosing gallery identity"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift#testDownloadIdentityLogsStayHashMasked"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift#testNoDownloadLogPublishesGalleryIdentity"
        status: pass
    human_judgment: false
  - id: D4
    description: "The refused blanking's forensic value on real hardware — that a device archive shows whether a blanking was real when a transient data-protection denial actually occurs"
    verification: []
    human_judgment: true
    rationale: "The failure family this defends against (descriptor exhaustion, EBUSY, a data-protection denial while the device is locked) cannot be provoked in the simulator; the test stages EACCES as its deterministic stand-in. Whether the .notice line reads usefully in a real sysdiagnose is a device observation."

# Metrics
duration: 55min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 30: Positive-Signal Guard on Destructive Manifest Blanking Summary

**A best-effort file probe's non-answer can no longer destroy a gallery's recorded content hashes: enumeration failure is surfaced from the store, the reconciliation refuses to blank on a failed or wholesale-blanking scan, and a blanking that does proceed logs at `.notice` with a hash-masked gid.**

## Performance

- **Duration:** ~55 min
- **Completed:** 2026-08-05T01:26Z
- **Tasks:** 1 (TDD: RED observed, then GREEN)
- **Files modified:** 3

## Accomplishments

- **G-15-9 closed.** `reconcileWorkingManifestAgainstPageFiles` no longer treats an empty probe answer as authoritative evidence that page files are gone. One failed `contentsOfDirectory` could previously blank EVERY claimed page of a gallery in a single pass, rewrite the manifest, publish a 0-of-N record and — through 15-29's D-G7-01 bracket — withdraw the full count from the session floor, all unlogged.
- **The failure is surfaced rather than flattened.** `existingAssetFileURLs(folderURL:)` returns `[URL]?`, and a new `PageFileScan` (`pages` + `scanSucceeded`) travels from the store to the one destructive consumer.
- **Probes stay probes.** `existingPageRelativePaths` is now a single forward to `pageFileScan(...).pages`, so its non-destructive callers keep their exact `[:]`-on-failure behavior; the cover/page lookup path collapses `nil` to `[]` at its own call.
- **The tradeoff is written down at the refusal site,** because an undocumented tradeoff is the wrong-premise defect class this phase kept paying for.
- **A real blanking is observable.** `logger.notice` records the blanked count (`.public`) beside a `.private(mask: .hash)` gid, following the module's existing pattern.
- **Falsifiability recorded.** The regression was watched destroying state before the fix landed.

## Task Commits

1. **Task 1: Surface the scan failure, install the refusal guards and the notice log, and pin the wholesale-failure case watched to fail first** — `0cf7d1b1` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — new public `PageFileScan` struct and `pageFileScan(folderURL:manifest:)`; `existingAssetFileURLs` returns an optional with a revised comment; `existingPageRelativePaths` re-expressed as the pages-only forward; the cover/page-lookup caller collapses `nil` to `[]`.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — `prepareWorkingSeed` consumes `pageFileScan` and threads `scanSucceeded`; `reconcileWorkingManifestAgainstPageFiles` gains the parameter, the two refusal guards, the `.notice` blanking log, and the two doc paragraphs.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` — `testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing` plus a `restoreFolderPermissions(at:to:)` helper.

## The RED reading (falsifiability recorded)

Run before the guards landed, same targeted command, same case. The five recorded issues, verbatim from the run log:

```
✘ …recorded an issue at DownloadContinuedSessionBasisTests.swift:638:9: Expectation failed:
    await manager.fetchDownload(gid: unlisted.gid)?.completedPageCount == 4
✘ …recorded an issue at DownloadContinuedSessionBasisTests.swift:646:9: Expectation failed:
    (refusalPair.completedUnitCount → 0) == 4
✘ …recorded an issue at DownloadContinuedSessionBasisTests.swift:648:9: Expectation failed:
    (refusalPair.subtitle → "0 / 6 pages · 1 gallery") == "4 / 6 pages · 1 gallery"
✘ …recorded an issue at DownloadContinuedSessionBasisTests.swift:654:9: Expectation failed:
    (onDiskManifest.pages → [5: "", 2: "", 6: "", 3: "", 1: "", 4: ""])
      == (manifest(for: unlisted).pages → [1: "sha256:done", 6: "", 3: "sha256:done",
                                           4: "sha256:done", 2: "sha256:done", 5: ""])
✘ …recorded an issue at DownloadContinuedSessionBasisTests.swift:655:9: Expectation failed:
    (onDiskManifest.completedPageCount → 0) == 4
✘ Test testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing()
    failed after 0.410 seconds with 5 issues.
```

Observed against derived, as the plan required:

| Reading | Observed (pre-fix) | Derived (post-fix) |
|---|---|---|
| index record `completedPageCount` | `0` | `4` |
| announcement's pushed pair | `0 / 6 pages · 1 gallery` | `4 / 6 pages · 1 gallery` |
| on-disk manifest hashes | all six entries `""` | the four `"sha256:done"` entries intact |

The on-disk row is worth naming: the manifest was **rewritten** under the execute-only folder, which independently confirms the staging isolates the *listing* failure rather than making the folder inert — the write path the destruction travelled on was fully available.

In the same RED run Tests G, H, J, K, L and the whole ledger suite (including Test E) were green: 20 tests, 5 issues, all five in the new case.

## The guards, quoted

```swift
    ) throws -> DownloadManifest {
        guard scanSucceeded else { return manifest }

        var pages = manifest.pages
        var blankedPageCount = 0
        for page in manifest.pages.keys.sorted() {
            guard pages[page]?.isEmpty == false, existingPages[page] == nil else { continue }
            pages[page] = ""
            blankedPageCount += 1
        }
        guard blankedPageCount > 0 else { return manifest }
        // Only claimed pages are blanked above, so equality here means every one of them would go.
        guard blankedPageCount < manifest.completedPageCount else { return manifest }
```

Both refusals sit before any mutation: the failed-scan guard is the function's first statement, and the wholesale guard precedes the `writeManifest` / `updateDownloadIndex` pair. `manifest.completedPageCount` is `pages.values.filter({ !$0.isEmpty }).count` (`DownloadedGallery+Manifest.swift:67-69`) — i.e. exactly the claimed-page count — and the blanking loop only ever counts a page whose hash is non-empty, so `blankedPageCount <= completedPageCount` always holds and equality is precisely the every-claimed-page case. The `> 0` guard above it already excludes the vacuous zero.

The blanking log:

```swift
        logger.notice(
            """
            Working manifest reconciled, blanked page count: \
            \(blankedPageCount, privacy: .public), \
            gid: \(manifest.gid, privacy: .private(mask: .hash)).
            """
        )
```

Every interpolation carries an explicit classification; the gid uses the module's `.private(mask: .hash)` pattern (the same spelling as the `enqueue` and `delete` notices in `DownloadClient+PublicAPI.swift`). Both `DownloadLogPrivacyInvariantTests` cases pass in the full run.

## The tradeoff paragraph, quoted

From the function's doc comment:

> **Wholesale refusal, and the tradeoff it deliberately accepts.** The refusal is also taken when a NOMINALLY SUCCESSFUL listing would blank every claimed page. The manifest was just read out of this very folder, so a listing of it that accounts for none of its claimed pages is the signature of per-file probe failure en masse — the sanitization levels above failing for every file — rather than proof that every page vanished. The cost is that a genuinely all-pages-vanished repair is no longer reconciled: it falls back to the pre-D-G5-01 arc, where the seed's empty `existingPages` makes the run re-fetch every page and the record's honesty catches up at flush time, and `resumeMode`'s `storage.validate` branch remains the route that resolves `.repair` for such a record. That is accepted against the alternative — letting one transient enumeration failure destroy every recorded hash a gallery has. Partial blanking is untouched: a scan that succeeds and finds SOME claimed files missing blanks exactly those.

The positive-signal paragraph above it names all three swallow levels (`existingAssetFileURLs`, the per-page `sanitizeAssetFileIfNeeded` drop, and its `canReadNonEmptyFile` fallback) and the transient causes each has.

## Probe callers untouched — evidence

`git grep -n 'existingPageRelativePaths(' -- AppPackage/Sources` reports 12 lines. Filtering the plan's diff (`git diff -U0` against the pre-plan tree) for that token yields exactly one changed line:

```
-            let existingPages = storage.existingPageRelativePaths(
```

— the destructive consumer in `prepareWorkingSeed`, replaced by `storage.pageFileScan(...)`. Every other caller (`DownloadClient+PersistenceHelpers.swift:32,55`, `DownloadStore.swift:184`, `DownloadStore+Operations.swift:63,86,234,270`, `DownloadClient+PublicAPI.swift:301,344`, `DownloadClient+ExecutionPerform.swift:128`, `DownloadClient+BackgroundDownloads.swift:211`) is unmodified in this plan's diff, and the function's signature is unchanged:

```swift
    public func existingPageRelativePaths(folderURL: URL, manifest: DownloadManifest) -> [Int: String] {
        pageFileScan(folderURL: folderURL, manifest: manifest).pages
    }
```

The store's five `existingPageRelativePaths` assertions in `DownloadStoreTests.swift` (`:195,217,236,254,275`) are likewise unmodified and pass in the full run.

The other `existingAssetFileURLs` consumer — the cover/page lookup at `existingAssetFileURL(folderURL:prefix:)` — absorbs the optional at the call:

```swift
        // A cover or page lookup is a probe: an unlistable folder has no findable asset, which is
        // the same answer an empty one gives. Collapsing nil here preserves that behavior exactly.
        existingAssetFileURL(
            in: existingAssetFileURLs(folderURL: folderURL) ?? [],
            prefix: prefix
        )
```

## D-G7-01 and the floor: untouched by construction

Confirmed by diff inspection — `git diff -U0 -- AppPackage/Sources` matches none of `withdrawingCountedBasisMovement`, `lastPushedCompletedPageCount`, `observedIncompleteSessionGIDs`, or `reconcileRetiredSessionPages`. 15-29's bracket keys on the pre/post `downloadIndex[gid]` delta, and a refusal calls neither `writeManifest` nor `updateDownloadIndex`, so the record does not move and the bracket subtracts zero. The regression asserts that end-to-end: the announcement's pushed pair reads `4 / 6 pages · 1 gallery`, unchanged from the start pair.

## Partial blanking survives — evidence

From the same GREEN targeted run (20 tests, all passed), with the bodies and literals of these cases untouched in this plan's diff (the diff touches only the new case and the new helper at the end of the basis file):

| Case | Claimed / blanked | Result |
|---|---|---|
| Test G `testABlankedGalleryPausedPartWayDoesNotFreezeTheSurvivorsPushes` | 4 claimed, 2 blanked | passed (0.540s), literals `7 / 14` → `5 / 14` → `5 / 10` → `10 / 10` intact |
| Test H `testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed` | 4 claimed, 2 blanked | passed (0.499s), literals `4 / 6` → `3 / 6` → `6 / 6` intact |
| Test E `testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull` (ledger) | 6 claimed, 1 blanked | passed (0.471s), literals `0 / 6` → `5 / 6` → `6 / 6` intact |
| Tests J / K / L (`.redownload`, `.update`, page-count-mismatch withdrawals) | no blanking at all | passed; their movements are fresh-manifest writes, so neither guard fires |

Test E's staging was checked against the plan's stated risk before proceeding: it writes files for pages `[1, 2, 4, 5, 6]` of a 6-claimed-page manifest, so it blanks page 3 alone — a partial blanking, safely clear of the wholesale guard. No finding to report there.

## Verification

| Check | Result |
|---|---|
| Targeted basis + ledger run, RED (pre-fix) | 20 tests, 5 issues, all in the new case |
| Targeted basis + ledger run, GREEN (post-fix) | `Test run with 20 tests in 2 suites passed after 0.544 seconds` |
| Full `FeatureTests` plan, one invocation | exit `0`; every suite passed (3 pre-existing known issues, unchanged) |
| SwiftLint (`--strict`, root config, three changed files) | `Found 0 violations, 0 serious in 3 files` |
| `grep -c 'struct PageFileScan' DownloadStore.swift` | `1` |
| `grep -c 'func pageFileScan' DownloadStore.swift` | `1` |
| `grep -c 'testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing'` | `1` |
| `wc -l` (file_length limit 1000, error severity) | `DownloadStore.swift` 674, `DownloadClient+ExecutionSupport.swift` 683, `DownloadContinuedSessionBasisTests.swift` 704 |
| Longest line across the three files | ≤ 120 columns (`awk 'length > 120'` returns nothing) |

Never more than one `xcodebuild` invocation at a time.

The regression's staging contains `posixPermissions`, `testingPrepareWorkingSeedAnnouncingProgress`, and the manifest re-read, and restores the folder's original mode in a `defer` ahead of the fixture cleanup (the removal needs the read bit back).

## Prohibitions — status

| Prohibition | Status |
|---|---|
| Must NOT change `existingPageRelativePaths`' signature or fallback for non-destructive callers | **Held** — signature identical, body is the single forward; 11 other call sites unmodified |
| Must NOT weaken partial blanking | **Held** — Tests G, H, E pass with byte-identical bodies and literals |
| Must NOT log gallery identity un-masked | **Held** — `.private(mask: .hash)` on the gid, explicit classification on both interpolations, privacy invariant suite green |
| Must NOT touch the D-G7-01 bracket, the trust set, the floor arithmetic, or `reconcileRetiredSessionPages` | **Held** — none appear in the source diff |
| Must NOT reach for a concurrency/lint escape hatch or add a suspension | **Held** — 0 lint violations, no suppressions; every added statement is synchronous (`pageFileScan`, the two guards, and `logger.notice` are same-actor calls) |

## Decisions Made

- **Enumeration failure surfaces as an optional, not a throw.** A throw would force ~10 probe call sites into `do`/`catch` (or, worse, the banned `try?`) to restore behavior they must keep exactly. The optional keeps the probe contract expressible as one `?? []` and one `guard let`.
- **The wholesale predicate is `blankedPageCount < manifest.completedPageCount`.** The plan phrased it as three conjuncts ("equals the completed count, positive, equals the claimed count"); re-derived from source, `completedPageCount` *is* the claimed-page count and the `> 0` guard above already covers positivity, so the three collapse to one comparison. Spelling all three would have implied a distinction the model does not have.
- **`PageFileScan` is `Equatable, Sendable` with a public memberwise init,** matching `DownloadFolderRecord` / `DownloadScanResult` in the same file.
- **The permissions restore is a recorded-issue helper, not a `try?`.** `optional_try` is an error-severity custom rule, and a `defer` cannot rethrow; `Issue.record` surfaces a stranded fixture without affecting the assertions.

## Deviations from Plan

None — plan executed as written. The one wording-level departure (the collapsed wholesale predicate) is recorded under Decisions Made above, with its derivation; it changes no behavior the plan specified.

## Issues Encountered

- The first targeted run was piped through `tail -60`, so the shell's exit status was `tail`'s and the failure detail scrolled out of the captured window. Re-run with full output redirected to a file; the RED readings above come from that complete log. No source change happened between the two runs.

## Known Stubs

None.

## Threat Flags

None — the change adds no network endpoint, auth path, or schema surface. The one new log line is covered by `T-15-30-03` and its mitigation (hash-masked gid) is in place and test-enforced.

## Next Phase Readiness

- G-15-9 is closed in code. It remains one of six gaps opened by the round-10 verification; 15-31 and 15-32 follow.
- Independently outstanding and **not** discharged by this plan: `15-UAT.md` test 2 still needs a physical-device re-run on iOS 26, covering the `.redownload` route and a `.repair` gallery in a multi-gallery queue.
- Coverage item D4 (whether the new `.notice` line reads usefully in a real sysdiagnose during an actual data-protection denial) is a device observation, not an automatable one.

## Self-Check: PASSED

- All three modified source/test files present on disk.
- Task commit `0cf7d1b1` present in `git log --oneline --all`.
- No absolute home paths recorded in this document.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
