---
phase: 15-continued-background-downloads
plan: 73
subsystem: downloads
tags: [tca, download-inspector, error-reporting, toast, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-69's retry-refusal fix — the toast surface wired onto retryPagesDone(.failure) and the private AppError mapping this plan renames and shares"
provides:
  - "toggleDownloadPauseDone(.failure) reports the client's refusal through the toast the reducer already owns"
  - "actionFailureToast — the same AppError mapping, renamed and re-derived for two consuming action families"
  - "A per-action failure disposition enumeration on BOTH reducers' type docs (4 inspector + 5 list), so an outcome-carrying action with no disposition contradicts a doc"
  - "DownloadInspectorPauseFailureTests — the pause branch pinned from both sides, per failure kind, plus the tap path end to end"
affects: [download inspector, downloads list, refusal reporting, verification round 21]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A per-branch disposition is stated ONCE at the type level as a checkable enumeration, with one-line anchors at each case — a scattered comment set cannot be checked against the action enum"
    - "A shared error→presentation mapping is named for the question it answers, not for its first caller"
    - "A test case pinning an arm its own caller cannot reach is labelled as a rename/regression guard, not as a reachability claim"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift
  modified:
    - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
    - .planning/phases/15-continued-background-downloads/deferred-items.md

key-decisions:
  - "DEC-A: the pause failure arm reuses the retry branch's shape verbatim (toast, then reload), so the two siblings read as one family; the mapping is renamed actionFailureToast and its doc re-derived for both"
  - "DEC-B: the sweep is stated ONCE per reducer as a type-level enumeration checkable against `Action`, with per-case one-line anchors — a new outcome-carrying action with no disposition contradicts the doc"
  - "DEC-C: `togglePause`'s reachable failure kinds are exactly `.notFound` and `.unknown` (derived by reading every exit); `.fileOperationFailed` is pinned as a rename guard on the SHARED mapping and labelled as such, not claimed as a togglePause exit"
  - "DEC-D: `DownloadsReducer.toggleDownloadPauseDone` is recorded as SILENT-AND-WEAKEST rather than deliberately silent — it is the same refusal seen from the list, and closing it needs a presentation surface the reducer does not own; logged as an open item instead of given a justification it does not have"

patterns-established:
  - "Disposition docs distinguish three verdicts, not two: reports / deliberately silent / silent-and-known-weak. The third exists so an unclosed item cannot be laundered into a considered decision."
  - "When a plan's staged inputs and its acceptance criterion disagree about reachability, the source is the arbiter and the divergence is written into the case doc."

requirements-completed: []

coverage:
  - id: D1
    description: "A pause/resume refusal for a gallery deleted underneath the inspector reports `.notFound`'s own wording and still resettles the screen"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift#testDownloadInspectorReportsAPauseRefusedBecauseTheGalleryVanished"
        status: pass
    human_judgment: false
  - id: D2
    description: "A pause/resume refusal for a status that left the toggleable set between render and tap reports `.unknown`'s wording"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift#testDownloadInspectorReportsAPauseRefusedBecauseTheStatusMovedOn"
        status: pass
    human_judgment: false
  - id: D3
    description: "The shared mapping's payload arm survives the rename: a file-shaped refusal renders its own sentence, not the generic prefixed one"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift#testDownloadInspectorRendersAPauseFailurePayloadWithoutTheGenericPrefix"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRetryTests.swift (whole suite green after the rename, zero expectation edits)"
        status: pass
    human_judgment: false
  - id: D4
    description: "The effect's catch arm carries the client's error kind through to the message — the tap path, not just the action"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift#testDownloadInspectorReportsARefusalRaisedOnTheTapPath"
        status: pass
    human_judgment: false
  - id: D5
    description: "The accepted side stays quiet: no toast AND no reload, pinned under full exhaustivity"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift#testDownloadInspectorSetsNoToastWhenAPauseRequestIsAccepted"
        status: pass
    human_judgment: false
  - id: D6
    description: "Nine-action disposition enumeration across both reducers, stated in code at the type level and reproduced below"
    verification:
      - kind: other
        ref: "rg -n 'retryFailureToast' AppPackage -> 0; rg -c 'actionFailureToast' DownloadInspectorReducer.swift -> 3; rg -nF 'state.toast' DownloadInspectorReducer.swift -> 3 writer sites (validation, retry failure, pause failure)"
        status: pass
    human_judgment: false
  - id: D7
    description: "A refused Pause/Resume tap in the inspector shows a toast whose message matches the refusal, on device"
    verification: []
    human_judgment: true
    rationale: "The toast's rendered presentation (Liquid Glass bottom toast, auto-hide) is a visual outcome the TestStore cases cannot observe; they pin the state that drives it"

# Metrics
duration: 22 min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 73: Reporting the Refused Pause Tap Summary

**`toggleDownloadPauseDone(.failure)` now writes the same toast its retry sibling does 25 lines above, the mapping both share is renamed `actionFailureToast` and re-derived for two families, and every outcome-carrying action in BOTH download reducers carries a stated disposition at the type level — including one recorded honestly as still open.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-10T13:17:00Z (approx.)
- **Completed:** 2026-08-10T13:39:00Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- **The silent branch reports, in the retry branch's exact shape.** `toggleDownloadPauseDone(.failure)` sets `state.toast = error.actionFailureToast` and then re-sends `.loadInspection`, ordering identical to `retryPagesDone`'s, so the two siblings read as one family rather than as two independently-invented answers to the same question.
- **The mapping is named for what it answers.** `retryFailureToast` → `actionFailureToast`, with the doc re-derived: it now names both consuming families, states that the mapping is defined over `AppError` as a whole rather than over one caller's kinds, and records that `togglePause` reaches only the `alertText` arm today while the payload arm is the contract it inherits.
- **The sweep is a checkable enumeration, not a scatter of comments.** Both reducers gained a type-level doc listing every outcome-carrying action with its disposition, phrased to be checked against the `Action` enum when one is added. Per-case one-line anchors point back at it. Nine actions total, all dispositioned (table below).
- **One disposition is recorded as unresolved rather than justified.** The downloads LIST offers the same Pause/Resume from a swipe action and a context menu, and its `toggleDownloadPauseDone` is silent on both arms — the identical refusal, seen from another screen. Closing it needs a toast surface `DownloadsReducer` does not own, which is outside this plan's stated no-behavior-change scope. It is written into the type doc as "silent, and it is the weakest of these" and logged in `deferred-items.md`, so round 21 finds a stated open item instead of a laundered decision.

## Task Commits

1. **Task 1: RED — pin the silent pause failure from both sides** — `da6a8ef3` (test)
2. **Task 2: GREEN — surface the branch, rename the mapping, sweep both reducers** — `3998018c` (fix)

## The nine-action disposition table

Derived by reading both reducers' `Action` enums and every `case …Done` arm, not from the plan's or the review's list. "Reachability" is what the production caller can actually answer, derived from source.

### `DownloadInspectorReducer` — 4 outcome-carrying actions

| Action | Failure reachability | Disposition | Stated in code |
|---|---|---|---|
| `loadInspectionDone` | Anything `downloadClient.loadInspection` throws | **Reports** — `loadingState = .failed(error)`, rendered as the screen's error state | Type doc on `DownloadInspectorReducer` |
| `retryPagesDone` | `retryPages`' refusals: `.fileOperationFailed(invalid page selection)` and the two absence exits as `.notFound` | **Reports** — `toast = error.actionFailureToast`; success silent (observe stream renders the queued work) | Type doc + the WR-04 comment at the branch |
| `toggleDownloadPauseDone` | `togglePause` answers exactly `.notFound` (record gone) and `.unknown` (status left the toggleable set) | **Reports (this plan)** — `toast = error.actionFailureToast`; success silent | Type doc + the new WR-05 comment at the branch |
| `validateImageDataDone` | `validateImageData` returns `nil` or `.missingFiles(message)`; it does not throw | **Reports both outcomes** — validation is a question the user asked, so its answer is a toast either way | Type doc |

`observeDownloadsDone` carries records with no failure channel, so it is outside the policy rather than an exception to it — stated in the same doc.

### `DownloadsReducer` — 5 result-carrying actions

| Action | Failure reachability | Disposition | Stated in code |
|---|---|---|---|
| `moveDownloadDone` | Anything `moveDownload` throws (folder admission, file ops) | **Deliberately silent** — the row keeps its current folder, so the screen already says the move did not happen | Type doc + case comment |
| `openReadingDone` | Anything `loadManifest` throws | **Reports by behaviour** — falls back to the remote reader; bails without presenting only when the record itself vanished mid-flight, since nothing is left to seed a reader | Type doc + case comment |
| `toggleDownloadPauseDone` | `.notFound` / `.unknown`, identical to the inspector's | **Silent — and recorded as the weakest of the five.** Reporting it needs a toast surface this reducer does not own (see Open Items) | Type doc + case comment + `deferred-items.md` |
| `updateDownloadDone` | Anything `retry(gid, .update)` throws | **Deliberately silent** — the update badge stays put, which is the same statement | Type doc + case comment |
| `deleteDownloadDone` | Anything `delete` throws | **Deliberately silent** — the row the user tried to delete is still on screen | Type doc + case comment |

## Decisions Made

**DEC-A — the pause branch copies the retry branch's shape, not just its intent.** Toast first, then `.send(.loadInspection)`; no state cleared (there is no pause analogue of `retryingPageIndices`). *Enforced by test* from both sides. The success arm keeps `return .none` and now says why, so "quiet on success" is a written choice rather than an omission.

**DEC-B — one enumeration per reducer, at the type level.** The gap asked that "a future action cannot be added silently". Five scattered comments cannot be checked against anything; a list attached to the type can be read beside `Action` and compared. Each case still carries a one-line anchor naming its verdict, so a reader at the branch is not sent hunting. *Derived by argument* — nothing enforces the check mechanically, and that limit is stated here rather than implied.

**DEC-C — `togglePause`'s reachable kinds were derived, and the plan's staged kind was kept with a corrected label.** Reading `togglePause` (`DownloadClient+PublicAPI.swift:189-215`) and every tail call — `pause` → `commitPause`, `resume`, `cancelQueuedWorkItem` — the only failures are `.notFound` (three `fetchDownload` guards) and `.unknown` (the `.completed`/`.error`/`.updateAvailable` arm). Every other exit returns `.success`. So the plan's requested `.fileOperationFailed` case is NOT a `togglePause` exit; it is kept because the mapping is now shared and the rename could silently drop either arm, and its case doc says exactly that instead of implying reachability. *Derived from source, stated in the suite header.*

**DEC-D — the list-side silence is not dressed up.** Writing "deliberately silent, because the record speaks for itself" over `DownloadsReducer.toggleDownloadPauseDone` would have been the same move this round exists to stop: a refused list toggle moves nothing at all, so the record-says-so argument that genuinely covers move/update/delete (the row stays, the badge stays, the folder stays) does not cover it. The doc says so in those words. *Derived by argument, and deliberately left open.*

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's `.fileOperationFailed` staging was relabelled rather than presented as a `togglePause` exit**

- **Found during:** Task 1 (RED authoring)
- **Issue:** The plan's behavior block asked for a `.fileOperationFailed(message)` case and its acceptance criterion said "the staged failure kinds are derived from `togglePause`'s real refusal exits, named in the case docs". Both cannot hold: reading the source, `togglePause` cannot answer `.fileOperationFailed`. Writing a case doc claiming otherwise would have planted the kind of false doc sentence this phase has repeatedly had to remove.
- **Fix:** Both requirements are satisfied truthfully — the two reachable kinds (`.notFound`, `.unknown`) are staged as production-reachable with their exits named and cited, and the `.fileOperationFailed` case is kept and explicitly labelled a rename guard on the now-shared mapping, with a note that it also states the contract for the day `togglePause` grows a file-shaped refusal. The suite header carries the full exit enumeration.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift`
- **Verification:** The exit enumeration was re-derived from `+PublicAPI.swift` and `+Scheduling.swift` rather than taken from any summary; the `.unknown` case is RED pre-fix, which the plan's own staging would not have produced.
- **Committed in:** `da6a8ef3`

**2. [Rule 2 - Missing Critical] The success case runs under FULL exhaustivity, not the retry suite's `.off`**

- **Found during:** Task 1 (RED authoring)
- **Issue:** The plan asks the success case to pin "sets no toast and triggers no reload". Copying the retry suite's `store.exhaustivity = .off` idiom pins only the first half — with exhaustivity off, an added `.send(.loadInspection)` on the success arm is silently ignored, so the case could not fail on the second half.
- **Fix:** That one case keeps default exhaustivity, under which an unreceived `.loadInspection` fails it. The failure cases keep `.off` for the reason the retry suite does (the reload mints a fresh `inspectionRequestID`).
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift`
- **Verification:** Case passes pre- and post-fix; the doc states which half each exhaustivity setting buys.
- **Committed in:** `da6a8ef3`

**3. [Rule 1 - Bug] Three STATE.md decision lines from plan 15-68 were labelled `(15-73)`**

- **Found during:** Task 2 (state updates)
- **Issue:** `.planning/STATE.md:779-781` carried `DEC-A/B/C (15-73)` for the user-folder confinement decisions. `git log -S` attributes them to `21ff03a9 docs(15-68): record plan completion in state`. Left alone, this plan's own three decisions would have been indistinguishable from another plan's under the same tag.
- **Fix:** Relabelled to `(15-68)`; this plan's decisions carry `(15-73)`.
- **Files modified:** `.planning/STATE.md`
- **Verification:** `git log -S` attribution; no decision text altered.
- **Committed in:** the docs commit below

---

**Total deviations:** 3 auto-fixed (2 bugs, 1 missing-critical). None changed the plan's scope.
**Impact on plan:** Deviations 1 and 2 make the plan's own acceptance criteria reachable and honest. Deviation 3 is a documentation correction found while writing state.

## Banked Falsifiability

RED (`da6a8ef3`), from the run: **5 tests, 4 issues.** All four failure cases failed on the missing toast — the diff showed `_toast: nil` against the expected `AppAlertState`, with no other state difference, because the pre-fix branch writes nothing at all and its only observable is the reload. `testDownloadInspectorSetsNoToastWhenAPauseRequestIsAccepted` **passed pre-fix**, which is the boundary evidence: the fix moves the refused side and leaves the accepted side exactly where it was.

## Verification

Serialized, one `xcodebuild` invocation at a time:

1. RED gate — `DownloadInspectorPauseFailureTests` alone: **5 tests, 4 failures** (the intended RED), success case green.
2. GREEN gate — `DownloadInspectorPauseFailureTests` + `DownloadInspectorRetryTests`: **12 tests in 2 suites passed**, with ZERO expectation edits in the retry suite the rename touched.
3. Full `FeatureTests`: **962 tests (952 passed + 10 expected failures), 0 failures**, on `iPhone Air` (`ADE09605-…`) — the 957 baseline plus this plan's 5 cases.
4. Clean app build (`generic/platform=iOS Simulator`, fresh derived data at `/tmp/EhPandaPhase1573DerivedData`): **BUILD SUCCEEDED, 0 errors, 0 warnings**.
5. SwiftLint `--strict` run DIRECTLY over the new test file and the whole `DownloadsFeature` module (the app scheme's gate does not cover `Tests/`): **0 violations in 4 files**.

Acceptance-criterion greps:

- `rg -n 'retryFailureToast' AppPackage` → **0 matches**, comments included.
- `rg -c 'actionFailureToast' …/DownloadInspectorReducer.swift` → **3** (declaration + two branch call sites).
- `rg -nF 'state.toast' …/DownloadInspectorReducer.swift` → **3 writer sites**: validation (269), retry failure (214), pause failure (250).
- No `DownloadsReducer` effect changed: the diff over that file is comments plus the type doc only.
- File sizes after the change: `DownloadInspectorReducer.swift` 369, `DownloadsReducer.swift` 514 — both far from the 1000-line limit; `DownloadClient+ExecutionSupport.swift` (999) was not touched.

## Issues Encountered

None beyond the three recorded deviations.

## Open Items / Non-blocking

- **`DownloadsReducer.toggleDownloadPauseDone` is still silent, and it is recorded as an open item, not as a decision.** The list offers Pause/Resume from a swipe action (`DownloadsView.swift:121-135`) and a context menu (`194-207`), both gated by the rendered snapshot's `canTogglePause`, so the boundary refuses exactly as it does in the inspector. Closing it is not a branch fix: `DownloadsReducer.State` owns no toast value — `alert` is `AppAlertState<Alert>` presented through `.appAlert`, which renders the `.alert` style, while the toast factories are constrained to `Action == Never` and render through a different modifier. It needs a new `@Presents` toast, an action case, an `.ifLet`, and a `DownloadsView` modifier — files this plan does not touch, and behavior the plan explicitly excludes. Logged in `deferred-items.md`.
- **`fetchDownloads` / `fetchFolders` `try` inside `.run` with no `catch:`** (`DownloadsReducer.swift:251-255`, `288-292`). Neither is result-carrying, so both are outside gap 4's contract — which is exactly why a throw there has nowhere to go: on the `fetchDownloads` path `loadingState` was just set to `.loading`, so a throwing fetch leaves the list spinning with no error state. Logged in `deferred-items.md`, not fixed.
- **Device item, carried forward from 15-VERIFICATION.md:** UAT test 2 (system card fraction + cancel parity) still needs a physical-device iOS 26 run; unrelated to this plan and not attempted here.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Gap 4 / review WR-05 is closed at its root and swept beyond the named branch: the inspector's last silent failure reports, the mapping is shared under an honest name, and both reducers carry a checkable per-action disposition list. The one item the sweep found and did not close is stated as open in three places (type doc, case comment, `deferred-items.md`) rather than closed by assertion. Gaps 1, 2, 3 and 5 belong to plans 15-70/71/72/74-77.

## Self-Check: PASSED

- Created file verified on disk: `AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift`.
- Modified files verified on disk: `DownloadInspectorReducer.swift`, `DownloadsReducer.swift`, `deferred-items.md`.
- Commits verified in `git log`: `da6a8ef3` (RED), `3998018c` (GREEN).
- Plan-level verification re-run and recorded above: gated suites green, full FeatureTests 962/0, clean build 0 warnings, SwiftLint 0 violations over all touched files.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
