---
phase: 11-infra-refactor-lint-capstone
plan: 3
subsystem: DownloadClient
tags: [lint, error-handling, logging, refactor]
requires:
  - "11-02 (ParserFeature at zero optional-try; established do/catch + shared-helper patterns)"
provides:
  - "DownloadStore/Operations/DownloadClient/Cache/PublicAPI/PersistenceNormalize free of optional-try"
  - "DownloadStore.probeManifest(folderURL:) — the module's manifest identity-probe seam"
  - "DownloadStore.discardRejectedAsset(at:) / closeReadHandle(_:) — logged best-effort cleanup seams"
affects:
  - "plan 11-04+ (remaining DownloadClient optional-try sites)"
  - "plan 11-24 (optional_try config flip)"
tech-stack:
  added: []
  patterns:
    - "identity probe modelled as a named Optional-returning helper instead of an inline try?"
    - "Result-returning coordinator calls consumed by an explicit switch rather than try? .get()"
key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadClient.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
decisions:
  - "Six manifest-probe sites collapse onto one named probeManifest helper rather than six inline do/catch blocks — the probe is a domain concept, not an error path"
  - "Probe failures are deliberately NOT logged; scans walk arbitrary user folders and would emit a line per unrelated folder"
  - "The two Result-to-Optional sites in DownloadClient.swift became explicit switch statements, not a new helper — each carries a distinct log descriptor"
  - "Zero D-02 exception candidates were needed: every in-scope site was expressible without try?"
metrics:
  duration: ~30m
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 3: DownloadClient Store/Persistence Optional-Try Removal Summary

Converted all 21 optional-try sites in DownloadClient's store/persistence cluster to explicit
`do`/`catch`, named probe helpers, or exhaustive `Result` switches, with zero behavior change and
zero exception candidates — the six in-scope files now hold no `try?` at all.

## What Was Built

### Task 1 — DownloadStore + Operations + DownloadClient (18 sites), commit `289e8380`

**`DownloadStore.probeManifest(folderURL:)`** — the plan anticipated a `Parser.degrading`-shaped
helper, and the manifest read is exactly that case. Six sites across four files did the same thing:
read a manifest purely to answer "is this folder a readable gallery?". They now call one
`internal` helper whose doc comment records the WHY of its silent `catch`: filesystem discovery
walks arbitrary user-visible folders (the app ships `UIFileSharingEnabled` /
`LSSupportsOpeningDocumentsInPlace`, so the user can create and move anything under the download
root), which makes an undecodable manifest the *ordinary negative answer*, not a failure. Logging
it would emit a line per unrelated folder on every scan.

**Two more cleanup seams in `DownloadStore`**, each replacing a duplicated `try?`:

- `discardRejectedAsset(at:)` — the two post-rejection `removeItem` calls in
  `sanitizeAssetFileIfNeeded`. The rejection stands regardless of removal success, so a failure is
  logged rather than folded into the `Bool` answer.
- `closeReadHandle(_:)` — the two `defer { try? handle.close() }` sites. Both sit after the value
  the caller wants is already produced, so a close failure is logged instead of replacing that
  result.

**Remaining `DownloadStore` sites converted inline:** backup-exclusion metadata (logged — an OS
rejection is unexpected), holding-directory purge (logged), the two `contentsOfDirectory` reads and
the `isDirectory` resource-value filter (not logged — absence is the normal control-flow path), and
the folder modification-date read (not logged — display metadata).

**`DownloadStore+Operations`** — both sites are genuine corruption signals, so both log. The
`validate` manifest read runs *after* an explicit `fileExists` check on the manifest URL, which
makes a read failure real corruption rather than absence. The page-hash site keeps its deliberate
"unreadable bytes are as bad as changed bytes" equivalence, now expressed as an `actualHash:
String?` that the existing `guard` compares — behavior is identical, the reason is on the page.

**`DownloadClient.swift`** — `fetchVersionMetadata` and `loadLocalPageURLs` were
`try? await ….get()` on a `Result`. Both became exhaustive `switch` statements returning the
success value or logging and returning `nil`. Since `Result` already carries the error, the
optional-try was pure information loss.

### Task 2 — Cache + PublicAPI + PersistenceNormalize (3 sites), commit `46a87e0f`

`DownloadClient+PublicAPI.reusableExistingManifest` and
`DownloadClient+PersistenceNormalize.validatedManifest` both call `storage.probeManifest` — they
are the same probe, one folder deeper in the call graph. `DownloadClient+Cache.removeCachedImages`
wraps its data-cache eviction in a logged `do`/`catch`; the loop that clears the independent
library image cache still runs on failure, exactly as before.

## Key Decisions

**One `probeManifest` helper instead of six inline `do`/`catch` blocks.** Four of the six sites sit
inside `guard let` condition chains (two of them inside `filter`/`compactMap` closures) and one is
a `(try? …) == nil` negation. Inline `do`/`catch` is expressible at some of them but not at all,
and writing six near-identical catch blocks would have obscured the fact that this is a single
domain operation with a name. Naming it also let the silent-catch rationale be stated once.

**Deliberately silent catches where absence is normal.** D-01 asks for logging "where failure is
unexpected". Probes, directory listings against possibly-absent folders, and display-metadata reads
are the routine-failure paths; logging them would be noise proportional to library size. Every one
of these carries a comment saying so. All eight logged sites use a fixed operation descriptor plus
the `error` value, both `privacy: .public` — no paths, URLs, or cookie-bearing values.

**No D-02 exception candidates.** Every in-scope site was expressible without `try?`, so the owner
has nothing to review from this plan.

## Deviations from Plan

### 1. [Rule 1 — Plan inventory] 21 in-scope sites, and the module total is 36 grep hits, not 36 sites

- **Found during:** Task 1 enumeration
- **Issue:** The plan describes the cluster as "roughly half of the module's 36 sites". The true
  in-scope count is **21** (DownloadStore 14, Operations 2, DownloadClient.swift 2, Cache 1,
  PublicAPI 1, PersistenceNormalize 1) — well over half.
- **Fix:** Converted all 21. Comment-filtered `try?` count across the six files is now **0**; the
  module has **15** remaining, all in files owned by later plans (ExecutionSupport, PageDownload,
  ResponseValidation, ResponseValidationHelpers, BackgroundDownloads, Networking).
- **Commits:** `289e8380`, `46a87e0f`

### 2. [Rule 3 — Blocking] Test target substitution: `DownloadClientTests` does not exist

- **Found during:** Task 1 verification
- **Issue:** Beyond the per-module-scheme problem carried forward from 11-01/11-02, there is no
  `DownloadClientTests` target at all — `AppPackage/Tests/` has no such directory. The
  `DownloadClient` module is exercised end-to-end by **`DownloadsFeatureTests`**, which is the
  target the plan's Task 2 already names.
- **Fix:** Ran `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air'
  -only-testing:DownloadsFeatureTests` (from `AppPackage/`) for both tasks. Task 1's and Task 2's
  automated verification are therefore the same command.
- **Note for later plans in this phase:** every remaining DownloadClient plan will hit this; there
  is no module-level test target to substitute for.

### 3. [Rule 2 — Missing critical functionality] Two duplicated cleanup patterns extracted rather than duplicated

- **Found during:** Task 1
- **Issue:** Converting `try? handle.close()` and `try? removeItem(at:)` in place would have
  produced four near-identical five-line `do`/`catch` blocks inside `defer` and `guard` bodies.
- **Fix:** Extracted `closeReadHandle(_:)` and `discardRejectedAsset(at:)`, each with a doc comment
  explaining why the failure is logged rather than propagated. Net line count is lower than the
  inline conversion and the intent is on the helper instead of repeated at each site.
- **Commit:** `289e8380`

## Verification

| Check | Result |
|-------|--------|
| `DownloadsFeatureTests` after Task 1 | 251 tests / 52 suites passed, **zero assertion edits** |
| `DownloadsFeatureTests` after Task 2 | 251 tests / 52 suites passed, **zero assertion edits** |
| `xcodebuild build -scheme EhPanda` | BUILD SUCCEEDED (26.9s) |
| Comment-filtered optional-try count in the six in-scope files | **0** |
| SwiftLint `--strict` on `AppPackage/Sources/DownloadClient` (all 35 files) | 0 violations, 0 serious |
| `bash Scripts/check-cookie-logging.sh` | exit 0 (both tasks) |

`DownloadSchedulingTests` — the previously-flaky, now-deterministic suite — passed on both runs, so
the scheduling paths that read manifests through `probeManifest` are unaffected.

## Known Stubs

None.

## Threat Flags

None. T-11-03's mitigation is satisfied: the eight new `logger.error` lines interpolate only a
fixed operation descriptor and the `error` value, both `privacy: .public`. No file path, URL,
gallery identifier, or cookie value reaches a log line, and the cookie-logging gate passes.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` — FOUND
- commit `289e8380` — FOUND
- commit `46a87e0f` — FOUND
