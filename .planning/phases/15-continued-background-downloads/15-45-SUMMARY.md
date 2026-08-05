---
phase: 15-continued-background-downloads
plan: 45
subsystem: downloads
tags: [swift, downloads, hygiene, dead-code, public-api, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-42/15-43 shifted `DownloadClient+ContinuedSession.swift` (+44 lines) and 15-44's read-authority docs; the WR-04 blank-line positions had to be relocated fresh against that HEAD"
  - phase: 15-continued-background-downloads
    provides: "G-15-19's probe classification (`probeAssetFile` / `AssetFileProbeOutcome`) and the licensing comment on the collapsed `Bool` forward, which is what made `isReadableAssetFile` a redundant second forward"
provides:
  - "WR-03 closed: `restoredIndices` builds from every result's index; the always-whole-array `prefix(progress.completedCount)` bound is gone"
  - "WR-04 closed: the stray blank line before the closing brace deleted in `DownloadClient+ContinuedSession.swift` and `DownloadClient+Scheduling.swift`"
  - "WR-05 closed: the unintended trailing comma removed from `clearSelectedFailedPages`' parameter list"
  - "The dead public API decided, not deferred: `validPageCount(folderURL:manifest:)` and `isReadableAssetFile(at:)` both deleted from `DownloadStore+Operations.swift`"
  - "The attributes-throw fallback pin rerouted onto `sanitizeAssetFileIfNeeded(at:)`, the surface all seven production call sites already use"
affects: [15-VERIFICATION, download-store, download-client]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Delete-by-default for a public symbol with no production caller; a kept one must carry its reason at the declaration"
    - "A test pinning behavior through a thin forwarder is rerouted onto the production surface rather than keeping the forwarder alive for the test"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift

key-decisions:
  - "15-45: `restoredIndices` drops its `prefix(progress.completedCount)` bound — proven equal to the whole array from the two writers of `completedCount`, not asserted."
  - "15-45: `validPageCount(folderURL:manifest:)` deleted outright — zero callers repo-wide, including App/, ShareExtension/, EhPandaUITests/ and AppPackage/Tests."
  - "15-45: `isReadableAssetFile(at:)` deleted rather than kept-with-a-reason — it is a bare forward to the PUBLIC `sanitizeAssetFileIfNeeded(at:)`, so remedy (a)'s precondition (a surviving public surface can drive the same staging to the same observable answer) is satisfied by the very body it forwarded to."
  - "15-45: the fallback pin is rerouted, not dropped — `testSanitizeAssetFileIfNeededDoesNotDeleteFileWhenAttributesLookupFails` keeps the same `ThrowingAttributesFileManager` staging and both assertions, and now exercises the surface production actually calls."

patterns-established:
  - "Hygiene-residue closure records its equivalence proof in the summary, not as a comment describing an absent construct"

requirements-completed: []

coverage:
  - id: D1
    description: "WR-03: `restoredIndices` builds from the whole results array; the always-whole-array prefix bound is gone with no behavior movement"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (872 tests, 0 failures)"
        status: pass
      - kind: other
        ref: "grep -c 'prefix(progress.completedCount)' AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "WR-04: the stray blank line before the closing brace deleted in both files"
    verification:
      - kind: other
        ref: "tail -n 2 of each file shows `    }` then `}` with no blank line between"
        status: pass
    human_judgment: false
  - id: D3
    description: "WR-05: the unintended trailing comma removed from `clearSelectedFailedPages`' parameter list"
    verification:
      - kind: other
        ref: "grep -c 'Int\\],$' AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift == 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "The dead public API decided: `validPageCount` and `isReadableAssetFile` deleted after a re-derived caller census"
    verification:
      - kind: other
        ref: "grep -rn --include='*.swift' 'validPageCount|isReadableAssetFile' . (excluding .build) == 0 matches"
        status: pass
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (872 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The attributes-throw → content-read fallback stays owned by a named test, rerouted onto the production surface"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift#testSanitizeAssetFileIfNeededDoesNotDeleteFileWhenAttributesLookupFails"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-08-06
status: complete
---

# Phase 15 Plan 45: G-15-25 Hygiene Group and the Dead-API Decision Summary

**Three hygiene residues closed at their roots (an always-whole-array prefix bound, two stray blank lines, one stray trailing comma) and both dead public `DownloadStore` symbols deleted, with the probe's attributes-throw fallback pin rerouted onto `sanitizeAssetFileIfNeeded(at:)` — the surface all seven production call sites already use.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-08-05T16:20:27Z
- **Completed:** 2026-08-05T16:26:37Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- **WR-03 closed with a derived equivalence, not an asserted one.** `restoredIndices` now reads `Set(progress.results.map(\.index))`.
- **WR-04 closed at both sites, located fresh.** The round-13 line numbers were stale for one of the two files, exactly as the plan anticipated.
- **WR-05 closed.** `clearSelectedFailedPages`' parameter list no longer ends in a comma — the only such occurrence in the module.
- **The dead public API decided rather than deferred a third time.** Both symbols deleted; the census was re-derived by grep at execution time and matched the round-13 record exactly.
- **The fallback pin survives, on a better surface than before.** The reroute moved the test off a forwarder with zero production callers onto the one production code actually uses.

## The WR-03 equivalence derivation

The bound removed was:

```swift
let restoredIndices = Set(
    progress.results
        .prefix(progress.completedCount)
        .map(\.index)
)
```

The rewrite is:

```swift
let restoredIndices = Set(progress.results.map(\.index))
```

`progress.completedCount` has exactly two writers in the module — the grep is closed, `grep -rn "completedCount" AppPackage/Sources/DownloadClient/` returns five lines and no other assignment:

| Site | Line | Effect | Position relative to the `restoredIndices` build (`:42`) |
|---|---|---|---|
| declaration | `+PageDownload.swift:12` | `var completedCount: Int = 0` | — |
| assignment | `+PageDownload.swift:97`, in `initializePageDownloadState` | `progress.completedCount = progress.results.count` | **upstream** — `initializePageDownloadState` is awaited at `:36-40`, immediately before |
| increment | `+PageDownload.swift:254`, in `applyPageTaskOutcome` | `progress.completedCount += 1` | **downstream** — only reachable through `processRemainingPages`, called at `:50` |

So at line 42, `completedCount == results.count` holds. The remaining question is whether `results` itself moves between the assignment at `:97` and the read at `:42`: it does not. `initializePageDownloadState`'s tail after `:97` is a `guard`, `flushManifestPageProgress(folderURL:pages:)` (which takes `progress.results` by value) and `notifyObservers()` — no write to `progress.results` — and the caller does nothing between the `await` returning and the `restoredIndices` build. `prefix(n)` where `n == count` yields the whole collection, so the two expressions produce the identical `Set`. The bound was therefore never a restriction; it read as a deliberate one, which is precisely the defect.

The derivation is recorded here rather than as a source comment on purpose: after the edit there is no non-obvious construct left in the file to explain, and a comment about a bound that is no longer written would document an absence.

## The WR-04 tails, quoted

The plan's round-13 positions were `+ContinuedSession.swift:625` and `+Scheduling.swift:370`. Located fresh at this HEAD, `+ContinuedSession.swift` had shifted to `:669` (the file is now 670 lines, a +44 shift from 15-42/15-43); `+Scheduling.swift` was still at `:370`. Both stray lines were the blank line immediately preceding the file's top-level closing brace.

`AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — before / after:

```swift
            continuedSessionSubtitle(for: pushed)
        )
    }
                        // ← deleted
}
```

```swift
            continuedSessionSubtitle(for: pushed)
        )
    }
}
```

`AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` — before / after:

```swift
        logger.notice("Download resumed, gid: \(gid, privacy: .private(mask: .hash)).")
        return .success(())
    }
                        // ← deleted
}
```

```swift
        logger.notice("Download resumed, gid: \(gid, privacy: .private(mask: .hash)).")
        return .success(())
    }
}
```

`tail -n 2` on each file now prints `    }` then `}`.

## The WR-05 parameter list, quoted

```swift
    public func clearSelectedFailedPages(
        gid: String,
        selectedPageIndices: [Int]
    ) {
```

The trailing comma after `[Int]` is gone. Nothing else in the function changed.

## The dead-API census, re-derived

`grep -rn --include='*.swift'` across the whole repository (which covers `App/`, `AppPackage/Sources`, `AppPackage/Tests`, `ShareExtension/`, `EhPandaUITests/` and `actions-tool/`), excluding `.build/`:

| Symbol | Matches before the edit | Classification |
|---|---|---|
| `validPageCount` | `DownloadStore+Operations.swift:271` | declaration only — **no caller anywhere** |
| `isReadableAssetFile` | `DownloadStore+Operations.swift:286` | declaration |
| `isReadableAssetFile` | `DownloadStoreTests.swift:311` | the single Tests caller |

No discrepancy against the round-13 record: total 3 matches, exactly the expected shape. The decision therefore proceeded.

## The per-symbol decision, with its derivation

### `validPageCount(folderURL:manifest:)` — deleted

Zero callers repo-wide. Deletion is the default for a public symbol with no production caller and there was nothing to weigh against it. Its helpers (`existingPageRelativePaths`, `validatedChildURL`, `sanitizeAssetFileIfNeeded`) all retain other callers, so the deletion left no orphan behind — the build is warning-free.

### `isReadableAssetFile(at:)` — deleted, remedy (a), pin rerouted

The decisive fact, found by reading `DownloadStore.swift` for candidate reroute targets: the function's entire body was

```swift
public func isReadableAssetFile(at url: URL) -> Bool {
    sanitizeAssetFileIfNeeded(at: url)
}
```

and `sanitizeAssetFileIfNeeded(at:)` (`DownloadStore.swift:701`) is **itself public**. `isReadableAssetFile` was therefore a thin wrapper adding nothing beyond a rename — the shape the project's global instruction explicitly forbids — over a surface that already has seven production call sites (`DownloadStore.swift:505`; `DownloadStore+Operations.swift:11, 91, 105, 280, 296, 339`).

That settles the plan's criterion for remedy (a): the precondition is "any surviving public surface can drive the staging to the same observable answer", and the surviving surface here is literally the callee the deleted forwarder returned. The reroute is strictly *more* production-shaped than the pin it replaces — before, the test drove a route no production code took; now it drives the route every production caller takes. Remedy (b), keeping the symbol with a written reason, would have required deriving that no surface can pin the behavior, and the opposite is demonstrably true.

The fallback contract itself is unchanged and still lives one level down, in `probeAssetFile(at:)`: `attributesOfItem` throwing routes to `probeAssetFileContent(at:)`, which opens the file, reads one byte, and answers `.usable` for a non-empty read — never discarding the file, because metadata never confirmed a zero-byte regular file.

### The surviving pin

`AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift#testSanitizeAssetFileIfNeededDoesNotDeleteFileWhenAttributesLookupFails`

(renamed from `testIsReadableAssetFileDoesNotDeleteFileWhenAttributesLookupFails`, so the name still names what it calls). Everything else about the test is byte-identical: the `ThrowingAttributesFileManager(failingPath:)` staging is intact, the file is still a real 3-byte JPEG header written to a temporary root, and both assertions survive —

```swift
#expect(storage.sanitizeAssetFileIfNeeded(at: fileURL))
#expect(FileManager.default.fileExists(atPath: fileURL.path))
```

— the readable-file-answers-usable assertion and the not-deleted assertion. Observed passing in the full run: `✔ Test testSanitizeAssetFileIfNeededDoesNotDeleteFileWhenAttributesLookupFails() passed after 2.679 seconds.`

## Task Commits

Each task was committed atomically:

1. **Task 1: Close WR-03, WR-04, and WR-05 at their roots** — `3f896c6d` (refactor)
2. **Task 2: Decide the dead public API and prove the whole plan green** — `a87cd1ba` (refactor)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` — WR-03: `restoredIndices` built from every result's index
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — WR-04: stray blank line before the closing brace deleted
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` — WR-04: stray blank line before the closing brace deleted
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift` — WR-05: trailing comma removed from `clearSelectedFailedPages`
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — both dead public symbols deleted (19 lines removed)
- `AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift` — the fallback pin renamed and rerouted onto `sanitizeAssetFileIfNeeded(at:)`

## Diff scope

Task 1's `git diff --stat` touched exactly the four named files and only the three named sites:

```
DownloadClient+ContinuedSession.swift    | 1 -
DownloadClient+PageDownload.swift        | 6 +-----
DownloadClient+PublicAPIHelpers.swift    | 2 +-
DownloadClient+Scheduling.swift          | 1 -
4 files changed, 2 insertions(+), 8 deletions(-)
```

Task 2's touched exactly the two named files:

```
DownloadStore+Operations.swift  | 19 -------------------
DownloadStoreTests.swift        |  4 ++--
2 files changed, 2 insertions(+), 21 deletions(-)
```

No file was deleted by either commit (`git diff --diff-filter=D` is empty).

## Decisions Made

Recorded above under "The per-symbol decision". In short: WR-03 is a proven equivalence rather than a judgment call; `validPageCount` deleted for having no caller at all; `isReadableAssetFile` deleted because remedy (a)'s precondition is satisfied by its own callee being public; the pin is rerouted onto that callee rather than retired.

## Deviations from Plan

None — plan executed exactly as written.

The plan anticipated that the WR-04 line numbers would be stale and required them to be located fresh; they were, and `+ContinuedSession.swift` had indeed shifted (625 → 669). Relocating them is the plan's instruction, not a deviation from it.

## Prohibitions checked

| Prohibition | Status |
|---|---|
| Must NOT change any observable behavior with WR-03/WR-04/WR-05 | **held** — WR-03 is a proven equivalence (both writers enumerated); WR-04/WR-05 are formatting-only; 872/872 tests pass, unchanged from 15-44's baseline |
| Must NOT silently drop the fallback behavior the one Tests caller pins | **held** — rerouted in the same commit onto `sanitizeAssetFileIfNeeded(at:)`, staging and both assertions intact, test named above and observed passing |
| Must NOT keep a dead symbol without a reason written at its declaration | **held** — neither symbol was kept; both are deleted, so the keep-with-no-recorded-why case does not arise |
| Must NOT reach for a concurrency or lint escape hatch or a SwiftLint suppression | **held** — no `swiftlint:disable`, no `@unchecked`, no `@preconcurrency`, no `try?` added; the SwiftLint build-tool plugin ran across every target during the test build with zero violations |

## Verification

- **Task 1 (build-level, as the plan specifies):** `xcodebuild build -project EhPanda.xcodeproj -scheme DownloadClient -destination 'generic/platform=iOS Simulator'` → `** BUILD SUCCEEDED ** [23.6 sec]`, zero warnings, zero errors.
- **Task 2 (the plan's single full invocation):** `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=ADE09605-…'` → `** TEST SUCCEEDED ** [86.8 sec]`, exit code 0, **872 tests across 22 test-target runs, zero `✘`**.
- **Test-count movement against the previous full run: zero.** 15-44's full run was also 872 tests; the reroute renamed a test rather than adding or removing one, so the count is unchanged as expected.
- Both deleted symbols sum to **0 matches** repo-wide after the edit.
- xcodebuild invocations never overlapped: the Task-1 module build completed before the full run started, and the full run was polled to completion (`until ! pgrep -f "xcodebuild test …"`) before any further command.

**Destination note (recurring, not a deviation):** the plan's verify block templates `name=iPhone Air`, which is ambiguous on this machine (two simulators carry that name). The concrete id `ADE09605-A44E-4F00-BE12-235970217355` was substituted; every other flag is verbatim from the plan.

## Issues Encountered

None. Two pieces of expected log noise appeared and are pre-existing environmental, not failures: `appintentsmetadataprocessor` "No AppIntents.framework dependency found" warnings, and `LLVM Profile Error: Failed to write file "default.profraw"`. Nine `withKnownIssue` expectations reported across four targets are likewise pre-existing and are reported as *passed with known issues*, not failures.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **G-15-25 is closed.** The hygiene review surface for the next verification round starts clean: no residue on the restore-accounting path (SC2) and none on the probe-fallback defence (SC3).
- **Wave 45 was the last plan of the round-14 gap closure.** Phase 15 is ready for the next verification round.
- **Still outstanding and NOT claimed by this plan:** `15-UAT.md` test 2 needs a physical-device re-run on iOS 26 covering the `.redownload` route and a `.repair` gallery in a multi-gallery queue. Per the round-13 verification it was to be run after G-15-23 landed (15-43 did that), so it is now runnable and is the remaining item between SC2 and verified.
- **Threat register:** T-15-45-01 mitigated by deletion (the collapsed-`Bool` forwarder with no production caller no longer exists to be adopted); T-15-45-02 mitigated by the rerouted named pin; T-15-45-03 mitigated by the recorded two-writer derivation plus the green suite.

## Self-Check: PASSED

All modified files exist on disk; both task commits (`3f896c6d`, `a87cd1ba`) are present in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-06*
