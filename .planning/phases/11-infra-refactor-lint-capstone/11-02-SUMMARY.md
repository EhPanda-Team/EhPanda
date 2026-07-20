---
phase: 11-infra-refactor-lint-capstone
plan: 2
subsystem: ParserFeature
tags: [lint, error-handling, refactor, regex]
requires:
  - "11-01 (Parser.degrading helper; Groups A/B converted)"
provides:
  - "ParserFeature at zero optional-try sites"
  - "parseDisplayMode as a non-throwing optional lookup"
  - "RegexBuilder-based parseScriptVariable (no runtime regex compile)"
affects:
  - "plan 11-24 (optional_try config flip)"
tech-stack:
  added: []
  patterns:
    - "compile-time-validated RegexBuilder in place of runtime NSRegularExpression compiles"
    - "absence-is-normal modelled as an Optional return, not a thrown error"
key-files:
  created: []
  modified:
    - AppPackage/Sources/ParserFeature/Parser+List.swift
    - AppPackage/Sources/ParserFeature/Parser+Detail.swift
    - AppPackage/Sources/ParserFeature/Parser+Shared.swift
    - AppPackage/Tests/ParserFeatureTests/List/ListParserTests.swift
decisions:
  - "parseDisplayMode returns String? instead of throwing — a missing selector is the normal toplist case, so it was never an error"
  - "parseScriptVariable rebuilt with RegexBuilder rather than restructured into a throwing accessor — removes the failure path entirely instead of routing it"
  - "No do/catch banner-precedence wrapper added around the mode switch — after 11-01 the mode parsers cannot throw, so the catch would be unreachable code"
metrics:
  duration: ~20m
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 2: ParserFeature Group C Error Propagation Summary

Converted the last 9 optional-try sites in ParserFeature to real propagation or to honest
`Optional` returns, leaving the module at zero `try?` sites, and added list-parser tests that pin
the throw-on-error-banner vs. empty-on-valid-empty-page contract.

## What Was Built

### Task 1 — 9 Group C sites, commit `0dbada87`

**`Parser+List.swift` (7 sites).** `parseDisplayMode` no longer throws: it returns `String?`, because
a page without a display-mode selector is the ordinary toplist case, not a parse failure. The
`switch` subject drops its `try?` unchanged in shape (Swift promotes the string patterns to
`Optional`), and each of the six mode branches becomes a plain `try` call whose failure rides the
function's existing `throws` signature instead of collapsing to `[]`. The `galleries.isEmpty +
parseResponseError` check is preserved and now carries a doc comment stating why the banner error
outranks a bare empty render.

**`Parser+Detail.swift` (1 site).** `parsePreviewConfig` hoists `try parsePreviewMode(doc:)` out of
its `guard let` chain. Behaviour is identical — both the old `try?`-then-`guard` and the new `try`
end in a thrown `AppError.parseFailed` — but the error is now the specific one the callee raised.

**`Parser+Shared.swift` (1 site).** `parseScriptVariable` replaces its runtime-compiled
`NSRegularExpression` with a `RegexBuilder` regex. This is the plan's preferred root fix adapted to a
dynamic pattern: the regex is validated at compile time so there is no construction failure to
swallow, and `name` is matched as a literal component, which also deletes the manual
`NSRegularExpression.escapedPattern` escaping step.

### Task 2 — parser tests, commit `0f9ceb41`

`ListParserTests` gains two cases that encode the post-change contract:

- `testUnparseableListWithErrorBannerThrows` — a page yielding no galleries and carrying a
  `Gallery not found.` banner throws `AppError.notFound`.
- `testValidEmptyListParsesToEmptyResult` — a structurally valid compact-mode page with zero rows
  still parses to `[]`, guarding against over-throwing.

The 31 pre-existing tests are untouched and still pass, which is the parity evidence for the
RegexBuilder swap: the date-seek navigation tests exercise `parseScriptVariable` against both
literal-HTML and full-page fixtures.

## Key Decisions

**`parseDisplayMode` became `-> String?` rather than staying `throws`.** The plan grouped its `try?`
with the whole-parse collapses, but it is not one: the very next line's `default` branch exists
*because* toplists ship no selector. Propagating there would break toplists. Modelling absence as
`nil` removes the optional-try at the root instead of converting a non-error into an error.

**No unreachable banner-precedence `do`/`catch`.** The plan asked to preserve banner-over-parse-error
ordering when a mode parser throws. After plan 11-01, none of the five `parse*ModeGalleries`
functions can throw — every internal failure routes through `Parser.degrading` and a bad row simply
`continue`s. A `catch` around the switch would therefore be dead code. The existing
`isEmpty + parseResponseError` check already delivers banner precedence for every reachable path, so
it was kept and documented rather than duplicated. The `throws`/`try` pairing is retained so a future
mode parser that does throw propagates correctly.

## Deviations from Plan

### 1. [Rule 1 — Inventory] 9 Group C sites, not 6

- **Found during:** Task 1 (carried forward from plan 11-01's Deviation 1)
- **Issue:** The plan budgets 6 sites; `Parser+List.swift` holds six mode branches plus the
  `parseDisplayMode` switch subject, so with `Parser+Detail.swift` and `Parser+Shared.swift` the true
  count is 9.
- **Fix:** Converted all 9. Verified `grep -rn "try? " AppPackage/Sources/ParserFeature | grep -v "//"`
  reports 0.
- **Commit:** `0dbada87`

### 2. [Rule 1 — Premise correction] The mode parsers cannot throw, so the observable behaviour change is nil

- **Found during:** Task 1
- **Issue:** The plan's must-have truth reads "an unparseable gallery-list page now throws instead of
  silently rendering as an empty list". After 11-01 that is not what the `try` conversion buys: the
  five mode parsers swallow every row-level failure through `Parser.degrading` and return `[]`. The
  only reachable throw from `parseGalleries` is the pre-existing error-banner path.
- **Fix:** Made the conversion anyway (it is the lint objective and it future-proofs the propagation
  channel), and did **not** invent an "empty means malformed" heuristic — that would throw on
  legitimately empty search results, which the plan's own acceptance criterion forbids. Task 2's
  tests document the real contract: throw when a banner names a cause, `[]` when the page is validly
  empty.
- **Impact:** Distinguishing a validly-empty page from a bannerless malformed one (e.g. detecting the
  "No hits found" marker) is a genuine behaviour change that was not planned and is not in scope
  here. Flagged for the phase owner.
- **Commit:** `0dbada87`

### 3. [Rule 3 — Blocking] Test scheme substitution (same as 11-01)

- **Issue:** `-scheme ParserFeature` has no test action.
- **Fix:** Ran `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air'
  -only-testing:ParserFeatureTests` from `AppPackage/`.

## Verification

| Check | Result |
|-------|--------|
| `xcodebuild build -scheme EhPanda` | BUILD SUCCEEDED (32.1s) |
| `ParserFeatureTests` | 33 tests / 10 suites passed (31 pre-existing untouched + 2 new) |
| Comment-filtered optional-try count in `AppPackage/Sources/ParserFeature` | **0** |
| SwiftLint `--strict` on `AppPackage/Sources/ParserFeature` | 0 violations, 0 serious in 17 files |
| SwiftLint build-tool plugin on `ParserFeatureTests` | clean (ran as part of the test build) |

## Known Stubs

None.

## Threat Flags

None. T-11-02's mitigation is unchanged in intent; see Deviation 2 for the honest scope of what the
propagation currently covers. `parseScriptVariable` reads the same document content it always did and
logs nothing.

## Self-Check: PASSED

- `AppPackage/Sources/ParserFeature/Parser+List.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Detail.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Shared.swift` — FOUND
- `AppPackage/Tests/ParserFeatureTests/List/ListParserTests.swift` — FOUND
- commit `0dbada87` — FOUND
- commit `0f9ceb41` — FOUND
