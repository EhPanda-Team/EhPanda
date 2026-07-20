---
phase: 11-infra-refactor-lint-capstone
plan: 4
subsystem: DownloadClient
tags: [lint, error-handling, logging, refactor]
requires:
  - "11-03 (DownloadClient store/persistence cluster at zero optional-try; probeManifest / closeReadHandle seams)"
provides:
  - "DownloadClient module at zero optional-try — no residue for the 11-24 optional_try flip"
  - "DownloadCoordinator.probeHTMLDocument(_:) — the response-DOM probe seam"
  - "DownloadCoordinator.probeFileData(at:) — the optional fingerprint-bytes probe seam"
  - "DownloadCoordinator.discardRejectedResponseFile(at:) — logged rejected-response cleanup seam"
affects:
  - "plan 11-24 (optional_try config flip)"
tech-stack:
  added: []
  patterns:
    - "in-chain probes (guard let / ?? / if let) modelled as named Optional-returning helpers"
    - "cross-type helper reuse: DownloadStore.closeReadHandle promoted to internal for the coordinator"
key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
decisions:
  - "Five probe sites collapse onto two named helpers (probeHTMLDocument, probeFileData) rather than five inline blocks — all five sit inside guard/if-let/?? chains where do/catch is not expressible without reordering evaluation"
  - "closeReadHandle reused from DownloadStore (private -> internal) instead of duplicating the helper on DownloadCoordinator"
  - "Probe helpers stay silent; cleanup and flush failures log — the split follows D-01's 'log where failure is unexpected'"
  - "Zero D-02 exception candidates: every site was expressible without try?"
metrics:
  duration: ~25m
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 4: DownloadClient Validation/Networking Optional-Try Removal Summary

Converted the last 15 optional-try sites in DownloadClient — networking cleanup, page-download
cadence, background staging, response validation, and execution support — to named probe helpers or
explicit `do`/`catch`, taking the module to **zero** `try?` with no behavior change and no exception
candidates.

## What Was Built

### Task 1 — Networking + PageDownload + BackgroundDownloads (5 sites), commit `a75dc726`

**`DownloadCoordinator.discardRejectedResponseFile(at:)`** replaces the two identical
rejected-temp-file removals in `downloadResponse(for:retriesRequest:)` and
`pageDownloadResponse`. Both sit immediately before a `throw` of the detected validation error, so
the doc comment records the Phase 9 invariant directly: the rejection is already decided and its
error is authoritative, therefore a removal failure is logged rather than allowed to compete.

**`readResponsePrefixData`'s `defer { try? handle.close() }`** now calls
`storage.closeReadHandle(_:)` — the helper 11-03 already wrote for exactly this shape on
`DownloadStore`. It was `private`; promoting it to `internal` was a smaller and more honest diff
than duplicating a second copy on the coordinator, and the operation is genuinely store-level file
I/O. No third call site was invented.

**`removeStagedBackgroundFile`** was already the named cleanup seam, so its `try?` converted inline
to `do`/`catch` with a log. **`DownloadClient+PageDownload`'s cadence flush** likewise converted
inline and gained a file-top `private let logger`: the flush is opportunistic (a later forced flush
persists the same progress), but a persistence write failing is unexpected and worth a line.

### Task 2 — ResponseValidation + Helpers + ExecutionSupport (10 sites), commit `2ae5ac92`

**Two probe helpers on `DownloadCoordinator`, both in `+ResponseValidationHelpers.swift`:**

- `probeHTMLDocument(_:)` — the two `Kanna.HTML(html:encoding:)` sites. Both callers treat a `nil`
  document identically to a document carrying no error and fall through to raw-content or
  status-code classification, so malformed markup is the *ordinary negative answer* for a probe
  aimed at truncated and non-HTML payloads. Silent by design; the doc comment says why.
- `probeFileData(at:)` — the three `Data(contentsOf:options:.mappedIfSafe)` fingerprint reads
  (`resolveFileData`, `loadPlaceholderDataIfNeeded`, `isQuotaExceededResponse`). These bytes only
  ever *add* a classification the caller could not otherwise make, so an unreadable file means
  "cannot be confirmed by content" and response metadata still drives the verdict.

All five of those sites sit inside a `guard let` chain, an `if let` chain, or a `??` right-hand
side. Inline `do`/`catch` would have required hoisting the read above the conditions that gate it,
changing evaluation order — the named-helper case the phase's patterns reserve for exactly this.

**`detectResponseError(fileURL:response:requestURL:)`'s prefix read** is in statement position and
converted inline to a `do`/`catch` that logs and falls back to empty `Data()`, preserving the
documented fall-through to placeholder/status-code validation. It logs because the file was just
staged by URLSession — failing to read it is genuinely unexpected.

**`fileSize(at:)`'s `resourceValues`** converted inline and stays silent: an absent size attribute
is the routine path callers already handle by consulting response headers.

**`DownloadClient+ExecutionSupport`'s two manifest reads** (`shouldReuseWorkingFolder`'s reuse probe
and `repairSeed`'s seeding probe) are the same domain operation 11-03 named, so both now call
`storage.probeManifest(folderURL:)` — bringing that helper's site count to eight. The stale
working-folder removal converted inline with a log, and the file gained a `private let logger`.

**Dead import removed:** `DownloadClient+ResponseValidation.swift` no longer references `Kanna`
directly once the DOM probe moved to the helpers file, so `import Kanna` was dropped. Verified by a
clean whole-app build.

## Key Decisions

**Two helpers, not five inline blocks, and not five separate helpers.** The three
`Data(contentsOf:)` sites were byte-identical in both code and intent; the two Kanna sites likewise.
Writing them out inline was not available (chain positions), and writing five one-off helpers would
have scattered one rationale across five doc comments. Each helper states its silent-catch reason
once.

**Reuse over duplication for `closeReadHandle`.** The alternative — a private `closeReadHandle` on
`DownloadCoordinator` — would have produced a second identical helper in the same module with a
second log descriptor for the same operation. Promoting the existing one to `internal` is a
one-word diff.

**The silent/logged split is per-site, not per-file.** Probes (HTML DOM, fingerprint bytes, file
size, manifest reuse) are silent because failure is the expected negative answer and logging would
scale with library size. Cleanup and persistence failures (rejected-response removal, staged-file
removal, stale-folder removal, cadence flush, prefix read) log, because each is an operation the
code intends to succeed. Every silent catch carries a comment saying so.

**No D-02 exception candidates.** As in 11-03, the owner has nothing to review from this plan.

## Deviations from Plan

### 1. [Rule 3 — Blocking] Test target substitution, again

- **Found during:** Task 1 verification
- **Issue:** The plan's Task 1 names `-scheme DownloadClient` and Task 2 names
  `-scheme DownloadsFeature`. Neither scheme exists; `DownloadClientTests` has no target at all
  (carried forward from 11-03).
- **Fix:** Both tasks verified with
  `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air'
  -only-testing:DownloadsFeatureTests` run from `AppPackage/`.

### 2. [Rule 1 — Plan inventory] 15 sites, not "~20"

- **Found during:** Task 1 enumeration
- **Issue:** The plan estimates "the remaining ~20 of 36 sites". The true remaining count was
  **15** (Networking 3, PageDownload 1, BackgroundDownloads 1, ResponseValidation 4,
  ResponseValidationHelpers 3, ExecutionSupport 3), matching 11-03's corrected residual figure.
- **Fix:** Converted all 15; module-wide comment-filtered count is now **0**.

### 3. [Rule 1 — Dead code] Unused `import Kanna`

- **Found during:** Task 2
- **Issue:** Moving the DOM probe out of `+ResponseValidation.swift` left its `import Kanna`
  unreferenced.
- **Fix:** Removed; whole-app build succeeds, confirming the `HTMLDocument` return type resolves
  through the helper without the direct import.
- **Commit:** `2ae5ac92`

## Verification

| Check | Result |
|-------|--------|
| `DownloadsFeatureTests` after Task 1 | 251 tests / 52 suites passed, **zero assertion edits** |
| `DownloadsFeatureTests` after Task 2 | 251 tests / 52 suites passed, **zero assertion edits** |
| `xcodebuild build -scheme EhPanda` | BUILD SUCCEEDED (24.9s), zero errors |
| Module-wide comment-filtered `try?` count in `AppPackage/Sources/DownloadClient` | **0** |
| SwiftLint `--strict` on `AppPackage/Sources/DownloadClient` | 0 violations, 0 serious |
| `bash Scripts/check-cookie-logging.sh` | exit 0 (both tasks) |

`DownloadSchedulingTests` — the deterministic-since-`557b0425` suite — passed on both runs, so the
scheduling and cadence-flush paths this plan touched are unaffected. The Phase 4 invariants
(25-pair gdata chunking, two-in-flight flood control, input-order reconstruction, page-URL ordering)
are covered by that suite and unchanged: no control flow was reordered, only `try?` expressions
replaced by equivalents with the same result on failure.

## Known Stubs

None.

## Threat Flags

None. T-11-04's mitigation holds: the four new `logger.error` lines interpolate only a fixed
operation descriptor and the `error` value, both `privacy: .public` — no path, URL, gallery
identifier, or cookie value reaches a new log line, and the cookie-logging gate passes. T-11-05's
mitigation holds: every catch path reproduces the prior fallback value exactly (`Data()`, `nil`, or
proceed), and the deterministic `DownloadsFeatureTests` suite passed unmodified as the behavioral
gate.

Note (pre-existing, out of scope): `DownloadClient+ResponseValidation.swift`'s unexpected-HTML
`logger.error` already interpolates `requestURL?.absoluteString`. It predates this plan, passes the
cookie-logging gate, and was left untouched.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- commit `a75dc726` — FOUND
- commit `2ae5ac92` — FOUND
