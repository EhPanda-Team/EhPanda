---
phase: quick-260818-mjs
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  # Task 1 — G-15-2H: freeze the gallery folder leaf
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
  - AppPackage/Sources/AppModels/Download/DownloadedGallery+Manifest.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
  # Task 2 — G-15-2F: publish the live run's measurement on the row
  - AppPackage/Sources/AppModels/Download/DownloadRunProgress.swift
  - AppPackage/Sources/AppModels/Download/DownloadedGallery.swift
  - AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRunProgressReloadTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestFactories.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
  # Task 3 — UAT record (edited by the executor, committed by the orchestrator)
  - .planning/phases/15-continued-background-downloads/15-UAT.md
autonomous: true
gap_closure: true
gap_ids: [G-15-2F, G-15-2H]
requirements: [G-15-2F, G-15-2H]

must_haves:
  truths:
    - "G-15-2H: the LEAF component of a gallery's folder (`[gid_token] Title`) is chosen once, when the folder is first created, and never recomputed: `folderRelativePath(for:parentFolderName:)` reuses the indexed record's `folderURL.lastPathComponent` whenever the gallery already has a record, and derives a fresh leaf from the payload only when it has none — so both callers (`processDownload` every mode incl. `.repair`, and `enqueue`) are covered by construction and a `.repair` over an existing folder reuses it in place with no second folder and no rename."
    - "G-15-2H: only the leaf is frozen. The PARENT component still follows the caller's `parentFolderName`, so an in-app move still relocates the gallery (`moveDownload` keeps the leaf verbatim already; same idiom)."
    - "G-15-2F: while a run's `RunProgressBasis` stands for a gallery, the published `DownloadedGallery` carries `runProgress` (the run's credited page set), the badge numerator reads that set's size, and `buildInspectionPages` reads `.downloaded` ⇔ credited / else `.failed` ⇔ recorded page failure / else `.pending` — ONE value for the header and the page groups, so they cannot disagree; out of a run both read the record exactly as before."
    - "G-15-2F: the row is re-published when the measurement is announced, at every manifest page flush (the row now differs each time, so `DownloadInspectorReducer.observeDownloadsDone`'s equality gate re-sends `.loadInspection`), and when the run exits (basis retired), including a run exit that does not own the active slot."
    - "G-15-2F: `completedPageCount`, `isIncomplete`, `canValidateImageData`, `retryablePageIndices`, `displayStatus`, resume-mode resolution and scheduling stay on the RECORD; the overlay writes nothing, consults no disk, never outranks queue membership, and is retired with the run (D-SSOT-10)."
    - "The census in `DownloadSourceInventoryTests` still totals 7 whole-name run-measurement sites: the credited-pages definition and the published row both read the basis through the single accessor `liveRunProgressBasis(gid:)`, so the two cannot drift."
    - "15-UAT.md records both fixes with commit hashes, root causes and what the next device round must show; both entries stay `status: open` until device verification (the project's G-15-2D precedent)."
  artifacts:
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      provides: "`folderRelativePath(for:parentFolderName:)` with the leaf freeze inside the ONE function"
      contains: "lastPathComponent"
    - path: "AppPackage/Sources/AppModels/Download/DownloadRunProgress.swift"
      provides: "`public struct DownloadRunProgress: Equatable, Sendable` — the row-published form of a live run's measurement (`creditedPageIndices`, `creditedPageCount`)"
      contains: "public struct DownloadRunProgress"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift"
      provides: "`liveRunProgressBasis(gid:)` — the single read of `runProgressBases` — and `publishedRunProgress(gid:)` mapping it to `DownloadRunProgress`"
      contains: "func liveRunProgressBasis"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift"
      provides: "`buildInspectionPages` with the D-SSOT-10 live-run regime and the revised D-SSOT-07 doc"
      contains: "D-SSOT-10"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift"
      provides: "the three fix_spec pins (same gid two titles → one folder; repair reuses in place; parent not frozen) plus the no-record fresh-leaf regression pin"
      contains: "DownloadFolderLeafFreezeTests"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift"
      provides: "wholesale-refusal overlay pins (announce → k flushes → run exit), honest-family idempotence, failed outstanding page, non-owner exit publish"
      contains: "DownloadRunProgressOverlayTests"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRunProgressReloadTests.swift"
      provides: "reducer pin: a row that differs only in `runProgress` re-sends `.loadInspection`"
      contains: "observeDownloadsDone"
  key_links:
    - from: "AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift"
      to: "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      via: "`fetchNormalizeAndDownload` calls `folderRelativePath(for:parentFolderName: download.folderName)`; the leaf freeze happens INSIDE that function, so no call site changes"
      pattern: "folderRelativePath\\("
    - from: "AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift"
      to: "AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift"
      via: "`downloadedGallery(from:)` sets `runProgress: publishedRunProgress(gid:)` — the only place the published row learns about a live run"
      pattern: "publishedRunProgress"
    - from: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      to: "AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift"
      via: "`sessionCreditedPages` regime 1 reads `liveRunProgressBasis(gid:)?.creditedPageCount` — same accessor as the published row"
      pattern: "liveRunProgressBasis"
    - from: "AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift"
      to: "AppPackage/Sources/AppModels/Download/DownloadRunProgress.swift"
      via: "`badge` numerator = `runProgress?.creditedPageCount ?? completedPageCount`"
      pattern: "creditedPageCount"
---

<objective>
Close the two open Phase-15 UAT gaps filed 2026-08-18 (round 6, incidental to test 2 clause 5):

1. **G-15-2H — a `.repair` renamed the user-visible folder.** Owner decision: NEVER RENAME. The fix_spec in `15-UAT.md` (lines 1080–1123) is LOCKED and is implemented as written: freeze the leaf inside `folderRelativePath(for:parentFolderName:)`, keep the parent caller-driven, no migration, no separate fix for the "Stale working folder removal failed … Code=4" line, three named tests.
2. **G-15-2F — the in-app Download Status sheet read "Downloading 27/27 / Downloaded (27) / Pending (0)" for a whole 27-page repair.** Two compounding causes: (i) the badge and `buildInspectionPages` derive from the RECORD, which for the wholesale-refusal family reads N/N throughout the repair by design; the run's own measurement (`runProgressBases[gid]`) reaches only the system card; (ii) the re-download re-records identical hashes, so the published `DownloadedGallery` is `==` its predecessor and `DownloadInspectorReducer.observeDownloadsDone` never reloads. Fix: publish the live run's credited page set on the row (`DownloadedGallery.runProgress`), read badge and page states from that ONE value while a run stands, publish at announce/flush/exit.

Purpose: a repair must restore a gallery in place, and the sheet a user opens during a repair must describe the work the repair is doing.
Output: source + tests on `feature/gsd-phase-15` (two code commits), and `15-UAT.md` updated by the executor (uncommitted; the orchestrator commits docs).
</objective>

## Decisions this plan implements (LOCKED — from 15-UAT.md and the orchestrator diagnosis)

| Source | Decision | Where |
|---|---|---|
| G-15-2H `owner_decision_2026_08_18` | NEVER RENAME an existing gallery folder on an upstream title change | Task 1 |
| G-15-2H `fix_spec` | Freeze ONLY the leaf, inside `folderRelativePath`; parent stays caller-driven; both callers covered by construction; no migration; do not "fix" the Code=4 log line; three tests | Task 1 |
| Orchestrator (G-15-2F) | Carry the live run's measurement on the published record; badge + `buildInspectionPages` read that ONE value while a run stands; strict overlay (`downloaded` ⇔ credited, else `failed` ⇔ page failure, else `pending`); publish at announce and at exit; record-completeness quantities and gates stay on the record; the overlay never consults the disk; doc the two regimes | Task 2 |
| Orchestrator (G-15-2F) | Do NOT reuse `sessionCreditedPages` regimes 2/3 for the row (queued-window zero is a session-numerator rule) | Task 2 (PD-2) |
| Orchestrator (constraints) | Work on `feature/gsd-phase-15`; one code commit per task; the UAT edit is left uncommitted for the orchestrator | all |

## Planner design decisions (justified — do not re-litigate)

**PD-1 The frozen leaf is resolved from the INDEX record, not from a disk walk.** `folderRelativePath` reads `downloadIndex[payload.gallery.gid]?.folderURL.lastPathComponent`. Both callers already run against a loaded index (`processDownload`'s `download` came from it; `enqueue` reads `downloadIndex[gid]` two lines earlier for the parent), and the index is documented as "the read authority between explicit sync points — hot lookups must not walk download folders" (`+Persistence.swift:27-29`). `storage.galleryFolderURLs(gid:token:)` walks every user folder and is the reconcile-time tool, not a per-run resolver. No parameter is threaded: the spec wants the freeze inside the one function, and both callers would only pass the same index value back in. Consequence, stated in the doc: a folder the user renamed in Files.app (matched by manifest identity) keeps the user's name too — the leaf is whatever the record says it is.

**PD-2 One accessor for the run measurement, in a NEW file, and the census stays at seven.** `DownloadClient+ContinuedSession.swift` is at 997/1000 lines, so the accessor cannot live beside `sessionCreditedPages`. New file `DownloadClient+RunProgress.swift` holds `func liveRunProgressBasis(gid:) -> RunProgressBasis?` (the ONLY new executable mention of `runProgressBases`) and `func publishedRunProgress(gid:) -> DownloadRunProgress?`. `sessionCreditedPages` regime 1 (`+ContinuedSession.swift:250`) becomes `if let basis = liveRunProgressBasis(gid: gid) { return basis.creditedPageCount }` — a same-length one-line replacement, so that file's line count and its other two census sites (`hasSessionCreditReading`, the departure branch selector at `:799`) are untouched. Net: `DownloadSourceInventoryTests.expectedRunProofSites` moves `+ContinuedSession.swift: 3 → 2` and gains `+RunProgress.swift: 1`; the total stays 7 and its doc gains the accessor's role. `RunProgressBasis` (Manager.swift, 961 lines) gains `var creditedPageIndices: Set<Int>` with `creditedPageCount` redefined as its `.count` — the credited SET is one definition and the count is its size, so the card's numerator and the row's overlay are the same arithmetic by construction. Regimes 2/3 are NOT consulted by the row.

**PD-3 `DownloadRunProgress` carries only `creditedPageIndices`.** The strict overlay never reads the outstanding set (an outstanding page and a page the run neither inherits nor owes both read `.pending`), and the row still changes at every landing because credited = inherited ∪ (initial − outstanding) grows whenever outstanding shrinks; a flush that records only pages the run never owed changes the manifest anyway. Carrying an unused set would be dead data.

**PD-4 Publish points.** (a) Announce: `prepareWorkingSeedAnnouncingProgress` calls `await notifyObservers()` inside `if !pendingPages.isEmpty`, AFTER the existing session push, so the recording stays synchronous ahead of both suspensions and the push's doc-stated ordering is unchanged. (b) Flush: already publishes (`flushDownloadProgress` → `notifyObservers()`); the row now differs. (c) Exit: `finishActiveTaskIfOwned` publishes only for the OWNING exit; a run whose slot was nulled mid-run (pause / expiry pause sweep) retires its basis and publishes nothing, so the paused row would keep the overlay until the next unrelated publish — a real inconsistency for the refusal family (row k/N vs record N/N). Fix: `retireRunProgressBasis` returns whether it withdrew a standing measurement, `finishActiveTaskIfOwned` returns whether it owned the slot (its contract already is "every owning exit publishes here"), and `processDownload`'s `defer` publishes when the first is true and the second false. No duplicate emission on the owner path.

**PD-5 The three existing suites that reach the repair-seed MATERIALIZATION through a title-change re-slot are restaged through a PARENT change, and the materialization machinery stays.** `DownloadCoordinatorRepairSeedTests.testAnInterruptedRepairWithRenameKeepsTheSourceRecordAndItsFilesInAgreement` (`:257-319`, asserts `folderURL != sourceFolderURL` from the production derivation) and both cases in `DownloadRepairSeedSignalPropagationTests` (`:113-130`, `:238-250`) derive a differing destination from a payload whose TITLE differs. Post-fix the leaf is frozen, so `folderRelativePath` returns the source path and those pins go RED. Restage each: destination = `folderRelativePath(for: payload, parentFolderName: "Relocated")` — still the production derivation for the leaf, and the parent difference is now the only differing-destination shape left (`materializeRepairSeed` creates intermediates). Update each doc sentence that says the re-slot is a title change. `repairSeed` / `materializeRepairSeed` / `RepairSeedContext` are NOT deleted: post-fix production never reaches them from `processDownload` (destination == record folder ⇒ `shouldReuseWorkingFolder`'s existence guard and `repairSeed`'s existence guard cannot both fail), but WR-02 / G-15-13 / G-15-19 pins own that branch's contract and the LOCKED spec does not ask for removal. Record it in the SUMMARY and the UAT entry as a follow-up question for the owner ("retire the seed materialization?"), not an action.

**PD-6 Docs that must move with the code.** `buildInspectionPages` (D-SSOT-07 → two regimes, D-SSOT-10 named), `DownloadedGallery.runProgress`, `DownloadRunProgress`, `DownloadManifest`'s header doc (`DownloadedGallery+Manifest.swift:4-7` says the title "can change and re-slot the directory" — stale after Task 1), `removeSupersededFolders`' comment (`+Execution.swift:83-86`), `prepareWorkingSeedAnnouncingProgress` (publish + second named suspension), `retireRunProgressBasis` (exit publish), `DownloadSourceInventoryTests` census doc + failure message, `DownloadManifestSSOTInvariantTests` header (D-SSOT-09 note gains the D-SSOT-10 sentence). D-SSOT numbering: 01–09 exist (09 in the invariant suite); this is **D-SSOT-10**.

**PD-7 `DetailReducer.downloadNeedsRepair` (`DetailReducer.swift:122-126`) is left alone.** It reads `badge.progress` but is gated on `badge.status == .error`; `displayStatus` derives `.error` from `validationErrors`/`downloadErrors`, and every route that announces a run clears those at enqueue (`clearDownloadFailureState`), so a live overlay and `.error` do not coexist. Executor: confirm by reading `displayStatus(for:)` and the clear sites before leaving it; if a coexisting path is found, read the record there instead and say so in the SUMMARY.

**PD-8 Files.** New suites carry their own private fixtures — `DownloadFeatureTestHelpers.swift` (992) is NOT edited. `makeStubbedURLSession(stubSessionID:)` (file-private in `DownloadContinuedSessionRunProofTests.swift:875-891`, doc says "this file holds the only consumer") is HOISTED to `DownloadFeatureTestFactories.swift` (400 lines) as an internal `DownloadFeatureTestCase` extension member and the private copy deleted, because Task 2's overlay suite is a second consumer; a private duplicate is the drift the helpers file's own doc warns about. `DownloadSourceInventoryTests.swift` is at 992: the census table gains ONE line and the doc paragraph is rewrapped within its current line budget — `wc -l` must stay < 1000.

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@./CLAUDE.md
@.swiftlint.yml
@.planning/phases/15-continued-background-downloads/15-UAT.md
@AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
@AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
@AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
@AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
@AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
@AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
@AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
@AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
@AppPackage/Sources/DownloadClient/DownloadStore.swift
@AppPackage/Sources/AppModels/Download/DownloadedGallery.swift
@AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift
@AppPackage/Sources/AppModels/Download/DownloadedGallery+Manifest.swift
@AppPackage/Sources/AppModels/Download/DownloadInspection.swift
@AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
@AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
@AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift
@AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
@AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
@AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
@AppPackage/Tests/DownloadsFeatureTests/DownloadEnqueueManifestTests.swift
@AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorLoadTests.swift
</context>

## Repo conventions the executor must honor (verified this round)

- Branch `feature/gsd-phase-15`, main working tree. Baseline before this plan: **993 tests / 0 failures** (22 targets).
- Build/test are Xcode-only (bare `swift build`/`swift test` FAIL). Build + lint gate: `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED with 0 warnings (the SwiftLint plugin runs; suppressions/disables are forbidden). Test gate, ONE invocation at a time, never overlapping, never `pkill -9` mid-launch: `cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' 2>&1 | tee /tmp/t.log; grep -E "Test run with [0-9]+ tests|\*\* TEST (SUCCEEDED|FAILED)" /tmp/t.log` (Swift Testing; read the `✔/✘ Test run with N tests` lines; `-only-testing` may not filter on this scheme; NEVER `-testPlan FeatureTests`). Test files are not linted by the app scheme: lint touched test files with the standalone binary `$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint lint --strict --quiet <files>` (delete `AppPackage/.build` first if present).
- Read `.swiftlint.yml` before writing Swift. Hard rules that bite here: line length 120 and file length 1000 are ERRORS; no `try?`, no force unwrap/try; `sorted_imports`; single-line trailing closures on `map`/`filter`/`contains`/`first`/`withLock`… must be parenthesized; unlabeled multi-element tuple TYPES banned; no `At`-suffixed date names.
- Doc-comment discipline of this subsystem: every non-obvious design carries its WHY on the declaration (see `RunProgressBasis`, `buildInspectionPages`, `retireRunProgressBasis`). New code follows suit; stale sentences are corrected, not appended to.
- Reducers keep the `Feature`/existing suffix; nothing is renamed. Skills to invoke while executing: `swift-testing-pro` / `pfw-testing` (new suites), `pfw-composable-architecture` (Task 2's reducer pin), `swift-concurrency` (the actor `Task` publish in the `defer`).
- Commits: one per task, code only, subject ≤ 50 chars, `type(15): summary` (precedent: `fix(15): serialize the activity-log pump`); each built + full suite green. Never write an absolute home path into any generated doc (`$HOME/…`).

<tasks>

<task type="auto">
  <name>Task 1: Freeze the gallery folder leaf across runs (G-15-2H)</name>
  <files>
    AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift,
    AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift,
    AppPackage/Sources/AppModels/Download/DownloadedGallery+Manifest.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
  </files>
  <action>
Implements the LOCKED fix_spec (`15-UAT.md:1080-1123`). Diagnosis is confirmed in `root_cause` (`:1046-1075`): `folderRelativePath(for:parentFolderName:)` (`+ExecutionSupport.swift:35-47`) rebuilds the leaf from the fresh payload's `trimmedTitle` on every run; `trimmedTitle` truncates at the first `|` (`GalleryDetail.swift:84-91`); callers `+Execution.swift:158` (every mode) and `+PublicAPI.swift:99` (enqueue). When the recomputed path does not exist, `shouldReuseWorkingFolder` (`:668-690`) fails its `fileExists` guard before `case .repair: return true`, `setupWorkingFolder` (`:704-734`) materializes the seed at the new path, and `removeSupersededFolders` (`+Execution.swift:76-93`) deletes the old folder at completion — a rename.

**1.1 The freeze, inside the one function (PD-1).** Rewrite `folderRelativePath(for:parentFolderName:)`: `let galleryFolderName: String`; if `downloadIndex[payload.gallery.gid]?.folderURL.lastPathComponent` is non-nil, use it; else derive as today via `storage.makeFolderRelativePath(gid:token:title:)` (the `trimmedTitle`-or-`gallery.title` fallback unchanged); return `"\(parentFolderName)/\(galleryFolderName)"`. Doc block on the function (this is the G-15-2H contract, write it fully): the leaf is chosen ONCE, at first creation, and never recomputed (owner decision 2026-08-18, NEVER RENAME); why — the downloads directory is user-visible and user-managed through Files, so a repair that re-addresses a stable folder by a name recomputed from live network data moves the user's data out from under bookmarks and external tools (and `trimmedTitle` differs between a title carrying `|` and one that does not); the leaf's source is the INDEX record and why (read authority between sync points; a disk walk here would violate the hot-lookup rule; both callers run after the index is loaded); the parent is deliberately NOT frozen — `parentFolderName` is the caller's, so an in-app move still relocates, and cite `moveDownload` (`+Folders.swift:267-270`) as the sibling idiom that already keeps `download.folderURL.lastPathComponent` verbatim; a Files-app-renamed folder (matched by manifest identity) therefore keeps the user's name; no migration for folders already renamed by the pre-fix behavior (record and disk agree; `galleryFolderURLs` matches on manifest gid/token regardless of the readable half). Do NOT touch `shouldReuseWorkingFolder`, `setupWorkingFolder`, `repairSeed`, `materializeRepairSeed` or the "Stale working folder removal failed" log (fix_spec: it disappears on its own; PD-5).

**1.2 Stale docs.** `+Execution.swift:83-86` (`removeSupersededFolders`): rewrite the comment — a completed run's folder no longer differs from the record's through a title change (G-15-2H froze the leaf); the sweep remains for pre-fix history (a rename interrupted between materialization and completion left two folders) and for any differing-parent destination handed to the preparation directly, and only the completed folder may survive or the stale duplicate resurfaces once the surviving record is deleted (keep that last reason verbatim in substance). `DownloadedGallery+Manifest.swift:4-7` (`DownloadManifest` header): replace "the title in it can change and re-slot the directory without affecting identity" with the post-fix truth — the readable half is chosen once when the folder is created and a later upstream title change does not rename it (G-15-2H); identity still lives in the manifest, which is what re-establishes it after a Files-app move or rename.

**1.3 Restage the three re-slot suites (PD-5).** (a) `DownloadCoordinatorRepairSeedTests.swift:274-285`: derive `folderURL` with `parentFolderName: "Relocated"` instead of `existingDownload.folderName`; keep the `!=` assertion; add `#expect(folderURL.lastPathComponent == sourceFolderURL.lastPathComponent)` (the leaf really is frozen; the difference is the parent); update the doc's condition (2) at `:244-245` — a differing destination now arises only from a different parent (G-15-2H), and this case stages that shape explicitly. (b) `DownloadRepairSeedSignalPropagationTests.swift`: both cases (`:116-130` and `:236-250`) — the "reslotted" gallery keeps its DIFFERENT title (that difference is now inert and pins the freeze) and the destination is derived with `parentFolderName: "Relocated"`; keep `destinationFolderURL != sourceFolderURL` and the not-exists check; add the same `lastPathComponent` equality; update the doc sentences at `:47-50` and `:186` ("The re-slot is the upstream title change" → the re-slot is a parent change; the title change is retained to show it no longer moves the leaf). Rewrap; both files have room (628 / 300 lines).

**1.4 New suite `DownloadFolderLeafFreezeTests.swift`** (`struct DownloadFolderLeafFreezeTests: DownloadFeatureTestCase`, imports as `DownloadEnqueueManifestTests.swift`; own private fixture: temp root, `DownloadStore`, `DownloadQueueStore(fileURL: storage.queueURL())`, `DownloadCoordinator(storage:urlSession: .shared, queueStore:)`, `testingInstallActiveTask(gid: "busy", task: Task {})` so enqueue never starts a run — the `DownloadEnqueueManifestTests:17-22` idiom; `defer { removeTemporaryItem(at: rootURL) }`). Titles: A = "Onna no Battle Woman's Battle" (no pipe), B = "Onna no Battle | Woman's Battle" (pipe; `trimmedTitle` = "Onna no Battle"). Payloads via `sampleGallery()` + `sampleGalleryDetail(gid:title:)`, `folderName: "Folder"`.
- `testTwoRunsWithDifferingTitlesKeepOneFolderUnderTheFirstLeaf` (spec test 1): `reloadDownloadIndex()`; `enqueue(payloadA)` succeeds; `leafA = storage.makeFolderRelativePath(gid:token:title: detailA.trimmedTitle)`; folder `Folder/<leafA>` exists. NON-VACUITY: `storage.makeFolderRelativePath(... title: detailB.trimmedTitle) != leafA`. Then `folderRelativePath(for: payloadB(.repair), parentFolderName: "Folder") == "Folder/\(leafA)"`; `enqueue(payloadB)` (the already-known route, `+PublicAPI.swift:76-80`) succeeds; `storage.galleryFolderURLs(gid:token:).map(\.lastPathComponent) == [leafA]` (exactly one folder, the first leaf); the manifest at `Folder/<leafA>` still reads.
- `testARepairOverAnExistingFolderReusesItInPlace` (spec test 2): fixture via `makeQueuedCoordinator(galleries: [SessionGallery(gid, title: "Kept Name", pageCount: 3, completedPageCount: 3)], queuedGIDs: [], client: .noop)` — its folder is `Folder/[gid_token] Kept Name`; `writePageFiles(indices: [1, 2])` (page 3 absent → `resumeMode == .repair`, assert it); `reloadDownloadIndex()`; payload = `makeRepairPayload(for: SessionGallery(gid, title: "Retitled Elsewhere", pageCount: 3, completedPageCount: 3))` (a derived leaf that DIFFERS — assert `storage.makeFolderRelativePath(... "Retitled Elsewhere") != staged.folderURL.lastPathComponent`); `path = folderRelativePath(for: payload, parentFolderName: staged.folderName)`; `storage.folderURL(relativePath: path).standardizedFileURL == staged.folderURL.standardizedFileURL`; `testingPrepareWorkingSeedAnnouncingProgress(payload:existingDownload: staged, folderURL:)` → `seed.existingPages.keys.sorted() == [1, 2]` (reused in place, files kept), `storage.galleryFolderURLs(gid:token:) == [staged.folderURL]` (RED pre-fix: the materialization created a second folder and nothing swept it before completion), manifest still readable at `staged.folderURL`.
- `testTheLeafIsFrozenButTheParentIsNot` (spec test 3): same staging; `folderRelativePath(for: payload, parentFolderName: "Elsewhere") == "Elsewhere/\(staged.folderURL.lastPathComponent)"`.
- `testAGalleryWithNoRecordStillDerivesAFreshLeaf` (regression pin of the unchanged branch): unknown gid → `folderRelativePath(...) == "Folder/" + storage.makeFolderRelativePath(gid:token:title: detail.trimmedTitle)`.

Run the full suite (expect 993 + 4 = 997, 0 failures — plus any count change from 1.3, which adds no cases), build with lint, standalone-lint the touched test files. Commit: `fix(15): freeze the gallery folder leaf across runs`.
  </action>
  <verify>
    <automated>cd "$(git rev-parse --show-toplevel)" && grep -q 'lastPathComponent' AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift && grep -q 'G-15-2H' AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift && grep -q 'G-15-2H' AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift && grep -q 'G-15-2H' AppPackage/Sources/AppModels/Download/DownloadedGallery+Manifest.swift && grep -q 'struct DownloadFolderLeafFreezeTests' AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift && grep -q 'parentFolderName: "Relocated"' AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift && test "$(grep -c 'parentFolderName: "Relocated"' AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift)" = "2" && cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' 2>&1 | tee /tmp/t.log | grep -E "Test run with [0-9]+ tests|\*\* TEST (SUCCEEDED|FAILED)"</automated>
  </verify>
  <done>`folderRelativePath` reuses the indexed record's leaf and derives a fresh one only without a record; parent stays caller-driven; the two stale docs are corrected; the three re-slot suites are restaged through a parent change and pin the frozen leaf; `DownloadFolderLeafFreezeTests` (4 cases) green, full suite green (0 failures), build 0 warnings, standalone lint clean on touched tests; committed.</done>
</task>

<task type="auto">
  <name>Task 2: Publish the live run's measurement on the row and read the sheet from it (G-15-2F)</name>
  <files>
    AppPackage/Sources/AppModels/Download/DownloadRunProgress.swift,
    AppPackage/Sources/AppModels/Download/DownloadedGallery.swift,
    AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift,
    AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift,
    AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift,
    AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift,
    AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift,
    AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift,
    AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift,
    AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRunProgressReloadTests.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestFactories.swift,
    AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
  </files>
  <action>
Implements the orchestrator's G-15-2F design under PD-2/3/4/6/7/8. Read BEFORE editing: `RunProgressBasis` (`+Manager.swift:121-168`) and `runProgressBases` (`:720-750`), `sessionCreditedPages` (`+ContinuedSession.swift:183-279`), `prepareWorkingSeedAnnouncingProgress` (`+ExecutionSupport.swift:505-646`), `processDownload`'s `defer` and `retireRunProgressBasis` (`+Execution.swift:9-24`, `:282-330`), `finishActiveTaskIfOwned` (`:253-280`), `downloadedGallery(from:)` (`+Persistence.swift:74-88`), `buildInspectionPages` (`+PublicAPIHelpers.swift:6-83`), `DownloadedGallery.badge` (`+SupportTypes.swift:31-39`), `observeDownloadsDone` (`DownloadInspectorReducer.swift:142-161`), and the census doc + table (`DownloadSourceInventoryTests.swift:300-336`). Invariants that must NOT move: the pushed page pair and its floor writers, D-G2-01/D-G7-01/D-G2C-01 choreography, the retirement gate `isSupersededByALiveRun`, `completedPageCount`/`isIncomplete`/`displayStatus`/`retryablePageIndices`/`canValidateImageData` derivations, and "the overlay never consults the disk".

**2.1 Model.** New `AppPackage/Sources/AppModels/Download/DownloadRunProgress.swift`: `public struct DownloadRunProgress: Equatable, Sendable { public let creditedPageIndices: Set<Int>; public init(creditedPageIndices:); public var creditedPageCount: Int { creditedPageIndices.count } }`. Doc (D-SSOT-10): the row-published form of ONE run's own measurement of the pages it has covered (inherited work plus its own landed pages, `RunProgressBasis.creditedPageIndices`); present on a `DownloadedGallery` only while that run's measurement stands, `nil` otherwise; it is progress-of-this-run, not completeness-of-this-record; per AGENTS.md's SSOT clause it is an OPERATION-level, run-scoped signal for what the record legitimately cannot record — the wholesale-refusal family, whose record reads complete for the entire re-download because the irreversibility guard refused to blank — and for the honest family it equals the record's read at every flush; it writes nothing, never outranks queue membership, and is retired with the run. `DownloadedGallery.swift`: `public let runProgress: DownloadRunProgress?`; init gains `runProgress: DownloadRunProgress? = nil` as the LAST parameter (source-compatible with every existing construction incl. the test-side convenience init in `DownloadFeatureTestFactories.swift:61-117`); short doc pointing at the model's doc. `+SupportTypes.swift` `badge`: numerator `runProgress?.creditedPageCount ?? completedPageCount`, denominator unchanged; one doc sentence: display progress reads the live run while one stands, the record otherwise; `completedPageCount`, `isIncomplete` and every gate below stay on the record.

**2.2 The single accessor (PD-2).** `+Manager.swift` `RunProgressBasis`: add `var creditedPageIndices: Set<Int> { inheritedPages.union(initialPendingPages.subtracting(outstandingPages)) }` and make `creditedPageCount` `creditedPageIndices.count` (doc: the SET is the one definition; the card's numerator and the row's overlay are its size and its membership). Keep `wc -l` < 1000 (961 now). New file `AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift` (`import AppModels`, `import Foundation`; extension DownloadCoordinator): `func liveRunProgressBasis(gid: String) -> RunProgressBasis? { runProgressBases[gid] }` and `func publishedRunProgress(gid: String) -> DownloadRunProgress? { liveRunProgressBasis(gid: gid).map({ DownloadRunProgress(creditedPageIndices: $0.creditedPageIndices) }) }`. Doc on the first: this is the ONE read of the run measurement that both the credited-pages definition (`sessionCreditedPages` regime 1) and the published row consult, so the card's numerator and the sheet's overlay cannot drift; the census in `DownloadSourceInventoryTests` counts it as the seventh site; the lifetime rules live on `runProgressBases`' declaration and are not restated. `+ContinuedSession.swift:250`: replace the line with `if let basis = liveRunProgressBasis(gid: gid) { return basis.creditedPageCount }` — ONE line for one line, no other edit in that file (997/1000). `+Persistence.swift` `downloadedGallery(from:)`: add `runProgress: publishedRunProgress(gid: gid)`; do NOT name the map there (its count of ONE is load-bearing).

**2.3 Inspector page states.** `+PublicAPIHelpers.swift` `buildInspectionPages`: before the three branches compute `let isDownloaded = download.runProgress.map({ $0.creditedPageIndices.contains(page) }) ?? (download.manifest.pages[page]?.isEmpty == false)` and branch on it; the `.failed` and `.pending` arms are unchanged (a page the run owes that failed reads `.failed`; an outstanding page reads `.pending` even if the manifest claims it; a page the run neither inherits nor owes reads `.pending` for the run's duration and returns to its record read at exit; a credited page with a stale failure entry reads `.downloaded`, as a hash does today). Revise the doc block to state the TWO regimes explicitly: D-SSOT-07 (record read, unchanged out of a run — keep the existing paragraphs' substance) and D-SSOT-10 (while `download.runProgress` stands, the run's own measurement; why: for the refusal family the record reads N/N by design for the whole repair, so the sheet showed "Downloaded (N) / Pending (0)" over a from-zero re-download while the system card, fed by the same measurement, was right — G-15-2F; the credited-set size IS the badge numerator by construction, so header and groups agree; for the honest family the overlay equals the record at every flush; the overlay never consults the disk, writes nothing, never outranks queue membership, is retired with the run). Cite AGENTS.md's clause on session-scoped operation-level signals.

**2.4 Publish points (PD-4).** (a) `+ExecutionSupport.swift` `prepareWorkingSeedAnnouncingProgress`: inside `if !pendingPages.isEmpty`, AFTER the `if let continuedSessionID { await push }` block, add `await notifyObservers()`. Doc: add a paragraph — the row is published at the announcement (D-SSOT-10) so the sheet flips to the run's read immediately rather than at the first flush; this is a SECOND named suspension (the observer publication) and it follows the push, so the recording still precedes both and nothing said about the push's ordering changes. (b) `+Execution.swift`: `retireRunProgressBasis` → `@discardableResult`-free `-> Bool` returning whether a standing measurement was withdrawn (`runProgressBases.removeValue(forKey: gid) != nil` — still one whole-name mention on one line); `finishActiveTaskIfOwned` → `@discardableResult public func … -> Bool` returning whether this exit owned the slot (its `Task` publishes; doc it: "owned ⇒ this is the publish"); `processDownload`'s `defer`: `let withdrewMeasurement = retireRunProgressBasis(...)`, `let publishedOnExit = finishActiveTaskIfOwned(...)`, `if withdrewMeasurement && !publishedOnExit { Task { await self.notifyObservers() } }` with the comment: the row's overlay is retired with the run (D-SSOT-10); a non-owning exit — pause or the expiry sweep nulled the slot mid-run — publishes nothing through `finishActiveTaskIfOwned`, so without this the paused row would keep the run's read until the next unrelated publish. Keep the existing "ahead of the ownership clear" ordering comment. `processScheduledDownload` (`+Scheduling.swift:77`) keeps its call unchanged (discardable). Update `retireRunProgressBasis`'s doc with the exit publish.

**2.5 Census + invariant docs (PD-6/8).** `DownloadSourceInventoryTests.swift`: `expectedRunProofSites` → `"DownloadClient+ContinuedSession.swift": 2`, add `"DownloadClient+RunProgress.swift": 1`; total stays 7; rewrite the doc at `:300-333` (the seventh role is the single accessor `liveRunProgressBasis`, which regime 1 AND the published row read; the ContinuedSession three become two — the has-a-reading predicate and the departure branch selector) and the failure message at `:643-654` accordingly, WITHOUT growing the file past 999 lines (992 now; the table adds one line — rewrap the prose to absorb it). `DownloadManifestSSOTInvariantTests.swift` header (`:30-39`, D-SSOT-09 note): add one sentence — D-SSOT-10 (G-15-2F): while a run is LIVE the badge numerator and the inspector page states read the run's own measurement; every target here has no live run (the blocker parks the slot), so these families pin the record regime, and the live regime is pinned by `DownloadRunProgressOverlayTests`. `DownloadFeatureTestFactories.swift`: hoist `makeStubbedURLSession(stubSessionID:)` from `DownloadContinuedSessionRunProofTests.swift:875-891` (internal, in the `DownloadFeatureTestCase` extension, doc adjusted: "shared by the run-exit cases"), delete the private copy and its "only consumer" sentence.

**2.6 Tests.**
- `DownloadRunProgressOverlayTests.swift` (new, `struct …: DownloadFeatureTestCase`, imports as `DownloadContinuedSessionLedgerRefusalTests.swift`; fixtures via `makeQueuedCoordinator(galleries:queuedGIDs:client: .noop, taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }), urlSession:)`; `defer { removeTemporaryItem(at: fixture.rootURL) }`):
  (a) `testAWholesaleRefusalRepairReadsTheRunNotTheRecord` — model on `DownloadContinuedSessionLedgerRefusalTests.testAnAllPagesGoneRepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull` (`:97-197`): 6/6 record, NO files, `retryPages(gid, [1…6])` then `waitUntil !testingHasActiveTask()`, payload via `makeRetriedPagesPayload`, subscribe `observeDownloads()` BEFORE the announcement, `testingPrepareWorkingSeedAnnouncingProgress`. Then: `fetchDownload(gid)` → `completedPageCount == 6` (record untouched), `runProgress?.creditedPageIndices == []`, `badge.progress.completedPageCount == 0`, `badge.progress.pageCount == 6`; `loadInspection(gid)` → `pages.map(\.status) == Array(repeating: .pending, count: 6)`, `inspection.download.badge.progress.completedPageCount == 0` (header and groups from one value); the stream yielded a row with `runProgress?.creditedPageIndices == []` (announce publish). Flush [1,2,3] via `writePageFiles` + `flushDownloadProgress(force: true)` → `runProgress?.creditedPageIndices == [1, 2, 3]`, badge 3/6, inspector `[.downloaded ×3, .pending ×3]`, `completedPageCount` still 6. Then a production run exit: `SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in throw URLError(.notConnectedToInternet) }` (+ `defer removeHandler`), fixture built with `urlSession: makeStubbedURLSession(stubSessionID:)`; `await manager.processDownload(gid:)`; `waitUntil !testingHasActiveTask()`; then `fetchDownload(gid)?.runProgress == nil` and `badge.progress.completedPageCount == completedPageCount` (the record read is back), and the stream yielded a row with `runProgress == nil` after the exit.
  (b) `testAnHonestRecordReadsTheSameUnderTheOverlayAndTheRecord` — 6-page record with 3 hashes and files [1,2,3] present, `.repair`/resume payload (`makeRepairPayload`), announcement (inherited {1,2,3}, pending [4,5,6]); at announce and after flushing 4 then 5: `badge.progress.completedPageCount == completedPageCount` and the inspector's `.downloaded` indices == the manifest's non-empty-hash pages — no visible change for the honest family (D-SSOT-10 idempotence). Bank a `runProgress != nil` assertion so the pin is not vacuous.
  (c) `testAFailedOutstandingPageReadsFailedUnderTheOverlay` — refusal staging as (a); `testingSetFailedPageErrors([PageFailure(index: 4, relativePath: nil, error: .networkingFailed)], gid:)`; `loadInspection` → page 4 `.failed`, pages 1–3,5,6 `.pending`; then flush page 4 → reads `.downloaded` (credit wins over a stale failure entry, as a hash does).
  (d) `testANonOwningRunExitStillPublishesTheRecordRead` — refusal staging + announcement, then `testingInstallActiveTask(gid: "busy", task: Task {})` (another gallery holds the slot ⇒ `isSupersededByALiveRun` false because `activeGalleryID != gid`, `isActiveTaskOwner` false because `activeTask != nil`); subscribe the stream; `processDownload(gid:)` against the failing stub; the stream yields a row for `gid` with `runProgress == nil` (RED without PD-4(c)); `fetchDownload(gid)?.runProgress == nil`.
- `DownloadInspectorRunProgressReloadTests.swift` (new, `@MainActor` per member as `DownloadInspectorLoadTests.swift:11-16`; own private `makeInspectorStore` shaped like `:331-363`): `testARowThatDiffersOnlyInRunProgressReloadsTheInspection` — `download = sampleDownload(gid:title:status: .downloading, completedPageCount: 6)` (`pageCount` 6), `initialInspection = sampleInspection(download:)`; `changed` = a private helper re-initialising via the memberwise init with `runProgress: .init(creditedPageIndices: [1, 2])` and every other field copied (`modificationDate: download.lastDownloadedDate`); `store.exhaustivity = .off`; `send(.observeDownloadsDone([changed]))` and `receive(\.loadInspection)`. Add the negative control with exhaustivity ON: `send(.observeDownloadsDone([download]))` (identical row) then `store.finish()` — no `.loadInspection` is received.
- Existing suites to keep green, run as part of the full suite: `DownloadManifestSSOTInvariantTests`, `DownloadContinuedSessionBasisTests`, `DownloadObserverBatchTests`, `DownloadRetryPagesTests`, `DownloadsPresentationLifecycleTests`, `DownloadInspectorPauseFailureTests`, `DownloadInterruptedResumeTests` (its `:117-124` badge pin is unaffected: overlay 0 == record 0), `DownloadSourceInventoryTests` (with exactly the table edit of 2.5).

Full suite (expect 997 + 6 = 1003, 0 failures), build with lint, standalone-lint touched test files. Commit: `fix(15): overlay a live run's progress on the row`.
  </action>
  <verify>
    <automated>cd "$(git rev-parse --show-toplevel)" && grep -q 'public struct DownloadRunProgress' AppPackage/Sources/AppModels/Download/DownloadRunProgress.swift && grep -q 'runProgress: DownloadRunProgress? = nil' AppPackage/Sources/AppModels/Download/DownloadedGallery.swift && grep -q 'func liveRunProgressBasis' AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift && grep -q 'liveRunProgressBasis(gid: gid)' AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift && grep -q 'publishedRunProgress(gid: gid)' AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift && grep -q 'D-SSOT-10' AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift && grep -q 'creditedPageIndices' AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift && grep -q '"DownloadClient+RunProgress.swift": 1' AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift && test "$(wc -l < AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift)" -lt 1000 && test "$(wc -l < AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift)" -lt 1000 && test "$(wc -l < AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift)" -lt 1000 && cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' 2>&1 | tee /tmp/t.log | grep -E "Test run with [0-9]+ tests|\*\* TEST (SUCCEEDED|FAILED)"</automated>
  </verify>
  <done>A live run's credited page set rides on the published row; badge numerator and inspector page states read it as one value while it stands and the record otherwise; the row is published at announce, every flush and every exit (owner and non-owner); regime 1 and the row read the basis through `liveRunProgressBasis`; the census totals 7 with the one deliberate table move; record-completeness quantities and gates unchanged; new suites (5 + 1 cases) green, full suite green (0 failures), build 0 warnings, standalone lint clean; committed.</done>
</task>

<task type="auto">
  <name>Task 3: Record both fixes in 15-UAT.md (edit only — the orchestrator commits)</name>
  <files>.planning/phases/15-continued-background-downloads/15-UAT.md</files>
  <action>
Edit ONLY the two gap entries, the Summary's `completion_note`/`open_issues_note`, and two frontmatter lines (`Edit`, never a whole-file `Write`; the file is ~1900 lines). Follow the project's precedent for a fix awaiting device verification: G-15-2D kept `status: open` and gained a `fix_landed_2026_08_18: |` block (`:1409`) that opens "STATUS STAYS OPEN: nothing here is device-confirmed". Do NOT commit this file — the orchestrator makes the docs commit; leave the diff in the working tree and say so in the SUMMARY.

- G-15-2H (`:1023-1137`): keep `status: open`; change `severity:` to `confirmed-defect (fixed in code; awaiting device verification)`; add `fix_landed_2026_08_18: |` after `fix_spec` — first line names the Task 1 commit hash; then: the leaf freeze is inside `folderRelativePath(for:parentFolderName:)` (index-record leaf when the gallery has a record, fresh `trimmedTitle` leaf only without one; parent stays the caller's; both callers covered by construction; `moveDownload` cited as the sibling idiom); no migration; the Code=4 line was not touched (falls out); the two stale docs corrected (`removeSupersededFolders` comment, `DownloadManifest` header); the three re-slot suites restaged through a parent change; the four pins in `DownloadFolderLeafFreezeTests` by name; the follow-up question for the owner from PD-5 (the seed materialization is now unreachable from `processDownload`; retire it in a design round?). State what the next device run must show: repair a gallery whose stored title differs from the site's — the folder name in Files is unchanged afterwards, one folder for the gid, no "Stale working folder removal failed … Code=4" line in the jsonl.
- G-15-2F (`:1139-1162`): keep `status: open`; add `root_cause: |` (the two compounding parts: display basis on the RECORD which for the wholesale-refusal family reads N/N throughout the repair by design while `runProgressBases[gid]` reached only the system card; and the byte-identical manifest making the published row `==` its predecessor so `observeDownloadsDone`'s equality gate never reloaded); add `fix_landed_2026_08_18: |` — Task 2 commit hash; `DownloadedGallery.runProgress` (`DownloadRunProgress`, the credited page set) populated from the single accessor `liveRunProgressBasis`; badge numerator + `buildInspectionPages` strict overlay from that one value while a run stands (D-SSOT-10; header and groups cannot disagree); record-completeness quantities and gates unchanged; publish at announce / every flush / every exit incl. non-owner; census kept at 7 by moving one site; the pinning suites (`DownloadRunProgressOverlayTests`, `DownloadInspectorRunProgressReloadTests`) by name. State what the next device run must show: the same wholesale-refusal repair with the sheet open — "Downloading 0/27 / Pending (27)" at the announce, the numerator and the Downloaded group climbing with the card, and the record read (27/27) restored the moment the run ends.
- Summary: `completion_note` (`:790-795`) — G-15-2F and G-15-2H both have fixes landed 2026-08-18 (commits) and await device verification; `open_issues_note` (`:803-811`) — same, keep "TWO gaps carry `status: open`" but say each has a landed fix pending device confirmation.
- Frontmatter `updated:` (`:6`) → current UTC timestamp; `awaiting:` (`:20`) → "device re-run of the G-15-2H repair (folder name unchanged) and of the G-15-2F sheet during a wholesale-refusal repair, on the 260818-mjs build". No other section changes; no absolute home paths.
  </action>
  <verify>
    <automated>cd "$(git rev-parse --show-toplevel)" && f=.planning/phases/15-continued-background-downloads/15-UAT.md && test "$(awk '/gap_id: G-15-2H/{f=1} f&&/fix_landed_2026_08_18/{print "yes"; exit}' "$f")" = "yes" && test "$(awk '/gap_id: G-15-2F/{f=1} f&&/fix_landed_2026_08_18/{print "yes"; exit}' "$f")" = "yes" && test "$(awk '/gap_id: G-15-2F/{f=1} f&&/root_cause:/{print "yes"; exit}' "$f")" = "yes" && test "$(grep -c '/Users/' "$f")" = "0" && git status --porcelain "$f" | grep -q '^ M'</automated>
  </verify>
  <done>Both entries carry `fix_landed_2026_08_18` with commit hashes, mechanism, tests and the device-run acceptance; G-15-2F carries `root_cause`; Summary and frontmatter refreshed; no absolute home path; the file is modified in the working tree and NOT committed by the executor.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| network payload → on-disk folder name | the fresh gallery title used to name a user-visible folder; post-fix it names a folder only at first creation |
| index record → path construction | the frozen leaf is taken from an indexed `folderURL`; it must remain a single confined component |
| coordinator run state → published UI row | a run-scoped measurement is exposed on a value type consumed by every list/badge surface |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-Q-01 | Tampering (path) | `folderRelativePath` leaf reuse | low | mitigate | the leaf is `lastPathComponent` of a URL the store's own root-confined scan produced (a single component cannot carry a separator); the parent still goes through the caller's confined resolution; no user string is admitted here |
| T-Q-02 | Information Disclosure | `DownloadRunProgress` on the row | low | accept | page indices only; no titles/paths added to logs; nothing logged in this task |
| T-Q-03 | Tampering (integrity of the record) | overlay vs manifest | medium | mitigate | the overlay writes nothing and consults no disk (`buildInspectionPages` stays a pure function of its inputs); `completedPageCount`, `isIncomplete`, `displayStatus`, retry basis unchanged; pinned by the SSOT invariant suite staying green and by the overlay suite |
| T-Q-04 | Denial of Service | extra observer publishes | low | mitigate | one publish at announce, one at a non-owner exit; flush cadence unchanged; no duplicate on the owner exit (Bool-gated) |
| T-Q-SC | Tampering | npm/pip/cargo installs | low | accept | no packages added |
</threat_model>

<verification>
- Full package suite green after each code task (one invocation at a time): Task 1 → 997, Task 2 → 1003 (baseline 993 + 4 + 6), 0 failures.
- `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED, 0 warnings.
- Standalone SwiftLint `--strict` clean over every touched/new test file.
- `DownloadSourceInventoryTests` passes with exactly the one table move (`+ContinuedSession.swift` 3→2, `+RunProgress.swift` 1; total 7); `DownloadManifestSSOTInvariantTests` passes unchanged in behavior.
- File-length gates: `+ContinuedSession.swift` (997) and `+Manager.swift` (<1000) and `DownloadSourceInventoryTests.swift` (<1000) under the ERROR gate; `DownloadFeatureTestHelpers.swift` untouched (992).
- `git status`: two code commits on `feature/gsd-phase-15`; `15-UAT.md` modified and uncommitted.
</verification>

<success_criteria>
- G-15-2H: a `.repair` (or any run) over a gallery that already has a record lands in the same folder under the same leaf; the parent still follows the caller; the three fix_spec tests plus the no-record pin are green; the seed materialization is unreachable from `processDownload` and that is recorded as an owner question, not acted on.
- G-15-2F: with a wholesale-refusal record (N/N claimed, files gone) under repair, the published row reads credited/N and the inspector reads N pending → k downloaded / N−k pending after k pages, from ONE value; the honest family shows no visible change; the row is re-published at announce, flush and exit; the reducer reloads on a row that differs only in `runProgress`.
- 15-UAT.md updated as specified and left for the orchestrator's docs commit; no absolute home paths anywhere.
</success_criteria>

<output>
Create `.planning/quick/260818-mjs-fix-g-15-2f-and-g-15-2h/260818-mjs-SUMMARY.md` when done (deviations, the two commit hashes, final test counts, the census table move, the PD-5 owner question, and confirmation that 15-UAT.md was edited but not committed).
</output>
