---
phase: 11-infra-refactor-lint-capstone
plan: 5
subsystem: AppTools + AppModels
tags: [lint, error-handling, logging, refactor, persistence]
requires:
  - "11-04 (DownloadClient at zero optional-try; named-probe-helper pattern established)"
provides:
  - "AppTools module at zero optional-try"
  - "AppModels module at zero optional-try"
  - "DataCache.evictFile(at:) — logged cache-file removal seam"
  - "DataCache.bumpAccessDate(for:) — logged access-date bump seam"
  - "JSONValue.probe(_:in:) — the single-value-container type-probe seam"
affects:
  - "plan 11-24 (optional_try config flip)"
tech-stack:
  added: []
  patterns:
    - "in-chain probes (guard let / if let / ?? / else-if chains) modelled as named Optional-returning helpers"
    - "static stored property with a throwing initializer expressed as an immediately-applied closure"
key-files:
  created: []
  modified:
    - AppPackage/Sources/AppTools/DataCache.swift
    - AppPackage/Sources/AppTools/Defaults.swift
    - AppPackage/Sources/AppTools/Extensions.swift
    - AppPackage/Sources/AppModels/Persistence/JSONValue.swift
decisions:
  - "Thirteen DataCache sites collapse onto two named seams (evictFile, bumpAccessDate) plus six inline do/catch blocks — the two seams carry the only logged failures in the file"
  - "Defaults.Regex.tagSuggestion compiles inside an immediately-applied closure: it is a static stored property, so propagating would force a force-try and the nil contract is deliberate"
  - "JSONValue's six probes route through one private generic helper rather than six inline blocks — do/catch is not expressible inside an else-if-let chain, and one helper states the swallow rationale once"
  - "Zero D-02 exception candidates: every site was expressible without try?"
metrics:
  duration: ~20m
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 5: AppTools + AppModels Optional-Try Removal Summary

Converted the 23 optional-try sites in the utility layer — DataCache's disk housekeeping, the
Encodable/Data/String convenience extensions, the tag-suggestion regex, and JSONValue's six-way
type-probe chain — to named seams or explicit `do`/`catch`, taking both modules to **zero** `try?`
with no behavior change and no exception candidates.

## What Was Built

### Task 1 — AppTools: DataCache + Extensions + Defaults (17 sites), commit `c8efeba2`

**Two named seams on `DataCache`**, both logging, both replacing repeated shapes:

- `evictFile(at:)` — the three cache-file removals (expired entry, corrupt entry, swept entry).
  All three run *after* their caller has already resolved its own outcome (a miss, or an eviction
  whose memory half still completes), so a failed removal cannot be allowed to change that
  outcome. It logs because the file was known to exist moments earlier, which makes failure
  genuinely unexpected — the same logged/silent split plan 11-04 settled on.
- `bumpAccessDate(for:)` — the two `touchAccessDate` calls (post-read and post-write). A failed
  bump only costs the entry its place in the LRU ordering, never the read or the write, so it is
  absorbed and logged.

**Silent inline conversions**, each carrying a comment naming why the catch says nothing:

- the `Data(contentsOf:)` read in `data(forKey:)` — an unreadable entry *is* the miss, the
  documented negative answer; only its cleanup logs.
- `totalSize()`'s per-file `resourceValues` — size reporting is intentionally approximate, so an
  unmeasurable entry is ordinary.
- both `accessDate(for:)` probes — a volume that does not record access dates is routine, and the
  documented fallbacks (modification date, then `.distantPast` so the sweep evicts) are unchanged.
- both `setResourceValues` metadata writes (backup exclusion, content-access date) — supplementary
  metadata that must not fail directory creation or a timestamp touch.
- `write`'s stale-root removal — the root is frequently simply absent, which is exactly the state
  the retry wants; `ensureDirectory` still decides whether the retry can proceed.

**One further logged site:** the background `sweepDisk()` in the memory-purge observer. It is
fire-and-forget with no user-facing result, but a persistently failing sweep lets the disk cache
grow unbounded, so it earns a line. The file gained a top-level `private let logger =
Logger(category: "DataCache")`, matching `Optional+ForceUnwrapped.swift`'s precedent —
AppTools already had its own `Logger+.swift` (it composes the subsystem locally because OSLogExt
depends on AppTools), so no new Logger extension was needed. No cached bytes, keys, or URLs are
logged; only `error` and fixed descriptors.

**`Extensions.swift`:** `Encodable.toData()` and `Data.toObject()` keep their public Optional
signatures and their nil-on-failure contract, now stated in a silent catch. `String.isValidURL`
was restructured — the detector is built in a `do`/`catch` that returns `false`, and the nested
`if let match … else { return false }` flattened into a `guard`. Same truth table, less nesting.

**`Defaults.Regex.tagSuggestion`** is a `static let` with a throwing initializer, so there is no
statement position to put a `do`/`catch` in. It now compiles inside an immediately-applied
closure, preserving the `NSRegularExpression?` type and the deliberate nil contract (a failed
pattern disables suggestions rather than failing app launch). No force-try was introduced.

### Task 2 — AppModels: JSONValue probe chain (6 sites), commit `3b03783f`

`JSONValue.probe(_:in:)` — one private generic helper performing a single
`SingleValueDecodingContainer.decode` in `do`/`catch`, returning `Optional`, called six times in
the original order. `do`/`catch` is not expressible inside an `else if let` chain, and six one-off
inline restructurings would have scattered one rationale across six comments; the helper states it
once: failure is the *control flow* here, since a mismatch is precisely how the decoder selects the
next representation, and only a value matching none of the six is a real failure — which the chain
still throws as `DecodingError.dataCorrupted` exactly as before.

The probe order comment was consolidated onto the chain and made explicit about why the order is
load-bearing (`Int` before `Double` prevents integer widening; composites last), since persisted
`@Shared` models decode through it under the v1-schema-until-release policy. Decode semantics,
ordering, and failure behavior are unchanged — AppModelsTests (schema + migration suites) pass
unmodified.

## Key Decisions

**Two seams, not thirteen inline blocks.** The three removals and the two access-date bumps were
byte-identical in code and intent. Naming each one once puts the "absorbed because the outcome is
already decided" rationale in a single doc comment instead of five.

**The logged/silent split is per-site and inherited.** Removals, bumps, and the background sweep
log — each is an operation the code intends to succeed. Probes (the entry read, size metadata,
access-date lookups, supplementary metadata writes, the stale-root removal, the two convenience
codecs, the URL detector, all six JSON type probes) stay silent because failure is the ordinary
negative answer, and every one of them carries a comment saying so. This is plan 11-04's split
applied unchanged.

**No `swiftlint:disable` was needed anywhere.** Every one of the 23 sites was expressible without
`try?`, including the two shapes that usually force an exception — a static stored property
(closure) and an `else if let` chain (named helper).

## Deviations from Plan

**1. [Carry-forward] Test invocation used `AppPackage-Package`, not the plan's per-module schemes.**
The plan's `<verify>` blocks name `-scheme AppTools` and `-scheme AppModels`; neither scheme exists,
and there is no `AppToolsTests` target at all. Task 1 was verified by the **full** `AppPackage-Package`
suite (AppTools is a dependency of nearly every module, and `ImageClientTests` exercises `DataCache`
directly) — all suites passed. Task 2 was verified by `-only-testing:AppModelsTests`, which holds the
schema/migration suites that exercise `JSONValue`. Both plus a clean whole-app `xcodebuild build
-scheme EhPanda`.

**2. LINT-01 deliberately NOT marked complete.** It spans all 30 plans and flips at 11-29.

## Threat Flags

None. No new network, auth, file-access, or schema surface: the diff is error-handling form only,
and the one class of new emission (OSLog lines in `DataCache`) carries no payload, key, or URL —
`Scripts/check-cookie-logging.sh` exits 0 (T-11-06). `JSONValue`'s probe order is preserved
verbatim and gated by the passing AppModels schema/migration suites (T-11-07).

## Verification

| Check | Result |
|-------|--------|
| `grep -rn "try? " AppPackage/Sources/AppTools AppPackage/Sources/AppModels \| grep -v "//" \| wc -l` | **0** |
| SwiftLint on both module paths | 0 violations |
| `xcodebuild build -scheme EhPanda` | BUILD SUCCEEDED, 0 errors |
| Full `AppPackage-Package` suite (task 1) | TEST SUCCEEDED |
| `-only-testing:AppModelsTests` (task 2) | TEST SUCCEEDED |
| `bash Scripts/check-cookie-logging.sh` | exit 0 |

## Known Stubs

None.

## Self-Check: PASSED

- `AppPackage/Sources/AppTools/DataCache.swift` — FOUND
- `AppPackage/Sources/AppTools/Defaults.swift` — FOUND
- `AppPackage/Sources/AppTools/Extensions.swift` — FOUND
- `AppPackage/Sources/AppModels/Persistence/JSONValue.swift` — FOUND
- commit `c8efeba2` — FOUND
- commit `3b03783f` — FOUND
