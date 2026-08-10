---
phase: 15-continued-background-downloads
plan: 69
subsystem: downloads
tags: [download-client, retry, page-selection, localization, toast, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-64's CR-04 narrowing — the fail-closed retry boundary and the three-state page-selection contract this plan completes at the callers"
provides:
  - "A distinct inadmissible-selection error at the public retry boundary, separated from the two absence exits that keep .notFound"
  - "A throwing collapse boundary: a fetch-time-emptied selection fails with a named reason before any run work"
  - "A surfaced retry-failure toast, so a refused tap is never a silent no-op"
  - "Two module-local localized keys carrying the two conditions apart in all six catalog locales"
affects: [retry UI failure path, run failure settlement, page-selection normalization, update-record refusal]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Give a refusal its own error only where the CONDITION differs; two exits that both mean absence should keep sharing one"
    - "Fail loudly at the boundary that can still name the reason, rather than quietly at the step that can only report a generic one"
    - "Render a carried message by its payload; fall back to the error's own wording, never to a blank caption"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
    - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRetryTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift

key-decisions:
  - "DEC-A: only the inadmissible-selection exit gets a new error; the absent-gallery and absent-folder exits keep .notFound, because absence is what both of them mean"
  - "DEC-B: the collapse THROWS rather than returning an empty-but-present payload — the no-widening property is unchanged, the failure merely stops being generic"
  - "DEC-C: the toast renders .fileOperationFailed by its payload alone and every other kind by alertText, with localizedDescription as the never-empty fallback"
  - "DEC-D: the RED cases assert the refusal's SHAPE, not the resolved catalog string, because module-local generated symbols are internal to DownloadClient and referencing one pre-fix would make RED a compile failure"
  - "DEC-E: the update-record refusal case moved to the new error with the repair cases — the guard sits ahead of mode resolution, so both record kinds are refused by the same exit"

patterns-established:
  - "Sweep the assertions that pin a refusal's VALUE, not only the code that produces it: the un-swept sibling here was a test in a file the plan never named"
  - "A test double that forwards to a boundary must inherit the boundary's throwing contract, or it hands cases a value production cannot produce"

requirements-completed: []

coverage:
  - id: D1
    description: "A refused retry sets the toast to the client's own message, clears retryingPageIndices and still reloads the inspection"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRetryTests.swift#testDownloadInspectorSurfacesTheClientsMessageWhenARetryIsRefused"
        status: pass
    human_judgment: false
  - id: D2
    description: "A failure carrying no message of its own still renders a non-empty caption"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRetryTests.swift#testDownloadInspectorSurfacesAMessageForARetryFailureThatCarriesNoneOfItsOwn"
        status: pass
    human_judgment: false
  - id: D3
    description: "An accepted retry sets no toast"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRetryTests.swift#testDownloadInspectorSetsNoToastWhenARetryRequestIsAccepted"
        status: pass
    human_judgment: false
  - id: D4
    description: "An all-invalid and an explicitly empty selection are refused with a distinct non-empty message, with every 15-64 no-mutation snapshot assertion intact"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryPagesRefusesAnAllInvalidSelectionWithoutMovingAnything"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryPagesRefusesAnExplicitlyEmptySelectionWithoutMovingAnything"
        status: pass
    human_judgment: false
  - id: D5
    description: "The boundary refusal and the fetch-time collapse do not share a sentence"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryPagesRefusesAnAllInvalidSelectionWithoutMovingAnything (cross-message arm)"
        status: pass
    human_judgment: false
  - id: D6
    description: "An absent gallery and an absent folder still answer .notFound, moving nothing"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryPagesStillAnswersNotFoundWhenTheGalleryOrItsFolderIsAbsent"
        status: pass
    human_judgment: false
  - id: D7
    description: "Normalization: nil stays unrestricted, a surviving subset stays a present set, and a collapse throws one named error by either route"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testNormalizationKeepsNilUnrestrictedPreservesASubsetAndRefusesACollapse"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testTheModulesOtherPageCountRangeSitesAnswerEmptyForAZeroPagePayload"
        status: pass
    human_judgment: false
  - id: D8
    description: "The composed widening stays closed and the seam still carries a real restriction through both steps"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testAnAllInvalidSelectionNeverNormalizesIntoWholeGalleryWork"
        status: pass
    human_judgment: false
  - id: D9
    description: "An inadmissible UPDATE request is refused before delegation with the same distinct error"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift#testAnInadmissibleUpdateRequestIsRefusedBeforeDelegation (2 arguments)"
        status: pass
    human_judgment: false
  - id: D10
    description: "Every pre-existing retry, ledger, zero-page, inspector and session behaviour is unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (950 tests / 164 suites / 22 targets, 0 failures)"
        status: pass
    human_judgment: false

# Metrics
duration: 35min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 69: Visible, Truthful Retry Refusals Summary

**WR-04 and WR-05 closed: an inadmissible page selection now carries its own localized error instead of the absence error, the inspector's failure branch renders that message as a toast instead of silently reverting, and a selection the freshly fetched page count empties fails at the normalization boundary with a named reason instead of reaching finalize and manufacturing a whole-manifest incomplete-download record.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-10T18:36Z
- **Completed:** 2026-08-10T19:11Z
- **Tasks:** 2 (RED, GREEN)
- **Files created:** 0
- **Files modified:** 13 (6 sources, 7 test files)

## Accomplishments

- **The two consequences are the same mistake read at two layers: a refusal that cannot say what it refused.** At the boundary, three exits shared one value — the gallery is absent, its folder is absent, and the pages you named are not this gallery's — so no localized string could match the condition, and `.notFound`'s reads as "this download is gone" over a download that is sitting right there. At the caller, the branch that received that value set no toast at all, so the rows flashed to `.pending` from the optimistic rewrite and reverted with nothing said. Both are now fixed at their own layer: the inadmissible exit answers `.fileOperationFailed` with a sentence naming the condition, the two absence exits keep `.notFound` because absence is what they both mean, and `retryPagesDone(.failure)` renders whatever arrived.
- **The collapse fails where the reason still exists.** 15-64's preserve-empty return stopped the widening but handed the run a request it could not honour: `pendingPageIndices` answered nothing, the announcement gate declined, `downloadCoverImage` still ran, and `finalizeBatchResult` then measured the WHOLE manifest through `missingFinalizedPageIndices` — so a page the `.repair` seed had just blanked raised the generic incomplete-download error and settled the gallery into a persistent `.error` record for work nobody requested. `normalizeFetchedPayload` now throws there. The no-widening property is untouched and re-pinned from both sides: no path maps a non-nil raw selection to a nil payload selection, because the one input that used to empty it produces no payload at all.
- **The throw lands before anything destructive, and that was confirmed against the ordering rather than assumed.** `fetchNormalizeAndDownload` normalizes at `Execution.swift:149` and only then calls `performDownload` at line 158, whose body is `ensureRootDirectory` → `prepareWorkingSeedAnnouncingProgress` (the seed materialization that blanks) → `downloadCoverImage` → `resolveSourceIfNeeded` → `downloadPages` → `finalizeBatchResult`. Every one of those is downstream of the throw. It propagates through `processDownload`'s existing catch to `handleProcessDownloadAppError` → `persistFailure` → `settleDownloadFailure`, which records the truthful message, clears the queue intent and removes the gid — so the gallery settles at `displayStatus == .error` with code `.fileOperationFailed`, which is exactly the shape D-G5C-01 widens the inspector's retry basis for. The user gets a forward affordance rather than a dead end, and no re-arming loop: `shouldSchedule`'s selection gate reads a value the settle just nil'd.
- **The sweep found a consumer the plan did not name, and it was an assertion rather than a code path.** `DownloadRetryUpdateFallbackTests.swift:140` pinned `error == .notFound` for an inadmissible UPDATE request. Because the admission test sits ahead of mode resolution, an update record and a repair record are refused by the *same* exit, so the distinct error reaches that case too. Leaving it pinned would have re-conflated the two conditions for exactly one of the two record kinds while the plan's own gate stayed green — the full-suite run is what surfaced it.
- **The catalog keys carry the two conditions apart in six locales, with no numeric argument.** Both are plain strings, so no `%#@variable@` substitution is owed and no bare numeric specifier enters the module-local catalog; both are real translations in `de`, `en`, `ja`, `ko`, `zh-Hans` and `zh-Hant` rather than English copied into five slots.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — pin the silent no-op, the conflated error, and the false failure record** - `34984354` (test)
2. **Task 2: GREEN — distinct errors, surfaced toast, throwing collapse, swept consumers** - `1d966aee` (fix)

## The Three-State Consumer Sweep, Enumerated From Source

Derived by enumerating the symbols in `AppPackage/Sources` **before** reading the plan's or the review's list — `rg -n "queuedPageSelections"`, `rg -n "\.pageSelection"`, `rg -n "pendingPageIndices|pendingIndices"` — then giving every hit a disposition, including the ones left alone.

### The record-side intent (`[Int]?`)

| Site | Kind | Disposition |
|---|---|---|
| `+Manager.swift:456` | declaration | Unchanged. |
| `+RetryHelpers.swift:134` (`performRetryPages`) | the ONLY non-nil writer | Unchanged. It cannot store an empty array: the admission test refuses one first, now with the distinct error. |
| `+RetryHelpers.swift:39`, `+Scheduling.swift:363`, `+Manager.swift:871` | nil writers | Unchanged — "no restriction" and "intent cleared". |
| `+Execution.swift:142` (`rawPageSelection`) | bridge into the run | Unchanged optional-presence semantics; it is the value the new throw judges. |
| `+Scheduling.swift:134` (`shouldSchedule`) | **GATE** keyed on the three-state | Unchanged and still correct. It reads the RECORD-side intent, which the fetch-time collapse never writes; and `settleDownloadFailure` nils it on the way out, so a collapsed run cannot re-arm the gate it failed under. |

### The payload-side selection (`Set<Int>?`)

| Site | Kind | Disposition |
|---|---|---|
| `+ExecutionFetch.swift:82` (`buildPayload`) | producer | Unchanged — presence is preserved through the fetch, so the normalizer sees the caller's request as made. |
| `+ExecutionFetch.swift:217` (rebuild equality guard) | internal | Unchanged; now reachable only for `nil` or a non-empty set. |
| `+ExecutionSupport.swift:861` (`pendingPageIndices`) | the ONLY reader | **Branch retained as defence in depth, doc re-derived.** An explicitly empty selection can no longer arrive; the reading is kept because it is what makes presence meaningful for any future producer, and a "non-empty selection restricts" rewrite would re-open CR-04. |

### Consumers derived from that reading

| Site | Kind | Disposition |
|---|---|---|
| `+ExecutionSupport.swift:610` (announcement gate) | **GATE** on `!pendingPages.isEmpty` | Unchanged. It is no longer reachable over an explicitly empty selection, and its own doc's claim — that normalization preserves a non-empty in-range selection for every mode but `.update` — remains true as written. |
| `+ExecutionPerform.swift:59` (`downloadCoverImage`) | run step | Unchanged. WR-05's complaint was that it ran for a request that could not be honoured; the throw precedes `performDownload` entirely, so it no longer can. |
| `+ExecutionPerform.swift:147` (`resolveSourceIfNeeded`) | selection-scoped filter | Unchanged — it already filters the RUN's pending list, not the manifest, so it was never the whole-manifest reader. |
| `+ExecutionPerform.swift:110,123` (`finalizeBatchResult` / `missingFinalizedPageIndices`) | whole-manifest accounting | **Unchanged, deliberately.** Measuring the whole manifest is correct for a run that was asked for the whole manifest; the defect was reaching it with an explicitly empty selection, which the throw makes unreachable. Narrowing it to the selection instead would have weakened the completeness check for every ordinary run to fix a case that should never arrive. |

## Banked Falsifiability

The RED suite failed against pre-fix production with **10 verbatim issues** across 5 of the 7 new or rewritten cases (26 tests in 3 suites, `** TEST FAILED **`).

| Case | Pre-fix (recorded verbatim) | Post-fix |
|---|---|---|
| inspector, `.fileOperationFailed` failure | `A state change does not match expectation. … − _toast: AppAlertState(… _message: "The pages you selected are no longer part of this gallery." …) + _toast: nil` | toast set, indices cleared, reload still sent |
| inspector, `.notFound` failure | the same diff shape at `DownloadInspectorRetryTests.swift:246` | caption falls back to the error's own wording |
| retryPages, all-invalid `[0, 999]` | `An inadmissible selection must not answer with an absence error, got .notFound.` | `.fileOperationFailed`, message non-empty and different from the collapse's |
| retryPages, explicit empty `[]` | `An explicitly empty selection must not answer with an absence error, got .notFound.` | same distinct error |
| normalization, explicit empty | `an error was expected but none was thrown and "DownloadRequestPayload(…)"` plus `An explicitly empty selection must throw a named error, got nil.` | named throw |
| normalization, all-invalid | `an error was expected but none was thrown …` / `(collapse → nil) != nil` (twice, at both call sites) | named throw, equal to the explicit-empty one |
| zero-page normalization | `an error was expected but none was thrown …` / `(collapse → nil) != nil` | named throw, no trap |

Two cases **passed pre-fix, deliberately**, and they are boundary pins rather than discriminators: `testDownloadInspectorSetsNoToastWhenARetryRequestIsAccepted` (the fix must not buy visibility by reporting every outcome) and `testRetryPagesStillAnswersNotFoundWhenTheGalleryOrItsFolderIsAbsent` (the two exits the new error must NOT take over).

The cross-message arm is the one that states what "distinct" has to mean: a fix that gave both new conditions one shared key would satisfy every error-kind assertion above and still leave the user unable to tell them apart.

## Decisions Made

- **DEC-A: only the inadmissible-selection exit gets a new error.** The reflex is to give each `return` its own value; that would be wrong here. The absent-gallery and absent-folder exits both mean "the thing you named is not there", and `.notFound`'s localized string says exactly that for both. Splitting them would add a distinction the user cannot act on differently, while the distinction that mattered — absence versus a request outside the gallery — is the one that was missing.
- **DEC-B: the collapse throws instead of returning an empty-but-present payload.** This revises 15-64's RETURN contract and keeps the property that contract protected. Both directions fail closed; the difference is whether the failure can still name its reason. At the normalization boundary the reason is known ("the fetched count no longer supports the pages you named"); by the time `finalizeBatchResult` runs, all that is left is "some pages are missing", asserted over pages nobody asked for. Failing where the reason exists is the only version of fail-closed that is also truthful.
- **DEC-C: the toast renders `.fileOperationFailed` by its payload alone.** `alertText` would prefix its own generic "local file operation failed" line ahead of the specific sentence, burying the part that answers the user's question — the kind is the carrier here, not the message. Every other kind keeps `alertText`, which is the app's own wording for it, with `localizedDescription` as the fallback for the two kinds whose `alertText` is empty (`.noUpdates`, `.webImageFailed`). Neither is reachable from this route, but a toast with a blank message reports nothing, which is the defect this mapping exists to close.
- **DEC-D: the RED cases assert the refusal's shape, not the resolved catalog string.** The plan asked for equality against the resolved localized strings. Module-local string-catalog symbols are internal to `DownloadClient` (this project hand-writes public wrappers in `ResourceStringSymbols.swift` for shared keys precisely because of that), and referencing a key that does not exist yet would have made the RED run a COMPILE failure rather than an assertion failure — an invalid RED, since the gate's `!` cannot tell the two apart. The cases instead pin the error kind, a non-empty message, and that the two new messages differ from each other and from the absence exits, which is the whole of the contract the string equality was standing in for.
- **DEC-E: the update-record refusal case moves to the new error rather than being exempted.** The admission test sits ahead of mode resolution by design (that ordering IS the CR-04 fix), so both record kinds leave through the same `guard`. Keeping `.notFound` there would have required a second, mode-aware refusal — reintroducing the conflation for update records only, and making the boundary's answer depend on state it deliberately consults after refusing.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] An assertion in a file the plan never named pinned the superseded refusal value**

- **Found during:** Task 2 (GREEN), the plan's full-suite gate
- **Issue:** `DownloadRetryUpdateFallbackTests.swift:140` asserted `error == .notFound` for both arguments of `testAnInadmissibleUpdateRequestIsRefusedBeforeDelegation`. The run reported `(error → .fileOperationFailed("The selected pages are no longer part of this gallery.")) == .notFound` twice. The plan's own `-only-testing` gate could not see it, and the plan's file list did not name the file.
- **Fix:** The case asserts the distinct error and a non-empty message, matching its repair-side siblings, with a doc paragraph deriving why the update path inherits the change: the guard precedes mode resolution, so both record kinds are refused by the same exit.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift`
- **Verification:** Full `FeatureTests` green afterwards; the whole-state no-mutation assertion in the same case is untouched.
- **Committed in:** `1d966aee` (Task 2 commit)

**2. [Rule 3 - Blocking issue] The retried-pages test double could not express the boundary's new contract**

- **Found during:** Task 2 (GREEN)
- **Issue:** `makeRetriedPagesPayload` forwards to `normalizeFetchedPayload`, which became throwing. A non-throwing double would have had to swallow the throw, handing cases a payload production can no longer produce — the exact un-faithfulness the helper's own doc says it exists to prevent (G-15-28), and the same class of drift 15-64 recorded as its deviation 1.
- **Fix:** The helper is `async throws` and its doc records why; the six call sites in `DownloadContinuedSessionLedgerRefusalTests.swift` (5) and `DownloadContinuedSessionLedgerTests.swift` (1) gained `try`. All six pass in-range indices, so no expectation changed.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift`, `DownloadContinuedSessionLedgerRefusalTests.swift`, `DownloadContinuedSessionLedgerTests.swift`
- **Verification:** Both ledger suites green in the full run.
- **Committed in:** `1d966aee` (Task 2 commit)

### Documented deviations from the plan's text

- **The plan's acceptance criterion pinning the resolved catalog strings is not met as written**, for the reason recorded in DEC-D; the property it was standing in for is asserted by shape and by cross-message inequality instead. The two greps the plan asks for do pass (see Verification Evidence).
- **`DownloadInspectorRetryTests.swift` was not a new file.** The plan's framing described it as newly declared; it already existed at 207 lines with a `makeRetryTestStore` factory, so the three new cases extend it as the plan's own `read_first` block actually instructs. The `-only-testing` selector names a real suite declared in that file, so 15-67's non-selecting-filter hazard did not apply — confirmed by the reported count moving from 22 to 26.
- **IN-02 was left alone.** The review's localized-key spelling inconsistency lives in `DownloadStore+Operations.swift:436-438`, a block this plan had no reason to touch. The opportunistic rule applies only to a block the work already edits.

### Undeclared files modified

`DownloadRetryUpdateFallbackTests.swift` (deviation 1) and the three helper/ledger files (deviation 2).

---

**Total deviations:** 2 auto-fixed (1 un-swept assertion, 1 forced double-faithfulness update), plus 3 documented departures from the plan's text
**Impact on plan:** No behaviour outside the plan's contract changed. Deviation 1 is inside the plan's own subject matter — it is the same refusal, asserted from the update side.

## Issues Encountered

- **A gate scoped to three suites cannot see the assertion that pins the value you are changing.** The plan's gate was green on the same code the full suite failed. The lesson from earlier in this round holds precisely: when a change alters what a refusal MEANS, sweep for the places that pin its value, not only for the code that produces it — and a test assertion is such a place.
- **The RED had to be assertion-shaped, not symbol-shaped.** Writing the pinned strings into the RED cases would have made the pre-fix run fail to compile, which the `!`-prefixed gate reports identically to a genuine RED. The distinction matters: a compile failure proves the test references something that does not exist, not that production behaves wrongly.
- **`try` on a not-yet-throwing call is a warning, and that is what makes a throwing-contract RED possible at all.** The three normalization cases were written with `try` from the start so the GREEN step changes production only; pre-fix they compile with a warning and fail on the missing throw, which is the observation wanted.

## Verification Evidence

Run one `xcodebuild` invocation at a time, with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`.

1. Task 1 RED gate — the plan's three `-only-testing` suites — **TEST FAILED**, 26 tests in 3 suites, **10 issues**, exactly the observations banked above.
2. Task 2 gate — the same invocation after the fix — **TEST SUCCEEDED**, 26 tests in 3 suites, zero `warning:` lines.
3. Full `FeatureTests` — **TEST SUCCEEDED**, **950 tests / 164 suites / 22 targets, 0 failures** (10 known/expected issues, unchanged from baseline). Downloads target **431 in 72 suites** (+4 over 15-68's 427, no new suite). The first full run FAILED with the two `DownloadRetryUpdateFallbackTests` issues of deviation 1; the two runs after the fix are both green.
4. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1569DerivedData build` — **BUILD SUCCEEDED**, **0 warnings, 0 errors** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
5. Standalone SwiftLint `--strict` over `Sources/DownloadClient`, `Sources/DownloadsFeature` and `Tests/DownloadsFeatureTests` (the app scheme does not lint `Tests/`) — **0 violations, 0 serious in 120 files**.

Acceptance greps and metrics:

- `python3` catalog check over both new keys → `True`; the strings dictionary is still key-sorted, every locale is `state: "translated"`, and neither value contains a `%` specifier of any kind.
- `rg -n 'downloadStoreInvalidPageSelection' …/DownloadClient+RetryHelpers.swift` → the refusal; `rg -n 'downloadStorePageSelectionOutdated' …/DownloadClient+ExecutionFetch.swift` → the throw.
- `rg -n 'state.toast' …/DownloadInspectorReducer.swift` → two sites, the validation one and the new retry-failure one.
- The toast surface is already presented for this store: `DownloadsView+Subviews.swift:107` carries `.toast($store.scope(\.$toast, action: \.toast))` on the inspector's own content, so this wires an existing affordance rather than adding a presentation.
- No `swiftlint:disable`, `@unchecked Sendable`, `@preconcurrency`, `try?`, force try or force unwrap was added (`git diff` over both commits, added lines only).
- `git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty on both task commits.
- File lengths after the change: `+RetryHelpers.swift` 155, `+ExecutionFetch.swift` 233, `+Execution.swift` 387, `+ExecutionSupport.swift` 883, `DownloadInspectorReducer.swift` 330, `DownloadFeatureTestHelpers.swift` 992, `DownloadRetryPagesTests.swift` 603, `DownloadZeroPagePayloadTests.swift` 433, `DownloadInspectorRetryTests.swift` 315 — all under the 1000-line error. `DownloadContinuedSessionTests.swift` (993) was not touched.
- No line over 120 characters in any touched file.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings` — FOUND
- `AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRetryTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift` — FOUND
- Commit `34984354` — FOUND
- Commit `1d966aee` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced. Both new catalog keys have a live production consumer, the toast mapping has a live reducer call site, and the throwing boundary has a live production caller.

## Threat Flags

None. The plan's registered threats are addressed rather than extended: T-15-69-01 by the named throw at the normalization boundary, with the ordering against `performDownload` confirmed line by line and recorded above; T-15-69-02 by the failure-branch toast plus the distinct localized message, asserted at the `TestStore` layer from both sides; T-15-69-03 (accepted) by keeping both messages static localized strings that name a condition — neither embeds a gallery identity, a title, a path or a page number, so no new disclosure surface exists and the module's hash-masked logging was not touched. No new network endpoint, auth path, file-access pattern or schema was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Verification gap 4 is closed.** WR-04's two halves (the swallowed refusal and the conflated error) and WR-05 (the false failure record) are all fixed at their own layer, with regressions at the reducer, client-boundary and normalization layers.
- One narrowing worth knowing, the sibling of the one 15-64 recorded: a run whose page selection the freshly fetched count refutes entirely now FAILS with a truthful message instead of silently downloading nothing and then reporting an unrelated incomplete-download error. The gallery settles at `.error` with `.fileOperationFailed`, which the inspector's widened retry basis treats as fully retryable, so the user's route forward is the Retry button on a refreshed page list.
- `DownloadFeatureTestHelpers.swift` is now at 992 of the 1000-line limit (was 989). 15-62's DEC-E split-before-growing rule applies harder than before: the next addition there needs a same-suite extension in a sibling file. `DownloadContinuedSessionTests.swift` (993) is unchanged.
- Remaining `15-REVIEW.md` items are untouched and independent: **CR-01** (the unbracketed `advanceQueueIntentGeneration`, verification gap 1) and **gap 2's read-path half** (the `discardingRejected` default flip and `scanCompletedFolder`'s non-reconciling sweep). **IN-02** (two localized-key spellings in `DownloadStore+Operations.swift`) is unrouted and untouched, deliberately.
- 15-67's DEC-C residual is unchanged: `materializeRepairSeed` still discards while scanning the SOURCE folder.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
