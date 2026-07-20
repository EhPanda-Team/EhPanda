---
phase: 11-infra-refactor-lint-capstone
plan: 20
subsystem: test-isolation
tags: [test-isolation, dependency-injection, parallel-tests, kingfisher, sharing, d-12, d-14]
requires:
  - "11-19's injectable-root seam and its prove-it-with-repeat-runs discipline"
  - "The pre-existing `withDependencies { $0.dataCache = … }` idiom in DownloadCoordinatorCaptureTests"
provides:
  - "`expectCachedPlaceholderRejected(url:placeholderData:)` — a shared, fully-isolated cached-placeholder-rejection assertion"
  - "`removeTemporaryItem(at:)` — a `try?`-free temporary-file cleanup helper for DownloadsFeatureTests"
  - "`fixtureData(filename:)` — the `HTMLFilename` sibling of the existing `writeFixtureToTemporaryFile(filename:)`"
  - "A documented, accurate D-14 rationale on DidLoginKeyTests"
affects:
  - "`DidLoginKey.subscribe` now registers its jar subscription synchronously (production behaviour change, strictly a narrowing of a lost-notification window)"
  - "Three suites (DownloadImageParsingTests, DownloadImageParsingCacheTests, ImageClientTests) now run in parallel"
tech-stack:
  added: []
  patterns:
    - "Injecting the byte cache the production read path actually resolves, rather than priming the library cache it stopped using"
    - "Bracketing a `nil`-result assertion with pre/post cache probes so a rejection cannot be mistaken for a cache miss"
    - "Creating an AsyncStream at subscription time, not inside the consuming task, so no element is published to zero subscribers"
key-files:
  created: []
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingCacheTests.swift
    - AppPackage/Tests/ImageClientTests/ImageClientTests.swift
    - AppPackage/Tests/CookieClientTests/DidLoginKeyTests.swift
    - AppPackage/Sources/CookieClient/DidLoginKey.swift
decisions:
  - "No Kingfisher seam was added, because the production path no longer reads Kingfisher. `validatedCachedAssetData` resolves `@Dependency(\\.dataCache)`; the two suites were priming `KingfisherManager.shared.cache`, which that path stopped consulting. The plan's conditional (\"if a PRODUCTION path resolves the shared cache, add a seam\") resolved to its other branch: the correct fix was to point the tests at the cache the code actually reads."
  - "Both rejection tests were asserting the right answer for the wrong reason. Priming an unread cache meant `== nil` was a trivial miss, not a rejection. The shared helper now asserts the entry is present before the call and evicted after it, so the middle assertion has to be a real rejection to pass."
  - "The rejection assertion became one shared helper rather than two near-identical bodies in two files, and it builds its own coordinator with `libraryClient: .noop` — the eviction path's only remaining touch of the process-shared Kingfisher cache."
  - "`DidLoginKeyTests` keeps no `.serialized` trait because one was never there and one would do nothing: `.serialized` orders cases within a suite, and this suite has exactly one case. The comment says so explicitly, since the enforcement mechanism is the suite's shape."
  - "A real flake found in DidLoginKeyTests was root-caused and fixed in production rather than papered over in the test. The subscription window is the bug; a longer poll timeout would only have hidden it."
metrics:
  duration: ~35 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 20: Kingfisher Seam, Vestigial Trait, Documented Keeper Summary

Three suites lost their serialization (two by moving off the process-shared image cache, one
because its trait was vestigial), the one legitimate keeper gained an accurate rationale, and a
real flake discovered along the way was root-caused and fixed. Two commits, one per task.

## Task 1 — the two DownloadImageParsing suites

**The plan's premise did not survive contact with the code, in a way that made the fix simpler.**
The plan asked for an injectable Kingfisher `ImageCache` seam on "the production call that resolves
`KingfisherManager.shared.cache`". Tracing the tests' entry point found no such call:

```
manager.validatedCachedAssetData(for:)
  → cachedImageData(for:)        @Dependency(\.dataCache)   ← the only read
  → removeCachedImages(for:)     dataCache + libraryClient  ← only on the reject path
```

`DownloadClient+Cache.swift` reads the owned byte cache (`DataCache`, already injectable — that is
what `ImageClient.dataCache` exists for), not Kingfisher. Meanwhile both suites were priming
`KingfisherManager.shared.cache`. So the shared cache entered these suites **test-side only**, and
the plan's second branch applied: replace the shared-cache priming directly.

**This exposed a genuine bug, not just a coupling.** Both tests store a placeholder, then assert
`validatedCachedAssetData(...) == nil`. Because the primed cache was one the code no longer reads,
`nil` was a trivial cache **miss** — the rejection logic under test was never reached. Two tests
named `...PlaceholderStoredUnderNormalImageURLIsRejected` were asserting nothing about rejection.

The shared helper replacing them makes the middle assertion load-bearing by bracketing it:

```swift
try await dataCache.store(placeholderData, forKeys: cacheKeys)
#expect(await dataCache.data(forKeys: cacheKeys) == placeholderData)   // it really is cached

#expect(await manager.validatedCachedAssetData(for: [url]) == nil)     // …and refused

#expect(await dataCache.data(forKeys: cacheKeys) == nil)               // …and evicted
```

A miss now fails the first probe; a rejection that forgot to evict fails the third. Everything it
touches is per-call: a `DataCache` rooted in a `UUID()` temporary directory, injected via
`withDependencies` (the idiom `DownloadCoordinatorCaptureTests` already established), and a
coordinator built with `libraryClient: .noop` so the eviction path's one remaining Kingfisher touch
stays off the process-global too. **No production code changed for this task** — the seam it needed
already existed, which is why T-11-23 (cache-identity drift) has nothing to mitigate here.

Both suites dropped `@Suite(.serialized)`, both dropped `import Kingfisher` and `import UIKit`, and
the now-unused `waitUntilCacheReady` helper was deleted rather than left behind.

Two smaller cleanups while in the files: the timestamp-derived `gid` values used to keep cache keys
distinct became `UUID()` (a timestamp collides if two cases start in the same microsecond — which
is exactly what removing serialization makes possible), and the ten
`defer { try? FileManager.default.removeItem(…) }` sites became `defer { removeTemporaryItem(at:) }`
against a helper with an explicit `do`/`catch`. Ten `try?` uses removed ahead of 11-24, none added.

### Proving it

All twelve cases across both suites **start** before the first one finishes — the log, not just the
exit code, is what shows the scheduler really ran them concurrently:

```
◇ Test testFileBasedQuotaImageMapsToQuotaExceeded() started.
◇ Test testCachedQuotaPlaceholderStoredUnderNormalImageURLIsRejected() started.
… (all 12, lines 6085–6169) …
✔ Test testFileBasedTextImageLimitMapsToQuotaExceeded() passed …   (line 6229)
```

| Run | Result |
|---|---|
| 1 | 253 tests / 53 suites passed (5.93 s) |
| 2 | 253 tests / 53 suites passed (6.12 s) |
| 3 | 253 tests / 53 suites passed (5.82 s) |

## Task 2 — one trait removed, one documented

**`ImageClientTests`' trait was vestigial, as described.** Every case already builds its own
`makeIsolatedDataCache()` and its own `sessionID`-keyed `URLProtocol` stub, and every image
assertion already compares `cgImage?.width/height` rather than point size. Nothing shared remained,
so the trait came off with no other change. It did **not** use `DataCache.shared` anywhere — the
thing the success criteria asked to check for. Six consecutive runs, all nine cases started before
any finished.

**`DidLoginKeyTests` keeps its single-sequential shape and gained the D-14 comment.** Worth being
precise about what "keeps its trait" means here: there is no `.serialized` trait and adding one
would be theatre — `.serialized` orders cases *within* a suite, and this suite has exactly one
case. The isolation mechanism **is** the one-case shape, so the comment says that rather than
implying a trait is doing the work. It states the real reason: Sharing's reference cache is a
process-global weak table keyed by `AnyHashable(id)`, `.didLogin` has one constant id, so all
readers of it resolve to one reference that captured whichever `cookieClient` was in scope when it
was first created — a coupling inside a third-party library's global state that no injection at
this layer removes. It also records why per-test key ids are not the escape hatch (they would
dissolve the coupling and the coverage together: the point is to test the production key), and why
login and logout share one case. A future reader can tell this apart from vestigial caution.

## Deviations from Plan

**1. [Rule 1 — Bug] `DidLoginKeyTests` was flaky, and the cause was in production code**

- **Found during:** Task 2 verification. `tracksJarChangesAcrossLoginAndLogout` failed at the
  login assertion in 1 of 3, then 1 of 5 runs — with the suite taking 1.5 s instead of 0.05 s,
  the signature of `pollUntil` exhausting its full ~1 s budget.
- **Issue:** `DidLoginKey.subscribe` created its jar stream *inside* the consuming `Task`:
  ```swift
  let task = Task { for await _ in client.cookiesDidChange() { … } }
  ```
  Creating the stream is what registers the subscription, and a task body starts asynchronously.
  Between `subscribe` returning and that task running, `CookieClientTestingStore.notify()` iterates
  a subscriber dictionary that is still empty, so the yield reaches nobody and the element is gone
  — there is no buffer to catch it, because no continuation exists yet. The reader then stays
  stale until the *next* mutation, which in this test is `clearAll()` (still `false`). Hence the
  failure landing precisely on `#expect(didLogin)`.
- **Fix:** create the stream in `subscribe`, so registration is synchronous, and let the task
  consume it. Anything published after `subscribe` returns is then buffered by the `AsyncStream`
  and delivered when the task starts. One moved line plus a comment explaining why the placement
  is load-bearing.
- **Why fixed rather than deferred:** raising the poll timeout would have hidden a dropped
  notification, and this is the plan's own subject area — documenting a suite as deliberately
  isolated while leaving it flaky would have made the comment misleading.
- **Verification:** 6 consecutive runs clean, and the suite's wall time returned to ~0.05 s in
  every one (no run spent time in an exhausting poll).
- **Files modified:** `AppPackage/Sources/CookieClient/DidLoginKey.swift`
- **Commit:** `6a1c3905`

**2. [Scope] No Kingfisher `ImageCache` seam was added**

- **Found during:** Task 1
- **Issue:** The plan's primary branch assumed a production path resolves
  `KingfisherManager.shared.cache`. It does not — the read path resolves `@Dependency(\.dataCache)`.
- **Fix:** the plan's own alternative branch ("if the shared cache is only touched TEST-side,
  replace it directly with per-test isolated instances"), using the already-injectable `DataCache`.
- **Files modified:** the three DownloadsFeatureTests files only; no production change.
- **Commit:** `b67e1115`

**3. [Scope] Two shared helpers and one deletion beyond the named files**

`DownloadFeatureTestHelpers.swift` is not in the plan's `files_modified`, but both target files
call into it: it gained `expectCachedPlaceholderRejected`, `removeTemporaryItem`, and a
`fixtureData(filename:)` overload mirroring the existing `writeFixtureToTemporaryFile(filename:)`,
and lost `waitUntilCacheReady` (its only two call sites were the rewritten tests).

## Verification

- `-only-testing:DownloadsFeatureTests` — **TEST SUCCEEDED** ×3 consecutively, 253 tests each,
  with parallel overlap confirmed in the run log.
- `-only-testing:CookieClientTests -only-testing:ImageClientTests` — **TEST SUCCEEDED** ×6
  consecutively after the flake fix (×3 before it, one of which failed — see Deviation 1).
- `-only-testing:CookieClientTests` alone ×5 **before** the fix: 4 passed, 1 failed. This is what
  established the flake as real and pre-existing rather than introduced here.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (62 s). The two pre-existing `withKnownIssue`
  markers are unchanged; no target regressed.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** (21.7 s).
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (28.2 s). This is the
  gate that lints `Tests/`; all four live rules pass on the rewritten files.
- `grep KingfisherManager` across both DownloadImageParsing suites — 0 matches.
- Ten `try?` uses removed, none added.
- `LINT-01` left open — it flips at 11-29.

## Flagged for owner review

**1. The `DidLoginKey` fix narrows, but does not close, the same window in the live client.**
`CookieClient.live`'s `cookiesDidChange` also builds its `NotificationCenter` observer inside an
inner `Task`, so a jar mutation in the instant after subscription can still be missed in
production. The impact is much smaller than in the testing store — the key's `load` re-reads
`didLogin` at creation, so only a change inside that window is lost, and the next change corrects
it. Closing it properly means awaiting observer registration before the stream is considered live,
which is a change to the live client this plan did not scope.

**2. `pollUntil` in `DidLoginKeyTests` is subtly wrong and should probably be rewritten.**
`for _ in 0..<100 where !condition()` does not stop when the condition becomes true — it keeps
iterating and simply skips the sleep, so the loop always runs 100 iterations. It works, and its
~1 s bound is real, but the `where` clause reads like an early exit and is not one. Left alone
because the plan says not to change this suite's tests.

**3. `removeCachedImages` still touches the process-shared Kingfisher cache via `libraryClient`.**
The shared helper sidesteps it with `libraryClient: .noop`, but every other DownloadsFeatureTests
case that hits the eviction path uses the default `.live`. The keys are per-test, so it is a write
of a non-existent key rather than a race — but it is still a global touch, and it is the kind of
thing 11-21 will meet again across the rest of that target.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, or schema surface. T-11-23 (production image-cache identity drift via a
seam) has nothing to mitigate: no seam was added, and no production default changed. The one
production edit — `DidLoginKey.subscribe` — changes *when* a subscription is registered, not what it
is registered against or what it reads; the client it captures is unchanged.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingTests.swift` — FOUND, no `.serialized`, no `KingfisherManager`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadImageParsingCacheTests.swift` — FOUND, no `.serialized`, no `KingfisherManager`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` — FOUND, `expectCachedPlaceholderRejected` present, `waitUntilCacheReady` gone
- `AppPackage/Tests/ImageClientTests/ImageClientTests.swift` — FOUND, no `.serialized`, no `DataCache.shared`
- `AppPackage/Tests/CookieClientTests/DidLoginKeyTests.swift` — FOUND, rationale comment begins `// Serialized:`
- `AppPackage/Sources/CookieClient/DidLoginKey.swift` — FOUND, stream created in `subscribe`
- `.planning/phases/11-infra-refactor-lint-capstone/11-20-SUMMARY.md` — FOUND
- Commit `b67e1115` — FOUND
- Commit `6a1c3905` — FOUND
