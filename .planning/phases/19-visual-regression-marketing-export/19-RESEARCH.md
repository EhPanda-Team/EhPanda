# Phase 19: Visual Regression & Daily Live-Parsing Check - Research

**Researched:** 2026-11-07 (inline; the plan-phase roles were run in one session because subagents were not
available)
**Domain:** app-hosted SwiftUI snapshot capture with swift-snapshot-testing 1.19.6, XCTest parallel simulator
clones, sharded GitHub-hosted macOS CI, a separate public baseline repository, and a read-only scheduled check of the
app's parsers against the live site.
**Confidence:** HIGH for the capture path (spike data) and the code map. MEDIUM for hosted-runner speed and clone
count (not yet measured; plan 19-04). MEDIUM for the Cloudflare question (OQ-6; only the probe can answer it).

## User Constraints (from 19-CONTEXT.md)

These are binding; the CONTEXT wins on any difference.

- One picture of every screen and state (D-03, D-12: about 136 scenarios) across six languages × iPhone and iPad ×
  portrait and landscape × light and dark × xSmall, Large and AX5 (D-04): 144 coordinates per scenario, about 19,584
  pictures. Every coordinate ends as captured, failed, or not applicable with a written reason (D-04, D-05).
- States the library cannot render are skipped and recorded, never captured another way (D-05).
- Public synthetic fixtures only (D-06). Capture is Path B (D-08): the real view and reducer hosted in the app-hosted
  test's key window, settled for at least 500 ms, drawn with `window.drawHierarchy(afterScreenUpdates: true)` and
  compared with the library's image diffing, never recording outside an explicit candidate run. 1x, precision 0.9999,
  perceptual precision 1 (D-10).
- Serial capture per simulator clone, several clones per job, several jobs at once (D-11, D-15). One `xcodebuild` per
  host (D-15; TESTING.md).
- Baselines in the new public repository `EhPanda-Team/ehpanda-snapshot`, created at execution with the owner's own
  sign-in; every push needs the owner's go-ahead; fingerprints and manifest committed in the app repository (D-14).
- 20 shards, 5 at a time, per-picture retry, per-shard re-run, fail-fast off, an aggregate job, per-shard timeouts,
  deterministic cost-balanced assignment (D-15 amendment, owner msg 2263).
- Gate on every PR and release; dependency PRs wait; superseded runs cancelled; 2-day limit (D-16). One owner
  approval, after agents pre-check every picture (D-17); planning default for the review: the short packet (OQ-4).
- Static offline report; controlled regression proven red then green (D-18). Native visual policy XCUITests in the
  gate as their own job (D-19).
- Daily live check: guest, GET only (D-21 as narrowed at planning), app's own request types and parsers, one issue
  per page that closes itself, no content in issues or logs, "could not reach" kept apart from parser failures,
  signed-in pages on saved fixtures (D-20 to D-24). The runner-IP probe runs first, after the owner's OK (D-25,
  OQ-6); the final runner is chosen after the probe.

### Claude's Discretion (from CONTEXT)

Scenario layout and naming, how a scenario declares its state, shard boundaries, whether orientation, text size and
appearance change in process or per configuration (language changes per process), the iPad model, manifest and report
formats, the live check's schedule time, pacing and issue wording.

### Deferred (out of scope)

Marketing pictures of any kind (dropped, owner msg 1949); the signed-in live check until the owner supplies a secret
(D-24); native tag management (TAG-01, TAG-02).

## 1. Summary

The spike settled the hard question: hosting the real view in the app's key window and drawing the window renders
everything the app uses (Liquid Glass, materials, menus, alerts, sheets, dialogs, the soft scroll edge), reproducibly
at 1x. What is left is engineering at scale: turning the throwaway spike helpers into a committed capture core,
declaring about 136 scenarios with their not-applicable rules, splitting 19,584 pictures over 20 hosted shards with
parallel clones, keeping 5 to 10 GB of approved pictures in a separate repository, and making a failure cheap and
legible (picture change versus infrastructure error).

The live check is small by comparison but has two traps: every package test target links a network guard that fails
any real request (18-UAT), and scheduled workflows run only from the default branch. The check therefore gets its own
test target without the guard, behind an explicit opt-in variable, and must be runnable on demand (push trigger and a
local script) before it ever reaches `main`.

## 2. Code map (current tree)

| Area | Where | Notes |
|---|---|---|
| Snapshot dependency | `AppPackage/Package.swift` (`swift-snapshot-testing` exact 1.19.6), module `VisualSnapshotSupport` | test-only; the Release scan (`Scripts/visual/verify-release.py`) proves no SnapshotTesting linkage |
| App-hosted test target | `VisualSnapshotTests` (Xcode target `A17000000000000000000006`, hosted by `EhPanda.app`), `AppPackage/Tests/VisualTests.xctestplan` | sets `EHPANDA_UITEST_STUB_NETWORK=1`, `EHPANDA_VISUAL_TEST_HOST=1`; `UITestAutomation.prepareIfNeeded()` in `setUp` |
| Phase 17 tracer | `VisualTracerTests`, `VisualMatrixTests` (one coordinate per process from `EHPANDA_VISUAL_COORDINATE`), `Resources/scenarios.json` (only `home-populated`) | `MatrixCoordinate.key` = `scenario__locale__size__orientation__family__theme`; consumers: `FixtureArtwork.export`, `Scripts/visual/contracts.py`, `run-regression.py`, `test_contracts.py` |
| Fixtures | `PublicVisualFixtures` (fixed date `1_735_689_600`, IDs `home-finite`, `comments-finite`, `downloads-finite`, `reader-vertical-finite`), `FixtureArtwork` | synthetic, publishable (CAP-17-03) |
| Environment pin | `Scripts/visual/regression-environment.json`, `Scripts/visual/environment.py` | iPhone Air and iPad Pro 11-inch (M5) (`iPad-Pro-11-inch-M5-12GB`), iOS 27.0, geometry per orientation, `reduceMotionEnabled: true` (freezes the Home card's Metal gradient) |
| Spike (throwaway, uncommitted) | `.airbuild/worktree/snap-spike`, `AppPackage/Tests/VisualSnapshotTests/HostedSnapshotSpikeTests.swift` | `host(_:variant:in:)` (sets `window.rootViewController` to a `UIHostingController` with animations disabled, trait overrides for style and size), `settle(_:)` (1x reads every 100 ms until identical for ≥ 500 ms, max 40 samples), `capture(_:scale:)` (`UIGraphicsImageRenderer`, opaque, `drawHierarchy(in:afterScreenUpdates: true)`); dependencies `context = .preview`, `cookieClient = .previewLoggedIn`, fixed date, incrementing UUIDs |
| Network guard | `AppPackage/Sources/TestNetworkGuard/TestNetworkGuard.m`, linked into every package test target by `testTarget(module:)` in `Package.swift` | fails every non-loopback request offline; the live check must not link it |
| Request types (live check) | `NetworkingFeature/Request+Gallery.swift` (`FrontPageGalleriesRequest`, `SearchGalleriesRequest`, `PopularGalleriesRequest`, `ToplistsGalleriesRequest`), `Request+Detail.swift` (`GalleryDetailRequest`, `GalleryPreviewURLsRequest`), `Request+Image.swift` (`ThumbnailURLsRequest`, `GalleryNormalImageURLsRequest`, `DataRequest`), `Request.swift` (`TagTranslatorRequest`), `Request+Report.swift` (`ReportFormRequest`) | all take a `urlSession`; all GET. POST types: `Request+GData.swift` (gdata), `GalleryMPVImageURLRequest` (imagedispatch), every `Request+Account.swift` write, `SendReportRequest` |
| Reachability signals | `isCloudflareChallenge(_:)` (`Request.swift`: 403 + `cf-mitigated: challenge`), `AppError.ipBanned`, `.networkingFailed`, `.parseFailed` | the request types return parsed values, not responses: status and headers come from a session delegate (§7) |
| Workflows | `.github/workflows/test.yml` (on push, `runs-on: xcode-27`, `[skip test]` opt-out, FeatureTests on iPhone Air ~26 min), `deploy.yml` (on PR to `main` closed+merged), `deploy-pre-release.yml`, `dependencies.yml` (weekly, PR via `peter-evans/create-pull-request` with the default token), `.github/dependabot.yml` (actions, weekly, to `main`) | the repository is public; default branch `main` |
| Native policy UI tests | none yet (`NativeVisualPolicyUITests` was planned in 17-09-T2, never written); `EhPandaUITests/Support/LocalizedLaunch.swift` passes `-UIPreferredContentSizeCategoryName` | UITests plan: `UITests.xctestplan` |

## 3. Capture core (Path B, from the spike)

- **Measured (D-09):** 25 cases × 3 scales; at 1x 0 mismatches in 75 compares at exact precision; at 3x one glass case
  flaked, absorbed by precision 0.9999 / perceptual 1, which still fails a deliberate 1-point shift. Median 1.18 s
  per picture including settle. iPhone Air 1x is 420 × 912 px; median about 120 KB, real screens 46 to 374 KB, AX5
  about 2.5× default. iPad not measured.
- **Port, do not copy:** the spike file is throwaway (header says "Not for commit"). Its three helpers become
  committed API in `VisualSnapshotSupport` (`HostedWindowCapture`), with the 500 ms rule, the 40-sample cap and a
  timeout status instead of a silent `-1`.
- **Comparison:** the library's `Diffing<UIImage>.image(precision: 0.9999, perceptualPrecision: 1, scale: 1)` on
  a reference read from the fetched baseline slice. The test code never writes into the reference directory; in
  candidate mode it writes PNGs (the library's `toData`) into the run's output directory only. A test proves the
  reference directory is byte-identical after a compare run (the "never record" proof).
- **Axes:**
  - *Language:* per process (CONTEXT). Test-plan configurations carry `-AppleLanguages (xx)` and `-AppleLocale`
    arguments, as Phase 17's runner did through the xctestrun (`run-regression.py` line 66).
  - *Text size:* per process too, through the same configuration's `-UIPreferredContentSizeCategoryName` argument
    (the UITests' existing mechanism). This sets the application-wide category, so UIKit pieces that read
    `UIApplication.preferredContentSizeCategory` agree with SwiftUI; the spike's trait override alone would not
    guarantee that. 6 languages × 3 sizes = **18 configurations** named `<locale>-<size>` (for example
    `zh-Hant-accessibility5`).
  - *Orientation:* in process, `UIWindowScene.requestGeometryUpdate(.iOS(interfaceOrientations:))`, then wait for the
    scene's geometry to match the pinned geometry in `regression-environment.json` (points, safe-area insets, size
    classes). Plan 19-01 proves it on both devices before anything depends on it; if the scene does not rotate in an
    app-hosted test, the plan stops and reports options (technical call for the developer, owner tagged).
  - *Appearance:* in process, `window.overrideUserInterfaceStyle`.
  - *Scale:* the renderer format's scale is 1, independent of the device's native scale.
- **Determinism:** fixed date, incrementing UUIDs, `TimeZone(secondsFromGMT: 0)`, animations off,
  `context = .preview`, Reduce Motion on (pinned; asserted with `UIAccessibility.isReduceMotionEnabled` in every
  clone, and set on the source simulator before cloning), the Kingfisher memory cache filled from fixture artwork
  before hosting.
- **Retry once (D-15 amendment):** a picture that differs or whose settle wait times out is re-hosted, re-settled,
  re-captured and compared once more. Second pass equal → `passed` with `flaky: true` in the flake log; otherwise
  `changed` (or `timeout`).

## 4. XCTest parallel clones and test layout

- `xcodebuild test-without-building -xctestrun <file> -destination <one simulator> -parallel-testing-enabled YES
  -parallel-testing-worker-count N -only-test-configuration <name> …` clones the destination N times and hands **test
  classes** to the clones. One class at a time per clone, so per-clone capture is serial by construction; no
  `.serialized` trait and no `swiftlint:disable` is needed (XCTest, not Swift Testing). D-11's approval still covers
  the serial-per-clone behaviour and is cited in a comment above the matrix base class; the AGENTS rule against
  single-worker caps is respected because N ≥ 2.
- **Granularity:** one XCTest class per scenario group (D-12 has 20 groups; groups over 10 scenarios split in two),
  one test method per scenario, and each method captures its 4 in-process coordinates (2 orientations × 2
  appearances) for the current configuration. A method therefore costs 4 to 10 s; a class 10 to 150 s.
- **Environment to the test host:** `TEST_RUNNER_`-prefixed variables set on the `xcodebuild` process reach the
  test host: `EHPANDA_SNAPSHOT_MODE` (`compare` | `candidate`), `EHPANDA_SNAPSHOT_REFERENCES`,
  `EHPANDA_SNAPSHOT_OUTPUT`, optional `EHPANDA_SNAPSHOT_ONLY` (comma-separated scenario IDs, used by the tracer
  and the measurement). Plan 19-01 proves they arrive in app-hosted tests on clones; the simulator process reads
  and writes Mac paths directly.
- **One `xcodebuild` per host:** locally too (TESTING.md). A shard runs its configurations inside one invocation.

## 5. Sharding, retries and CI shape (D-13 to D-16, owner msg 2263)

- **Hosted limits (GitHub Docs, Actions limits):** standard hosted runners on Free, Pro and Team allow at most 5
  concurrent macOS jobs (Enterprise 50); further jobs queue. A job stops at 6 h; a workflow run at 35 days; a matrix
  has at most 256 jobs. These 5 slots are shared with `test.yml` and the deploy workflows, which queue behind a gate
  run. Job metadata shows `xcode-27` runs in runner group "GitHub Actions" (runner name `GitHub Actions <n>`), but a
  custom label is unusual for standard runners: plan 19-04 confirms from the job's runner metadata and the run's
  billing whether it is a standard (free for public repositories) or a larger (billed) runner, and stops for the
  owner if billed.
- **Units:** (device, configuration) = 2 × 18 = **36 units** of about 544 pictures each (136 scenarios × 4 in-process
  coordinates, minus not-applicable).
- **20 shards:** one device per shard, one or two units each, assigned by longest-processing-time-first on the
  measured per-unit cost (iPad and AX5 cost more), ties broken by unit key order, so the same cost table always
  gives the same shards. `Scripts/visual/snapshot_shards.py` writes `Scripts/visual/snapshot-shards.json`
  (committed); CI reads it; a test proves determinism and balance (max shard ≤ 1.25 × mean).
- **Time:** at 1.2 to 2.4 s per picture and the clone speed-up measured in 19-04, a shard of about 980 pictures
  takes about 12 to 25 min of capture plus about 10 min to boot, clone and fetch its slice. 20 shards at 5 at a time
  run in 4 rounds: capture time as D-13 estimated, plus about 30 min of extra per-shard overhead, so **about 2 to 3
  hours per PR** including the shared build. More concurrency needs Enterprise or a support-ticket increase.
- **Timeouts:** shard test step `timeout-minutes` = 2 × the shard's estimated minutes, at most 120; the job at most
  150 (6-hour cap: 360).
- **Failure classes:**
  - *Picture change* (`changed`, `missing-baseline`): the shard uploads its results and the failing
    baseline/actual/diff and reports no infrastructure error; the aggregate job fails.
  - *Infrastructure error* (test process crash, step timeout, missing results, runner lost): inside the job, a
    crashed or timed-out `xcodebuild` is re-run once for the unfinished classes only (the results file says which
    are done). If the shard still has unfinished classes, its `shard.json` names the error; if the runner is lost,
    no artifact arrives at all. A `triage` job (`if: always()`) reads the artifacts and lists the shards with an
    infrastructure error or no artifact; a `retry` job runs exactly those shards once more, in the same workflow run
    (dynamic matrix `fromJSON` of the triage output, skipped when the list is empty). The aggregate takes each
    shard's latest attempt. Retry-attempt failures are reported, never retried again.
  - *Why not GitHub's "re-run failed jobs":* its trigger (`workflow_run`) works only from the default branch, so it
    could not be proven before merge, and a re-run attempt replaces the run's summary.
  - *Environment drift* (Xcode build, runtime or device model differs from the manifest) and *baseline mismatch*
    (fetched pictures differ from `fingerprints.json`): the shard captures nothing and records the class; the
    aggregate fails with that class, which is never retried.
- **`strategy.fail-fast: false`** and `continue-on-error: true` on the shard and retry matrices, so a failed or lost
  shard never cancels another and never decides the run by itself; `triage` and `aggregate` run `if: always()`.
  The aggregate job's result is the run's result and the check that branch protection requires.
- **Superseded runs:** `concurrency: { group: snapshot-${{ github.event.pull_request.number || github.ref }},
  cancel-in-progress: true }` on PR runs; candidate runs use their own group and are never cancelled by PRs.
- **Build once:** a `build` job runs `build-for-testing` and uploads the products and `.xctestrun` as one artifact
  (retention 1 day); shards download it.
- **Triggers:** `pull_request` (every PR, Dependabot's included: its PRs run with a read-only token, which is enough
  because the snapshot repository is public), `workflow_dispatch` (inputs `mode: compare|candidate`), and
  `workflow_call` for the deploy workflows. **Trap:** PRs that `dependencies.yml` opens with the default
  `GITHUB_TOKEN` do not trigger `pull_request` workflows; `workflow_dispatch` is the documented exception, so
  `dependencies.yml` dispatches the gate on its `update-dependencies` branch after creating the PR (needs
  `actions: write`). **Trap:** `workflow_dispatch` and `workflow_run` work only for workflow files on the default
  branch; until the phase reaches `main`, runs are started by pushing a dedicated branch (`on: push` with a
  `branches` filter) with the owner's go-ahead.
- **Release:** `deploy.yml` and `deploy-pre-release.yml` gain a first job that calls the gate (`workflow_call`) in
  compare mode and `needs` it, so no release builds without a green full matrix.

## 6. Baseline store (D-14)

- **Layout** (snapshot repository and every fetched slice): `<family>/<locale>/<size>/<scenario>/<orientation>-<theme>.png`;
  a slice is `<family>/<locale>/<size>`. Repository root: `README.md` (what this is, that every push is
  owner-approved, how to fetch a slice) and `baseline.json` (the approval record).
- **Fetch:** `git clone --depth 1 --filter=blob:none --sparse https://github.com/EhPanda-Team/ehpanda-snapshot`,
  `git sparse-checkout set <slices>`, `git checkout <commit from fingerprints.json>`; then every picture's SHA-256
  must equal `fingerprints.json`, and a missing or extra file fails the shard as drift-like "baseline mismatch".
- **App repository:** `AppPackage/Tests/VisualSnapshotTests/Baseline/fingerprints.json` (schema 1: repository, commit,
  tag, count, `pictures: {key: sha256}`; about 2 MB) and `AppPackage/Tests/VisualSnapshotTests/Baseline/manifest.json`
  (environment pins, precision, scale, worker count, cost table digest, scenario inventory digest, every
  not-applicable coordinate with its reason, the approval record).
- **Push size:** GitHub refuses a push above 2 GB and recommends repositories stay under 5 GB (1 GB ideal). An
  estimated 5 to 10 GB set is therefore pushed as one commit per device-and-language slice (12 pushes of about 0.4
  to 0.8 GB), then an approval commit with `baseline.json` and a tag `baseline-<n>`; one owner go-ahead covers the
  series (CONTEXT D-14 planning note). If the measured set exceeds 5 GB, the developer proposes the storage choice to
  the owner at that checkpoint (options: keep git anyway; store each slice as a compressed release asset of the same
  repository with the same fingerprints; reduce PNG size with lossless optimisation, which changes no pixel).
- **Creation:** `gh repo create EhPanda-Team/ehpanda-snapshot --public` with the owner's own sign-in, using the
  AIRBUILD push environment (injected `GH_TOKEN` and `GIT_CONFIG_*` variables dropped for that one command); only
  after the owner's go-ahead.

## 7. Daily live-parsing check (D-20 to D-26)

- **Target:** a new package test target `LiveCheckTests` that does **not** link `TestNetworkGuard`, declared through a
  separate helper in `Package.swift` with a comment naming it the only exception; every test in it calls
  `XCTSkip`/`Testing` skip unless `EHPANDA_LIVE_CHECK=1`, so a package-wide test run never touches the network.
  A Python test proves every other test target still links the guard. Test plan `AppPackage/Tests/LiveCheck.xctestplan`,
  referenced from the `EhPanda` scheme, with no stub-network variable.
- **Pages and request types (all GET):** front page `FrontPageGalleriesRequest`; search `SearchGalleriesRequest`
  with a fixed neutral keyword committed in code (never logged); Popular `PopularGalleriesRequest`; Toplists
  `ToplistsGalleriesRequest`; a gallery with comments `GalleryDetailRequest` on a gallery picked at run time from the
  first Toplists result (never logged); reader `GalleryPreviewURLsRequest` or `ThumbnailURLsRequest` then
  `GalleryNormalImageURLsRequest` for page 1, then `DataRequest` for that image, decoded in memory and discarded;
  tag suggestions `TagTranslatorRequest` (the GitHub-hosted tag database the suggestions read); the Report form page
  `ReportFormRequest` on the same gallery's `?report=other` URL. No POST type is reachable (allowlist test).
- **Observation without changing the request types:** each page runs on its own ephemeral `URLSession` whose task
  delegate collects `URLSessionTaskMetrics`; status code, `cf-mitigated` and `server` header names/values are read
  from the transaction metrics. Classification per page: `ok`; `unreachable` (403 with `cf-mitigated: challenge`,
  `AppError.ipBanned`, `networkingFailed` after the request type's own attempts, timeout, 5xx); `parser` (2xx and
  `parseFailed`, or an expectation from the fixed table failed). Each expectation has an ID and a fixed English
  sentence (for example `toplists.rows`: "expected a gallery table with at least one row, found none").
- **Pacing:** pages run one after another with a 5 s pause; the request types' own retry policy is kept (normal app
  behaviour); a run makes about 12 GETs.
- **Output:** `results.json`: schema 1, run date, mode (`hosted` | `local`), per page `{page, status (int or null),
  classification, expectation (ID or null)}`. Nothing else: no URL, title, gallery ID, header dump or body. The test
  never calls `XCTFail` with a dynamic string; the `.xcresult` and console logs are never uploaded.
- **Issues:** `Scripts/live-check/report_issues.py` reads `results.json` and the previous runs' results, and uses
  `gh` (label `live-check`): for each `parser` page, open or update one issue titled `Live check: <Page> parser`
  with the fixed sentence; close it on the next `ok`. `unreachable` never opens a parser issue; after three
  consecutive runs on which any page was unreachable, open one `Live check: cannot reach the site`, closed on the next
  run that reached every page. Previous results: in CI, the last two successful runs' `live-check-results`
  artifacts (`gh run list` / `gh run download`); locally, a state directory under `$HOME/Library/Application
  Support/EhPanda live check/` that holds only result files. Bodies are built only from fixed strings; a test feeds a
  results file containing content-like text and proves it never reaches an issue.
- **Two runners, one script:** `Scripts/live-check/run-live-check.sh --mode hosted|local` builds and runs the plan,
  writes results, and calls the reporter. Locally it first checks that no other `xcodebuild` runs (TESTING.md) and
  waits up to 2 h, then skips the day with a local note; it uses the owner's `gh` sign-in through the AIRBUILD
  environment rule, and a `launchd` agent template (`Scripts/live-check/live-check.plist.template`, `$HOME`
  placeholders) runs it daily. Hosted: `.github/workflows/live-check.yml` (`schedule` daily at 04:17 UTC,
  `workflow_dispatch`, `push` to `ci/live-check`), `permissions: { contents: read, issues: write, actions: read }`.
- **Traps:** scheduled workflows run only from the default branch, and GitHub disables a public repository's
  schedules after 60 days without repository activity; both are recorded in the README and the runner checkpoint.
- **Probe (D-25):** `RunnerProbeTests` in the same target: three GETs (front page, Popular, one gallery from
  Popular), 5 s apart, recording only status, whether `cf-mitigated` was present, and whether the app's parser
  succeeded, into `probe.json`; workflow `.github/workflows/runner-probe.yml` on `push` to `ci/runner-probe`
  (commit message carries `[skip test]` so `test.yml` does not also run). Needs the owner's OK (OQ-6).

## 8. Pitfalls

1. **Network guard:** linking `TestNetworkGuard` into `LiveCheckTests` makes every page "unreachable"; removing the
   guard from any other target reopens the 18-UAT leak. Guard both directions with a test.
2. **Branch-only triggers:** `schedule`, `workflow_dispatch` and `workflow_run` need the file on `main`; every
   pre-merge proof runs from a pushed branch (owner go-ahead each time).
3. **Default-token PRs** do not trigger `pull_request` (dependencies.yml); dispatch the gate explicitly.
4. **Clone settings:** clones copy the source simulator's state at clone time; set Reduce Motion before the run and
   assert it in each clone.
5. **Orientation in an app-hosted test** may not follow `requestGeometryUpdate` on every device; prove it first
   (19-01).
6. **Settle loop on animated states** (spinners, progress): a loading scenario must freeze its indicator (the state
   is a still), or it times out; such states get `ProgressView` in a fixed state through the existing preview
   dependencies, never a capture-only code path in the app.
7. **Size:** 5 to 10 GB baseline: push in slices under 2 GB; never `git add` the whole set in one commit.
8. **Public logs:** `xcodebuild` echoes failure messages; the live check never fails a test with page-derived text.
9. **Free-runner contention:** a gate run occupies all 5 macOS slots for hours; `test.yml` and deploys queue.
10. **Keyboard, web content, share sheet, file importer** cannot be rendered by the library (D-05): declare them
    not applicable with reasons, never fall back to simulator screenshots.

## 9. Cross-plan data contracts

| Contract | Producer | Consumers | Shape |
|---|---|---|---|
| Coordinate key | 19-02 (`snapshot_matrix.py`), 19-01 (Swift `SnapshotCoordinate`) | 19-05..08, 19-09, 19-10, 19-13 | `scenario__locale__size__orientation__family__theme`; values `en de ja ko zh-Hans zh-Hant`, `xSmall large accessibility5`, `portrait landscape`, `iphone ipad`, `light dark` |
| Scenario inventory | 19-02 (`Resources/scenarios.json`, schema 2) | 19-01 catalog test, 19-05..08 factories, Python tools | `{schema: 2, scenarios: [{id, group, fixtureID?, state, notApplicable: [{when: {axis: value}, reason}]}]}`; `home-populated` kept |
| Test configurations | 19-01 (`AppPackage/Tests/SnapshotMatrix.xctestplan`) | 19-02 shards, 19-04, 19-10 | 18 configurations named `<locale>-<size>` |
| Results | 19-01 (Swift writer) | 19-09 aggregate/report, 19-10 triage, 19-13 | `results.jsonl` lines `{key, status: passed|changed|missing-baseline|recorded|timeout|error|notApplicable, attempts, flaky, seconds, settleSamples, bytes, sha256, reason?}`; `shard.json` `{shard, units, workers, xcodeBuild, runtime, model, runnerImage, started, finished, infra: null|crash|timeout|runner-lost|drift|baseline-mismatch}` |
| Shard plan | 19-02 / 19-04 (`Scripts/visual/snapshot-shards.json`) | 19-10 | `{schema: 1, costTable: digest, workers, shards: [{id: s01..s20, family, configurations: [...], estimatedMinutes}]}` |
| Baseline | 19-13 | 19-10 shards, 19-17 | §6 layout; `Baseline/fingerprints.json`, `Baseline/manifest.json` |
| Live results | 19-03 (probe), 19-14 | `report_issues.py` | §7 |

## 10. Open questions

- **OQ-6 (owner, pending card msg 2246):** the probe's go-ahead. Plan 19-03 waits for it at its checkpoint.
- **OQ-3 (owner, only if the probe shows a block):** where the daily check runs instead; asked at 19-15's runner
  checkpoint with the recommendation from CONTEXT (the owner's Mac on a timer).
- **OQ-4 (owner, low):** review format; the planning default is the short packet, changeable at 19-13's checkpoint.
- **OQ-5 (owner, later):** the sign-in secret's account; nothing in this phase needs it.
- **R-1 (developer, 19-04):** whether `xcode-27` is a standard runner; stop for the owner if billed.
- **R-2 (developer, 19-13):** storage choice if the measured set exceeds 5 GB (§6).
- **R-3 (developer, 19-01):** in-process rotation in app-hosted tests (§3).

## 11. Validation Architecture

| Property | Value |
|---|---|
| Frameworks | XCTest (`VisualSnapshotTests` app-hosted, `LiveCheckTests`, `EhPandaUITests`), Swift Testing (FeatureTests), Python `unittest` (`Scripts/visual`, `Scripts/live-check`) |
| Config | `AppPackage/Tests/SnapshotMatrix.xctestplan` (new), `AppPackage/Tests/LiveCheck.xctestplan` (new), `UITests.xctestplan`, `AppPackage/Tests/FeatureTests.xctestplan`, `.swiftlint.yml` |
| Devices (local) | `EhPanda iPhone Air` (`$PHONE`), `EhPanda iPad Pro 11-inch (M5)` (`$PAD`), resolved by name as in 18.1 |
| Quick checks | `python3 -m unittest discover -s Scripts/visual -p 'test_snapshot*.py'`; `python3 -m unittest discover -s Scripts/live-check -p 'test_*.py'`; a tracer run `-testPlan SnapshotMatrix -only-test-configuration en-large -only-testing:VisualSnapshotTests/<Class>` |
| Full | FeatureTests and UITests on both devices; the hosted gate (20 shards + aggregate) in compare mode; the live check run once |
| Sampling | per task: touched Python tests or the touched snapshot class on `$PHONE`; per plan: both devices for the touched classes; phase gate: plan 19-17 |
| Wave 0 | the test files each plan names first (no framework install) |

## Security Domain

| ASVS area | Applies | Control |
|---|---|---|
| V8 data protection | yes | live-check issues and logs carry only page names, status codes, classifications and fixed sentences; no `.xcresult` upload; baselines contain synthetic fixtures only |
| V13 API / outbound | yes | GET-only allowlist; no state-changing request reachable; pacing; guest only (no cookies) |
| V14 configuration | yes | workflow `permissions` minimal per job; no secrets needed; the snapshot repository push only with the owner's own sign-in and go-ahead |
| V10 malicious code / supply chain | yes | actions pinned to the major versions already in use (`actions/checkout@v7`, `actions/upload-artifact@v7`, `nick-fields/retry@v4`); `actions/download-artifact` at the matching major; no new third-party action |
| V1 architecture | yes | Release builds carry no capture code, fixtures or SnapshotTesting (verify-release.py) |

## Sources

- Primary: this repository (files in §2), the spike worktree and its data in `/tmp/ehp19-snapspike/hosted/`
  (timings JSON for runs `h-r1`, `h2-rec`, `h2-c1` to `h2-c3`), GitHub's job metadata for run 42139577395 (runner
  group "GitHub Actions", label `xcode-27`, 26 min FeatureTests).
- Secondary (GitHub Docs, current): Actions usage limits (concurrency per plan, 6 h job cap, 256 matrix jobs),
  triggering workflows with `GITHUB_TOKEN`, `schedule` and `workflow_dispatch` default-branch rules, scheduled
  workflows disabled after 60 days of inactivity in public repositories, re-run failed jobs REST endpoint, push size
  limit (2 GB) and repository size guidance.
- Tertiary: swift-snapshot-testing 1.19.6 source (`Diffing<UIImage>.image(precision:perceptualPrecision:scale:)`).

## Metadata

- UI gate: the deterministic UI check matched "UI" in the goal (this phase photographs existing UI). No new app UI is
  built; the offline review report is a developer tool whose content D-18 fixes. Planned with `--skip-ui`.
- CONTEXT amendments made at planning: D-15 (owner msg 2263), D-14 push-size note, D-21 GET-only note, OQ-4 default.
