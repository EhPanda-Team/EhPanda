---
phase: 14-analytics-instrumentation
plan: 05
subsystem: infra
tags: [telemetrydeck, analytics, privacy, swift-testing, closed-enum, rendering]

# Dependency graph
requires:
  - phase: 14-analytics-instrumentation
    provides: "plan 14-03's closed vocabulary and audited reductions — HomeSection, AppTab, SearchSurface, DownloadOutcome, LoginFailureKind, Category.analyticsName, TagNamespaceCounts, SearchShape, AppErrorKind, AnalyticsErrorCategory"
  - phase: 14-analytics-instrumentation
    provides: "plan 14-02's owner decisions D-15 (eleven-case Category), D-16 (exact per-namespace tag counts), D-19 (the D-09 wall at the module boundary)"
provides:
  - "AnalyticsSignal — the closed thirteen-case enum that is the entire analytics vocabulary a reducer can reach, with no case able to carry a String, URL, Data or content type"
  - "AnalyticsSignal.Rendered plus the internal rendered property — the single String-minting site, an exhaustive switch with no catch-all arm"
  - "An exhaustive rendering suite: per-case wire-form pinning, the 25-entry reserved-key collision sweep, and the D-06 no-content sentinel sweep"
affects: [14-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Closed signal vocabulary: the transmission API accepts one enum whose every associated value is a closed enum, a Bool, a bucket, or a documented exact Int, so a free-form payload is unexpressible by construction (D-09)"
    - "Single String-minting site: every analytics name and key is a static constant in one file behind an exhaustive no-default switch, so a new case cannot ship unrendered and no second site can assemble a name"
    - "Whole-dictionary rendering assertions plus a case-insensitive reserved-key sweep and a sentinel content sweep, both guarded against a vacuous pass"

key-files:
  created:
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift
  modified: []

key-decisions:
  - "Both D-08 exact-Int exceptions render as decimal integers: search keyword length (D-07) and per-namespace tag counts (D-16). The plan's Task 2 wording naming keyword length as 'the one permitted exact Int' is stale under D-16 and is superseded here."
  - "galleryDetailOpened carries Category directly — already closed and String-raw (D-15) — with no mirror enum; the emission site in a later plan maps the domain enums onto the vocabulary."
  - "errorSurfaced renders to .error(id:category:parameters:) with empty parameters, routing to the SDK's error preset with the id drawn from AppErrorKind, so the free-form message: parameter is never reached."
  - "Per-namespace tag-count keys are built as Gallery.tagNamespace.<namespace> from the closed TagNamespaceKey spelling, so a scraped raw namespace can never become a key."

patterns-established:
  - "The wire form is a two-case Rendered enum (signal vs error preset), so the rendering layer speaks plain Swift and imports no SDK; the single SDK call site translates it in plan 14-06."
  - "Reserved-key defence is dot-namespacing plus a case-insensitive test sweep, because the SDK only logs a collision and still sends."

requirements-completed: []

coverage:
  - id: D1
    description: "AnalyticsSignal is a closed thirteen-case enum covering every D-05 flow-family item not already emitted by the SDK, with no case carrying a String, URL, Data or AppModels content type (D-09)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift#theVocabularyIsThirteenSignalsWide"
        status: pass
      - kind: other
        ref: "grep -cE '^    case ' AnalyticsSignal.swift == 13; grep -cE 'case .*\\(.*String' == 0; grep -cE 'case .*\\((URL|Gallery|GalleryDetail|GalleryTag|DownloadedGallery|Data)' == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every signal renders to its exact stable name and full parameter dictionary through one exhaustive no-default switch, the single site where an analytics name or key is minted"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift#everySignalRendersToItsPinnedWireForm, #anUnrecognizedTagNamespaceRendersToTheAnonymousSpelling"
        status: pass
      - kind: other
        ref: "grep -c 'default:' AnalyticsSignal+Rendering.swift == 0; every ParameterKey constant contains a dot; the file has no SDK import"
        status: pass
    human_judgment: false
  - id: D3
    description: "No rendered parameter key collides case-insensitively with the SDK's 25-key reserved set, and no rendered signal name begins with the reserved TelemetryDeck. prefix (D-06 tampering, threat T-14-04)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift#noRenderedKeyCollidesWithAReservedKeyAndNoNameCarriesTheReservedPrefix"
        status: pass
    human_judgment: false
  - id: D4
    description: "An exhaustive sentinel sweep over every case proves no rendered name, key or value carries gallery, keyword, tag or error-payload text (D-06, threat T-14-01)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift#noSentinelSurvivesIntoAnyRenderedNameKeyOrValue"
        status: pass
    human_judgment: false
  - id: D5
    description: "SwiftLint reports zero violations across the module and its test target with no suppression directive added"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "swiftlint lint --strict over AppPackage/Sources/AnalyticsClient and AppPackage/Tests/AnalyticsClientTests — exit 0, no violations; no swiftlint:disable added"
        status: pass
    human_judgment: false

# Metrics
duration: ~11min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 05: The AnalyticsSignal vocabulary and its rendering Summary

**The load-bearing half of D-09 in concrete form: a closed thirteen-case signal enum no reducer can escape, rendered to stable names and dot-namespaced parameters from one auditable file, with the D-06 no-content guarantee and the reserved-key non-collision both proven by exhaustive test.**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-07-24T04:19:10Z
- **Completed:** 2026-07-24T04:30:00Z
- **Tasks:** 3 (each RED → GREEN; Task 3 is a test-only addition over already-shipped rendering)
- **Files created:** 3

## Accomplishments

- `AnalyticsSignal` exists as a public, `Equatable`, `Sendable` enum with exactly thirteen cases grouped by D-05 flow family. Not one case can carry a `String`, `URL`, `Data` or an AppModels content type — every associated value is a closed enum, a `Bool`, a bucket, or `Category` / `TagNamespace?` (both permitted by D-07). The three deliberate omissions (launch/foreground, reading direction and dual-page mode, field settings) are documented in the file header so a later reader does not re-add them.
- `AnalyticsSignal.Rendered` and the internal `rendered` property are the single place in the repository where an analytics name or parameter key is minted. The switch is exhaustive with no catch-all arm, so a case added without a rendering is a compile error rather than a signal shipped unrendered. Every literal lives once, in a `private enum SignalName` and a `private enum ParameterKey`, so the "one minting site" claim is checkable by reading one file. The file imports no SDK.
- Every signal's wire form is pinned case by case against a literal name and a full parameter dictionary — the whole dictionary, not a spot check, so an unexpected extra parameter fails rather than passing.
- The reserved-key sweep copies the SDK's 25-entry reserved set verbatim and asserts case-insensitive non-collision plus the reserved name-prefix check; the sentinel sweep drives distinctive content tokens through every fixture and asserts none reaches any rendered name, key or value. Both guard against a vacuous pass over an empty fixture list.
- The whole `AnalyticsClientTests` target passes: 44 tests across 6 suites (39 prior + 5 new). SwiftLint `--strict` reports zero violations across the module and its test target with no suppression directive added.

## Task Commits

Each task committed atomically:

1. **Task 1: The AnalyticsSignal closed enum** — `532fa9c5` (test, RED) → `180bf229` (feat, GREEN)
2. **Task 2: The rendering layer — the single String-minting site** — `45a8af03` (test, RED) → `b4bf3743` (feat, GREEN)
3. **Task 3: Reserved-key and no-content sweeps** — `59ea8891` (test)

## Files Created/Modified

- `AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift` — the thirteen-case closed vocabulary, grouped by D-05 family with a `// MARK:` banner per family
- `AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift` — the `Rendered` enum, the exhaustive `rendered` switch, and the `SignalName` / `ParameterKey` constant enums
- `AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift` — the thirteen-fixture wire-form table, the reserved-key collision sweep, and the sentinel content sweep

## Decisions Made

- **Both of D-08's documented exact-`Int` exceptions render as decimal integers.** `Search.keywordLength` (D-07's original exception) and the per-namespace tag counts under `Gallery.tagNamespace.<namespace>` (D-16's amendment) both ship exact. Every other counter — `Search.wordCount`, `Search.resultCount`, `Reading.pagesRead` — goes through the shared bucket vocabulary, and `Reading.duration` through `DurationBucket`.
- **`galleryDetailOpened` carries `Category` directly.** Per D-15 the enum is already closed and `String`-raw across all eleven cases, so no mirror is needed; the vocabulary's `Category.analyticsName` supplies the dashboard spelling.
- **`errorSurfaced` routes to the SDK's error preset.** It renders to `.error(id: kind.rawValue, category: kind.category, parameters: [:])`, so the identifier is the closed `AppErrorKind` spelling and the preset's free-form `message:` parameter — opted out in `COVERAGE.md` — is never reached.
- **Per-namespace tag-count keys are built from the closed `TagNamespaceKey` spelling.** `Gallery.tagNamespace.<namespace>` interpolates a closed case-set spelling (or the literal `unrecognized`), so a scraped raw namespace can never become a key.

## Deviations from Plan

### Superseded plan wording — D-16's second exact-`Int` exception (recorded, not fixed here)

Task 2's `<behavior>` says rendered values are "a closed enum's raw value, `"true"`/`"false"` for a `Bool`, or the decimal rendering of **the one permitted exact `Int`** (`Search.keywordLength`)." Under **D-16** — an owner amendment postdating this plan's authoring, and flagged in the execution prompt's `<owner_decisions>` — there are now **two** permitted exact-`Int` sources, and both are rendered as decimal integers:

| Superseded plan entry | What it asserts | What shipped |
|---|---|---|
| Task 2 `<behavior>`, rendering-values sentence | "the decimal rendering of the one permitted exact `Int` (`Search.keywordLength`)" | two exact-`Int` sources rendered decimal: `Search.keywordLength` **and** the per-namespace tag counts under `Gallery.tagNamespace.<namespace>` |

The tag counts were **not** bucketed to satisfy the stale wording and were **not** dropped from the payload — either choice would contradict D-16, which the prompt names as binding. This follows the precedent plan 14-03 set, whose SUMMARY records the same D-16 divergence in a superseded-entry table so the phase verifier reads the difference as intended scope rather than drift.

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `-skipMacroValidation -skipPackagePluginValidation` on every verify gate**
- **Found during:** Task 1 (first verification run)
- **Issue:** This plan's `<automated>` gates omit both flags. Phase 14's TelemetryDeck dependency invalidated Xcode's macro trust approvals, so every unflagged build fails at `ComputeTargetDependencyGraph`. The execution prompt's `<build_command_requirement>` and `14-03-SUMMARY.md` both flag this as a phase-wide carry-forward.
- **Fix:** Both flags added to every `xcodebuild` invocation, matching `.github/workflows/test.yml`.
- **Files modified:** none — invocation-level only.

**2. [Rule 3 — Blocking] Split the `searchPerformed` fixture initializer across lines**
- **Found during:** Task 2 (RED run)
- **Issue:** The single-line `searchPerformed(shape:resultCount:)` fixture reached 121 characters, one past the `line_length` error limit.
- **Fix:** Broke the call onto three lines. No behavior change.
- **Files modified:** `AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift` (before its RED commit).

## Known Stubs

None. Every case renders to a real name and a real parameter dictionary; there is no placeholder value in the module.

## Issues Encountered

- The `AnalyticsClient` module has no committed `swiftlint` on `PATH`; the SwiftLint binary bundled in the project's DerivedData `SourcePackages` artifact bundle was used for the `--strict` lint gate, matching the plugin the package builds with.

## User Setup Required

None — no external service configuration required by this plan. The TelemetryDeck app ID and salt were plumbed in plan 14-04; the single SDK call site is plan 14-06.

## Next Phase Readiness

- Plan **14-06** owns the single SDK call site: it consumes `AnalyticsSignal.Rendered`, calls `TelemetryDeck.signal(_:parameters:)` for the `.signal` case and `TelemetryDeck.errorOccurred(id:category:)` for the `.error` case, and translates `AnalyticsErrorCategory` into the vendor's `ErrorCategory` there. `Rendered` and `rendered` are `internal`, reachable from within the module.
- Carry-forward, unchanged: every `xcodebuild` invocation in this phase needs `-skipMacroValidation -skipPackagePluginValidation`.
- Reconciliation still outstanding (owned by plan **14-17**, surfaced by 14-03): `Buckets.swift`'s header and `ANALYTICS-01` in `REQUIREMENTS.md` still describe D-08 as having a single documented exception; there are two.

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*

## Self-Check: PASSED

All 3 source and test files exist on disk; all 5 task commits (`532fa9c5`, `180bf229`, `45a8af03`, `b4bf3743`, `59ea8891`) resolve in `git log`. No absolute home path appears in this document.
