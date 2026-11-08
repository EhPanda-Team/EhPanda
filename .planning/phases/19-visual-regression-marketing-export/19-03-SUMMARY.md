---
phase: 19-visual-regression-marketing-export
plan: "03"
subsystem: testing
tags: [live-check, network-guard, ci, probe, xctest]

requires:
  - phase: 19-01
    provides: "The phase's test plan conventions and the one-xcodebuild-at-a-time host rule"
provides:
  - "`LiveCheckTests`, the only package test target without `TestNetworkGuard`, declared through `liveCheckTestTarget` in `Package.swift`"
  - "`LiveCheckGate.requireOptIn()`: every live test skips unless `EHPANDA_LIVE_CHECK=1`"
  - "`PageObservation`: status and `cf-mitigated` from `URLSessionTaskMetrics`, one ephemeral session per page, GET only"
  - "`RunnerProbeTests` (three guest GETs, 5 s apart) and the four-field `probe.json`"
  - "`LiveCheck.xctestplan` in the `EhPanda` scheme, `Scripts/live-check/test_network_guard.py`, `.github/workflows/runner-probe.yml`"
  - "`19-03-PROBE.md`: local and hosted runs, Verdict: reachable"
affects: [19-04, 19-14, 19-15]

actuals:
  tokens: 90000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "A live test target is the single named exception to the network guard, and a script test checks both directions"
    - "A live session refuses any request that is not a GET before it leaves the process"

key-files:
  created:
    - AppPackage/Tests/LiveCheckTests/.swiftlint.yml
    - AppPackage/Tests/LiveCheckTests/LiveCheckGate.swift
    - AppPackage/Tests/LiveCheckTests/PageObservation.swift
    - AppPackage/Tests/LiveCheckTests/ProbeReportTests.swift
    - AppPackage/Tests/LiveCheckTests/RunnerProbeTests.swift
    - AppPackage/Tests/LiveCheck.xctestplan
    - Scripts/live-check/test_network_guard.py
    - .github/workflows/runner-probe.yml
    - .planning/phases/19-visual-regression-marketing-export/19-03-PROBE.md
  modified:
    - AppPackage/Package.swift
    - EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme

key-decisions:
  - "The two list pages (front page, Popular) use the app's URL builders and list parser over a plain GET, not `FrontPageGalleriesRequest` / `PopularGalleriesRequest`: those request types also send the gdata title query, a POST, which D-21 forbids. The gallery page goes through `GalleryDetailRequest`."
  - "The probe records and does not judge: a block is written to `probe.json`, the test does not fail on it."
  - "`runner-probe.yml` keeps the full xcodebuild log on the runner (a failed request's console line carries its URL and the repository's logs are public); it prints only counts, verdicts and error lines, and uploads only `probe.json`. The job reads `actions` to print the runner name, image and group for 19-04."
  - "Hosted verdict `reachable` (owner msg 2397, run 42433098473): OQ-3 is not asked; 19-15 can choose the hosted runner on this evidence."

patterns-established:
  - "Live outputs carry only fixed fields; a test with a title-like value proves it never reaches the file"

requirements-completed: []

coverage:
  - id: D1
    description: "The guard-free target, inert by default, and the guard check in both directions"
    requirement: VIS-19-01
    verification:
      - kind: unit
        ref: "python3 -m unittest discover -s Scripts/live-check -p 'test_network_guard.py' (6 tests, OK)"
        status: pass
      - kind: integration
        ref: "xcodebuild test -testPlan LiveCheck on $PHONE without the opt-in: every live test skipped, TEST SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D2
    description: "Local probe from a residential address: three pages 200, no challenge, parsed"
    requirement: VIS-19-01
    verification:
      - kind: integration
        ref: "19-03-PROBE.md local run, 2026-11-07 13:52 UTC: 5 executed, 0 failures"
        status: pass
    human_judgment: false
  - id: D3
    description: "Hosted probe on the xcode-27 runner after the owner's go-ahead"
    requirement: VIS-19-01
    verification:
      - kind: integration
        ref: "run 42433098473 on xcode-27-arm64 20261104.0337.1: three pages 200, cfMitigated false, parsed; Verdict: reachable"
        status: pass
      - kind: manual
        ref: "owner msg 2397 (answer to card msg 2246) authorised the ci/runner-probe push and its deletion"
        status: pass
    human_judgment: true

duration: two sessions (the hosted run waited for the owner)
completed: 2026-11-08
status: complete
---

# Phase 19 Plan 03: Guard-free live-check target and runner-IP probe Summary

**`LiveCheckTests` is the only package test target without the network guard, skips unless opted in, and its
three-GET probe found GitHub's hosted `xcode-27` Mac able to read the front page, Popular and one gallery as a guest
with no Cloudflare challenge. Verdict: reachable.**

## Performance

- **Tasks:** 3 (Task 3 was the owner checkpoint; the hosted run and its record were done by the parent agent)
- **Files:** 9 created, 2 modified

## Accomplishments

- **The live target** (Task 1). `liveCheckTestTarget` beside `testTarget(module:)` declares `LiveCheckTests` without
  `TestNetworkGuard`, commented as the only exception. `test_network_guard.py` fails if the live target gains the
  guard or if any other test target stops going through `testTarget(module:)`. `PageObservation` reads status and
  `cf-mitigated` from the metrics transaction and ignores every other header; each page has its own ephemeral
  session (no cookies, no cache) that refuses any non-GET request offline. `ProbeReportTests` prove that a
  title-like header and the gallery ID stay out of `probe.json`, and that a non-GET request is refused.
- **The local probe and the workflow** (Task 2). Locally all three pages answered 200 with no challenge and parsed.
  `runner-probe.yml` runs on a push to `ci/runner-probe` on `xcode-27`, uploads only `probe.json`, and writes the
  runner name, image version and runner group to the job summary.
- **The hosted probe** (Task 3). Owner msg 2397 allowed the push. Run 42433098473 (runner `GitHub Actions
  1000000629`, image `xcode-27-arm64` `20261104.0337.1`): frontPage, popular and gallery each 200, `cfMitigated`
  false, parsed. The remote branch `ci/runner-probe` was deleted afterwards under the same go-ahead.

| Run | frontPage | popular | gallery | Verdict |
|-----|-----------|---------|---------|---------|
| Local (residential) | 200, parsed | 200, parsed | 200, parsed | — |
| Hosted `xcode-27` | 200, parsed | 200, parsed | 200, parsed | reachable |

- **Verification:**
  - `test_network_guard.py`: 6 tests, OK (re-run 2026-11-08 at this summary).
  - Opt-out `LiveCheck` run: every live test skipped, TEST SUCCEEDED. Opted-in local and hosted runs: 5 executed,
    0 failures.
  - SwiftLint (strict, no cache) on `AppPackage/Tests/LiveCheckTests`: 0 violations.
  - `FeatureTests.xctestplan` does not list `LiveCheckTests`; `runner-probe.yml` has no `xcresult`.

## Task Commits

1. **Task 1: The guard-free LiveCheckTests target and the probe** - `e62bd2456` (test)
2. **Task 2: Local probe run and the probe workflow** - `c8b28e3fd` (test)
3. **Task 3: Owner go-ahead, hosted probe run and record** - `8dbf5d0c2` (docs, by the parent agent); the probe
   commit itself (`23ce9a0b9`, `[skip test]`) lived only on the deleted `ci/runner-probe` branch

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **The list pages do not go through `FrontPageGalleriesRequest` and `PopularGalleriesRequest`.** Those request
   types also send the gdata title query as a POST, which the plan's prohibition (D-21) forbids. The probe uses the
   app's URL builders and list parser over a plain GET; the gallery page uses `GalleryDetailRequest` as planned.
2. **`grep -n "POST\|httpMethod" AppPackage/Tests/LiveCheckTests` is not empty.** The matches are the GET-only
   refusal in `PageObservation` (`request.httpMethod`), the test that proves it (a `PUT`), and doc comments that say
   why no POST is sent. No request in the target sets a method other than GET. (19-14's uncommitted files add one
   more match of the same kind: a stub that records request methods.)
3. **Task 3 was carried out by the parent agent**, who held the owner's answer; this summary records its result.

## Issues Encountered

- One hosted run is one sample. 19-14's daily check keeps recording `cf-mitigated`, so a later block shows up there.
- The hosted run spent most of its 10 min 44 s installing the iOS platform; 19-04 and 19-15 should budget for it.

## User Setup Required

None.

## Next Phase Readiness

- 19-14 extends `LiveCheckTests` (gate, observation, ephemeral GET-only sessions).
- 19-15 can pick the hosted runner for the daily check; OQ-3 is not needed.
- 19-04 has the runner name, image version and group for its R-1 check.
- VIS-19-01 stays Pending (19-14 and 19-15 share it).
