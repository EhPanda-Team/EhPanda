---
phase: 15-continued-background-downloads
plan: 70
subsystem: downloads
tags: [download-client, filesystem, path-confinement, security, manifest-ssot, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-63's confinedDirectUserFolderURL and 15-68's mutatingConfinedUserFolder — the boundary this round re-terms"
provides:
  - "confinedDirectUserFolderURL as an ADMISSION test written in the listing's terms: every name scanDownloads can promote is mutable, with two named deliberate exceptions"
  - "DownloadFolderAdmissionTests: the positive half of the user-folder name catalog, four own-on-disk non-normalizing names asserted to list, delete and rename"
  - "FolderNameRefusal: both refusal catalogs pin WHICH refusal, so neither can drift into the other's answer"
  - "moveDownload's destination admitted as picked rather than rewritten, closing the near-duplicate folder hazard"
affects: [user-folder boundary, folder listing/mutation agreement, record/disk convergence, download-root confinement]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A predicate over untrusted input must be derived from the surface that PRODUCES that input, not from the surface that generates the app's own values"
    - "An argument catalog that stages only refusals can fail only when the boundary is too loose; the positive half is what pins it from below"
    - "When a refusal's SHAPE changes, re-derive which true thing it says rather than accepting 'some failure'"
    - "State a structural claim at the strength it actually holds — name the composition that still reproduces the defect rather than calling it unwritable"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderAdmissionTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift

key-decisions:
  - "DEC-A: the PREDICATE moves, not the listing — the scan describes a disk the app does not own, so admission is stated in the listing's terms and normalization is confined to the sites that MINT a name"
  - "DEC-B: the admission test is structural, not a membership test against the scanned listing — a listing lookup would make a mutation depend on a cached read of a disk that may have changed, and the structural clauses already refuse every escape"
  - "DEC-C: two refusals CAN name a listed directory (control characters, a symlinked direct child) and both are kept deliberately, named in the doc rather than papered over with an absolute claim"
  - "DEC-D: moveDownload's destination is ADMITTED raw — the menu offers only listed values, and rewriting one created a near-duplicate folder beside the folder the user picked"
  - "DEC-E: the padded/separator alias arguments are re-pinned to .notFound rather than deleted; the property they protect is unchanged, only which true thing the refusal says"

patterns-established:
  - "Every argument in a name catalog asserts WHICH refusal, through one shared expectation both catalogs call"
  - "A fixture proves it reaches its intended shape: each catalog name asserts what normalization would rewrite it into, so a case cannot quietly stop discriminating"

requirements-completed: []

coverage:
  - id: D1
    description: "A folder whose OWN on-disk name is not its normalized form lists, deletes, and converges all three record stores"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderAdmissionTests.swift#testAListedNonNormalizedFolderDeletesWithRecordConvergence"
        status: pass
    human_judgment: false
  - id: D2
    description: "The same folder renames, its downloads repoint, and the DESTINATION is still minted"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderAdmissionTests.swift#testAListedNonNormalizedFolderRenamesAndRepointsItsDownloads"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every structural escape refusal survives the relaxation, each pinned to the specific refusal it must produce"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift#testDeleteFolderRefusesANameThatIsNotADirectChild + #testRenameFolderRefusesASourceThatIsNotADirectChild + the symlink case"
        status: pass
    human_judgment: false
  - id: D4
    description: "No public API reproduces the unconfined name-to-URL construction in one call"
    verification:
      - kind: unit
        ref: "grep gate: `removeFolder(relativePath` returns no hit in Sources, Tests, App or ShareExtension"
        status: pass
    human_judgment: false

# Metrics
duration: 30min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 70: Admission on the Listing's Terms Summary

**The boundary and the surface that feeds it now describe the same set of names: `confinedDirectUserFolderURL` is an admission test written in `scanDownloads`' terms, so every folder the app lists is deletable and renamable again, while every structural escape is refused exactly as before — and the one-call rewrite of the original defect is deleted.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-08-10T11:45Z
- **Completed:** 2026-08-10T12:14Z
- **Tasks:** 2 (RED, GREEN)
- **Files created:** 1
- **Files modified:** 4 (3 sources, 1 test file)

## Accomplishments

- **The defect was a predicate borrowed from the wrong surface, and the fix moves the predicate.** `normalizedUserFolderName` answers "what would this app NAME a folder"; it was being asked "is this a folder the app may TOUCH". Those are the same question only for names the app minted itself. The listing mints nothing — it reports whatever is on a disk shared over File Sharing and open-in-place — so the two sets diverge the moment a user makes a folder in the Files app. The RED run recorded all eight consequences verbatim and identically: `Art  Books`, `" Photos"`, `Manga\Vol1` and `Misc etc.` each answered `failure(AppError.fileOperationFailed("The folder name is invalid."))` to BOTH `deleteFolder` and `renameFolder`, while the listing assertion in the same case passed on every one. That asymmetry — listed and un-mutable in one test body — is the gap stated in its own words.
- **The positive half of the catalog is what makes the boundary two-sided.** The refusal catalog can fail only when the boundary is too loose; that is why a boundary too tight shipped green twice, through a code review and a verification cycle. Each new argument is staged with `FileManager.createDirectory` under its OWN name — never through `createFolder`, which would mint it away — and each one asserts, before anything else, that normalization really does rewrite it (`Art  Books` → `Art Books`, `" Photos"` → `Photos`, `Manga\Vol1` → `Manga Vol1`, `Misc etc.` → `Misc etc`). A case that quietly became a normalizing name would fail on that assertion instead of silently passing over the defect, which is the failure mode this phase has shipped more than once.
- **Nothing was bought by weakening a refusal.** All six delete arguments, all six rename arguments and the symlink case stayed in the suite unchanged in what they protect. What changed is that each now names WHICH refusal it expects, through one shared expectation both catalogs call. Three arguments legitimately moved from "this name is invalid" to "this name is fine and there is nothing at it" — because a source is admitted as written, `"  Keeper  "` can only ever mean a directory literally so named, and none exists. The folder they guard, `Keeper` / `Alias Target`, is still never reached.
- **`moveDownload`'s destination was a second instance of the same mistake, in the opposite direction.** It normalized a name the folder MENU had produced, so picking the listed `Art  Books` resolved onto `Art Books`, which `ensureUserFolder` would then create — moving the gallery into a second folder the user never made and leaving two near-identical rows. The destination is now admitted as picked, and the vanished-folder recreation recreates it verbatim.
- **The structural claim behind 15-68 was restated at the strength it holds.** The old tombstone said deleting `userFolderURL(name:)` made the defect "unwritable". It did not: a `public` relative-path removal spelling reproduced it in one call. That function is deleted (zero callers, verified across `App`, `AppPackage` and `ShareExtension` before removal). But `folderURL(relativePath:)` is still public and must be, because record paths are strings — so the honest claim, now written in the source, is that no SINGLE call turns a caller's name into a mutation, and that reproducing the defect takes composing two functions whose docs both refuse it. That is a convention review enforces, not a property the type system does.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — pin the positive half of the admission contract** - `b111ca91` (test)
2. **Task 2: GREEN — move the predicate to the listing's terms** - `50661d95` (fix)

## The Consumer Sweep: Every Name-to-URL Site and Its Disposition

Enumerated from source (`confinedDirectUserFolderURL`, `createUserFolder`, `ensureUserFolder`, `deleteUserFolder`, `removeFolder`, `folderURL(relativePath:)`, `normalizedUserFolderName`), not from the plan's list.

| Site | What the name is | Disposition |
|---|---|---|
| `deleteFolder`'s resolution + existence pre-check (`+Folders.swift:122`) | a LISTED name from the UI | **Admitted raw. Changed.** Previously refused for a non-normalizing listed folder before the disk was consulted; now `.notFound` can only be said about the name the caller actually gave. |
| `deleteUserFolder(named:)` (`+Operations.swift:527`) | the same string | **Admitted raw. Changed.** Same boundary re-decided inside the lock; the `.typeDirectory` guard is untouched. |
| `renameFolder`'s SOURCE → `renameUserFolder(oldName:)` (`+Folders.swift:85`) | a LISTED name | **Admitted raw. Changed.** Never normalized: normalizing selects a different folder than the caller named. |
| `renameFolder`'s DESTINATION (`+Folders.swift:58`) | a name being MINTED | **Still normalized. Unchanged.** |
| `createFolder` (`+Folders.swift:23`) | a name being MINTED | **Still normalized. Unchanged.** |
| `moveDownload`'s destination + `ensureUserFolder` recreation (`+Folders.swift:214, 265`) | a PICKED name — `DownloadsView.moveDestinations` filters `store.folders`, so only listed values reach it | **Admitted raw. Changed (DEC-D).** The rewrite was the near-duplicate hazard. |
| `repointRenamedUserFolder` (`+Folders.swift:307`) | the store's own post-move `relativePath` | **Unchanged.** A read model describing a move already performed; path and URL derived from one value. |
| `manifestURL(relativePath:)` (`DownloadStore.swift:134`) | a record's relative path | **Unchanged.** A read; no mutation reaches it. |
| `writeInitialManifest` (`+PublicAPI.swift:152`) | `<parent>/<gallery>` from the enqueue payload or the scanned record | **Unchanged, and out of this family.** It constructs a two-component GALLERY folder, a shape a direct-child boundary cannot express. Note that 15-68's DEC-C reason for not confining it (a gallery under a non-normalizing folder would become permanently un-enqueueable) is now obsolete — the boundary would admit such a parent — but the shape mismatch stands, so nothing changed here. |
| `removeFolder(at:)` → `removeGalleryFolders` (`+Execution.swift:101`) | a URL the scan produced | **Unchanged.** The record-path primitive; deliberately prefix-based because its caller names gallery folders nested under user folders. |
| `removeFolder(relativePath:)` | an arbitrary caller string | **DELETED (WR-01).** Zero callers before removal, verified across `App`, `AppPackage`, `ShareExtension`. |

`ensureUserFolder` has exactly ONE caller at this HEAD (`moveDownload`); `createUserFolder` one (`createFolder`); `deleteUserFolder` one (`deleteFolder`). Every user-folder mutation is still a `mutatingConfinedUserFolder` body.

## Which Side Moved, and What the Boundary Now Admits (verification gap 1, bullet 1)

The PREDICATE moved. The listing is not a set the app chooses; `scanDownloads` promotes every visible directory that is neither gallery-shaped nor manifest-bearing, over a root inside `Documents/` with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` both true.

Deleted: the normalization-identity clause. Kept verbatim: non-empty, not `.`, not `..`, exactly one path component, standardized parent == root, resolved parent == root, and the leaf's `.typeDirectory` re-check inside the mutation lock. Added: a control-character refusal and a gallery-shape refusal.

**Two of these refusals can, in principle, name a real listed directory, and both are deliberate (DEC-C).** This is stated in the function's doc rather than smoothed over, because "an admission test that cannot refuse a listed name" is not literally achievable and claiming it would be the same kind of overclaim this phase has been correcting:

- **Control characters.** POSIX permits them in a filename, so such a directory can exist and be listed. It is refused because the name flows into log lines, error strings and a `Result` the UI renders, and no ordinary file browser produces one.
- **A symlinked direct child.** `directoryURLs` resolves `.isDirectoryKey`, so a link to a directory IS listed. Renaming or removing through it acts on the link, not on the folder the user is looking at — the property 15-63's DEC-B established and this round did not touch.

Everything else the listing can produce is admitted: a single component with no control characters, whose parent is the root both lexically and after symlink resolution, is exactly what `contentsOfDirectory` yields.

**Why structural rather than a membership test against the scan (DEC-B).** The review offered exact membership against the listing as an alternative. It was rejected: `userFolders` is a cached read of a disk that may have changed, so a mutation gated on it would be authorized by stale state — the precise failure `mutatingConfinedUserFolder` exists to prevent by re-deciding inside the lock. The structural clauses already refuse every escape argument in both catalogs, and none of those refusals ever depended on the deleted clause.

## Banked Falsifiability

The RED suite failed against pre-fix production with **48 verbatim issues** across 8 parameterized cases — 7 per delete case, 5 per rename case. The listing assertion (`"The listing must produce this name verbatim"`) **passed on all eight**; that it passes while the mutations fail is the gap.

| Argument | Pre-fix delete | Pre-fix rename | Post-fix |
|---|---|---|---|
| `Art  Books` | `failure(.fileOperationFailed("The folder name is invalid."))`; folder, page bytes, index, queue store, task store and listing all still present | same error; nothing moved | deletes with all four records cleared; renames onto the minted destination |
| `" Photos"` | identical | identical | identical |
| `Manga\Vol1` | identical | identical | identical |
| `Misc etc.` | identical | identical | identical |

The two RED runs were byte-identical (48 issues each) and neither logged a `Download failed` line, so the foreign scheduler hold did its job: no independent run decided the record assertions.

Re-pinned refusal arguments — RED under Task 1 by construction, since they assert the post-fix answer:

| Argument | Was pinned | Now pinned | Why the property is unweakened |
|---|---|---|---|
| delete `whitespacePaddedAlias` (`"  Keeper  "`) | `.fileOperationFailed` | `.notFound` | A source is admitted as written, so this string can only mean a directory literally so named. `Keeper`, its gallery folder and its page bytes are still asserted intact, as are all three record stores. |
| rename `whitespacePaddedAlias` (`"  Alias Target  "`) | `.fileOperationFailed` | `.notFound` | Same; `Alias Target` still asserted in place and the destination still never created. |
| rename `separatorSanitizedAlias` (`"Alias:Target"`) | `.fileOperationFailed` | `.notFound` | Same. Not named by the plan — see Deviations. |

The four remaining delete arguments, the four remaining rename arguments and the symlink case are unchanged in both their assertions and their pinned refusal.

## Decisions Made

- **DEC-A: the predicate moves, the listing does not.** Filtering the listing instead would hide a real folder the user can see in the Files app, which is a worse answer than refusing to mutate it; the folder is a usable download destination and must stay one.
- **DEC-B: structural admission, not membership against the scan.** A membership test would authorize a mutation from a cached read. The structural pair (single component + both parent equalities) is what actually refused `"MyFolder/[123_abc] Title"`, `..`, `../Outside` and the absolute path — none of those refusals ever came from the deleted clause.
- **DEC-C: the two listing-reachable refusals are named, not claimed away.** Recorded in the source doc with what each costs. An absolute "cannot refuse a listed name" would be false, and a later round reasoning from it would land wrong — the failure mode the last three reviews each caught once.
- **DEC-D: `moveDownload` admits its picked destination.** The menu is built from `store.folders`, so in production the destination is always a listed name; admitting it raw changes no production path and closes the near-duplicate creation. It does mean the API, called directly with an unlisted padded string, would now create a folder literally so named rather than a trimmed one — a test-only reachability, recorded rather than hidden.
- **DEC-E: the alias arguments are re-pinned, not removed.** They are the only cases proving a source is never rewritten onto a different real folder; deleting them to avoid re-deriving an expectation would drop the protection along with the assertion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan named one re-derivation; the same shape occurs twice more**

- **Found during:** Task 1 (RED)
- **Issue:** The plan required re-deriving `whitespacePaddedAlias` in both catalogs and stated that was the only change. The rename catalog's `separatorSanitizedAlias` (`"Alias:Target"`) is the identical shape — a spelling normalization would resolve onto a real folder, naming nothing on disk itself — so it too flips from `.fileOperationFailed` to `.notFound` once sources are admitted as written. Left unre-derived it would have failed the Task 2 gate and invited exactly the wrong repair: tightening the boundary back onto `:`.
- **Fix:** Both alias arguments in the rename catalog and the one in the delete catalog re-pinned to `.absentSource`, each with a case doc deriving why the property is unchanged. The pinning is done through one shared `expectRefusal` both catalogs call, so an argument can no longer be satisfied by the other catalog's answer.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift`
- **Verification:** Both six-argument catalogs and the symlink case green under the Task 2 gate; 14 tests in 2 suites.
- **Committed in:** `b111ca91` (Task 1 commit)

### Corrections to the plan's premises

Recorded rather than silently followed, since both are claims a later round could reason from:

1. **The plan's disposition list names `ensureUserFolder`'s "other callers (enqueue-parent path — constants `Default`/`Automation`)".** That caller does not exist at this HEAD: 15-68's DEC-C removed it as redundant. `ensureUserFolder` has exactly one caller, `moveDownload`. The table above is enumerated from source.
2. **The plan's `must_haves` truth says every listed folder is mutable, unqualified.** Two deliberate refusals can name a listed directory (DEC-C). The source doc and this summary state the exception; the four catalog names — the shapes the gap was reported for — are all admitted.

### Files declared but not modified

`AppPackage/Sources/DownloadClient/DownloadStore.swift` was modified (the tombstone comment), as declared. All five declared files were touched.

---

**Total deviations:** 1 auto-fixed (an unswept sibling inside the plan's own re-derivation), plus 2 recorded corrections to the plan's premises
**Impact on plan:** No behaviour outside the plan's contract changed, and no assertion was weakened to make a case pass.

## Issues Encountered

- **The obvious symmetry ("make the sibling match") is what doubled this defect's blast radius one round ago.** The predicate was extended from rename to delete faithfully, and nobody compared it against `scanDownloads`. The lesson recorded here: a predicate over untrusted input has to be derived from the surface that PRODUCES the input, and a sibling sweep is not a substitute for that derivation.
- **A refusal-shape change is a place where a fix can quietly buy itself green.** Flipping three arguments from "invalid name" to "not found" would look like a passing catalog even if the boundary had been loosened to admit `..`. Pinning WHICH refusal, through one function both catalogs call, is what keeps the catalog discriminating in both directions.
- **The plan's `-only-testing:` selector had to be confirmed rather than trusted.** The reported count moved 12 → 14 across two suites, so the new suite really ran; 15-67's non-selecting-filter hazard did not apply, because the struct is declared in the file the suite is named for.

## Verification Evidence

One `xcodebuild` invocation at a time, with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`:

1. Task 1 RED gate — `-only-testing:DownloadsFeatureTests/DownloadFolderAdmissionTests` — **TEST FAILED**, 2 tests / 8 cases / **48 issues**, run twice with identical results and no `Download failed` line.
2. Task 2 gate — both suites — **TEST SUCCEEDED**, **14 tests in 2 suites**, 0 warnings (12 → 14 confirms the filter selected the new suite).
3. Full `FeatureTests` — **TEST SUCCEEDED**, **952 tests / 0 failures across 22 targets** (baseline 950, +2 for the two parameterized cases); downloads target **433 tests in 73 suites**. Zero `warning:` lines in the whole run.
4. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1570DerivedData build` — **BUILD SUCCEEDED**, **0 warnings, 0 errors**; the SwiftLint build plugin runs in-build, so this is lint-clean over `Sources/`.
5. Standalone SwiftLint `--strict` over all 5 touched files (the app scheme does not lint `Tests/`) — **0 violations, 0 serious**.

Acceptance greps:

- `rg -n 'normalizedUserFolderName\(rawName\) == rawName' AppPackage/Sources` → **no match**.
- `rg -n 'removeFolder\(relativePath' AppPackage/Sources AppPackage/Tests App ShareExtension` → **no match** (declaration, callers and comments all gone).
- `rg -n 'controlCharacters' .../DownloadStore+Operations.swift` → line 654, the admission clause; `rg -n 'isGalleryFolderLikeName' .../DownloadStore+Operations.swift` → line 655, the gallery-shape refusal.
- `rg -n 'normalizedUserFolderName' .../DownloadClient+Folders.swift` → exactly two hits, `createFolder` (23) and `renameFolder`'s new-name guard (58). `moveDownload` has none.
- File lengths: `+Operations.swift` 829, `DownloadStore.swift` 941, `+Folders.swift` 334, `DownloadFolderOperationTests.swift` 751, `DownloadFolderAdmissionTests.swift` 275 — all under the 1000-line error. `DownloadContinuedSessionTests.swift` and `DownloadFeatureTestHelpers.swift` (992) were **not touched**; the new suite carries its own fixture.
- Line lengths: no line over 120 in any touched file.
- `git diff --diff-filter=D --name-only HEAD~2 HEAD` → empty.
- No `swiftlint:disable`, no `try?`, no force unwrap, no new localized catalog entry.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderAdmissionTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift` — FOUND
- Commit `b111ca91` — FOUND
- Commit `50661d95` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced. Every symbol added has a live consumer: the admission clauses run on every user-folder mutation, and `FolderNameRefusal` is asserted by both catalogs.

## Threat Flags

None. The plan's registered threats are addressed rather than extended:

- **T-15-70-01 (relaxation as privilege escalation):** the relaxation admits no multi-component path, no `.`/`..`, no absolute path, no control character, no name whose standardized or resolved parent is not the root, no symlinked child (lock-time `.typeDirectory` re-check) and no gallery-shaped name. Both six-argument catalogs and the symlink case re-run green beside the new positive catalog, each pinned to a specific refusal.
- **T-15-70-02 (resurrection of the unconfined construction):** deleted outright, grep-gated across `Sources`, `Tests`, `App` and `ShareExtension`. The residual composition risk is stated at its true strength in the source rather than claimed away.
- **T-15-70-03 (listed folder un-mutable):** closed for the four reported shapes, pinned end to end from listing through delete/rename with record convergence.
- **T-15-70-04 (padded alias resolving onto a different folder):** sources are never normalized; all three alias arguments re-pinned with their survival assertions verbatim.

No new network endpoint, auth path or schema was introduced, and no log line was added or moved.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Verification gap 1 / CR-01 is closed at its root**, with all four `missing[]` bullets answered: which side moved and why (bullet 1), a disposition table over every name-to-URL site including `moveDownload`'s near-duplicate hazard (bullet 2), the positive half of the catalog with success-side convergence (bullet 3), and the dead reconstruction deleted (bullet 4 / WR-01).
- **Remaining verification gaps are untouched and independent:** gap 2 (`materializeRepairSeed`'s source-folder divergence, review WR-02), gap 3 (`authorizedReconciliationScan`'s missing post-removal compensation and the `scanSucceeded` re-sourcing), gap 4 (`toggleDownloadPauseDone(.failure)`'s silent refusal), gap 5's unowned-invariant residuals including IN-01 and IN-02.
- **One follow-up this round created work for:** 15-68's DEC-C rationale for leaving the enqueue parent-folder path unconfined is now obsolete, since the boundary would admit a non-normalizing parent. The site was still left alone because it builds a two-component gallery path, which this boundary cannot express — a future round wanting to confine it needs a gallery-folder boundary, not this one.
- The localized-key spelling split (IN-02) was neither widened nor narrowed: the two refusal helpers this file already had are untouched, and no new localized string was introduced.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
