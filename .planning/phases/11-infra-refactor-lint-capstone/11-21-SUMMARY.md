---
phase: 11-infra-refactor-lint-capstone
plan: 21
subsystem: test-isolation
tags: [test-isolation, dependency-injection, parallel-tests, clock-injection, d-12, d-14]
requires:
  - "11-19's injectable-root-with-production-default seam shape"
  - "11-20's proof standard: repeat runs plus run-log evidence that cases actually overlapped"
provides:
  - "`DownloadCoordinator.init(now:)` — an injectable wall clock defaulting to `Date()`"
  - "A fully parallel `DownloadsFeatureTests`: zero serialization traits across 57 suites"
affects:
  - "`flushDownloadProgress` reads the injected clock instead of `Date()` directly (no production behaviour change — the default is `Date()`)"
  - "38 suites now run their cases concurrently"
tech-stack:
  added: []
  patterns:
    - "Freezing an injected clock to make a throttle's elapsed-time branch provably dead, so a coalescing assertion measures coalescing rather than machine load"
    - "Diagnosing serialization by suite *shape* first: a `struct` suite gets a fresh instance per case, so only process-globals can leak between them"
key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
    - AppPackage/Tests/DownloadsFeatureTests/ (38 suite files)
decisions:
  - "All 38 traits were removed and none retained, so there is no D-14 rationale comment to write. The one suite that genuinely failed in parallel failed for a reason `.serialized` never fixed, so keeping its trait would have documented a false constraint."
  - "`.serialized` orders cases *within* a suite only; it does not hold a suite apart from other suites. This target already ran 15 unserialized suites concurrently with the 38 serialized ones, so no cross-suite coupling could have been what the traits were guarding — which is what reduced 38 diagnoses to one question per suite."
  - "The real defect found was a wall-clock-sensitive assertion, and the fix was an injected clock rather than a widened bound. Widening the budget would have made the test pass by asserting less."
  - "The clock is a defaulted `init` parameter, not `@Dependency(\\.date)`. `\\.date`'s test value is unimplemented, so routing production through it would have made every test that drives a download report an issue — a large blast radius for one assertion."
metrics:
  duration: ~50 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 21: DownloadsFeatureTests De-serialization Summary

All 38 remaining serialization traits in `DownloadsFeatureTests` are gone, none retained. One
suite genuinely failed in parallel; its root cause was a wall-clock-dependent assertion, fixed
with an injected clock. Two commits, one per task.

## What made 38 diagnoses tractable

Two structural facts, established before touching a file, collapsed most of the work:

**1. `.serialized` is a within-suite trait.** It orders a suite's own cases relative to each
other; it does not hold the suite apart from anything else. This target already contained 15
suites with no trait at all, running concurrently with the 38 that had one. So no trait here
could ever have been guarding *cross-suite* state — if such coupling existed it would already
have been biting. The question per suite therefore narrowed to: **what does this suite share
between its own cases?**

**2. Every one of the 38 is a `struct`.** Swift Testing builds a fresh suite instance per test
case, so stored properties are per-case by construction (the only two that exist,
`AppReadingFlushTests.now` and `ReadingReducerFlushTests.now`, are immutable `Date` constants
anyway). Instance state cannot leak between cases. That leaves exactly one channel: process
globals.

So the diagnosis for all 38 reduced to enumerating the process globals reachable from this
target and checking each is keyed per-case:

| Global | Status |
|---|---|
| Temporary-directory roots | Every case builds `temporaryDirectory/UUID()`. Verified: no fixed path in the target. |
| `SharedSessionStubURLProtocol.handlers` | A `Mutex`-guarded dictionary keyed by `sessionID`; every `sessionID` in the target is `UUID().uuidString`. `canInit` returns `false` for an unknown session, so an unregistered request falls through rather than being stolen. |
| `URLProtocol.registerClass` | Process-wide but idempotent, and the registered class only claims requests carrying a known session header. |
| `FailFastURLProtocol` / `HangingURLProtocol` | `canInit` returns `true` unconditionally — but they are only ever installed via a per-test `URLSessionConfiguration.protocolClasses`, never `registerClass`. Scoped to their own session. |
| `DataCache.shared` | Never referenced. Every `DataCache` in the target is constructed with a UUID root. |
| Sharing's process-global ref cache | `.galleryHistory` is `.appStorage("galleryHistory")`, and `AppStorageKeyID` is `(key, store)`. `TestStore` resolves `defaultAppStorage` to its test value, `UserDefaults.inMemory`, which is a fresh `UUID()`-named suite per resolution — so each store gets its own id and its own reference. The two flush suites additionally pass their own `UserDefaults(suiteName:)`. This is the coupling that kept `DidLoginKeyTests` serialized in 11-20; it does not reach here, because that key's id is constant and these are not. |
| `KingfisherManager.shared.cache` | Reached by `removeCachedImages` through the default `.live` library client — the global 11-20 flagged this plan would meet again. It is write/remove-only, keyed by per-case image URLs, and nothing in the target asserts on its contents (11-20 established the production read path resolves `DataCache`, not Kingfisher). No seam needed; see "Flagged" below. |
| Live singletons | None. Grep for `liveValue` / `DownloadClient.live` across the target returns nothing but a doc comment. |

Two of the 38 turned out to be single-case suites — `DownloadIpBanTests` and
`DownloadProcessCacheTests` — where `.serialized` was doing literally nothing, the same shape
11-20 documented for `DidLoginKeyTests`.

## Verdict table

All 38 removed. No suite required a new seam for isolation, and no suite retained its trait.

| # | Suite | Verdict |
|---|---|---|
| 1 | AppReadingFlushTests | removed — per-case `UserDefaults(suiteName: UUID())`, distinct `AppStorageKeyID` |
| 2 | DataCacheTests | removed — per-case UUID root, own `DataCache` instance |
| 3 | DetailReducerDownloadTests | removed — `TestStore` with stubbed deps only |
| 4 | DetailReducerMetadataTests | removed — `TestStore` with stubbed deps only |
| 5 | DetailReducerMetadataUpdateTests | removed — `TestStore` with stubbed deps only |
| 6 | DetailReducerObserveTests | removed — `TestStore` with stubbed deps only |
| 7 | DetailReducerPauseAndGuardTests | removed — `TestStore` with stubbed deps only |
| 8 | DownloadAutomationTests | removed — `TestStore`; `defaultAppStorage` resolves per-store |
| 9 | DownloadBackgroundCompletionTests | removed — per-case UUID roots |
| 10 | DownloadBackgroundProcessingTests | removed — per-case UUID roots + UUID `sessionID` |
| 11 | DownloadCoordinatorCachedURLTests | removed — single case; trait was a no-op |
| 12 | DownloadCoordinatorCaptureTests | removed — per-case UUID root and injected `DataCache` |
| 13 | DownloadCoordinatorRepairSeedTests | removed — per-case UUID roots |
| 14 | DownloadCoordinatorStorageTests | removed — per-case UUID roots (20 cases); dead `import Kingfisher` dropped |
| 15 | DownloadFolderOperationTests | removed — per-case UUID roots |
| 16 | DownloadImageErrorTests | removed — per-case UUID temporary files |
| 17 | DownloadInspectorLoadTests | removed — `TestStore` with stubbed deps only |
| 18 | DownloadInspectorRetryTests | removed — `TestStore` with stubbed deps only |
| 19 | DownloadInspectorSkipTests | removed — `TestStore` with stubbed deps only |
| 20 | DownloadIpBanTests | removed — single case; trait was a no-op |
| 21 | DownloadObserverBatchTests | **seam + removed** — see below; the one real failure |
| 22 | DownloadObserverReadingTests | removed — `TestStore` with stubbed deps only |
| 23 | DownloadObserverRefreshTests | removed — `TestStore` with stubbed deps only |
| 24 | DownloadPauseAndReconcileTests | removed — per-case UUID roots + per-session `FailFastURLProtocol`; dead `import Kingfisher` dropped |
| 25 | DownloadProcessCacheTests | removed — single case; injects its own `LibraryClient`, so it never touches the shared image cache |
| 26 | DownloadProcessTests | removed — per-case UUID roots + UUID `sessionID` |
| 27 | DownloadRetryMinimalSourceTests | removed — per-case UUID roots + UUID `sessionID` |
| 28 | DownloadRetryPagesTests | removed — per-case UUID roots |
| 29 | DownloadRetryUpdateFallbackTests | removed — per-case UUID roots + UUID `sessionID` |
| 30 | DownloadVersionSignatureTests | removed — per-case UUID roots |
| 31 | DownloadsPresentationLifecycleTests | removed — `TestStore` with stubbed deps only |
| 32 | DownloadsReducerActionTests | removed — `TestStore` with stubbed deps only (11 cases) |
| 33 | DownloadsReducerRefreshTests | removed — `TestStore` with stubbed deps only |
| 34 | FolderManagerReducerTests | removed — `TestStore` with stubbed deps only (13 cases) |
| 35 | PreviewsReducerDownloadTests | removed — `TestStore` with stubbed deps only |
| 36 | ReadingReducerDownloadTests | removed — `TestStore` with stubbed deps only |
| 37 | ReadingReducerFlushTests | removed — per-case `UserDefaults(suiteName: UUID())` |
| 38 | ReadingReducerLocalTests | removed — per-case UUID temporary page files |

## The one that really failed

`testDownloadCoordinatorBatchesObserverUpdatesDuringProgressFlush` failed on the first
full-target run after the second batch of removals:

```
✘ Expectation failed: (emissionCount → 6) <= (2 + Int(ceil(Double(pageCount) / 8.0)) → 5)
```

It was not re-run. `flushDownloadProgress` throttles on **either** of two conditions:

```swift
let shouldFlush = force
    || pendingResolvedPages.count >= Self.progressFlushPageInterval        // 8 — deterministic
    || Date().timeIntervalSince(lastFlushDate) >= Self.progressFlushMinimumInterval  // 0.4 s — wall clock
```

Only the first is the coalescing behaviour the test names. The second makes the emission count a
function of **how long the twenty-iteration loop takes**, which is a function of machine load. The
budget of 5 allows one elapsed-time flush (the first call, whose `lastFlushDate` is
`.distantPast`, always takes that branch). Raising the target's concurrency made the loop straddle
a second 0.4 s window, and a sixth emission appeared.

This is worth being precise about: **the trait was never fixing this.** `.serialized` orders the
suite's own five cases; it never stopped the other ~250 cases in the target from loading the
machine. The test was latently wall-clock-fragile the whole time and the trait only made the
failure rarer. Retaining it under a D-14 comment would have recorded a constraint that does not
exist.

The fix injects the clock, in the shape this codebase already uses for `storage`, `libraryClient`,
`storedCookiesProvider` and 11-19's `FileClient.live(applicationSupportURL:)` — a defaulted
initializer parameter:

```swift
now: @escaping @Sendable () -> Date = { Date() }
```

`flushDownloadProgress` calls `now()` at both sites. Production is byte-identical: the default is
`Date()` and no call site passes anything else. The test passes a frozen `Date`, which makes the
elapsed-time branch **permanently false** rather than merely unlikely — the page-count branch is
then the only trigger, and the assertion measures coalescing. The bound was left exactly as it
was; nothing was widened.

`@Dependency(\.date)` was the other candidate and was rejected: its test value is unimplemented,
so routing production through it would make every test that drives a download through this path
report an issue. That is a large blast radius to buy one assertion's determinism.

## Proving it

Both halves, from the run logs rather than the exit codes — every multi-case suite has **all** its
cases started before the first one finishes, which is precisely what `.serialized` used to prevent:

| Suite (sample) | Cases started before first finish |
|---|---|
| DownloadCoordinatorStorageTests | 20/20 |
| FolderManagerReducerTests | 13/13 |
| DownloadsReducerActionTests | 11/11 |
| DownloadFolderOperationTests | 9/9 |
| DownloadInspectorLoadTests | 9/9 |
| DownloadAutomationTests | 8/8 |
| DownloadPauseAndReconcileTests | 7/7 |
| DataCacheTests | 6/6 |
| DownloadObserverBatchTests | 5/5 |

Every one of the 36 multi-case suites reached *n*/*n*; the remaining two are single-case. Across
the whole target, **239 of 252 cases start before the first finish** (168/252 measured after the
first half alone, before the second batch).

| Run | Scope | Result |
|---|---|---|
| after Task 1 | DownloadsFeatureTests | 253 tests / 53 suites passed (7.32 s) |
| after Task 1 | DownloadsFeatureTests | 253 passed (log captured for overlap analysis) |
| after Task 2, pre-fix | DownloadsFeatureTests | **FAILED**, 1 issue — root-caused, not retried |
| 1 | DownloadsFeatureTests | 253 passed (7.58 s) |
| 2 | DownloadsFeatureTests | 253 passed (7.52 s) |
| 3 | DownloadsFeatureTests | 253 passed (7.87 s) |
| 4 | DownloadsFeatureTests | 253 passed (6.98 s) |
| 5 | DownloadsFeatureTests | 253 passed (6.89 s) |

Five consecutive clean runs after the fix, matching 11-20's escalation for a suite that had been
seen to flake. Test count is unchanged at 253 throughout — no case was lost or skipped.

## Verification

- `-only-testing:DownloadsFeatureTests` — **TEST SUCCEEDED** ×5 consecutively after the fix.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (60.8 s). The two pre-existing
  `withKnownIssue` markers are unchanged; no target regressed.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** (21.7 s), zero warnings.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (27.6 s). This is the
  gate that lints `Tests/`; all four live rules pass.
- `grep -rn '\.serialized' AppPackage/Tests/DownloadsFeatureTests` — **0 matches**.
- No `try?` introduced. None removed either — the `try?` sites in this target belong to 11-23,
  and the files were touched too lightly here to make clearing them anything but scope creep.
- `LINT-01` left open — it flips at 11-29.

## Deviations from Plan

**1. [Rule 1 — Bug] A wall-clock-dependent assertion, fixed with an injected clock**

- **Found during:** Task 2 verification, first full-target run after the second batch.
- **Issue:** `flushDownloadProgress`'s elapsed-time flush trigger made
  `testDownloadCoordinatorBatchesObserverUpdatesDuringProgressFlush`'s emission budget a measure
  of machine load. Raising the target's concurrency pushed it from 5 to 6.
- **Fix:** `DownloadCoordinator.init(now:)`, defaulting to `{ Date() }`; the test freezes it so
  the elapsed-time branch cannot fire. The assertion's bound is unchanged.
- **Why fixed rather than kept serialized:** `.serialized` orders a suite's own cases and never
  isolated it from the other ~250 tests loading the machine, so the trait was not what was
  holding this together. Keeping it would have documented a constraint that does not exist.
- **Files modified:** `DownloadClient+Manager.swift`, `DownloadClient+Persistence.swift`,
  `DownloadObserverBatchTests.swift`
- **Commit:** `ffce4c1e`

**2. [Scope] The plan says 37 suites; there were 38**

Re-enumeration found 38 `@Suite(.serialized)` occurrences, not 37. The verdict table above has
38 rows. The two Kingfisher suites fixed in 11-20 are correctly excluded from that count.

**3. [Scope] No D-14 rationale comments were written**

The plan's acceptance criterion is that any *retained* trait carries a `// Serialized:` comment.
None were retained, so there is nothing to annotate. The one suite that looked like a candidate
turned out to need a fix, not a comment.

**4. [Scope] Two production files modified, which the plan did not list**

`files_modified` names only `AppPackage/Tests/DownloadsFeatureTests/`. The clock seam required
editing `DownloadClient+Manager.swift` and `DownloadClient+Persistence.swift`. The plan
anticipates this — its action step says to fix discovered shared state "at root by injection".

**5. [Scope] Two dead `import Kingfisher` lines removed**

`DownloadCoordinatorStorageTests` and `DownloadPauseAndReconcileTests` each imported Kingfisher
without referencing a single symbol from it — residue of the pre-11-20 shared-cache priming. Both
dropped while the files were already open.

## Flagged for owner review

**1. `removeCachedImages` still touches the process-shared Kingfisher cache, and now does so from
more concurrent cases.** 11-20 flagged this would come up again, and it did — but it did not turn
out to be a coupling worth a seam. The writes are keyed by per-case image URLs, and no assertion
in the target reads the shared cache (the production read path resolves `DataCache`). So it is
noise on a global, not a race. A `libraryClient: .noop` default for test-constructed coordinators
would remove the touch entirely; that is a change to every construction site in the target and was
not scoped here.

**2. `DownloadProgress.lastFlushDate` still defaults to a real `Date()`.** In
`DownloadClient+PageDownload.swift` the progress struct seeds `lastFlushDate` with `Date()`
directly, which the injected clock does not reach (it is a struct default with no access to the
coordinator). Nothing depends on it today — the one test that injects a clock supplies its own
`lastFlushDate` — but a future test that freezes the clock and drives a *full* download would see
the seed and the clock disagree. Threading `now` in would mean giving that struct an initializer
parameter, which was more than this plan needed.

**3. The frozen-clock fix removes the only coverage of the elapsed-time flush trigger.** With the
clock frozen, `progressFlushMinimumInterval` is never exercised in this test — and no other test
covers it either. It is production behaviour (the UI must refresh during a slow download even
when pages arrive faster than one batch per 0.4 s) with no assertion behind it. Now that the clock
is injectable, a test could advance it deliberately and assert the time-based flush fires; worth a
follow-up, and cheap to write against the seam this plan added.

**4. `#expect(emissionCount <= 2 + Int(ceil(Double(pageCount) / 8.0)))` hardcodes the `8`.**
`DownloadCoordinator.progressFlushPageInterval` is public and is that 8, so the expression could
reference the constant instead of restating it. Left alone: changing it is unrelated to
serialization, and the bound is now deterministic either way.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, or schema surface. T-11-24's mitigation held and did its job: the
per-suite diagnosis ran before removal, the stability runs surfaced the one piece of hidden
state-dependence, and it was resolved by injection rather than by re-adding a trait. The new
`now` parameter defaults to `{ Date() }` and no production call site overrides it, so the live
coordinator's clock is unchanged.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND, `now:` parameter and stored property present
- `AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift` — FOUND, both `Date()` reads replaced with `now()`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadObserverBatchTests.swift` — FOUND, frozen clock with rationale comment
- `AppPackage/Tests/DownloadsFeatureTests/` — FOUND, 0 matches for `.serialized`
- `.planning/phases/11-infra-refactor-lint-capstone/11-21-SUMMARY.md` — FOUND
- Commit `f6d7e5ef` — FOUND
- Commit `ffce4c1e` — FOUND
