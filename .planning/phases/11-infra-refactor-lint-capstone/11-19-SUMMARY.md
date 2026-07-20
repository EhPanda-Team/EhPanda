---
phase: 11-infra-refactor-lint-capstone
plan: 19
subsystem: file-client
tags: [test-isolation, dependency-injection, parallel-tests, tag-translation, d-12]
requires:
  - "DownloadStore's `rootURL`-with-production-default shape (the precedent this mirrors)"
  - "11-18's four live lint rules, all satisfied by the new code"
provides:
  - "`FileClient.live(applicationSupportURL:cachesURL:)` — an injectable directory-root seam with production defaults"
  - "`TagTranslationStore` — path derivation + raw-file I/O for the cached tag-translation tables, rooted at two injected directories"
  - "A parallel `FileClientTests` with no serialization trait"
affects:
  - "`FileClient.live` is now a function, not a static property — `FileClient.live()` at the one in-module use site"
  - "Every future FileClientTests case gets its own root for free (instance-property seeding)"
tech-stack:
  added: []
  patterns:
    - "Injecting the directory root instead of serializing the suite (project's stated inject-over-serialize preference)"
    - "Seeding the per-test root as a suite instance property, since Swift Testing builds one suite instance per case"
    - "`final class` suite with `deinit` cleanup — one cleanup site instead of a `defer` in every case"
key-files:
  created: []
  modified:
    - AppPackage/Sources/FileClient/FileClient.swift
    - AppPackage/Tests/FileClientTests/FileClientTests.swift
decisions:
  - "Two roots, not one. The client writes to Application Support (custom import, not purgeable) and Caches (remote table, purgeable) — two genuinely different production directories with different semantics. Collapsing them behind a single root would have changed production behavior, which is exactly what T-11-22 forbids."
  - "`FileClient.live` became a function rather than gaining a sibling factory. A static property and a static method cannot share a name in Swift, and the only non-test use site is `FileClientKey.liveValue` in the same file — so the function-only shape costs one character at the one production call site and avoids a second spelling of the same thing."
  - "The four file-private free functions became methods on a file-private `TagTranslationStore` struct. Threading two URLs through four free functions would have added six parameters; the struct holds them once and is the same shape as `DownloadStore` (roots + path builders + I/O)."
  - "The suite is a `final class` so `deinit` can remove the root once, rather than a `struct` repeating a `defer` in all eight cases. Swift Testing builds a fresh instance per case either way, which is what makes the instance-property root unique per test."
  - "Per-test roots let three tests get simpler, not just isolated: `loadCachedTagTranslatorThrowsWhenCacheMissing` no longer has to delete a file to create the missing-cache condition, and two OpenCC parity tests no longer need a cache-URL `defer` at all."
metrics:
  duration: ~20 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 19: FileClient Injectable Root Summary

`FileClient.live` takes its two directory roots as parameters defaulting to the production
locations, and `FileClientTests` runs in parallel on per-test roots with the `.serialized` trait
and its rationale comment removed. Two commits, one per task.

## The seam

The tag-translation endpoints derived their paths from two file-private globals:

```swift
private var customTranslationsURL: URL { .applicationSupportDirectory.appending(…) }
private func remoteTranslationsURL(_ language:) -> URL { .cachesDirectory.appending(…) }
```

Those two expressions, unchanged, are now the **default arguments**:

```swift
public static func live(
    applicationSupportURL: URL = .applicationSupportDirectory,
    cachesURL: URL = .cachesDirectory
) -> Self
```

so `FileClientKey.liveValue = FileClient.live()` resolves to byte-identical paths. The four
functions that consumed the globals (`buildAndCacheTranslations`, `loadCachedTranslations`,
`removeCustomTranslationsFile`, plus the import closure's write) are now methods on a file-private
`TagTranslationStore` holding the two roots — the `DownloadStore` shape: roots, path builders,
I/O, no cross-call state.

**Two roots rather than one.** Application Support (a custom import, which cannot be
re-downloaded) and Caches (a remote table, which can) are deliberately different directories with
different purgeability. A single root would have merged them and changed where production writes,
which T-11-22 rules out.

**`live` is a function, not a property with a factory beside it.** Swift will not let a static
property and a static method share a name, and the only non-test use of `FileClient.live` in the
repo is `FileClientKey.liveValue` in the same file. So the whole cost of the seam outside tests is
one pair of parentheses. Nothing in `App`, `ShareExtension` or any other module referenced
`FileClient.live` — verified by grep across all three roots.

Method references (`store.buildAndCacheTranslations`) satisfy the `@Sendable` closure properties
directly, since `TagTranslationStore` is `Sendable` (two `URL`s). No wrapper closures needed.

## The tests

The suite is a `final class` whose `root` is an instance property:

```swift
private let root = FileManager.default.temporaryDirectory
    .appending(component: UUID().uuidString, directoryHint: .isDirectory)
```

Swift Testing builds one suite instance per test case, so a plain stored property with a `UUID()`
default *is* the per-test root — no `init` hook and no explicit setup call. `client` derives
`ApplicationSupport/` and `Caches/` subdirectories from it, and `deinit` removes the whole tree in
one place instead of a `defer` repeated across eight cases.

Neither subdirectory needs pre-creating: `writeTranslations` already calls
`createDirectory(withIntermediateDirectories: true)` on the parent, and the read paths treat an
absent file as the error they are asserting.

**Isolation made three tests smaller, not just safer:**

- `loadCachedTagTranslatorThrowsWhenCacheMissing` used to `try?`-delete the real Japanese cache
  file to manufacture the missing-cache condition. A fresh root is missing by construction, so
  the deletion is gone — and with it an `optional_try` site, ahead of 11-24.
- The two OpenCC parity tests no longer need a cache-URL `defer` at all.
- Every `defer { try? FileManager.default.removeItem(…) }` in the file is gone: eight `try?` uses
  removed, none added. The one remaining cleanup is `deinit`'s explicit `do`/`catch`.

The temporary import fixture also moved under the per-test root (it was previously a
`UUID()`-named file directly in the system temporary directory), so cleanup is a single
`removeItem` on the root.

## Proving the serialization was vestigial

The parallel-scheduling evidence is in the run log, not just the exit code — the first run shows
all eight cases *starting* before any of them finishes:

```
◇ Test importsValidTranslationFileViaCoordinatedRead() started.
◇ Test traditionalChineseAppliesOpenCCConversionAndCustomFullColor() started.
… (all 8) …
✔ Test cachesRemoteTableAndRebuildsItFromMetadata() passed after 0.008 seconds.
```

Under `.serialized` those lines interleave one-by-one. Three consecutive runs, all green:

| Run | Result | Suite wall time |
|---|---|---|
| 1 | 8 tests passed | 0.226 s |
| 2 | 8 tests passed | 0.329 s |
| 3 | 8 tests passed | 0.337 s |

Zero flakes across the three.

## Verification

- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** (23.5 s), run after Task 1.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (28.4 s), run after
  Task 2. This is the gate the app-scheme build does not give: the test target carries the
  SwiftLint plugin, and all four rules flipped in 11-11 through 11-18 pass on the rewritten file.
- `-only-testing:FileClientTests` on `AppPackage-Package` — **TEST SUCCEEDED** ×3 consecutively.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (61 s). The pre-existing `withKnownIssue`
  markers are unchanged; no target regressed.
- `grep 'FileClient.live'` across `AppPackage`, `App`, `ShareExtension` — only
  `FileClientTests.swift` matched outside the module, confirming no production call site moved.
- No `try?` introduced anywhere; eight removed from the test file.
- `LINT-01` left open — it flips at 11-29.

## Deviations from Plan

**1. [Rule 3 — Blocking] `FileClient.live` had to change from a property to a function**

- **Found during:** Task 1
- **Issue:** The plan asked for a "default parameter at init/construction" mirroring
  `DownloadStore`. `DownloadStore` is a struct with an `init`; `FileClient` is a struct of
  closures whose live instance is a `static let`, so there is no init to add parameters to.
  Keeping `static let live` alongside a `static func live(…)` is an invalid redeclaration.
- **Fix:** `static let live` became `static func live(applicationSupportURL:cachesURL:)`. The one
  in-module use site (`FileClientKey.liveValue`) gained `()`. No other module referenced it.
- **Files modified:** `AppPackage/Sources/FileClient/FileClient.swift`
- **Commit:** `7a18ec14`

**2. [Scope] The suite became a `final class`**

- **Found during:** Task 2
- **Issue:** The plan says "create in setup, remove in cleanup". A `struct` suite has no `deinit`,
  so cleanup would have been a `defer` repeated in all eight cases.
- **Fix:** `final class FileClientTests` with a single `deinit`. Swift Testing instantiates a
  suite per test case either way, so the per-test uniqueness of the root is unaffected.
- **Files modified:** `AppPackage/Tests/FileClientTests/FileClientTests.swift`
- **Commit:** `8ba33944`

## Flagged for owner review

**1. `saveTorrent` still writes a fixed real Caches path.** `FileClient.saveTorrent(hash:data:)`
builds `URL.cachesDirectory.appendingPathComponent("\(hash).torrent")` and is untouched here — it
is not one of the tag-translation cache/import endpoints this plan scoped, and it has no test that
would race. If a future plan wants it on the seam, it is an instance method on `FileClient` with
no access to the injected roots, so it would need to become a closure property like the others
(or take the root as a parameter). Not a small change; deliberately not made.

**2. `deinit` cleanup is best-effort by construction.** If a test's root removal fails, the
directory is left under the system temporary directory and the failure is swallowed — cleanup is
housekeeping, not a result the test asserts. This matches how `DownloadStore` treats its own
best-effort filesystem housekeeping. The alternative (failing a test because its temp cleanup
failed) would report a false regression.

**3. The rewrite removed the only surviving assertion that the *production* paths are the ones
used.** Every case now runs against injected roots, so nothing checks that
`.applicationSupportDirectory` / `.cachesDirectory` are the defaults — that is guaranteed only by
reading the default expressions. A test could assert it by constructing `FileClient.live()` with
no arguments and probing, but that would reintroduce writes to the real directories, which is the
coupling this plan removed. The trade is deliberate; recording it because the coverage genuinely
moved.

## Known Stubs

None.

## Threat Flags

None. No new network, auth or schema surface. T-11-22's mitigation holds: the default argument
expressions are the previous global expressions verbatim, so the live client's storage locations
are unchanged, and the only caller that could pass something else is the test file. Phase 9's
error contracts are untouched — every `AppError.fileOperationFailed` descriptor is the same fixed
string as before, and no path is disclosed in any of them.

## Self-Check: PASSED

- `AppPackage/Sources/FileClient/FileClient.swift` — FOUND, `live(applicationSupportURL:cachesURL:)` and `TagTranslationStore` present
- `AppPackage/Tests/FileClientTests/FileClientTests.swift` — FOUND, no `.serialized`, no fixed real-directory writes
- `.planning/phases/11-infra-refactor-lint-capstone/11-19-SUMMARY.md` — FOUND
- Commit `7a18ec14` — FOUND
- Commit `8ba33944` — FOUND
