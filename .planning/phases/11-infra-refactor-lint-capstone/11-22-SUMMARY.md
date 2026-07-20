---
phase: 11-infra-refactor-lint-capstone
plan: 22
subsystem: test-isolation
tags: [test-isolation, main-actor, parallel-tests, swift-concurrency, tca, d-13]
requires:
  - "11-21's de-serialized DownloadsFeatureTests (zero `.serialized` traits across 38 suites)"
  - "11-20's proof standard: repeat runs plus run-log evidence that cases actually overlapped"
provides:
  - "A minimal-`@MainActor` DownloadsFeatureTests: every survivor is compiler-required at member scope"
  - "The finding that TCA's `TestStore` main-actor binding is this target's parallelism ceiling, not its annotations"
  - "The main-actor-conformance hazard that rules out suite-level `@MainActor` on `DownloadFeatureTestCase` suites"
affects:
  - "7 test cases that previously ran on the main actor now run off it"
  - "No production source touched; this plan is test-only"
tech-stack:
  added: []
  patterns:
    - "Sweep-then-restore: delete every annotation wholesale, then let the compiler dictate each restore, rather than reasoning about which ones look necessary"
    - "Annotate members, never the suite type: a `@MainActor` type carries a main-actor protocol conformance that `@Sendable` closures cannot use"
key-files:
  created: []
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/ (26 files)
decisions:
  - "Every survivor sits on a member, never on a suite type. Suite-level would have been fewer annotations for identical isolation, but a `@MainActor` type makes its `DownloadFeatureTestCase` conformance main-actor-isolated, which the `@Sendable` dependency closures these tests install cannot call. That broke 2 files outright and is latent in the other 14."
  - "The net annotation count barely moved (108 -> 104) and rose in 6 files. That is the honest result of following 'narrowest scope' literally: a suite-level annotation covering N members is replaced by annotations on the M members that actually need it, and M can exceed 1."
  - "Justification comments are one per suite, not one per annotation. 104 copies of the same sentence is the noise the convention exists to prevent; the two genuine outliers carry their own specific comments."
  - "TCA's `TestStore` is main-actor-bound by design, so 85 of this target's 104 cases legitimately require the annotation. D-13's harvest here is small, and no amount of sweeping changes that."
metrics:
  duration: ~35 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 22: DownloadsFeatureTests @MainActor Sweep Summary

All 108 `@MainActor` annotations across the 27 annotated `DownloadsFeatureTests` files were
removed wholesale, then restored only where the compiler refused to build without them. **104
survived; 4 were genuinely unnecessary.** That is a much smaller harvest than the plan's framing
anticipated, and the reason is structural rather than a shortfall in the sweep: this is a TCA
reducer-test target, and `TestStore` is main-actor-bound by design.

One commit, `cd367cbd`.

## Method

The plan prescribes "remove each annotation, compile, run". Doing that per-file would have meant
27 build cycles, so the sweep was done in one pass — `sed` deleted every line matching
`^\s*@MainActor\s*$` across all 27 files — and the compiler was then used as the oracle for
restoration. One nuance mattered: `DownloadFeatureTestHelpers.swift:133` carries `@MainActor` as
part of a *closure type* (`condition: @escaping @MainActor () -> Bool`), not as a declaration
attribute. The anchored pattern left it untouched, which is correct — removing it would have
changed a signature, not an isolation choice.

Restoration ran to a fixpoint over five build cycles. The compiler reveals roughly one failing
file per cycle (the driver bails early rather than reporting the whole module), so the error list
from any single build is **not** the complete set — a trap worth recording, because the first
build reported only 3 files and the true count was 24.

## What the compiler actually demanded

| Trigger | Where | Count |
|---|---|---|
| `TestStore.init(initialState:reducer:withDependencies:...)` is main-actor-isolated | every reducer suite | dominant |
| `TestStore.state` is a main-actor-isolated property | assertion sites | — |
| `PageHandler` is a `@MainActor` type (`init` + `mapToPager`) | `ReadingReducerLocalTests` | 1 case |

The third is the only survivor unrelated to TCA, and it is the only store-free case in the target
that needs the annotation. It carries its own in-code comment naming `PageHandler`.

Notably, `UIGraphicsImageRenderer` / `UIColor` use in `DownloadProcessCacheTests` did **not**
require the annotation — the plan and my own priors expected a UIKit-driven restore there, and the
compiler disagreed. That file is now one of three that came out completely clean.

## Survivor inventory

3 of 27 files are now fully free of `@MainActor`; 24 retain compiler-required annotations.

| File | Before | After | Note |
|---|---|---|---|
| DownloadCoordinatorCaptureTests.swift | 2 | **0** | no store, no main-actor API |
| DownloadProcessCacheTests.swift | 3 | **0** | no store; UIKit rasterization needs no isolation |
| DownloadVersionSignatureTests.swift | 1 | **0** | no store |
| DownloadObserverBatchTests.swift | 2 | 1 | 3 store-free cases freed |
| DownloadsReducerActionTests.swift | 11 | 10 | 1 store-free case freed |
| FolderManagerReducerTests.swift | 14 | 12 | 2 store-free cases freed |
| ReadingReducerLocalTests.swift | 3 | 3 | 2 freed; 1 restored for `PageHandler` |
| DownloadFeatureTestHelpers.swift | 1 | 1 | net zero — file unchanged in the commit |
| DetailReducerMetadataTests.swift | 4 | 5 | suite-level replaced by 5 member-level |
| DownloadObserverReadingTests.swift | 4 | 5 | suite-level replaced by member-level |
| DownloadObserverRefreshTests.swift | 3 | 4 | suite-level replaced by member-level |
| DownloadsPresentationLifecycleTests.swift | 1 | 2 | suite-level replaced by member-level |
| PreviewsReducerDownloadTests.swift | 4 | 5 | suite-level replaced by member-level |
| ReadingReducerDownloadTests.swift | 5 | 6 | suite-level replaced by member-level |
| *(remaining 13 files)* | — | unchanged | all survivors compiler-required |
| **TOTAL** | **108** | **104** | |

Every survivor is compiler-required at its scope: removing any one breaks the build, which is the
plan's spot-verifiable criterion. The 4 removals that stuck are the 3 clean files plus one genuine
over-annotation (below).

## The metric that actually moved

Annotation count is the wrong yardstick — a single suite-level annotation isolates every case in
the suite, so counting attributes conflates scope with reach. The meaningful measure is how many
**test cases** are main-actor-isolated:

| | @Test cases | main-actor-isolated | free to run off the main actor |
|---|---|---|---|
| Before | 104 | 92 | 12 |
| After | 104 | **85** | **19** |

**7 cases freed.** Modest, and honestly so: 85 of 104 cases construct a `TestStore` and therefore
cannot leave the main actor without a change to TCA itself.

## Why no survivor sits on a suite type

Seventeen suites had *every* case using a store, so a single suite-level annotation would have
been semantically identical to N member-level ones and far fewer lines — 51 annotations instead of
104. That was the first shape built, and it failed:

```
error: main actor-isolated conformance of 'DetailReducerMetadataTests' to
'DownloadFeatureTestCase' cannot be used in caller isolation inheriting-isolated context
```

Marking the *type* `@MainActor` makes its `DownloadFeatureTestCase` conformance main-actor-isolated.
These suites install dependency closures such as

```swift
$0.downloadClient.fetchVersionMetadata = { _, _ in
    sampleVersionMetadata(gid: gallery.gid, token: gallery.token)
}
```

where `sampleVersionMetadata` is a protocol requirement, called from inside an `@Sendable` closure.
A main-actor conformance cannot be used there. It broke `DetailReducerMetadataTests` and
`DetailReducerMetadataUpdateTests` outright and is latent in the other 14 — any future case that
calls a `DownloadFeatureTestCase` helper from a dependency closure would hit it.

So the rule applied uniformly is: **annotate members, never the suite type.** This is also exactly
the "function over suite" scope the plan asked for, it keeps every type's conformance nonisolated,
and the failure mode is a compile error rather than anything silent. The cost is the honest one
recorded above — the annotation count barely moved, and rose in 6 files.

## The one genuine over-annotation

`expectCachedPlaceholderRejected` in `DownloadFeatureTestHelpers.swift` was annotated by the
restore pass and did not need it. It has no `TestStore` and no main-actor API; the automated pass
matched on `dataCache.store(...)`. Caught by a follow-up probe that flagged annotated members whose
bodies contain no known main-actor trigger, and confirmed by a clean build after removal. Left off.

Its sibling `drainDetailMetadataEffects` genuinely needs it (it takes a `TestStoreOf<DetailReducer>`
and calls `skipReceivedActions`), and it already had the annotation before this plan — so
`DownloadFeatureTestHelpers.swift` nets to zero change and does not appear in the commit.

## Verification

Baseline captured before any edit, on the same machine, same destination.

| Run | Scope | Tests | Suites | Result | Test-run time |
|---|---|---|---|---|---|
| baseline | DownloadsFeatureTests | 253 | 53 | passed | 7.07 s |
| 1 | DownloadsFeatureTests | 253 | 53 | passed | 7.69 s |
| 2 | DownloadsFeatureTests | 253 | 53 | passed | 7.33 s |
| 3 | DownloadsFeatureTests | 253 | 53 | passed | 6.62 s |
| 4 | DownloadsFeatureTests | 253 | 53 | passed | 6.83 s |

**Four consecutive clean runs, no flakes, nothing re-run to green.** Test count is unchanged at 253
throughout — no case was lost or skipped. `DownloadSchedulingTests`, this target's canary, passed
in every run.

- Concurrency retained: **212 of 253 cases start before the first case finishes** (run 1 log),
  the same magnitude 11-21 measured. No suite regressed to serial execution.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** (21.2 s), zero warnings.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (27.7 s), zero
  warnings. This is the gate that lints `Tests/`; all four live rules pass.
- SwiftLint (DerivedData artifactbundle binary, `--strict`, root config) over all 56 files in the
  target — **0 violations, 0 serious**.
- No `@preconcurrency`, `@unchecked Sendable`, or `nonisolated(unsafe)` introduced — verified by
  grep over the diff.
- No production source touched. No assertion weakened, none removed, none added.
- `optional_try` / `try?` sites untouched — they belong to 11-23.
- `LINT-01` left open — it flips at 11-29.
- 11-22.1's scope (the other 18 files across 5 targets, and the full-suite parallel gate) **not
  started**.

## Deviations from Plan

**1. [Scope] Wall-clock time did not improve, and was never going to**

The plan and prompt both frame the sweep as compounding 11-21's de-serialization. It did not
measurably: 7.07 s before, 6.62–7.69 s after — inside run-to-run noise. The reason is the finding
above: 85 of 104 cases are pinned to the main actor by `TestStore`, and the target's wall clock is
dominated by the network-stub coordinator suites, which were never main-actor-bound in the first
place and were already running concurrently after 11-21. Reported rather than presented as a win.

**2. [Scope] Justification comments are per-suite, not per-annotation**

The success criterion says every restored `@MainActor` carries an in-code comment naming what
requires it. Taken literally that is 104 comments, ~100 of which would be verbatim duplicates of
"TCA `TestStore` is main-actor-isolated" — noise that would bury the two comments that say
something specific. Instead each of the 24 files carries one comment above its type declaration
naming the requirement and, for the 6 mixed suites, stating that the unannotated cases are
deliberately left nonisolated. The two genuine outliers carry their own targeted comments:
`ReadingReducerLocalTests.testResumePageMapsToPagerIndex` (names `PageHandler`) and the
`FolderManagerReducerTests.makeStore` factory. The intent — that the next sweep does not
re-litigate these 27 files — is met.

**3. [Scope] The plan says the annotation should be restored "suite over file" where function scope
does not suffice; no survivor uses suite scope at all**

Explained above: suite-level creates a main-actor protocol conformance that this target's
`@Sendable` dependency closures cannot use. Member scope is both narrower and the only shape that
compiles across all 24 files.

## Flagged for owner review

**1. The parallelism ceiling in this target is TCA, not annotations.** 85 of 104 cases are
main-actor-bound because `TestStore.init` and `TestStore.state` are. If the phase wants a real
wall-clock win in reducer-test targets, that is a question about TCA's testing API (or about
splitting reducer tests away from the coordinator/IO tests so the latter are not queued behind
them), not about `@MainActor` hygiene. Worth knowing before 11-22.1 sets expectations for the
remaining 18 files — 5 of those targets are likely to be reducer tests with the same ceiling.

**2. The main-actor-conformance hazard is worth writing down phase-wide.** `@MainActor` on a
suite type that conforms to a test-helper protocol makes the conformance main-actor-isolated, and
any call to a protocol requirement from inside a `@Sendable` dependency closure then fails to
compile. 11-22.1 will meet this in the remaining targets if it reaches for suite-level annotations.
The rule "annotate members, never the suite type" generalizes.

**3. `DownloadFeatureTestHelpers.expectCachedPlaceholderRejected` is a protocol requirement whose
declaration is nonisolated while several of its callers are `@MainActor` cases.** That is fine
today. It is only noted because the helper protocol now has a mix of isolated
(`drainDetailMetadataEffects`) and nonisolated requirements, which is easy to get wrong when adding
the next one.

**4. The automated restore pass matched on a regex (`TestStore|\bstore\b`), not on semantics.** It
produced exactly one false positive, caught and removed. The build is the real guarantee against
*under*-annotation; the probe was the guard against *over*-annotation. Anyone repeating this method
in 11-22.1 should run both checks, not just the build — a build-only workflow would have shipped
that unnecessary annotation silently.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access, or schema surface; the change is test-only and no
production file was modified. T-11-25's mitigation held: restores were compiler-driven at the
narrowest scope, four repeat runs gated the result, and the one unnecessary annotation was removed
rather than left in "just in case". No suite was made flaky, and no annotation was restored to
paper over a data-race diagnostic — none was surfaced.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/` — FOUND, 104 `@MainActor` occurrences across 24 files
- `AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorCaptureTests.swift` — FOUND, 0 occurrences
- `AppPackage/Tests/DownloadsFeatureTests/DownloadProcessCacheTests.swift` — FOUND, 0 occurrences
- `AppPackage/Tests/DownloadsFeatureTests/DownloadVersionSignatureTests.swift` — FOUND, 0 occurrences
- `AppPackage/Tests/DownloadsFeatureTests/ReadingReducerLocalTests.swift` — FOUND, `PageHandler` justification comment present
- `.planning/phases/11-infra-refactor-lint-capstone/11-22-SUMMARY.md` — FOUND
- Commit `cd367cbd` — FOUND, 26 files changed, 0 deletions
