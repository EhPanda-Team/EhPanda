# Phase 19: Visual Regression & Daily Live-Parsing Check - Context

**Gathered:** 2026-11-07 (owner decisions from the Phase 18 discussion and owner msgs 1949, 1961, 1964, 2006, 2243;
the capture spike; the runner-IP desk check). Replaces the 2026-11-05 context and its 2026-11-06 scope-change notes,
and absorbs the uncommitted 2026-11-06 discussion prep, which predated the scope change.
**Amended:** 2026-11-07, three times the same day. First, one picture per screen and state on one setup (owner msg
2243; lead msg 2244; team msg 2245). Then, superseding that, the matrix in D-04 (owner msgs 2247, 2249; product lead
msgs 2248, 2250; team msg 2251), which resolves OQ-1. Then the baseline store and parallel runs (owner msg 2252),
which resolve OQ-2 (D-13 to D-15). OQ-4 (review format) stays open at low priority. A fourth amendment the same
day, at planning: 20 smaller shards with retries and error handling (owner msg 2263, D-15), and planning notes on
D-14 (push size), D-21 (GET only) and OQ-4 (the planning default).
**Status:** Ready for planning. Next open item: the runner-IP probe's go-ahead (OQ-6, card pending, msg 2246); OQ-4
low priority; OQ-3 only if the probe shows a block; OQ-5 later. None blocks the first screenshot plans. The
directory name is unchanged.
**Sources:** ROADMAP.md Phase 19 (scope items 1 to 9); REQUIREMENTS.md VIS-18-01, VIS-19-01; the owner decisions
recorded during the Phase 18 discussion (owner msg 1753); owner msgs 1949, 1961, 1964, 2006, 2243, 2247, 2249, 2252;
lead msgs 1952, 2007, 2008, 2244, 2248, 2250; team msgs 2245, 2251; the snapshot spike (worktree
`.airbuild/worktree/snap-spike`, branch `spike/snapshot-testing`, uncommitted).

<domain>
## Phase Boundary

This phase delivers two checks against the settled 3.0 UI:

1. **The screenshot check (VIS-18-01)**, moved from Phase 17: one picture of every real screen and state, Phase 18
   and 18.1 included, across the D-04 matrix; real-app scenario dispatch (17-11); strict never-record comparison and a
   review report (17-08 to 17-12); one owner-approved baseline (17-13, with 17-20 folded in); the CI gate on every PR
   and release (17-14 T1/T3) with the native visual policy tests (17-09-T2); preview review documentation (17-15);
   and the `Scripts/visual/README.md` rewrite.
2. **The daily live-parsing check (VIS-19-01)**: a scheduled GitHub Actions workflow that runs the app's own parsers
   on the live pages EhPanda reads, read-only, and reports a break through a GitHub issue that closes itself on the
   next clean run.

Requirements: VIS-18-01, VIS-19-01; moved from Phase 17: CAP-17-02, CAP-17-03 and the moved parts of CAP-17-01
(17-11) and CAP-17-06 (17-09-T2, 17-15).

**Not in this phase:**

- **Dropped (owner msg 1949; lead msg 1952; restated by the product lead in msg 1993):** all marketing pictures. No
  regenerated iPhone marketing set, no iPad marketing set, no 384-coordinate export tooling or handoff validator
  (17-07), no final gallery selection and no 384 regeneration (17-21). MKT-18-01's Phase 19 part and CAP-17-04's
  moved 384 export go with them. The "six galleries per Toplists period" fixture rule existed only for those pictures
  and is dropped; the fixtures keep three per period.
- **Phase 20:** the AltStore promotional images and store screenshots (17-22, CAP-17-05; non-adult pictures only on
  the AltStore listing, guideline 2.3.8; store screenshots are the website screenshots plus the designer's
  decorations, owner msg 1753) and the final Release isolation scan.
- **No phase:** tagging and release order (owner msg 1753).

</domain>

<decisions>
## Implementation Decisions

### Phase organisation and order

- **D-01:** This phase runs after all in-app work, so the baseline is approved once, against final UI (owner msg
  1753). No baseline is recorded while any Phase 18 or 18.1 UI is still changing.
- **D-02:** The screenshot check goes first; the daily live-parsing check follows, except its runner-IP probe (D-25),
  which runs early because its answer may need an owner decision (owner msg 1949; ROADMAP scope item 9).

### Coverage

- **D-03:** Every screen and state of the app is covered, including every Phase 18 and 18.1 screen: the age wall
  (Continue dimmed and enabled); the analytics choice (nothing selected, then Minimal, Basic and Full); the Settings
  analytics picker with its Privacy Policy row; the native Report form (Phase 18.1, which replaced the report
  confirmation); the posting warning; the blocked-comment row, collapsed and shown; Blocked Users, filled and empty.
  All six languages use the approved copy (18-COPY-FIRST-LAUNCH.md, 18-COPY-MINIMAL.md, 18-COPY-COMMENTS.md).
  Blocked comments in fixtures use member IDs (18-12, owner msg 1918).
- **D-04 (owner msgs 2247, 2249; lead msgs 2248, 2250; team msg 2251):** every scenario is captured across **six
  languages × iPhone and iPad × portrait and landscape × light and dark × three text sizes: the smallest (xSmall),
  the default (Large) and the largest accessibility size (AX5)**, which is 144 pictures per scenario. This supersedes
  both Phase 17's axes (17-CONTEXT D-07, all 12 text sizes) and the one-setup reading of owner msg 2243. ROADMAP
  success criterion 1 and VIS-18-01 were amended to match on 2026-11-07.
  Other sizes were offered (about 4,900, 23,900 and 78,300 pictures) and not chosen. Every coordinate ends as
  captured, failed, or not applicable with a written reason in the manifest.
- **D-05:** States the snapshot library cannot render are skipped and recorded as not applicable with that reason;
  there is no simulator-screenshot fallback (owner msg 1964). Known members: the keyboard (a separate system window;
  search-focus states are captured without it), live web content (sign-in web page, the Cloudflare check page, site
  pages opened in a web view), the system share sheet, and the system file importer.
- **D-06:** Regression content is the public, synthetic fixture set (`PublicVisualFixtures`, `FixtureArtwork`): no
  real gallery covers or titles, so every baseline picture can be published (CAP-17-03).

### Capture method (owner msgs 1961, 1964; spike; lead's call)

- **D-07:** Tool: swift-snapshot-testing, in process, already a dependency through `VisualSnapshotSupport` (pinned
  exactly at 1.19.6) (owner msg 1961). No XCUITest screenshot path for the matrix.
- **D-08 (lead's call after the spike, "Path B"):** each scenario's real view, with its real reducer and preview
  dependencies, is hosted in the app-hosted test's real key window; the test waits until the window has settled
  (unchanged for at least 500 ms), draws it with `window.drawHierarchy(afterScreenUpdates: true)`, and compares the
  image with the library's `.image` strategy under `record: .never`. Recording happens only in an explicit candidate
  run (D-17). This replaces the 17-11 XCUITest dispatcher for the matrix; "real-app dispatch" now means real
  feature views and stores in the real app process.
- **D-09: spike findings** (25 cases × 3 scales, one record and three compare runs, iPhone Air simulator):
  - Path B renders Liquid Glass (`.glass`, `.glassProminent`), materials, menus, alerts, sheets, confirmation
    dialogs and the soft scroll edge, which package-only tests could not. The glass backdrop blur is weaker than on
    a device but identical between runs.
  - The library's own `drawHierarchyInKeyWindow` strategy ("Path A") flaked on glass and scrolled-edge cases across
    runs; it is not used.
  - Path B at 1x: 0 mismatches in 75 compares at exact precision. At 3x one glass case flaked; precision 0.9999 with
    perceptual precision 1 absorbs it and still fails a deliberate 1-point layout shift.
  - Cost: about 1.2 s per image including the settle wait (median 1.18 s at 1x).
  - Size at 1x on iPhone Air (420 × 912 px): median about 120 KB, mean about 147 KB; real app screens 46 to 374 KB;
    AX5 about 2.5× the default size. iPad sizes were not measured.
- **D-10:** Baselines are 1x (lead's recommendation from the spike; smallest files, and the 1-point shift is still
  caught). Comparison: precision 0.9999, perceptual precision 1, applied uniformly; any other tolerance needs a
  measured justification recorded in the manifest.
- **D-11:** Capture is serial within each simulator: each simulator clone captures one picture at a time, while
  several clones per CI job and several jobs run in parallel (D-15; owner msgs 1949, 2252). This is allowed for the
  screenshot runs only. The approval is documented above each narrow
  `// swiftlint:disable:next no_serialized_test`, as AGENTS.md requires. All other tests stay parallel. Locally,
  `xcodebuild` invocations never overlap (`.planning/codebase/TESTING.md`).

### Matrix, run time and storage (owner msgs 1949, 2247, 2249)

- **D-12: scenario inventory and matrix.** From the views, presentations and states in `AppPackage/Sources` and the
  scroll-edge page inventory, the check has about **136 scenarios** (plan 1 confirms the exact list in
  `scenarios.json`; expected range 130 to 150). With D-04's 144 coordinates each, that is **136 × 144 = 19,584
  pictures** before not-applicable reductions:

  | Group | Scenarios (states) | Count |
  |---|---|---|
  | First launch (Phase 18) | age wall unticked, ticked; analytics choice none selected, Minimal, Basic, Full | 6 |
  | Shell | Library title menu open; Library sidebar with empty detail (regular width) | 2 |
  | Home | populated, loading, error | 3 |
  | Front Page | list, grid, loading, empty, error, search with query | 6 |
  | Popular | list, grid, loading, error | 4 |
  | Watched | list, grid, signed out, empty, error | 5 |
  | Toplists | list, grid, period menu open, error | 4 |
  | History | list, grid, empty, clear confirmation | 4 |
  | Search | root with history, root empty, typing with tag suggestions, clear confirmation; results list, grid, empty, error | 8 |
  | Quick Search, Filters, Date Seek | list, empty, word editor, delete confirmation; Filters form, reset confirmation; Date Seek | 7 |
  | Favorites | list, grid, signed out, empty, category menu | 5 |
  | Downloads | list, grid, empty, active and failed items, delete confirmation, retry confirmation; inspector details, error | 8 |
  | Gallery detail | loaded, loading, error, downloading, delete-download confirmation, retry confirmation, rating; iPad gallery sheet | 8 |
  | Detail pages | Previews loaded, loading; Gallery Info; Detail Search list, grid; Archives, Archives insufficient funds; Torrents, empty; Tag Detail; New Dawn; Folder Manager, delete confirmation | 13 |
  | Comments (Phase 18) | list, comment menu, block confirmation, blocked row collapsed, blocked row shown; post empty, post filled, posting warning | 8 |
  | Report form (Phase 18.1) | loading, ready, reason chosen and filled, sending, sent, unavailable, error alert | 7 |
  | Reader | horizontal, vertical, two-page spread, controls shown, slider scrub, page failed, loading, Live Text; reader settings sheet | 9 |
  | Settings | root; Account signed in, signed out, logout confirmation; Blocked Users filled, empty; Login empty, filled, error | 9 |
  | Settings pages | General with Minimal, Basic, Full footers, cache confirmation; Activity Logs list, empty, run picker; Appearance, app icon picker; Reading; Download; Laboratory; About; Site settings loaded, loading/error, confirmation | 16 |
  | App-wide | Error Info sheet; success and failure toasts; app alert | 4 |
  | **Total** | | **136** |

  Not applicable by design, with reasons in the manifest (Claude's call): the Library sidebar and the iPad gallery
  sheet where the width is compact, the compact-only Library title menu where it is regular, the two-page spread
  outside landscape or iPad, and the D-05 skips. These remove a few hundred coordinates at most.
- **D-13: run time (owner msg 2252: "test in parallel to reduce test time"; estimate is Claude's call).** At 1.2 s
  per picture (spike, this machine) up to 2.4 s (an assumed 2× slowdown on GitHub's runners, not yet measured), the
  pictures take about 6.5 to 13 simulator-hours. They run on five hosted Macs at once, each running parallel
  simulator clones (D-15). **Assumption:** two clones per Mac, giving about 1.7× one simulator's throughput (the
  500 ms settle wait leaves the CPU partly idle), so about 8.5 simulators' worth in total. Capture then takes about
  45 to 95 minutes, plus about 30 minutes for the shared build and about 10 minutes per shard to boot and fetch its
  baseline slice: **about 1½ to 2¼ hours per PR**. With three clones per Mac (about 2.4×), if plan 1 shows the
  runner sustains them, about 1¼ to 1¾ hours. Both are well inside the 2-day limit (D-16).
- **D-14: storage (owner msg 2252; resolves OQ-2).** At 1x the spike measured 46 to 374 KB for real app screens on
  the iPhone Air (median about 120 KB) and AX5 at about 2.5× the default; iPad pictures are assumed about 2.5× the
  iPhone's area. The baseline is therefore about **5 to 10 GB**, so it is kept out of the app repository:
  - The approved pictures live in **a separate public repository in the EhPanda-Team organisation**, named
    `EhPanda-Team/ehpanda-snapshot` to mirror the existing `ehpanda-fixture` repository (lowercase, singular; the
    fixture repository is private, this one is public by the owner's choice). We create it at execution time with
    the owner's own GitHub sign-in on this machine (owner msg 2252); each push still needs the owner's go-ahead.
  - Claude's calls: the pictures are laid out by device and language so each shard fetches only its slice with a
    shallow, sparse checkout; each owner approval is one commit there; if its history nears 5 GB, a cleanup is
    proposed to the owner rather than done silently.
  - *Planning note (2026-11-07, Claude's call):* GitHub refuses a single push above 2 GB, so one approval is
    pushed as a short series of commits, one per device and language slice, each under 2 GB, ending with an
    approval commit and tag that names the whole set. The owner's go-ahead covers the whole series of that one
    approval. The measured candidate size is shown to him before the first push; GitHub recommends keeping a
    repository under 5 GB, so if the first set already exceeds that, the developer proposes the storage choice
    to him then (19-RESEARCH §6).
  - The approved set's fingerprints (one hash per picture), the snapshot repository commit they came from, and the
    manifest are committed with the test source in the app repository, which is how CAP-17-03's "committed with
    the test source" is met. A run fails if the fetched pictures do not match the committed fingerprints.
  - Each run's actual images are kept only for that run's report; failures upload their baseline, actual and diff
    as a run artifact.

### CI gate

- **D-15: correction found during this context pass.** The `xcode-27` label used by every workflow is a
  GitHub-hosted runner (job records show runner group "GitHub Actions"), not a self-hosted Mac as the 2026-11-05
  developer default and the discussion prep assumed. Consequences, all Claude's calls:
  - GitHub-hosted jobs stop at 6 hours, so the matrix is split into shards (by device and language, for example)
    that each finish well inside that, five at a time (the free plan's macOS job limit); one build-for-testing job
    feeds them.
  - Inside each shard, one `xcodebuild test-without-building` runs XCTest's parallel testing on simulator clones
    (`-parallel-testing-enabled YES` with a fixed worker count), so there is never more than one `xcodebuild` per
    host. Scenarios are split across enough test classes for the clones to share the work. Plan 1 picks the worker
    count: the largest (starting at 2, trying 3 and 4) that the runner sustains without slowing each clone by more
    than about a quarter, without memory pressure, and without changing any picture between runs. The chosen
    number and its measurement go in the manifest.
  - The runners keep nothing between runs, so each shard fetches its slice from `ehpanda-snapshot` (D-14).
  - Baselines are recorded and compared on the same runner image and simulator pins (iPhone Air and the pinned iPad
    model, iOS 27.0, the Xcode build in the manifest; drift fails the run); local runs are advisory. Plan 1 measures
    the per-picture time and run-to-run identity on the hosted runner before the full matrix is recorded.
  - Standard hosted runners are free for public repositories; plan 1 confirms `xcode-27` is a standard one.
  - **Amended 2026-11-07 (owner msg 2263: "We can make it 10 or 20 Macs, just consider retrying and error
    handling").** GitHub's standard hosted runners on the Free, Pro and Team plans run at most 5 macOS jobs at once
    (Enterprise 50); further jobs queue. Claude's calls under that message:
    - The matrix is split into **20 smaller shards**: 5 run at once and the rest queue automatically, so one
      failure costs little. Running more than 5 at once needs GitHub Enterprise or a limit increase through
      GitHub support; the capture time estimate in D-13 is therefore unchanged by the extra shards, which add
      only their own boot and fetch time.
    - **Per-picture retry:** a picture that differs or times out is captured and compared once more before it
      counts as failed; every retry goes into a flake log that the report shows.
    - **Per-shard retry:** a shard that crashes, times out or loses its runner is re-run automatically once, then
      reported. Only such infrastructure errors trigger the re-run; picture changes are counted by the aggregate
      job, so they never do. *Planning note (Claude's call):* the re-run is a retry job in the same workflow run
      that repeats only the shards with an infrastructure error, not GitHub's "re-run failed jobs", whose
      `workflow_run` trigger works only from the default branch and so could not be proven before merge.
    - **Fail-fast off:** one shard can never cancel the others.
    - **Aggregate job:** a final job merges the per-shard results, separates real picture changes from
      infrastructure errors (and environment drift) in the report, and fails with a clear summary of each.
    - **Timeouts:** each shard has its own timeout well under GitHub's 6-hour cap, set from the measured cost.
    - **Assignment:** shards are assigned deterministically and balanced by measured cost, so the same commit
      always gives the same shards.
- **D-16: run limits (owner msg 1949).** One full check may take up to 2 days before options go back to the owner.
  The check runs on every PR and every release (17-CONTEXT D-13); weekly dependency-update PRs wait for it too.
  Superseded runs of the same PR are cancelled.
- **D-17: approval.** Candidates are recorded only by an explicit candidate run. Agents pre-check every picture first
  and record their findings; the owner then reviews and approves the whole set once. How he reviews about 19,600
  pictures is OQ-4 (low priority; recommendation: a short packet). Approval is tied to the committed fingerprints.
- **D-18:** The report is a static, offline HTML page (no remote scripts or fonts), grouped by screen, with
  baseline/actual/diff and filters for language, text size, device, orientation and appearance. A controlled
  regression (a one-point change to one token) is proven red, then restored green; both runs are kept (17-CONTEXT
  D-14).
- **D-19:** The native visual policy tests (17-09-T2: cold entry and live text-size changes, rotation, title and
  search behaviour at standard, AX1, AX3, AX5) stay XCUITests and run in the gate as their own job; they test
  transitions, which snapshots do not.

### Daily live-parsing check (VIS-19-01; owner msg 2006; lead msg 2008)

- **D-20:** A scheduled GitHub Actions workflow runs once a day (plus manual dispatch). It fetches, as a guest, the
  pages EhPanda reads and runs the app's own parsers on them through the app's own request types: Home front page,
  search results, Popular, Toplists, a gallery page with comments, the reader page and its image data, the tag
  suggestion data, and the native Report form page.
- **D-21: read-only.** It never sends a report, comment, vote, favourite, rating, setting change or sign-in. Claude's
  call: read queries that the site's API takes as JSON POST (`gdata` metadata, and `imagedispatch` where the reader
  path needs it) count as reads and are allowed; an allowlist of request types enforces this, and a test fails if a
  state-changing request type is reachable from the check.
  *Narrowed at planning (2026-11-07, within Claude's call):* the check sends **GET requests only** and never a POST.
  None of the D-20 pages needs `gdata` or `imagedispatch` (the guest reader path reads each page's image URL by
  GET), so the allowlist admits GET request types only and the test fails if any POST is reachable.
- **D-22: reporting.** On a failure it opens or updates one GitHub issue per page, naming the page and what the
  parser expected; the next clean run closes it. Issues and logs never carry page content, images, gallery titles,
  gallery IDs, cookies or account details, because the repository is public. Claude's call: one issue per page with a
  stable title and a label; logs print only page name, HTTP status and the failed expectation.
- **D-23:** A Cloudflare challenge, an E-Hentai IP ban page, a timeout or a 5xx is "could not reach the page", never a
  parser failure, so a block never opens a false "parser broken" issue. Claude's call: after three such days in a row
  the check opens one "live check cannot reach the site" issue, which closes on the next reached run.
- **D-24:** Signed-in pages (Watched, Favorites, ExHentai) are covered by saved fixtures until the owner supplies a
  sign-in kept as a GitHub secret; the workflow skips them while the secret is absent (which account, OQ-5).
- **D-25: runner-IP probe, first task.** A one-off manually dispatched job on the hosted runner fetches the front
  page, Popular and one gallery page (three GETs, normal delays) and records only status codes, whether Cloudflare
  challenged (`cf-mitigated`), and whether the parser succeeded. It needs a push, so it waits for the owner's OK to
  push (OQ-6). If GitHub's machines are blocked, OQ-3 is asked.
- **D-26: desk check (2026-11-07), recorded for the probe.**
  - `e-hentai.org` (guest gallery pages) and `exhentai.org` now resolve to Cloudflare addresses and answer with
    `server: cloudflare`; Phase 12 had seen only the forum host behind Cloudflare. `api.e-hentai.org` (the JSON API)
    and the thumbnail and image hosts are not behind Cloudflare.
  - Three guest GETs from the development machine (front page with an app-like `CFNetwork` user agent, Popular,
    front page with curl's user agent) all returned 200 listing pages with no challenge, so the site does not filter
    by user agent today.
  - The app sends no custom user agent: every request uses URLSession's default (`EhPanda/<build> CFNetwork/…
    Darwin/…`); only the sign-in replay sends the challenge web view's agent (Phase 12). Running the real request
    types in the check gives it the app's own identity.
  - Whether Cloudflare challenges cloud-datacenter addresses is a per-site setting that only a probe from the runner
    reveals. Public bug reports from other open-source E-Hentai clients (2023 to 2026) show Cloudflare 403
    challenges on the forum sign-in and on ExHentai, ExHentai requiring a "clean" address, and E-Hentai's own
    temporary IP bans after heavy use; none found was about GitHub runners and guest pages. Risk: medium.

### Carried project rules

- **D-27:** SwiftLint as error, no suppressions without permission; every `.xcstrings` key filled for six locales;
  tests parallel by default (AGENTS.md); agent-run UAT where no hardware or owner judgement is needed; closing gates
  need zero failures and zero Repetition nodes. Release builds contain no capture code, fixtures, test assets or
  SnapshotTesting linkage (success criterion 8; 17-14 T2's scan stays green).
- **D-28:** Rewrite `Scripts/visual/README.md`: drop the removed "Visual capture" workflow and the per-coordinate
  `run-regression.py` flow, describe this phase's in-process runner, sharded CI gate and report, and point at the
  current fixture index `website-capture-20261104.json` (11 fixture versions). The fixture repository's commits
  `8ee4fc2` and `f71d108` were pushed on 2026-11-05, so R4-3 is resolved; with the marketing export dropped, nothing
  in this phase needs it.

### Claude's Discretion

Within the decisions above: scenario file layout and naming; how a scenario declares its state; shard boundaries;
whether orientation, text size and appearance change in process or per test configuration (language changes per
process); the iPad model (pinned with the iPhone Air, runtime and Xcode build in the manifest; drift fails the run);
the manifest and report formats; the live check's schedule time, request pacing and issue wording within D-22.

### Open questions for the owner

Plain-language versions with options are in the owner handoff.

- **OQ-1, matrix size: resolved** (D-04; owner msgs 2247, 2249).
- **OQ-2, where the approved pictures are kept: resolved** (D-14; owner msg 2252): a separate public repository,
  `EhPanda-Team/ehpanda-snapshot`.
- **OQ-6, the runner-IP probe's go-ahead** (D-25): next open item; asked, the owner's card is pending (msg 2246).
- **OQ-4, how the owner reviews about 19,600 pictures** (low priority; *planning default, 2026-11-07:* the short
  packet below, which the owner may change at the approval checkpoint): a short packet (each screen and state once,
  plus everything agents flagged and the not-applicable list), the full report, or the designer first.
  Recommendation: the short packet.
- **OQ-3, if E-Hentai blocks GitHub's machines** (asked only if the probe shows a block): run the daily check on the
  owner's Mac on a timer, register that Mac as a GitHub runner, or keep only saved fixtures. Recommendation: the Mac
  timer.
- **OQ-5, which account the later sign-in secret uses** (later): a separate account made for the check, the owner's
  own account, or none. Recommendation: a separate account.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and requirements

- `.planning/ROADMAP.md`: Phase 19 (scope items 1 to 9, success criteria 1 to 8, plan outline) and the split map at
  the end of the Phase 18 section.
- `.planning/REQUIREMENTS.md`: VIS-18-01 (with its 2026-11-06 amendment), VIS-19-01, CAP-17-01 to CAP-17-06,
  MKT-18-01 (what was dropped).

### Screens to cover and their copy

- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-CONTEXT.md` and `18-UI-SPEC.md`
  (frames 01 to 22).
- `18-COPY-FIRST-LAUNCH.md`, `18-COPY-MINIMAL.md` (its revision precedence), `18-COPY-COMMENTS.md` in the same
  directory.
- `.planning/phases/18.1-native-report-form/`: the native Report form and its states.
- `.planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/SCROLL-EDGE-INVENTORY.md`: the page inventory
  the scenario list is checked against.

### Phase 17 decisions and moved plans

- `.planning/phases/17-localized-screenshot-capture-harness/17-CONTEXT.md` (D-07, D-11 to D-14), `17-RESEARCH.md`
  ("Complete Coverage Inventory"), and the superseded plans 17-08 to 17-15 and 17-20.

### Rules

- `AGENTS.md`: test parallelism, simulators, accessibility navigation and search, scroll-edge policy, dialog
  placement.
- `.planning/codebase/TESTING.md`: no overlapping `xcodebuild` on one host.

### Code and tooling

- `AppPackage/Sources/VisualSnapshotSupport/`, `AppPackage/Tests/VisualSnapshotTests/` (`scenarios.json` holds only
  the `home-populated` tracer today), `AppPackage/Tests/VisualTests.xctestplan`.
- The spike: `AppPackage/Tests/VisualSnapshotTests/HostedSnapshotSpikeTests.swift` in the `snap-spike` worktree
  (throwaway; its host-window, settle and capture helpers are the reference for D-08); data in
  `/tmp/ehp19-snapspike/hosted/` while it lasts.
- `AppPackage/Sources/NetworkingFeature/` (request types, `isCloudflareChallenge`), `AppPackage/Sources/ParserFeature/`.
- `.github/workflows/test.yml`, `deploy.yml`, `deploy-pre-release.yml`, `dependencies.yml`, `.github/dependabot.yml`.
- `Scripts/visual/README.md`, `Scripts/visual/verify-release.py`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `VisualSnapshotSupport`: `PublicVisualFixtures` (synthetic galleries, fixed date `1_735_689_600`, fixture IDs
  `home-finite`, `comments-finite`, `downloads-finite`, `reader-vertical-finite`), `RenderSettlement`,
  `FullContentHost`, `RenderedContentInspection`.
- The spike's `withDependencies` setup (`context = .preview`, `cookieClient = .previewLoggedIn`, fixed date,
  incrementing UUIDs) and its host/settle/capture helpers.
- `GalleryLayoutPicker` (`GalleryListDisplayMode.row` / `.grid` per scope): one setting gives every list page its
  list and grid scenarios.
- `AppError` cases (`networkingFailed`, `parseFailed`, `notFound`, `loginRequired`, `ipBanned`, …) drive the error
  scenarios and the live check's "could not reach" classification (D-23), with `isCloudflareChallenge`.
- Request types for the live check: `FrontPageGalleriesRequest`, `SearchGalleriesRequest`, `PopularGalleriesRequest`,
  `ToplistsGalleriesRequest`, `GalleryDetailRequest`, `GalleryPreviewURLsRequest`, `ThumbnailURLsRequest`,
  `GalleryNormalImageURLsRequest`, `GalleriesMetadataRequest`, `TagTranslatorRequest`, `ReportFormRequest`.

### Established Patterns

- The package is iOS 27 only, so the parsers run in an iOS simulator on a macOS runner, like `test.yml`.
- `test.yml` installs the iOS platform with retries, pins `iPhone Air` on iOS 27.0, and uploads the result bundle.
- Persisted settings are `@Shared` v1 models edited in place; scenarios set them through dependencies, not
  migrations.

### Integration Points

- New workflows: the sharded screenshot gate (PRs and releases) and the scheduled live check; both separate from
  `test.yml`.
- `scenarios.json` grows from one tracer to the D-12 inventory, with not-applicable reasons per coordinate.

</code_context>

<specifics>
## Specific Ideas

- The owner expected "hundreds of reference pictures" and said "swift-snapshot-testing snapshots won't take so much
  space" (msg 1949): the size options are given in pictures and gigabytes so he can pick against that.
- The public issue must be useful without content: "Toplists: expected a gallery table with at least one row, found
  none" is the shape; never a title or link to a gallery.

</specifics>

<deferred>
## Deferred Ideas

- The 384 marketing export, the final gallery selection, the iPad marketing set and the six-per-period Toplists
  fixtures (dropped, owner msg 1949).
- The live check for signed-in pages, until the owner supplies the secret (D-24).
- Native tag management and tag context menus are future milestones (TAG-01, TAG-02), not covered until they exist.

</deferred>

---

*Phase: 19-visual-regression-marketing-export*
*Context gathered: 2026-11-07; matrix and baseline store decided (owner msgs 2247, 2249, 2252); OQ-6 next, OQ-4 low
priority, OQ-3 conditional, OQ-5 later*
