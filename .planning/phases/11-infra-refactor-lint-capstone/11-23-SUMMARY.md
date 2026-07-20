---
phase: 11-infra-refactor-lint-capstone
plan: 23
subsystem: test-hygiene
tags: [optional-try, d-15, swift-testing, lint, downloads, test-helpers]
requires:
  - "11-22.1's repaired FeatureTests.xctestplan — the Tests/ lint gate is only trustworthy from that wave on"
  - "11-21/11-22's de-serialized, member-annotated DownloadsFeatureTests"
provides:
  - "A DownloadsFeatureTests target with zero optional-try sites (D-15)"
  - "Three documented free helpers carrying the deliberate-silence rationale: removeTemporaryItem, sleepIgnoringCancellation, requestBodyJSONObject"
  - "The finding that this target's sites are almost entirely best-effort cleanup and cancellation absorption, not hidden test defects"
affects:
  - "155 sites across 32 files; no production source touched"
  - "removeTemporaryItem moved from a protocol extension to a free function, reaching 7 non-conforming suites"
tech-stack:
  added: []
  patterns:
    - "Route a repeated deliberate-silence idiom through one documented helper rather than N inline do/catch blocks — the rationale is written once and cannot drift"
    - "Convert mechanically, then let the compiler adjudicate which sites sit in non-throwing contexts"
key-files:
  created: []
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/ (32 files)
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
decisions:
  - "The plan says 33 files; there are 32, holding 155 sites. Reported, not adjusted."
  - "Only 2 of 155 sites became plain `try`. The design intent expected plain `try` to be the majority; in this target it is not, and the reason is structural rather than a conversion shortcut — see 'Where the plan's expectation did not hold'."
  - "`removeTemporaryItem` already existed but lived in the `DownloadFeatureTestCase` protocol extension, so 7 suites could not call it. Moved to a free function next to `requestBodyData`; it was never a protocol requirement, so nothing was widened."
  - "The 129 cleanup sites route through one helper rather than 129 inline do/catch blocks — the plan explicitly sanctioned this and it keeps the silence rationale in one reviewable place."
  - "Poll loops keep their `while` predicate and only swap the sleep. Collapsing `while !Task.isCancelled { sleep(10ms) }` into a single long sleep would be behaviourally equivalent only while the task is always cancelled; keeping the loop is a zero-risk diff."
metrics:
  duration: ~20 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 23: DownloadsFeatureTests optional-try Elimination Summary

`DownloadsFeatureTests` is at **zero optional-try sites**. 155 sites across 32 files, two commits,
253 tests green, both whole-app gates clean, SwiftLint clean at `--strict` over all 56 files in the
target.

Commits: `66f17023` (cleanup routing) and `7a3842f6` (sleeps, probes, cache removals).

## Scope: 32 files / 155 sites, not the plan's 33 files

The plan gives a file count with no site count. The true figures:

| | Plan | Actual |
|---|---|---|
| Files | 33 | **32** |
| Sites | — | **155** |

Consistent with every prior wave in this phase, the plan's count drifted — this time by one file,
the mildest drift so far. The target is driven to zero; other targets are left for 11-24.

## What the 155 sites actually were

| Class | Sites | Conversion |
|---|---|---|
| `defer { try? FileManager.default.removeItem(at:) }` and pre-create stale-leftover removal | **129** | `removeTemporaryItem(at:)` |
| `try? await Task.sleep(…)` — blocker tasks and poll loops | **21** | `await sleepIgnoringCancellation(for:)` |
| `try? JSONSerialization.jsonObject(…)` inside a stub handler's `.flatMap` | **3** | `requestBodyJSONObject(from:)` |
| `try? await dataCache.removeData(forKeys:)` | **2** | plain `try` |

### Where the plan's expectation did not hold

The design intent states that **most sites become plain `try`** because Swift Testing test functions
are `throws`. In this target that is not what the sites are. **2 of 155 became plain `try` — 1.3%.**

This is not a conversion shortcut, and it is worth recording because 11-24 will meet the same
distribution in the sibling targets. `DownloadsFeatureTests` is an IO-heavy target: every case builds
a UUID-scoped temporary root and tears it down in a `defer`, and a `defer` cannot throw. 83% of the
target's sites are that single line. Another 14% are `Task.sleep` in a context where cancellation is
the *designed exit* — a `Task<Void, Never>` blocker the case cancels on purpose, or a
`while !Task.isCancelled` poll loop that must return to its predicate rather than unwind past it.
Both are the design intent's second and third cases, not its first.

So the conversion ladder was applied faithfully; this target simply sits almost entirely on the
lower two rungs. The rule is satisfied either way — no `try?` survives, and every remaining silence
is explicit and carries a written reason.

### The three helpers

Each idiom routes through one free function in `DownloadFeatureTestSupportTypes.swift`, so the
"why silence is correct here" argument is written once rather than copied 129 times:

- **`removeTemporaryItem(at:)`** — cleanup under the system temporary directory is housekeeping no
  case asserts on, and it is also called before a create to clear a stale leftover, where
  "no such file" is the norm.
- **`sleepIgnoringCancellation(for:)`** *(new)* — cancellation is the caller's exit condition,
  checked by the surrounding loop or awaited by the case that cancelled the task.
- **`requestBodyJSONObject(from:)`** *(new)* — a genuine probe. The URL-protocol stub handlers route
  on the decoded `method` field, so a body that is absent or is not JSON is a legitimate answer
  ("this is not that request"), not a failure. This preserves the probe meaning exactly.

## `removeTemporaryItem` was unreachable from 7 suites

The helper already existed — but as a member of the `DownloadFeatureTestCase` protocol extension.
Seven suites in the target (`DownloadStoreTests`, `DownloadStoreHashTests`, `DownloadQueueStoreTests`,
`DownloadStoreRepairTests`, `DownloadBackgroundTaskStoreTests`, and others) declare no conformance,
so 5 compile errors surfaced on the first build cycle.

It was never a protocol *requirement*, only a default implementation, so moving it to a free function
beside `requestBodyData` widened nothing and shrank the protocol extension. That is what made the
one-helper approach viable for all 129 sites instead of just the conforming subset.

## No hidden broken tests surfaced

The design intent's third case — a `try?` masking a test that asserts nothing, or asserts against a
state that a silent failure produced — **did not occur here.** All 253 tests passed on the first run
after each conversion batch, with no assertion touched.

That is a real result rather than an absence of effort: the 2 sites that genuinely became plain `try`
(the `dataCache.removeData` calls, which now fail the test if the removal fails) are the only ones
whose failure visibility changed, and both stayed green. The other 153 were never masking a result —
they were masking cleanup and cancellation, which is why they convert to documented silence rather
than to propagation.

## Verification

- `xcodebuild test -scheme AppPackage-Package -only-testing:DownloadsFeatureTests` —
  **253 tests in 53 suites passed**, 7.4 s test time, 22.6 s total. Run after each of the two commits.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** (21.2 s), zero warnings.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (28.5 s), zero warnings.
  This is the phase's `Tests/` lint gate and it is the repaired 18-target plan from 11-22.1.
- SwiftLint (DerivedData artifactbundle binary, `--strict`, root config) over all **56 files** in
  `AppPackage/Tests/DownloadsFeatureTests` — **0 violations, 0 serious**. All four live rules pass.
- `grep -rn "try? " AppPackage/Tests/DownloadsFeatureTests | grep -v "//"` — **0**.
- `.swiftlint.yml` untouched. No `swiftlint:disable` directive written anywhere; `optional_try`
  remains commented out and flips in 11-24.
- No `.serialized` trait restored and no `@MainActor` added at suite-type level — 11-21's and
  11-22's work is intact. `DownloadSchedulingTests`, the deterministic canary, passed every run.
- No production source touched. No assertion weakened, added or removed.
- `LINT-01` left open — it flips at 11-29.

## Deviations from Plan

**1. [Scope] Task split by conversion class, not alphabetically**

The plan splits the work as "first ~17 files" then "remaining ~16". The sites are not distributed
that way — one idiom accounts for 83% of them and spans every file. Splitting alphabetically would
have produced two commits neither of which is a coherent unit, and the first would have left the
target half-converted for no verification benefit.

Split instead by class: commit 1 is the 129 cleanup sites (one mechanical rewrite, one helper move),
commit 2 is the remaining 26 (sleeps, probes, cache removals). Each commit is independently green
under the full target suite, which is what the atomic-commit rule is protecting.

**2. [Rule 3 — Blocking issue] `removeTemporaryItem` moved out of the protocol extension**

Documented above. Required to complete Task 1 at all; 5 suites could not compile otherwise.

**3. [Scope] Two helpers added, where the plan sanctioned one**

The plan anticipated "ONE small helper … if repetition warrants" for the cleanup idiom. That helper
already existed. Two were added instead, for the sleep idiom (21 sites) and the JSON probe idiom
(3 sites), on the same reasoning the plan gives for the first: fewer lines than the inline
equivalents, and the rationale is stated once where a reviewer can find it.

The 3-site probe helper is the marginal one — 3 inline `do`/`catch` blocks would also have been
acceptable. It was folded in because the three call sites are byte-identical stub-handler
preambles across three files, so the shared function also removes a copy-paste triple.

## Flagged for owner review

**1. The plain-`try` yield in test code is far lower than D-15 anticipated, for structural reasons.**
1.3% here. 11-24 should expect the same shape in the sibling targets rather than treating a low
plain-`try` ratio as evidence of a lazy conversion. If the owner wants a higher propagation ratio,
the lever is the `defer`-teardown pattern itself — a fixture type that removes its root in `deinit`
would delete all 129 sites outright — not the conversion ladder. That is a test-architecture change
well outside this plan's scope, and it would touch every case in the target.

**2. Nothing was found to fix.** The phase has repeatedly used this conversion to surface broken
tests (11-09 found four, 11-20 found two). This target yielded none. Worth stating explicitly so the
absence is read as a checked result rather than an unchecked one.

## Exceptions recorded for 11-24

**None.** No site required a lint exception, so nothing needs a `// reason:` +
`// swiftlint:disable:next optional_try` pair when the rule flips.

## Known Stubs

None.

## Threat Flags

None. Test-only change; no production file modified, and no new network, auth, file-access or schema
surface. T-11-26's mitigation holds: no assertion was changed, added or removed, and the target suite
passed with identical assertions after each commit — verified by the unchanged 253-test count across
both runs.
