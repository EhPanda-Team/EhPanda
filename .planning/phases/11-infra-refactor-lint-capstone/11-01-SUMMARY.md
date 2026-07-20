---
phase: 11-infra-refactor-lint-capstone
plan: 1
subsystem: ParserFeature
tags: [lint, error-handling, logging, refactor]
requires: []
provides:
  - "Parser.degrading(_:_:) — the module's single logged-degradation seam"
  - "ParserFeature Groups A/B free of optional-try"
affects:
  - "plan 11-02 (Group C propagation)"
  - "plan 11-24 (optional_try config flip)"
tech-stack:
  added: []
  patterns:
    - "single shared do/catch helper instead of 33 inlined catch blocks"
key-files:
  created: []
  modified:
    - AppPackage/Sources/ParserFeature/Parser+Shared.swift
    - AppPackage/Sources/ParserFeature/Parser+Detail.swift
    - AppPackage/Sources/ParserFeature/Parser+List.swift
    - AppPackage/Sources/ParserFeature/Parser+Torrent.swift
decisions:
  - "Group A/B conversion routes through one `Parser.degrading` helper rather than per-site inline do/catch — inline do/catch is not expressible at these sites without changing evaluation order"
  - "Existing Phase 9 rationale comments kept verbatim in place rather than reworded"
metrics:
  duration: ~25m
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 1: ParserFeature Group A/B Optional-Try Removal Summary

Converted every ParserFeature per-row-drop and per-field-default `try?` site to a logged
`do`/`catch` via a single shared `Parser.degrading` helper, preserving byte-identical degradation
behavior and leaving only the D-04 Group C whole-parse collapses for plan 11-02.

## What Was Built

**`Parser.degrading(_:_:)`** (`Parser+Shared.swift`) — one `do`/`catch` that runs a throwing parse,
logs a failure via the module's existing file-top `private let logger`, and returns `nil`:

```swift
static func degrading<Value>(_ description: String, _ parse: () throws -> Value) -> Value? {
    do {
        return try parse()
    } catch {
        logger.error("\(description, privacy: .public) failed to parse: \(error, privacy: .public)")
        return nil
    }
}
```

All 33 Group A/B call sites pass a fixed literal descriptor (`"Cover URL"`, `"Gallery tags"`,
`"Thumbnail panel"`, …). No call site interpolates document content, URLs, or cookie-bearing values.

### Task 1 — Group A (21 per-row / per-candidate drop sites), commit `25e30036`
- `Parser+Detail.swift`: 9 sites in the `parseGalleryDetail` guard chain (cover, tags, previews,
  archive/torrent, info panel, visibility, uploader, rating, posted date)
- `Parser+List.swift`: 11 sites (4× thumbnail panel, 4× gallery title, panel rating, div/span title
  candidate fallthroughs)
- `Parser+Torrent.swift`: 1 site (torrent posted date)

### Task 2 — Group B (12 per-field default sites), commit `531deb9b`
- `Parser+Shared.swift`: script date, text rating
- `Parser+Detail.swift`: preview config, archive URL, fallback archive URL
- `Parser+List.swift`: 4× gallery tags, 2× uploader, published date

## Key Decisions

**One shared helper, not 33 inline `do`/`catch` blocks.** Most of these sites sit inside `guard let`
condition chains or call arguments, where Swift cannot host a `do`/`catch`. Hoisting each parse into
a preceding statement would run parses the chain currently short-circuits past — extra work, extra
log lines, and in several cases impossible because the parse consumes a binding the same `guard`
introduces (`gl2mNode`, `gd4Node`). The helper is the only shape that keeps evaluation order and
short-circuiting byte-identical. Its rationale is recorded as a doc comment on the helper itself.

**Phase 9 rationale comments kept in place, unchanged.** They already read as plain doc comments
explaining the deliberate degradation, so rewording them would have been churn without gain. Each
converted site still carries its own WHY (row dropped vs. field defaulted).

## Deviations from Plan

### 1. [Rule 1 — Plan inventory arithmetic] Group counts corrected: 33 sites, not 36; 9 remain, not 6
- **Found during:** Task 1 enumeration
- **Issue:** The plan (and D-04) budget 42 sites as 23 Group A + 13 Group B + 6 Group C. The actual
  split is **21 A + 12 B + 9 C**. Group C was undercounted: `Parser+List.swift` lines 10–29 hold
  the `switch try? parseDisplayMode` plus **six** mode-branch fallbacks (the plan says "×4"),
  which with `Parser+Detail.swift:130` and `Parser+Shared.swift:58` totals 9.
- **Fix:** Converted all 33 genuine Group A/B sites; left all 9 Group C sites untouched for plan
  11-02. The Task 2 acceptance check "count equals exactly 6" therefore reads **9**, and every one
  of the 9 is a named D-04 Group C location (verified by inspection, listed below).
- **Impact on 11-02:** plan 11-02 must propagate 9 sites, not 6. The 3 extra are `Parser+List.swift`
  lines 22 and 25 (Extended / Thumbnail mode branches) and line 10 (the `parseDisplayMode` switch
  subject) — all the same whole-parse-collapse shape as the branches the plan already names.
- **Commits:** `25e30036`, `531deb9b`

### 2. [Rule 3 — Blocking] Test scheme substitution
- **Found during:** Task 1 verification
- **Issue:** `xcodebuild test -scheme ParserFeature` fails with "Scheme ParserFeature is not
  currently configured for the test action" — the per-module schemes in `EhPanda.xcodeproj` have no
  test action, and `AppPackage-Package` is not a scheme of that project.
- **Fix:** Ran the package's own scheme from the package root, scoped to this module's tests:
  `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air' -only-testing:ParserFeatureTests`
  (invoked from `AppPackage/`). This is the project-constraint-sanctioned substitution.
- **Note for later plans in this phase:** every plan whose `<verify>` block names a per-module
  scheme will hit this; use the same substitution.

## Verification

| Check | Result |
|-------|--------|
| `ParserFeatureTests` (31 tests, 10 suites) | passed, **zero assertion edits** |
| Comment-filtered optional-try count in `AppPackage/Sources/ParserFeature` | 9 — all Group C |
| `bash Scripts/check-cookie-logging.sh` | exit 0 |
| SwiftLint on `AppPackage/Sources/ParserFeature` | exit 0, no output |

Remaining Group C sites (untouched, for plan 11-02):

```
Parser+Shared.swift:58   guard let regex = try? NSRegularExpression(pattern: pattern)
Parser+List.swift:10     switch try? parseDisplayMode(doc: doc)
Parser+List.swift:13,16,19,22,25,29   galleries = (try? parse…ModeGalleries(…)) ?? []
Parser+Detail.swift:130  guard let previewMode = try? parsePreviewMode(doc: doc)
```

## Known Stubs

None.

## Threat Flags

None. The only new surface is the `logger.error` line inside `Parser.degrading`, which is covered by
threat T-11-01's mitigation: it interpolates only a caller-supplied fixed literal and the `error`
value, both marked `privacy: .public`, and the cookie-logging gate passes.

## Self-Check: PASSED

- `AppPackage/Sources/ParserFeature/Parser+Shared.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Detail.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+List.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Torrent.swift` — FOUND
- commit `25e30036` — FOUND
- commit `531deb9b` — FOUND
