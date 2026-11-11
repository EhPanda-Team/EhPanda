---
gsd_state_version: "1.0"
milestone: v3.0.0
current_phase: 20
current_phase_name: "3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks"
status: executing
stopped_at: Completed 20-10-PLAN.md (closed by decision); main merged (Phase 19 complete with deferred items)
last_updated: "2026-11-11T12:00:00.000Z"
last_activity: 2026-11-11
last_activity_desc: "main (Phase 19 closed with deferred items, owner msgs 3425, 3428, 3573) merged into feature/gsd-phase-20 (OQ-F, owner msg 3346)"
state_head: 7b3bf8ec5589c912f22851b2dc1f563618209855
progress:
  total_phases: 21
  completed_phases: 19
  total_plans: 321
  completed_plans: 326
  percent: 90
milestone_name: Dependency Reduction & Modernization
source_head: 891103afa
---

# Project State

**Phase 20 planned** (2026-11-09) on `feature/gsd-phase-20`, in parallel with Phase 19 (owner msg 2770; product lead msg 2771): `20-CONTEXT.md`, `20-RESEARCH.md`, 14 plans following the fixed order (D-14), and `20-VALIDATION.md`; OQ-1 resolved by D-22 (product lead msg 2775: the current icon is kept). Product lead msg 2783 answered OQ-G, OQ-C and OQ-D (D-23 to D-25): 20-07, 20-09 and 20-12 start in wave 1, so the phase runs in 8 waves; the PAL `developerName` is "EhPanda Team"; the copywriter writes a PAL-specific subtitle and description, approved by the owner at the listing step with the first screenshot's caption. Owner msg 2802 (D-26): 3.0 ships on GitHub and AltStore Classic first, with ehpanda.app going live at that release, and the AltStore PAL submission follows. So 20-08 moves to wave 8 after 20-14, OQ-A is answered (20-10's set) and OQ-B is moot. Open before or during execution: OQ-E and OQ-F (20-RESEARCH.md). OQ-E answered at 20-12 (product lead msg 2829; owner msgs 2837, 2842).

## Phase 20 executing — 2026-11-09

- **20-01 complete** (`e8efa2f7e`, `85b459112`, `c04ba6939`, `2d21eeafc`, `6806961bc`, `777e37f00`;
  `20-01-SUMMARY.md`, `1e7756361`): `Config/Marketplace.xcconfig` (`.marketplace`, name EhPanda, scheme `ehpanda-marketplace`,
  stamp `altstorePAL`); `App/Info.plist` reads the stamp from `EHPANDA_DISTRIBUTION_CHANNEL` (`source` in
  `Flavor.xcconfig`), so unsigned builds and `package-channel.sh` are unchanged; `GalleryURLParser` takes the new
  scheme; `App/PrivacyInfo.xcprivacy` (UserDefaults CA92.1, FileTimestamp C617.1, three unlinked analytics data
  types) ships in the app of every build, the extension has none. Both unsigned archives checked. DIST-18-01 stays
  Pending (20-14 shares it). Next: 20-02.
- **20-02 complete** (`0c79b66d2`, `aab86b0d4`, `9800e1813`, `08a101b1b`, `88e842112`; `20-02-SUMMARY.md`,
  `baacdba5b`): `deploy.yml` checks the build number before the tests, against main's AltStore.json, SideStore.json
  and altstore-beta.json (not the PAL source); `test_workflows.py` guards that step, the asset URLs, the
  history-keeping filter call and the notes checks, and forbids tag commands. The build is 3.0.0 (159), one above
  main's 158; `bump-version.sh` now leaves the UI and snapshot test targets at 1. `EhPanda-Team/ehpanda-assets` is
  public at `d69b30a` (owner msgs 2787, 2794; created by the orchestrator) and the seven screenshot URLs return 200.
  REL-18-01 stays Pending. `ReleaseNotes/3.0.0.md` (owner content) is still needed before the release PR.
- **20-03 complete** (`487ebd814`, `408fe7822`, `df31999cc`, `ec51d1062`; `20-03-SUMMARY.md`):
  `actions-tool/altstore-pal.template.json` (source `app.ehpanda.altstorepal`, app `app.ehpanda.marketplace`,
  AltStore.json's metadata, `nsfw: true`, empty `marketplaceID`, no screenshots, no versions).
  `altstore-add-version.jq` takes optional `assetURLs` (manifest = `downloadURL`, no `sha256`), `entitlements`
  (replace, without the two identity keys) and `marketplaceID` (set once, then must match). Golden files prove the
  Classic, SideStore and beta output byte-identical. `check_source(pal=True)` checks the PAL source.
  `AltStorePAL.json` is not created. The public address will be https://ehpanda.app/AltStorePAL.json (owner msg
  2822). Open items: the template still has the Classic copy, which 20-10 replaces with the PAL copy (D-25); 20-10's
  `pal/` screenshot paths are stale (`app-marketplace/`). DIST-18-02 stays Pending.
- **20-04 complete** (`53b4dd7d0`, `4825bfa7b`, `37c3b3da9`, `9774e8f13`, `d8e25a543`; `20-04-SUMMARY.md`):
  `actions-tool/asc.py` (stdlib + openssl ES256; `check-build`, `wait-build`, `ensure-version` with
  NOTARIZATION/MANUAL, `attach-build`, `submit`, `adp-id`; method-scoped allow-list with no record-making path;
  call record with key ID and role only), `actions-tool/marketplace-signing.sh` (temporary keychain, profiles,
  generated xcconfig selecting `$(EHPANDA_PROFILE_$(TARGET_NAME))`, always-safe teardown),
  `ExportOptions-marketplace.plist`, and `.github/workflows/deploy-pal.yml`: `workflow_dispatch` only, `submit` job in
  environment `pal-notarization` (D-26: first live run is 20-08). Secret and variable names fixed in the workflow
  header for 20-06. Nothing contacted Apple; the workflow was not dispatched. Open items: upload without
  `-allowProvisioningUpdates` and manual release before AltStore can fetch the ADP are first seen at 20-08; the PAL
  template still has the Classic copy, which 20-10 replaces and updates its test (D-25). DIST-18-03 stays Pending.
- **20-05 complete** (`3f21419ae`, `6a3dfb4b6`, `e9fc98685`, `2a2feec0d`, `98a54be69`; `20-05-SUMMARY.md`):
  `.github/actionlint.yaml` declares the `xcode-27` label (actionlint clean on every workflow).
  `actions-tool/pal_publish.py`: `process` (AltStore `POST /adps`), `fetch` (polls `GET /adps/<id>` for
  `downloadURL`, or `--from` a zip or folder; byte copies with SHA-256 per file), `publish` (release by the version's
  tag only, never created; `EhPanda-AltStorePAL-*` assets, re-downloaded and hash-compared; `assetURLs`,
  entitlements and privacy from the signed variant; `AltStorePAL.json` on main with five push attempts;
  `--dry-run`). `deploy-pal.yml` gains the `publish` job and the `dry_run` input (default true). Research: Apple
  generates the ADP on acceptance when the app is already on a marketplace (no POST; the POST stays refused, D-07),
  and in Pending Developer Release, so MANUAL does not block the package; whether AltStore PAL distributes a
  version still pending release is undocumented, an open item for the owner at 20-08 (no release call was added).
  Nothing contacted AltStore, Apple or GitHub. DIST-18-02 and DIST-18-03 stay Pending.
- **20-12 complete** (`02b242cfc` proposal; sign-off in the 20-12 docs commit; `20-12-SUMMARY.md`):
  `20-12-VOCABULARY.md` is signed off (OQ-E). Product lead msg 2829 approves the §2 signals (seven, all Basic).
  Owner msg 2837 drops `Moderation.reportReason` (3-i): the report signal carries the outcome only and the README
  line loses "with its reason". Owner msg 2842 puts `App.distributionChannel` on every signal at Basic and Full (§3
  option 1), with one README Basic line. OI-4 answer A and the SC8 wording are developer calls; ROADMAP SC8 now
  reads "nothing is sent before a level is chosen". No level description changes; no code changed. 20-13
  implements it.
- **20-10 closed (2026-11-10)** (`134b6ff36` RED, `176b9e170` GREEN; `20-10-SUMMARY.md`): by product lead
  msg 3168, after owner msg 3167 ("Screenshots for PAL? Approved."), with the owner's seven decorated iPhone
  screenshots (owner msg 2628; pushed, msg 2798, assets `41f9a13`). The PAL template lists them exactly as the
  other sources do; the source-template tests hold it to that. No Phase 19 renders; 20-10 no longer depends on
  Phase 19 (20-11 still does). Moved to 20-08: the collaborator's App Store Connect upload, the PAL copy
  (copywriter msg 2785) and its owner approval, and the iPad 13-inch question (no iPad set exists). MKT-18-01,
  DIST-18-02 and CAP-17-05 stay Pending.
- **20-11 Tasks 1 and 2 done (2026-11-11)** (RED `ad510b18b`; GREEN `7f994d323`; `20-11-GATE.md`): OQ-F
  answered by owner msg 3346 ("wait for phase 19 closure. before that, we update the github actions workflow"):
  Phase 19 reaches this branch through `main` after it closes; nothing is merged from or committed to
  `feature/gsd-phase-19`. `actions-tool/require-snapshot-gate.sh <sha> <check name>` reads the commit's check runs and
  passes only for a GitHub Actions run of that name that is completed with `success`. `deploy.yml` (on the PR head)
  and `deploy-pal.yml`'s submit job (on `github.sha`) require it right after Checkout, with `checks: read`. The check
  name is `aggregate` (read from `snapshot-gate.yml` on `feature/gsd-phase-19`, no `name:` on the job); the file is not
  on this branch, so the tests hold both workflows to one shared name and compare it with the file once it is there
  (skipped while absent). **Task 3 (the live read of a real verdict) waits for Phase 19's closure**; 20-11 stays open
  and `20-11-SUMMARY.md` is not written. Open for Task 3: a PAL dispatch on a squash commit on `main` has no gate
  verdict (`20-11-GATE.md`, point 1). REL-18-01 stays Pending.
- **Decision (2026-11-11, owner msg 3501; product lead msg 3502):** the website gets no GitHub Issues link. The
  published contact link is out of the 3.0 plan (ROADMAP Phase 20 item 4 and SC4, D-05, 20-07, 20-08 amended), and
  UGC-18-01 is marked complete. The App Store Connect Support URL is the GitHub repository page,
  https://github.com/EhPanda-Team/EhPanda (guideline 1.5 is a Notarization guideline; 1.2 is not).

## Phase 19 complete, with deferred items — 2026-11-11

Phase 19 (Visual Regression & Daily Live-Parsing Check) is complete at 15/17 plans executed. It is closed the way
Phase 17 was: the executed work is verified and the rest is recorded as deferred, never as satisfied.

- **Executed:** 19-01 to 19-11 and 19-14 to 19-17. 19-10 and 19-17 closed without their hosted parts.
- **Not executed:** 19-12 and 19-13 (owner msg 3428). Their checkboxes stay unchecked in ROADMAP.md.
- **Verification:** `19-VERIFICATION.md` is `human_needed`, 5/8 truths verified. Success criteria 2, 3 and 4 are not
  proven until the deferred hosted runs and the owner's approval happen.
- **Security:** `19-SECURITY.md` is `verified`, `threats_open: 0`: 36 of 40 threats closed, and T-19-24, T-19-25,
  T-19-26 and T-19-27 are accepted-deferred by the owner (msg 3573). Condition: carried with the deferred
  19-12/19-13 screenshot publishing; must be closed before any baseline publication. UF-3 stays open (low): delete
  `origin/ci/snapshot-gate` after run 42951290351 ends.
- **Validation:** `19-VALIDATION.md` is `validated`, `nyquist_compliant: true` under the accepted rules (owner msgs
  3539, 3554 for the UITests first-run flakes and iPad retries; 3425, 3428 for the deferred hosted rows; 3431 for the
  required check). Seven rows stay deferred.
- **Requirements:** VIS-18-01, VIS-19-01, CAP-17-02 and CAP-17-03 stay Pending in REQUIREMENTS.md: the hosted gate
  proof, the baseline and the post-merge live-check runs are still owed.
- **Deferred Items** (below): the green gate run (before release day), 19-12, 19-13, 19-17's hosted regression, and the
  four accepted-deferred threats. The release workflows `deploy.yml` and `deploy-beta.yml` refuse to ship until a
  green `aggregate` check exists on the shipped commit.

Phase 20 merged this state from `main` on 2026-11-11 (OQ-F, owner msg 3346) and carries on below.

## Phase 19 executing — 2026-11-07

- **19-01 complete** (`e35212190`, `fce1558b7`, `69788658f`; `19-01-SUMMARY.md`, `19-01-MEASURE.md`): hosted-window
  capture with settle and one retry, `SnapshotMatrix.xctestplan` (18 configurations), tracer green twice on both
  devices, the 1-point shift caught. iPad captures one orientation per process (iPadOS refuses in-process
  rotation), so 19-02 has 54 shard units.
- **19-11 complete** (`99470c25c`, `fd9d4baa2`; `19-11-SUMMARY.md`): `NativeVisualPolicyUITests` 9/9 with 0
  Repetition nodes on both devices (cold entry at four sizes, live size through the Settings app, turns, reader
  toolbar priority, dialog and menu anchors). On iPad the floating tab bar stands for the title. The class takes
  13 to 15 minutes per device, which 19-10's `native-policy` job must budget for. CAP-17-06 stays Pending (19-17
  shares it).
- **19-02 complete** (`158b8f59c`, `cb42e2264`, `2e684b76f`, `3b0573255`; `19-02-SUMMARY.md`): schema-2
  `scenarios.json` with 137 scenarios, 19,440 expected coordinates and 288 not applicable under four by-design
  rules; D-05 surfaces under `notCaptured`. `snapshot-shards.json` has 20 shards over 54 per-process units (iPad
  split by orientation), largest 1.16 x the mean on the model cost table, with a `runs` list that 19-10's
  `run-shard.sh` should loop over. Group catalog files for 19-05 to 19-08, `ScenarioInventoryTests` (134 IDs without
  a factory yet), `run-snapshot-local.sh`. `VisualMatrixTests.testSelectedCoordinate` needs
  `EHPANDA_VISUAL_COORDINATE` (fails at the base too). VIS-18-01 and CAP-17-01 stay Pending (later plans share them).
- **19-03 complete** (`f042a3d78`, `5714c1cc4`, `8dbf5d0c2`; `19-03-SUMMARY.md`, `19-03-PROBE.md`): the guard-free
  `LiveCheckTests` target (skips unless `EHPANDA_LIVE_CHECK=1`; `test_network_guard.py` checks both directions),
  `runner-probe.yml` and the probe. Owner msg 2397 allowed the push; hosted run 42433098473 on `xcode-27-arm64`
  `20261104.0337.1`: front page, Popular and one gallery 200, no `cf-mitigated`, parsed. Verdict: reachable, so OQ-3
  is not needed and 19-15 can choose the hosted runner. `ci/runner-probe` deleted. The list pages use the app's URL
  builders and parser over a plain GET (their request types POST the gdata title query). VIS-19-01 stays Pending.
- **19-05 complete** (`a9e760cdd`, `a0c12d299`; `19-05-SUMMARY.md`): all 34 browsing scenarios on real views and
  reducers, eight matrix classes. Two compares green on both devices in en-large (phone 132, iPad portrait 66) and
  one each in ja-accessibility5 and de-xSmall on the phone; 0 changed, timeout, error or flaky. About 1.5 s per
  picture on the phone and 1.7 s on the iPad. Toolbar menus open through the bar button's primary action. No
  proposed not-applicable rules. VIS-18-01 and CAP-17-01 stay Pending.
- **19-06 complete** (`97967f85b`, `6602f79a5`, `34dc087a5`, `614667a7e`, `44ba5eaa2`; `19-06-SUMMARY.md`): all 36
  search, Quick Search, Filters, Date Seek, Favorites, Downloads and gallery scenarios on real views and reducers, five
  matrix classes. Two compares green on both devices in en-large (phone 140, iPad portrait 72) and one each in
  ja-accessibility5 and de-xSmall on the phone; 0 changed, timeout or error, 1 flaky (`search-root-empty` landscape
  light, an early settle; risk noted for 19-12). Lists rest at their top before capture; bar menus open through the
  trailing-most bar control. Deviation: the settle now compares reads in the comparison's 8-bit form
  (`HostedWindowCapture`, a 19-01 file). Proposed for 19-10: `favorites-category-menu` not applicable on iPad.
  VIS-18-01 and CAP-17-01 stay Pending.
- **19-07 complete** (`eda416fde`, `5c8417e7f`, `dac4956af`; `19-07-SUMMARY.md`): all 37 Comments, Report form,
  detail page and reader scenarios on real views and reducers, five matrix classes. Two compares green on both devices
  in en-large (phone 146, iPad portrait 72) and one each in ja-accessibility5 and de-xSmall on the phone; 0 changed,
  timeout or error, 2 flaky (`report-form-unavailable` ja landscape light, `reader-slider-scrub` de portrait light).
  Deviation: `SnapshotMatrix.xctestplan` (a 19-01 file) sets SWIFT_DETERMINISTIC_HASHING=1, because Gallery Info's
  Torrent URL query order followed the per-process hash seed. App follow-up: build that query in a fixed order. No
  proposed not-applicable rules. VIS-18-01 and CAP-17-01 stay Pending.
- **19-09 complete** (`0fe8d3c62`, `58c9c092b`; `19-09-SUMMARY.md`): `snapshot_aggregate.py` merges shard results with
  retries, requires one line per expected coordinate (`missing-result` otherwise), fails on any of four classes
  (picture changes, infrastructure errors, drift, baseline mismatches) counted first in fixed order, and `--triage`
  lists only infrastructure failures and missing artifacts, never a retry again; flake log with seconds and attempts.
  `snapshot_report.py` writes the offline report (grouped by screen, five filters, failure triplets, n/a reasons,
  flake log) and `--packet`. 11 + 6 Python tests. VIS-18-01 and CAP-17-02 stay Pending.
- **19-08 complete** (`a3b0cc980`, `db0188b7d`, `0f2031305`; `19-08-SUMMARY.md`): factories for all 30 Settings,
  Settings page and app-wide scenarios on SettingView, SettingReducer and the pages' reducers; 27 captured in four
  classes. Two compares green on both devices in en-large (phone 108, iPad portrait 54) and one each in
  ja-accessibility5 and de-xSmall on the phone; 0 changed, timeout or error, 1 flaky (`app-wide-app-alert` ja
  portrait light). Fixes: Laboratory waits for its glass shadow; the Runs menu holds every list's indicator hidden.
  Proposed for 19-10: the three Login scenarios not applicable (wall-clock wave backdrop) or an app Reduce Motion
  change. Issues for 19-12/19-13: the site-settings error page is blank (ErrorView over an empty ZStack, likely an
  app bug); Account signed in shows the preview cookies marked invalid. VIS-18-01 and CAP-17-01 stay Pending.
- **19-14 complete** (`a6b4eceaa`, `faf6cbff3`, `e42c8df41`; `19-14-SUMMARY.md`): the daily live check reads front
  page, search, Popular, Toplists, a gallery, its reader page and first image, tag suggestions and the Report form
  page as a guest, GET only, 5 s apart; Watched, Favorites and ExHentai are skipped. Pure classification (`ok`,
  `unreachable` for a block, `parser` with a fixed expectation ID for a break); `results.json` schema 1 with enum-only
  page fields. 11 offline tests on saved pages and 11 Python tests (allowlist, no POST). One local run: nine pages
  200 ok. Deviations: the list pages use the app's list URLs and parser over a plain GET (their request types also
  POST); 19-03's `PageObservation` now reads each task's final response. VIS-19-01 stays Pending.
- **19-15 complete** (`6995bee47`, `355901883`, `500f4dffc`, `e76d492ff`; `19-15-SUMMARY.md`): runner GitHub's
  hosted runner (owner msg 2441; probe reachable). `report_issues.py` opens one `Live check: <Page> parser` issue
  per broken page, comments while it stays broken, closes it on the next `ok`; a block never opens one, and three
  unreachable runs in a row open `Live check: cannot reach the site`, closed on the next fully reached run. Strict
  validation before any `gh` call; text only from module templates; 16 Python tests against the recording
  `fake-gh/gh`. `run-live-check.sh --mode hosted|local`, `live-check.yml` (daily 04:17 UTC, dispatch, push to
  `ci/live-check`; contents read, issues write, actions read), the `launchd` template (not installed). Local dry
  run: nine guest pages ok, the fake `gh` got only `issue list`. Nothing pushed; `ci/live-check` is 19-16's, with
  the owner's go-ahead. VIS-19-01 stays Pending.
- **19-16 complete** (`b8dd155ee`, `98bf8a407`; `19-16-SUMMARY.md`, `19-16-DEPLOY.md`): owner msg 2456 allowed one
  push of `ci/live-check` (empty signed `[skip test]` commit `3d58637e6` built in a worktree; `test.yml` skipped).
  Hosted run 42443815779 (`xcode-27-arm64` `20261104.0337.1`, 12 min 34 s) succeeded: nine guest pages 200 `ok`,
  Watched, Favorites and ExHentai `skipped`. The reporter found no previous run and took no action, so no issue or
  label was created. The log and `results.json` hold no URL, title, gallery ID, header or body ("log checked: no
  content"); billable minutes `{}` (public repository). The remote branch, the worktree and the local branch are
  removed. Pending after merge (for 19-17's validation): the first scheduled run from `main`, the previous-results
  path, the 60-day inactivity rule, and the first label and issue. VIS-19-01 stays Pending.
- **19-04 complete, on the interim count** (`f75c1aced` to `e7f373b31`, closing docs; `19-04-SUMMARY.md`,
  `19-04-MEASURE.md`): no hosted run chose a worker count under D-15's rule, so the gate stays at **2 workers on the
  model** (`snapshot-cost.json` `source: model`, `invocationMinutes: 8.5`; shard plan current).
  - **Final run 42533872440** (owner msg 2743, 2 h 40 min, billable `{}`, standard `xcode-27` runner):
    - 7 of 8 jobs failed "Create the pinned simulator" in both attempts: settings writes over 60 s, `bootstatus`
      over 300 s, "device is not booted".
    - `iphone en-xSmall` measured 2.06 s per picture at 2 workers and 2.19 s at 3, then hit its 140-minute step
      limit at 4.
    - `agewall-unticked` was changed twice: a candidate glass button that settled early, by at most 1/255.
    - `front-page-search`'s 15 s focus deadline ran out in 3 of 5 compare attempts.
    - `home-loading` was identical, so the indicator freeze holds on the hosted runner.
    - About 68 minutes went to three step faults: `clear-clones` with no device set, a startup watchdog keyed to
      the log, and a recovered `server died` counted as infra.
  - `ci/snapshot-measure` deleted.
  - **Owner decision open:** fix these and measure once more, or accept 2 workers on the model.
  - VIS-18-01 stays Pending.
- **19-10 closed; its green hosted run is deferred** (owner msg 3425, product lead msg 3426; `19-10-SUMMARY.md`,
  `19-10-PROOF.md`):
  - Tasks 1 to 3 done (`4f61f2af1` to `bac068b98`; the Login gap closed by `30bed51c9`, `9d2eb3c04`): the closed
    inventory, `run-shard.sh`, `snapshot_fetch.py`, `hosted-simulator.sh`, `snapshot-gate.yml` (27 shards, triage,
    retry, native policy, aggregate) wired into `deploy.yml`, `deploy-beta.yml` and `dependencies.yml`.
  - Task 4: hosted runs 1 (42562780142), 2 (42577585956) and 3 (42727781967) failed; each cause was fixed. Run 3's
    fixes: `1877226d3` (runtime wait), `8f830801d` (fixture covers never expire), `dc1e6dfd7` (rotation wait in
    reads), `58a04fb37` (iPad native policy). Run 4 (42951290351, `a100173b5` on `ci/snapshot-gate`) was still
    running at handoff; its result is unread and it was not cancelled.
  - **Deferred** (Deferred Items below): the green gate run, owed before release day, and the hosted runs of
    19-12, 19-13 and 19-17 (owner msg 3428).
  - VIS-18-01 stays Pending.
- **19-17 done, with deferred parts** (`4ab811374`, `b255c6969`, `1240992ad`, closing docs; `19-17-SUMMARY.md`,
  `19-VALIDATION.md`):
  - README rewritten; preview review procedure and validator (8 tests) done; the real preview render is open (needs a
    running Xcode with the preview tools).
  - Controlled regression (Task 3) deferred (owner msg 3428). Required check: not required (owner msg 3431), for now.
  - Local gate: FeatureTests and UITests passed on both devices (0 failures); lint 0; Python suites 384 and 27 OK;
    Release build and `verify-release.py` PASS. UITests had 2 Repetition nodes per device (flaky first runs of two
    accessibility audits, passed on retry), accepted with the retries noted (owner msgs 3539, 3554), so `nyquist_compliant` is true.
  - Phase 19 was closed afterwards with deferred items (section above).

## Phase 19 planned: Visual Regression & Daily Live-Parsing Check — 2026-11-07

`/gsd-plan-phase 19`: research (`19-RESEARCH.md`), 17 plans in 8 waves and the validation strategy
(`19-VALIDATION.md`). Plan-check passed: plan structure valid for all 17, failure directions ok, all 28 CONTEXT
decisions covered, no duplicate threat IDs, every requirement (VIS-18-01, VIS-19-01, CAP-17-01/02/03/06) mapped.

- **Waves:** 1: 19-01, 19-11 · 2: 19-02, 19-03 · 3: 19-05 to 19-09, 19-14 · 4: 19-04, 19-15 · 5: 19-10, 19-16 ·
  6: 19-12 · 7: 19-13 · 8: 19-17.
- **Owner checkpoints:** 19-03 (hosted probe push), 19-04 (hosted measurement, billing), 19-10 (hosted proof on a
  `ci/` branch), 19-12 (candidate run; creating the public snapshot repository), 19-13 (the one approval; the push),
  19-15 (live-check runner), 19-16 (first real run), 19-17 (hosted controlled regression; required check on `main`).
- **Open risks:** E-Hentai may refuse GitHub runner IPs (19-03 decides); hosted cost and the 5-job concurrency limit
  (19-04); candidate artifacts expire after 7 days, so approval must follow 19-12 within that window; storage above
  5 GB returns options to the owner before the repository is created.

Next: `/gsd-execute-phase 19` (wave 1). Phase 18 closing checks (UI review, UAT) remain open.

## Phase 18.1 complete: Native report form — 2026-11-07

`/gsd-verify-work 18.1`, agent-run (owner rule msg 1652): verification passed 6/6 (`18.1-VERIFICATION.md`) and UAT
10/10, all auto-covered and rerun on both simulators (`18.1-UAT.md`).

- **Rerun:** FeatureTests phone 1806 (1796 passed, 10 expected failures, 0 failed), pad 1806 (1797 passed, 9
  expected failures, 0 failed), 0 Repetition nodes. Every 18.1 UI suite passed on both devices; copy checks and the
  cookie-logging audit pass.
- **Fixed:** `GalleryCardUITests` tapped the Settings tab by a glyph identifier the tab bar no longer lists; it now
  taps the tab by its label (`99a2436a5`, test only).
- **Gaps outside 18.1 (for the lead):** the pad's `DeepLinkSchemeUITests` page-link cases fail in the full plan after
  a landscape test on the same clone (pass alone 8/8); the pad FeatureTests run held live TCP 443 connections to
  e-hentai.org from four test bundles. Unverified: OQ-2 (signed-in email prefill), OQ-1 (the site's reply).

Next: Phase 18 closing checks (UI review, UAT). Phase 19 is not started.

## Phase 18.1 inserted and planned: Native report form — 2026-11-06

The owner chose EhPanda's own report form over the site's page as the first route (owner msg 1931, card 1929,
"Our own form"). Phase 18.1 was inserted after Phase 18 and planned; Phase 18 stays complete (verified 10/10) and its
plans are unchanged. Only its UI-SPEC (Colo's final spec, msg 1978, with C-13 and C-1 "No bar background") and its
mockups (01–04, 16–18 and 20 re-rendered; 25–31, 33 and 34 added; 32 withdrawn) were refreshed.

- **Decisions:** comment reasons are child and other illegal content only (owner msg 1950); the pinned bar has no
  background (owner msgs 1955, 1965); Camo's copy is approved (owner msg 1975, final file msg 1977) and its six
  gallery-only strings do not ship; there are no gallery reports, now or later, unless distribution is blocked
  without them (owner msg 1975); the live test runs on the real site with Proxyman blocking the report (owner msg
  1933), run by an agent (owner msg 1652).
- **Plans:** Wave 1: 18.1-01 (parser, report URL, requests), 18.1-02 (23 strings, copy check). Wave 2: 18.1-03
  (reducer, routing). Wave 3: 18.1-04 (view, stubs, a UI test per C-13 state). Wave 4: 18.1-05 (gate, then the
  agent-run live check, the phase's only checkpoint).
- **Done (2026-11-07):** all five plans. 18.1-05's gate is green on both devices and in Release, and its live check
  passed: under owner msg 2066 and the tool change (mitmproxy, Pluso's technical call), one tap on Send made exactly
  one POST to gallery 4308676's `?report=other` URL, built as the site's form and answered locally; nothing was
  forwarded and no report was filed. OQ-2 (signed-in email prefill) is unverified.
- **Open, non-blocking:** what the site returns after a real report (Research OQ-1, default DD-03); frame 26 showed a
  leftover "Spam:" in Details (resolved: the refreshed frames, committed with 18.1-04, use the illegal-content
  wording); `report.reason.choose` is approved but unused by C-13 (for the lead).

Next: `/gsd-verify-work 18.1`.

## Phase 18 split into three phases; Phase 18 context gathered — 2026-11-05

The owner split the original Phase 18 into three phases (msg 1753, card msg 1748). Nothing was dropped; the split
map is at the end of the ROADMAP Phase 18 section, and REQUIREMENTS.md traceability names each requirement's phase.

- **Phase 18: In-App 3.0 Readiness: Age Wall, Analytics Choice, Comment Moderation & Reader Rework.** AGE-18-01,
  CONSENT-18-01, UGC-18-01 (report, posting warning, blocking), DIST-18-01 (`MKSellsDigitalGoods`), the reader
  page-tracking rework with the G1/G2 UI tests, and IN-02/IN-03. The directory was renamed to
  `phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/`.
- **Phase 19: Visual Regression & Marketing Export.** VIS-18-01, MKT-18-01 (384 export, final selection,
  regeneration), CAP-17-02, CAP-17-03, the moved parts of CAP-17-01/04/06, the six-per-period Toplists fixtures and
  the `Scripts/visual/README.md` rewrite. It covers the Phase 18 screens.
- **Phase 20: 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks.** DIST-18-01 (flavor),
  DIST-18-02, DIST-18-03, DEV-18-01, REL-18-01, MKT-18-01 (store screenshots and promotional images, CAP-17-05),
  UGC-18-01 (published contact link), the repeated Release isolation scan and, as the last plan, ANALYTICS-02. The
  install source needs the marketplace build, so the analytics revision sits there.

Owner decisions of 2026-11-05 (msgs 1753, 1765, 1767, 1780):

- **First launch:** two screens, everyone once (age wall, then the analytics choice), with None / Basic / Full and
  none pre-selected. The age-wall sentence is the approved website sentence (msgs 1454, 1457) with no examples.
- **Comments:** reporting goes to E-Hentai only, with no in-app contact option now (msg 1774). The posting filter
  warns and allows posting anyway. Blocked comments collapse, and a Blocked Users list goes in Settings.
- **Marketplace build:** same features, PAL only.
- **Tagging:** "Tagging is not your business"; tag and release-order decisions are dropped.
- **Copy:** the approved six-language copy is committed in the Phase 18 directory as `18-COPY-FIRST-LAUNCH.md` and
  `18-COPY-COMMENTS.md`.
- **Design:** the designer Colo owns the layout spec (msg 1757), so Phase 18 UI execution waits for a UI-SPEC
  (`/gsd-ui-phase 18` or his spec).

Phase 18's discuss step is done: `18-CONTEXT.md` and `18-DISCUSSION-LOG.md`, with the prep kept as
`18-DISCUSSION-PREP.md` (L10 updated per msg 1753). `19-CONTEXT.md` and `20-CONTEXT.md` hold the owner decisions for
those phases; their discussions have not run yet. Planning documents only; no app code.

Next: `/gsd-plan-phase 18`. UI tasks depend on the UI-SPEC.

## Phase 17 complete — 2026-11-05

Phase 17 (Screenshot Automation, Visual Regression & OS 27 Modernization) is complete at its reduced
scope (owner msg 1305): 13/13 in-scope plans have summaries; the 11 moved plans keep `status: superseded`.
The GSD close steps are done:

- **Verification:** 17-VERIFICATION.md `passed`, 8/8 truths (round 5, `7566b1001`; tested source `891103afa`).
- **UAT:** 17-UAT.md complete, 31/31 passed, 0 issues (`458a16d5b`).
- **Security:** 17-SECURITY.md `verified`, 39/39 threats closed, `threats_open: 0` (F-17-FX-01 accepted, owner msg 1667).
- **Validation:** 17-VALIDATION.md `validated`, `nyquist_compliant: false`: gaps G1 and G2 are open on purpose
  (the WR-01 and RTL runtime checks used throwaway harnesses).

Requirements: CAP-17-04 (amended) and CAP-17-07 (amended) are complete, as are the Phase 17 parts of CAP-17-01
and CAP-17-06. CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/04/06 are in Phase 18. They
were moved, not satisfied.

**Moved to Phase 18** (ROADMAP Phase 18; 17-VERIFICATION.md `deferred`):

- **Step 4b:** the reader page-tracking rework (owner msg 1630, product lead msg 1631), plus committed reader UI
  tests for G1/G2: the WR-01 rebuild paths (Reload All Images, then a page turn; a reading-direction change during
  Auto-Play) and RTL page sync.
- **Steps 2 and 3:** the first-launch age wall (AGE-18-01) and analytics consent (CONSENT-18-01). Both are
  standards for every build (Deferred Items below).
- **Steps 5 to 9:** visual regression (VIS-18-01) and the marketing/AltStore work (MKT-18-01, DIST-18-02).
- **Step 7:** review items IN-02 and IN-03.
- **Context item 8:** the `Scripts/visual/README.md` rewrite.

Carried risk: the fixture repository's current layout (`8ee4fc2`, `f71d108`) is not pushed (R4-3). Pushing is
the owner's decision.

Next: Phase 18 has no CONTEXT.md and no plans. The workflow routes to `/gsd-discuss-phase 18`, which has not
been started.

## Live Text fixtures retained; fixture repository holds only the current set — 2026-11-05

Re-verification human item 3 is decided. The owner kept the six Live Text fixture versions behind the
current website set and their translation records (msg 1645). Then the owner asked that the fixture
repository keep only the latest copies (msg 1647). Fixture repository commit `8ee4fc2`:

- **Added.** The six Live Text versions, with their translation records.
- **New index.** `website-capture-20261104.json` names the fixture behind each of the 118 approved
  files. It is built from the website provenance record at `d4393bd`.
- **Removed.** The 11 versions the current set does not use, and `website-capture-20261102.json`.
  The `data/` archive stays.
- **Carried to Phase 18.** `Scripts/visual/README.md` ("Approved website fixtures", 2026-11-02) still
  describes `website-capture-20261102.json` and `readerByLocale`. No code reads them (checked: no reference in
  Scripts, AppPackage or UITests). Rewrite that section with the Phase 18 capture work; it is left as is so
  the Phase 17 source stays the tested `891103afa` tree.

17-FINAL-VALIDATION.md section 3 names the versions. ROADMAP Phase 17 criterion 2 now also cites the
2026-11-04 approval (msg 1581). The reader root-cause analysis is committed as 17-READER-ROOT-CAUSE.md;
Phase 18 Step 4b points to it.

## Phase 17 records corrected per owner decisions (msg 1640) — 2026-11-05

The verifier's 17-VERIFICATION.md (`7900db15e`) is `human_needed`. The owner decided five of its human
items (2, 3, 4, 6 and 7) on 2026-11-05 (msg 1640); the records now say so (docs only).

- **Page-sync stress.** ×5 on both phone and iPad at `891103afa` (40/40 each) is accepted as a known
  limit. The ×20 phone run is at `e745f38f6`, before the WR-01/IN-01 fixes.
- **Stale `requirements-completed`.** 17-01, 17-02 and 17-24 no longer claim CAP-17-02, CAP-17-03 or
  CAP-17-06; each summary has a correction note.
- **CAP-17-04** means the current website image set: the 2026-11-04 recapture (118 files serving the
  192 coordinates, owner msg 1581; website repository `d4393bd`). See 17-FINAL-VALIDATION.md section 3.
- **Accepted:** the CAP-17-07 unclassified-edge classification and the synthetic-comment exception
  (comment 9000000001 by CedarComet91 on gallery 2758456, and the edited image B).

Also corrected: the 17-VALIDATION.md banner now names `891103afa`. 17-FINAL-VALIDATION.md section 9
says that no Debug negative-control scan ran at `891103afa`; the last one ran at `97b31b063`. 17-23's
note on 17-VERIFICATION.md is corrected, and the 17-LAYOUT-AUDIT.md ReadingView line numbers are dated
to `24edc450d`. The Phase 18 roadmap now carries the reader rework, IN-02 and IN-03.

Next: the verifier updates 17-VERIFICATION.md, then UAT, secure-phase and validate-phase.

## Phase 17 code review fixed; gate repeated at `891103afa` — 2026-11-04

The phase code review found 0 critical, 2 warnings, 3 info. WR-01 (the reader's page-turn gate
survived a pager rebuild) and IN-01 are fixed (`92181ccd2`, `18ec91b86`); WR-02 is not a gap (owner,
msg 1627); IN-02 and IN-03 are deferred to Phase 18. Every 17-23 check except the Debug negative-control
scan passed again at `891103afa`, with ReaderPageSyncUITests ×5 on phone (40 of 40 passed, 0 retries)
and iPad (40 of 40 passed, 0 retries). Known limit: both devices ran ×5 at `891103afa`, not just the
iPad (owner-accepted, msg 1640).

**Carried to Phase 18 (owner msg 1630, product lead msg 1631).** Rework how the reader tracks its
current page: one source of truth for the page shown and the number displayed, as one task, not more
patches.

Next: the verifier's 17-VERIFICATION.md, then UAT, secure-phase and validate-phase.

## 17-23 reduced-scope gate passes — 2026-11-04

At `97b31b063` every 17-23 check passes, and Phase 17 has executed 13 of 13 plans. The GSD close steps
are next.

- **FeatureTests.** iPhone Air 1526 passed, iPad 1525 passed, 0 failed, 0 Repetition (9 and 10 expected failures; the iPad's extra one is the known SettingReducerTests timing issue).
- **UITests.** iPhone Air 68 passed, 20 skipped; iPad 71 passed, 17 skipped; 0 failed, 0 Repetition.
- **Lint.** Strict lint finds 0 violations in 759 files.
- **Release scan.** Repeated at `97b31b063`, because the reader fixes changed the built source: exit 0, 0 findings; the launched probe can't activate capture.
  The Debug control finds 991. The scanner tests give 19 OK.
- **Reader page-sync stress.** ReaderPageSyncUITests ×20 on the iPhone Air at `e745f38f6`: 160 of 160 passed, 0 retries.
  ×5 on the iPad at `97b31b063`: 40 of 40 passed, 0 retries.

**What it took.** Reader fixes found by the gate: `adbd63809`, `8f0d09fff`, `2539331b2` (indicator
and screen agree after a slider drag), `4372e4b8f` (cold opening on the resume page), `346a3ea87`
(landscape after the soft bottom edge). The reader also gained a soft bottom edge (`90d6a6339`) and
hides the home indicator with its controls (`e745f38f6`).

**Known limits.**

- The iPad page-sync stress ran 5 iterations, not 20 (owner's choice, 2026-11-04). At the closing source
  `891103afa` both devices ran ×5 (owner-accepted, msg 1640; see the 2026-11-05 entry).
- Page-sync tests don't cover right-to-left reading or an iPad landscape spread.
- The slider still seeks live during a drag; the indicator stays correct.

[Evidence](phases/17-localized-screenshot-capture-harness/17-FINAL-VALIDATION.md),
[summary](phases/17-localized-screenshot-capture-harness/17-23-SUMMARY.md).
Next: the Phase 17 close steps (code review, regression gate, verification, UAT, secure, validate).

## 17-14 T2 Release isolation gate passes — 2026-11-03

At `1829841d8` every T2 check passes.

- **Release scan.** The Release build has 0 findings, and the launched probe can't activate capture.
  The Debug control finds 991. The scanner tests give 19 OK.
  - The builds come from a worktree at `ef625c0cb`, which has the same app and extension source.
  - The worktree was removed after the evidence was recorded.
- **Lint.** Strict lint finds 0 violations in 756 files.
- **FeatureTests.** 1522 cases on iPhone Air and on iPad Pro 11-inch (M5). 0 failed, 10 expected
  failures, 0 Repetition.
- **UITests.** 88 cases, 0 failed and 0 Repetition: 68 passed on the iPhone, 71 on the iPad.

**What it took.**

- Two app bugs were fixed:
  - `d8567a8f8`: a Library or gallery list returns the row a person saw to the top after a layout
    switch.
  - `ef625c0cb`: the open Auto-Play menu is no longer rebuilt on page turns.
- Test fixes:
  - quick task `261103-test-plan-repairs`;
  - `7ede42c85`, `900501eaf` and `b24f8b3dd`;
  - `1829841d8`. The two landscape Library tap tests left the iPad in landscape, so DeepLinkScheme's
    page-link tests opened a two-page spread. `1829841d8` restores portrait. It was not an app
    regression.

**Known risks** (none failed the final gate):

- `ReaderPageProbe` can't read an iPad landscape spread.
- One diagnostic iPad run saw two failures that did not recur:
  - the long-press "Inspect downloaded pages" in `testDownloadManagementInBothLayouts`;
  - the Front Page title in `testFrontPageAudit` (Show All).

[Evidence](phases/17-localized-screenshot-capture-harness/17-RELEASE-ISOLATION.md),
[summary](phases/17-localized-screenshot-capture-harness/17-14-SUMMARY.md).
Next: 17-23, then the Phase 17 close steps.

## 17-19 Settings, Detail routing and idiom census complete — 2026-11-03

`TabBarSettingPresentationTests` passes on iPhone Air and on iPad Pro 11-inch (8 cases each, no Repetition).
A second simulator pass at HEAD's source recorded what the first pass couldn't, because the stub
then had no `api.php` route. Detail is a 580×660 pt sheet at iPad full width. It pushes, with Back
and the tab bar, in a 375 pt iPad window and in iPhone landscape. Settings is a sheet only at full
width. All of this matches D02. Every hit of the idiom grep has a census row. On 2026-11-03 the
owner chose to keep all five places (msg 1409, answering msg 1408): the reader lower Close, the
Library sidebar, the Home title, the device name in error details and the Duo/iPad capability. No
change plan follows, and no app source changed.
[Audit](phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md),
[summary](phases/17-localized-screenshot-capture-harness/17-19-SUMMARY.md).
Next: the 17-14 T2 behavior gate, then 17-23.

## 17-14 T2 Release isolation run, behavior gate open — 2026-11-03

The Release simulator build of `9805537a9` ships and activates no capture facility.
`Scripts/visual/verify-release.py` passes it with 0 findings and finds 991 on the Debug build. Its 19
tests pass, including a seeded bad payload (RED `eadb4e8a1`, GREEN `7af68d0e6`, evidence
`035c4a65b`). Strict no-cache lint is clean. **T2 acceptance is not met:** FeatureTests fail 2 cases
on the phone and 7 on the tablet; UITests fail 23 on the phone and 26 on the tablet, with Repetition
nodes. Most UITests failures come from `9da595d93`: its new `POST /api.php` list metadata request
has no route in `UITestStubURLProtocol`, so Home and Favorites show "Couldn't Read Page". Fixing it
is app/test code, outside this plan, and needs orchestrator direction. 17-14 is not marked complete.
Quick task 261103-test-plan-repairs has since repaired these failures in tests and test support, without changing the
app. T2 still needs a fresh run.
[Evidence](phases/17-localized-screenshot-capture-harness/17-RELEASE-ISOLATION.md),
[summary](phases/17-localized-screenshot-capture-harness/17-14-SUMMARY.md).
Next: the owner's 17-19 keep/change answers and orchestrator direction on the 17-14 behavior gate.

## 17-18 landed Search and Downloads routing verified — 2026-11-03

Search and Downloads taps send `openGalleryDetail` to the app root, which applies the same
both-regular rule (Downloads' modal is seeded from the download); `routeGalleryDetail` has no
reference left and GalleryNavigation keeps `presentationEffect`, `nextScreen` and
`appendGuardingDuplicate`. The migration's Downloads diff is routing-only, so the manifest, deletion
and dialog-anchor rules are untouched. AppDownloadDetailRoutingTests, DownloadAutomationTests and
GalleryNavigationTests pass on iPhone Air then iPad Pro 11-inch (11 cases each, no Repetition). No
app source change. The census items 17-16 to 17-18 hand to 17-19: Home's Duo split-layout read
(`HomeReducer.usesSplitLayout`). [Summary](phases/17-localized-screenshot-capture-harness/17-18-SUMMARY.md).
Next: 17-19 (owner keep/change checkpoint).

## 17-17 landed Home and Library routing verified — 2026-11-03

Home and Library (Favorites) gallery taps reach `AppReducer.openGalleryDetail`, which presents a
sheet only when `WindowSizeClasses.presentsModally` (both classes regular) and pushes otherwise;
`605b4e4749` is an ancestor. GalleryDetailRoutingTests and CaptureRouteTests pass on iPhone Air then
iPad Pro 11-inch (15 cases each, no Repetition). Home's `.compactHeight` entry has no test of its own
(shared helper covered by the other hosts); Home's Duo split-layout read goes to the 17-19 census.
No app source change. [Summary](phases/17-localized-screenshot-capture-harness/17-17-SUMMARY.md).
Next: 17-18.

## 17-16 landed view layouts verified — 2026-11-03

Home Toplists, Search keywords, TagSuggestion, GalleryCardCell and NewDawn read size classes, the
system's suggestion placement or container fitting at HEAD; `e03456839a` and `30ef583d21` are
ancestors and an idiom grep over the five files finds nothing for the 17-19 census. HomeFeatureTests
and SearchFeatureTests pass on iPhone Air then iPad Pro 11-inch (90 each, no Repetition). No app
source change. [Audit](phases/17-localized-screenshot-capture-harness/17-LAYOUT-AUDIT.md),
[summary](phases/17-localized-screenshot-capture-harness/17-16-SUMMARY.md). Next: 17-17.

## Phase 17 reduced, Phase 18 added — 2026-11-03

Owner msg 1305 closes Phase 17 small. CAP-17-04 is amended to the 192 owner-approved website images
of 2026-11-02 and CAP-17-07 to the size-class migration that already landed through quick task
`261015-duo-session-record`, before snapshot coverage existed. Plans 17-07 to 17-13, 17-15 and
17-20 to 17-22 carry `status: superseded` with a pointer to Phase 18; 17-14 keeps only its T2
Release isolation check, 17-16 to 17-18 become short verifications of the landed layout, 17-19
becomes the census of the remaining idiom reads with an owner keep/change checkpoint, and 17-23 is
rewritten as the reduced-scope report. CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of
CAP-17-01 and CAP-17-06 map to Phase 18; they are moved, not satisfied.

Phase 18, "3.0 Release Readiness: Age Wall, Consent, Marketplace Distribution & Visual
Regression", is the remaining 3.0 phase (owner msgs 1287, 1289, 1294, 1299, 1305). New requirements:
REL-18-01, DIST-18-01, AGE-18-01, CONSENT-18-01, UGC-18-01, VIS-18-01, MKT-18-01, DIST-18-02,
DIST-18-03, DEV-18-01, ANALYTICS-02 (44/44 mapped). The ROADMAP holds a twelve-step outline with its
owner checkpoints; PLAN files come from `/gsd-plan-phase 18`.

Per owner msg 1307, Phase 17 is not marked complete and no VERIFICATION.md is written here. Next:
execute the remaining Phase 17 plans in order (17-16, 17-17, 17-18, 17-19 with its owner
checkpoint, 17-14 T2, 17-23), then the GSD close steps: the `/gsd-execute-phase 17` phase gates
(code review via `/gsd-code-review`, regression gate, and the `gsd-verifier` agent writing
`17-VERIFICATION.md`), `/gsd-verify-work 17`, `/gsd-secure-phase 17` and `/gsd-validate-phase 17`.
Planning documents only; no app code, build or simulator run.

## History compaction — 2026-11-03

The owner requested fewer commits. The 106 unpushed commits on this branch become 72, rewritten
in place with SHA references repaired in each historical snapshot; the existing final documentation
commit carries this record and no commit is appended. Planning-only commits moved forward to join
their record, and every commit keeps the non-planning tree of its last original commit, so earlier
build and test evidence keeps its stated scope and no new build or simulator run is claimed. The
base commit is unchanged. No remote push.

## Approved Comments screenshot matrix — 2026-11-02

Owner approved the complete 192-image screenshot set after the 14-comment composite on gallery
2758456 was applied. All 24 Comments coordinates now show the initial position with CedarComet91's edited
B image fully visible in the third row. Comment text and author names contain no Chinese; interface
and date labels follow the selected locale. The other 168 images are retained. All 192 artifacts
and browser routes passed checks; the full local review is `/comments-20261102/`. Synthetic
insertion and image-edit provenance are preserved in the private fixture repository, with the
approved routing in `website-capture-20261102.json`. See the [approval record](quick/261101-website-review/APPROVAL-20261102.md).
Both task simulators were removed. No publication.
[Plan and verification](quick/261101-website-review/PLAN.md).

## Comment parser — 2026-11-02

Comments no longer show `&gt;` or literal tags such as `<strong>`, and they now render the author's bold, italic,
underline and strikethrough. The parser took its text from serialized HTML, so it now walks the DOM (`965c53d5a`) and
keeps the styles in an `AttributedString`, which native `Text` draws together with its links (`cf0573b00`). Chinese and
Japanese italics stay upright, and editing a comment drops its styles. Underline and strikethrough were not seen in the
running app. The final 24 website Comments captures use the updated parser and styles. [Quick task](quick/261102-comment-parser/SUMMARY.md).

## Website reading-language refresh — 2026-11-02

Reading and Live Text now share the requested source-language book per screenshot locale; real Apple
translations target that locale in both groups. Comments uses gallery 3845660's image-bearing first
comment at the initial position. Recaptured 72 coordinates; the complete 192-image local review
passed artifact and browser checks. Existing literal `<strong>` comment markup is annotated for
owner review. No publication or visual approval is implied.
[Record](quick/261101-website-review/LANGUAGES-20261102.md).

## README cleanup and copy audit — 2026-11-02

Screenshots is gone from all six READMEs and System Requirements is now a small note under Installation. The audit's 96
copy edits are applied, two sections are now Disclaimer and Community, and Community sits under Installation. No native
speaker reviewed German, Japanese or Korean. [Quick task](quick/261102-readme-copy-audit/SUMMARY.md).

## Search range indicator setting — 2026-11-02

The E-Hentai settings section now mirrors the site: its question as the header, and a picker with Normal and Disabled
in place of a toggle, in all six languages. The section was rendered but not seen inside the running app, because that
page needs a login. A side-by-side pass then corrected the page's zh-Hant and zh-Hans strings whose meaning differed,
leaving differences of wording and regional vocabulary. [Quick task](quick/261102-search-range-setting/SUMMARY.md).

## Gallery rating display — 2026-11-02

Gallery Info now shows the average to two decimals and the user's rating to one, instead of truncating them. The parser
takes the site's average rather than the half-star image, which also corrects the Detail page, and a half-star rating
reopens correctly in the rating control. The File Size row keeps its decimals and shares a format with the Detail page.
The live site was not checked.
[Quick task](quick/261102-rating-display/SUMMARY.md).

## Home test repairs — 2026-11-02

The Home tests that failed regardless of other work now pass. Three were stale, along with a fourth stale test that is
skipped by default. One exposed a real bug: the first portrait-to-landscape rotation on iPhone left the previous
gallery in the carousel's center, now fixed. VoiceOver now walks all six carousel cards both ways (`bea94f1cd`); its
rotation offset remains open. The Duo suites passed in an owner-approved serial run before that fix, after three more
stale tests were repaired; none of them checks the carousel's selection across rotation. `DuoHomeUITests` and
`DuoToolbarUITests` passed again on the fix in a second approved run.
[Quick task](quick/261102-home-test-repairs/SUMMARY.md).

## App-wide copywriting audit — 2026-11-02

The audit is applied in all six locales, with changed English terms renamed through keys, files and types while stored
and wire names stay. After the owner found languages drifting apart, every key was compared side by side, so copy now
matches across languages in concept and scope. Six locales were checked on iPhone Air screens at the default text size;
the E-Hentai settings page contents, iPad and larger text sizes were not rendered, and no human native speaker has
reviewed the result. Marketing and website screenshots are stale. [Quick task](quick/261101-copy-audit/SUMMARY.md).

## Consolidated tag database — 2026-11-02

All five tag datasets now come from one repository, `EhPanda-Team/ehpanda-tag-database`, whose pipeline runs the OpenCC
conversion. The app compares its own language's asset digest and no longer depends on OpenCC. The repository is public,
and a live simulator download passed for all five languages on 2026-11-02.
[Quick task](quick/261102-tag-database-consolidation/SUMMARY.md).

## Legacy search toggles removed — 2026-11-01

Live comparisons on E-Hentai and ExHentai showed the six Filters toggles no longer affect results
(`f_sdt2` by indirect evidence only), so the owner chose to remove them, along with `f_sr` and `f_sp`. No
schema change is needed. 24 Filters website screenshots are affected and not yet recaptured.
[Quick task](quick/261101-remove-legacy-search-toggles/SUMMARY.md).

## Toplists spacing review — 2026-11-01

Stars now match the pages caption style; category/pages/rating use fixed 4-point gaps.
Build and lint pass, and the native iPad screenshot is ready for owner review. Uncommitted
continuation recorded in the adaptive Home summary.

## Cover-tinted light-mode slideshow card — 2026-11-01

The focused light-mode Home card now shows its cover gradient through `CardGradientTint`, which
keeps each palette hue at OKLCH chroma ≤ 0.035 (owner's option 2a, chosen in the simulator over the
paler 2f) and pays for chroma with lightness, so every color carries the gray fallback's weight and
the card's text keeps its contrast (within 0.2%); hues past the sRGB gamut keep the most chroma that
fits. Unselected cards keep the gray fallback. Light-mode Home baselines change; not promoted.
[Quick task](quick/261101-slideshow-light-tint/SUMMARY.md).

## Readable dark-mode slideshow gradient — 2026-11-01

Owner chose the per-color design: `CardGradientCeiling` dims each cover-palette color above a knee
in linear light (hue kept) so the focused dark-mode card's white and secondary text stay readable.
Ceilings hold for every sRGB hue, because ColorfulX's Lab blends take hues the palette lacks:
L* 32.2 standard, 27.1 with Increase Contrast (the approved mockup's gray-derived 41.1 failed
saturated colors). Light-mode tinting followed as its own task (above).
[Quick task](quick/261101-slideshow-dark-ceiling/SUMMARY.md).

## iPad slideshow title alignment — 2026-11-01

Owner-requested regular slideshow titles now fill available height with top-leading alignment,
matching the compact title policy. The two-line reservation is removed; metadata retains its
intrinsic height. Toplists stars now use footnote while rating digits retain subheadline. The owner requested
committing both changes and their records after build and lint validation; see the
[adaptive Home summary](quick/261101-home-adaptive-tags-covers/SUMMARY.md).

## Reviewed Home and translation work committed — 2026-11-01

Owner requested committing the outstanding changes: Home tags/proportions/covers `3bdd9865e`;
Live Text translation replay `388b68ec6`. Signatures verified. The 52 Python fixture tests pass.
Fresh Duo/iPad Home captures are complete: 14 configurations, 111 native PNGs, two verified ZIPs.
The merged iPad refresh row is visible in the expanded layouts.
[Recapture evidence](quick/261101-home-poses-review/SUMMARY.md#refresh-fix-recapture-r2--2026-11-01).
Owner visual review remains pending.


## iPad top-bar Reload fixed — 2026-11-01

UIKit merges a tab's navigation bar into the iPad top tab bar only while the NavigationStack is the
tab's sole child controller. `HomePaneSheet`, a `UIViewControllerRepresentable` beside Home's stack
since `8c332e2a2`, broke that and dropped Reload to y=100. The owner chose moving it into the stack's
root content (`350773d46`): Reload shares the tab row (y=36), pushed Home pages merge Back and their
items too, and iPhone and Duo frames are unchanged. A UI assertion guards the row.
[Quick task](quick/261101-ipad-reload-row/SUMMARY.md). A pure SwiftUI probe on 27.2 matches the
half-open Duo sheets, including nested ones. Fully open sheets cross the fold unless sized with the
system's outer margin, which the SDK does not expose, and placement does not update on presented
sheets. The owner keeps `HomePaneSheet`; revisit only when the SDK closes both gaps.
[Probe results](quick/261101-ipad-reload-row/SWIFTUI-SHEET-SPIKE.md).

## Native iPad refresh placement experiment — 2026-11-01

Owner-requested same-row experiment did not succeed with semantic placement, a direct single-column
navigation container, or the browser toolbar role. All experiment source edits restored. No refresh
UX change retained; prior accepted work preserved. Evidence and details are in the adaptive Home summary.

## Home slideshow aspect ratio — 2026-11-01

Owner-selected maximum width/height ratio is approximately 2.74:1 (751/274). Height-derived width
ceilings replace the previous wide-landscape threshold. Native compact window: 562 × 205; regular
landscape: 751 × 274. Both builds, strict lint and 39 focused cases pass. Standard iPhone review app
updated and left running; changes remain uncommitted. See the adaptive Home summary below.

## Adaptive Home tags and covers — 2026-11-01

Owner-directed follow-up implements fitting-only compact slideshow tags and caps oversized
Frontpage covers to their slideshow counterparts. Build, strict lint and 27 focused layout cases pass.
[Implementation and native evidence](quick/261101-home-adaptive-tags-covers/SUMMARY.md). Changes remain uncommitted.

## Home pose screenshot review — 2026-11-01

The owner requested whole-Home screenshots for Duo and iPad Pro, expanded to Stage Manager,
Split View and portrait/landscape windows. [Capture matrix and evidence](quick/261101-home-poses-review/SUMMARY.md).
This review does not change Home source, final generation authorization or the rendering pin.

## Translated Live Text screenshots approved — 2026-11-01

The owner rejected recognition-only highlights and requested original lettering replaced by translation.
Debug replay now binds recorded Apple Translation responses to recognized groups, uses the normal
layout/renderer and waits for completion. Both page-12 captures (Japanese → English and English →
Japanese) pass and were approved by the owner. 20 focused Swift tests, 52 fixture tests and strict lint pass. Heading OCR/translation
quality and the large fallback plate remain visible review findings. See
[review evidence](quick/261101-live-text-review/SUMMARY.md). Changes remain uncommitted.
Final generation/locale selection and rendering-pin decisions are pending; Phase 17 gates remain unchanged.

## Home screenshot review accepted — 2026-11-01

The owner accepts the final iPhone Home review and requests committing the work. Compact slideshow
metadata, typography and matching Frontpage covers are implemented; gallery 3600779 is the selected
center in fixture `marketing-a6157bfafd6db913` (local fixture commit `83f9adb`). The final native light
screenshot has no Dynamic Island capsule or charging indicator. Build/lint and the native capture
pass; the cover-layout suite passed at its recorded source boundary. See
[review record](quick/261101-phone-slideshow-review/SUMMARY.md) for evidence and limitations.

**Next: Live Text screenshot review.** The current fixture contains book 4217037; the owner's second
selected book is 4223235 and its review composition remains to be decided. Final screenshot generation,
rendering-pin changes and website publication remain outside this acceptance. Phase 17 gates are unchanged.


> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## History cleanup - D145, 2026-10-27

The owner requested removal of a local simulator-tool name throughout tracked project content
and removal of image files from planning history. The 126 commits in the selected range are
rewritten in place, with SHA references repaired in each historical snapshot. Two fixed-clock
commit dates are reconstructed on October 24; see the [cleanup record](quick/261015-duo-session-record/SUMMARY.md#history-cleanup-and-test-clock-correction--d145).

## Duo session record — 2026-10-15

The complete Duo/landscape session decisions, superseded choices, implementation ledger, retained verification and historical wide-screen proposals are in [261015-duo-session-record/CONTEXT.md](quick/261015-duo-session-record/CONTEXT.md). This retrospective record does not complete Phase 17. Branch migration is tracked separately there.

The follow-up [Library design](quick/261015-duo-session-record/LIBRARY-DIRECTION.md) is implemented by quick task [261015-tx1](quick/261015-tx1-implement-library-with-shared-favorites-/261015-tx1-SUMMARY.md): shared category navigation with separate Favorites/Downloads groups, independently remembered row/grid choices and a regular grid replacing waterfall. Current validation records 959 FeatureTests identities, 6/6 UI tests on each of iPhone/iPad/Duo, native resize/fold checks and bounded accessibility evidence. D120 keeps the current Search design and closes the earlier A/B selection. D121 reorders its sections and keeps empty placeholders visible; D122 reserves minimum height for empty content and D123 top-aligns its text. D124–D126 add section spacing, equal keyword-row heights and native Remove All actions; see [the follow-up](quick/261022-search-section-placeholders/SEARCH-ACTIONS.md). D127 removes nested whitespace to make the section gaps consistent; D128 increases their shared value to 32 points; D129 doubles it to the current 64 points ([measurements](quick/261022-search-section-placeholders/EQUAL-SECTION-SPACING.md)). Phase 17 status is unchanged.

D130–D132 extend Home section information to iPhone and introduce the native glass Library source
picker. Duo uses the phone layout in portrait at every posture, plus closed landscape; only
partially/fully open landscape keeps the sidebar. iPad retains its sidebar. See
[implementation, screenshot and verification boundaries](quick/261015-duo-session-record/PHONE-HOME-LIBRARY.md).
The three review apps are running; owner visual acceptance remains pending. D133 now shows only
the source-picker symbols while retaining localized Labels. D134/D135 request a title menu and
a long-press tab sheet. The owner requested a closed-title screenshot and authorized custom-bar
research; [findings and screenshot](quick/261015-duo-session-record/CUSTOM-TAB-BAR-FEASIBILITY.md)
are recorded. D136 rejects custom-bar implementation and retains the system tab bar. D137 clarifies
that Library and the source-menu subtitle must occupy one navigation-title region, superseding the
earlier separate-position alternatives. A native `.largeSubtitle` Menu with `.inlineLarge` renders
that composition; the system reduces the title font size to fit the subtitle.
[Native screenshot and verification limits](quick/261015-duo-session-record/LIBRARY-SUBTITLE-MENU.md).
D138 asks to retain the original system circular arrow. D139 accepts it beside Library and requests
the complete composition with `.inlineLarge`. Native title-menu probes on 27.0 and 27.1 render no
arrow in that mode, including explicit indicator visibility; the `.inline` controls show it.
D140 now explicitly authorizes an app-drawn circular arrow. A native `.largeTitle` Menu prototype
combines it with the Library title, source subtitle and `.inlineLarge`; actual light/dark captures
are recorded in the same report. Production integration remains pending; no different title mode
or custom tab bar is approved.
See [the tested native prototype and screenshot](quick/261015-duo-session-record/LIBRARY-TITLE-MENU.md).
D141 adds [20 multi-device initial/scroll screenshots](quick/261015-duo-session-record/LIBRARY-TITLE-MATRIX.md).
The custom title Menu disappears after scrolling in every captured case; this is an unresolved
prototype behavior, not owner acceptance. D133 remains the approved implementation.
D142 verifies a [persistent native inline alternative](quick/261015-duo-session-record/LIBRARY-TITLE-PERSISTENCE.md)
across the same 10 configurations. Its title mode and iPad vertical placement differ from D141;
acceptance and production integration remain pending.

On 2026-10-28 the owner requests the final persistent title design with the custom system-style
arrow. [Quick task 261028-hi0](quick/261028-hi0-adopt-native-bottom-bars-enforce-paralle/UI-IMPLEMENTATION.md)
restores it on compact Library roots. After briefly requesting both controls, the owner explicitly
chooses to remove the bottom-right switch and keep only the title menu. This final decision
supersedes the pending-integration status above; the expanded sidebar retains its existing titles.

D143 integrates all 107 commits from `agent/app-design` into `feature/gsd-phase-17` by fast-forward,
preserving original commit IDs and GSD references. The consolidated target is `feature/gsd-phase-17`;
the `agent/app-design` worktree and branch remain available. This integration does not approve or
implement the pending D142 title alternative and does not complete Phase 17.
See [integration verification](quick/261015-duo-session-record/SUMMARY.md#phase-17-integration--d143)
and the earlier [workspace rebuild](quick/261015-duo-session-record/WORKSPACE-REBUILD.md).
D144 subsequently normalizes author and committer offsets to UTC+8 while preserving their Unix
timestamps. SHA references are repaired within each rewritten commit; the range remains 108
commits. See the [rewrite record](quick/261015-duo-session-record/SUMMARY.md#utc8-history-rewrite--d144).

Library follow-up: D75 keeps the native sidebar and records the unresolved header displacement;
D76 restores the working hide/show toggle, initially expanded. See
[header investigation and reproduction](quick/261015-tx1-implement-library-with-shared-favorites-/HEADER-STABILITY.md).
This supersedes D69's fixed-open policy and does not claim a header fix or change the Phase 17 gate.

D77 removes the generic Downloads sidebar link; actual folders and native section actions remain.
`b2d1d602dc` passes the focused compact navigation regression, clean build/lint and iPad folder entry.
See [folder-only entry evidence](quick/261015-tx1-implement-library-with-shared-favorites-/SIDEBAR-ACTIONS.md#folder-only-navigation-follow-up--d77).

D79–D80 originally delivered transparent aligned cards and default-on simplified titles for every row/grid list.
D119 retires simplification throughout lists and Home; see [the current removal record](quick/261015-tx1-implement-library-with-shared-favorites-/REMOVE-SIMPLIFIED-TITLES.md).
D81 (`428897f452`) corrects all four cover corners to rounded, uses the reference's 2117:3000 ratio and
limits grid titles to two lines. Two focused final UI tests pass across iPad/iPhone standard and
AX1/AX3/AX5; builds/lint clean. The earlier 97 model and four UI tests remain tied to `7b58987a7d`.
See [grid and title evidence](quick/261015-tx1-implement-library-with-shared-favorites-/GRID-TITLES.md).
The updated iPad remains open with its original data and the proposal preview remains available.

D82–D84 (`8b2f03519b`) remove horizontal grid metadata padding, hide Library grid ratings only, and
move Downloads actions into the native card context menu. Five focused iPad/iPhone UI tests pass;
builds/lint are clean. D85's floating-inspector question is investigated, with no presentation
replacement selected. See [current grid refinements](quick/261015-tx1-implement-library-with-shared-favorites-/GRID-LIBRARY-REFINEMENT.md).

D86 (`cb029d6db0`) and D87 (`658ba665b2`) are historical, rejected presentation trials. Their original
functional results and screenshots remain in the [sheet report](quick/261015-tx1-implement-library-with-shared-favorites-/FLOATING-PANEL-PROTOTYPE.md)
and [inspector report](quick/261015-tx1-implement-library-with-shared-favorites-/NATIVE-INSPECTOR-PROTOTYPE.md).

D88 (`b20b6ff8a43d45d8c05d04dcdfb203699201fb9c`) reverts all non-documentation changes since D86, restoring the pre-trial
source tree at `019b598a66`. The owner rejects the sheet effect, inspector transparency and recurrence
of the top-background continuity issue. D82–D84 remain active. See
[rollback scope and verification](quick/261015-tx1-implement-library-with-shared-favorites-/PRESENTATION-TRIAL-ROLLBACK.md).

D89 (`c484eb3a0aa4dde4eed037e071b74d5f6c153b20`) implements Library single-tap Detail and double-tap reading for Favorites
and Downloads, row and grid. Fifty feature tests and five final iPad/iPhone UI tests pass with clean
builds/lint; the original review iPad is updated. See [tap behavior and evidence boundaries](quick/261015-tx1-implement-library-with-shared-favorites-/LIBRARY-TAP-ACTIONS.md).

D90 (`2f5706b0cfa24a5e880cdc301b3a457b153632b8`) aligns row titles, adds Detail/Previews thumbnail backgrounds, and makes
grid menus management-only with an opaque card-preview container. iPad verification passes;
iPhone landscape first-item menu activation remains unresolved and has an independent native
reproducer. See [results and limits](quick/261015-tx1-implement-library-with-shared-favorites-/LIBRARY-VISUAL-POLISH.md).

D91 (`ee11c8e800474bddfb5cb1054870ccb9ae9c242f`) restores iPad Home to one pane, ordinary section navigation and regular rankings;
Duo Home and independent reader controls remain active. Verification includes 44 passing feature
tests, the four-size iPad layout case and the final Home carousel/audit check, with exact source
boundaries and intermediate failures preserved. See [rollback record](quick/261015-duo-session-record/IPAD-HOME-ROLLBACK.md).

D92–D94 explore richer Home section information for iPad and future macOS at larger widths.
[Sketch 001](sketches/001-large-home-information/README.md) provides three alternatives and
screenshots. D98 selects C slideshow with B elsewhere; D99 subsequently authorizes implementation.
The owner fixes the framework and makes the original brief the reference, with no further Mac
App Store inspection. The original comparisons remain historical.

D99–D100 (`1cc211aee6158251c5ae3533cc59a22e33af1dc2`) originally delivered the selected B+C Home and shared simplified titles; D119 retires title simplification.
Fifty feature/model tests and native iPad UI checks pass within their recorded source boundaries.
Four-size iPad/iPhone captures, initial title blank frames and LLVM tooling diagnostics are retained.
The review iPad has the final app; Phase 17 remains unchanged. See
[quick implementation and verification](quick/261017-pjj-implement-b-home-sections-with-selected-/261017-pjj-SUMMARY.md).

## Project Reference

See: .planning/PROJECT.md (updated 2026-11-05)

**Core value:** The load-bearing paths — fetch, parse, read, download galleries — keep working; every task is a foundation change held to behavior/appearance parity.
**Current focus:** Phase 20 — 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks (Phases 17, 18, 18.1 and 19 complete; Phase 19 with deferred items)

## Current Position

Phase: 20 — 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks
Plan: Not started (no plans yet)
Status: Ready to discuss and plan; Phase 19 complete with deferred items
Last activity: 2026-11-11 — Phase 19 closed (15/17 plans; deferred items recorded)

Phase 17 closed with 13/13 in-scope plans, verification passed 8/8, UAT 31/31, security verified and validation
validated. Phase 18 closed with 12/12 plans and verification passed 10/10 (`18-VERIFICATION.md`); Phase 18.1 closed
5/5. Phase 19 closed 15/17 with deferred items (`19-VERIFICATION.md` `human_needed`, `19-SECURITY.md` `verified` with
four threats accepted-deferred, `19-VALIDATION.md` `validated`). Phase 20 has an owner-decision CONTEXT file and no
plans.

**2026-11-03 scope reduction (historical):** see the section "Phase 17 reduced, Phase 18 added" above. The 17-06 owner review is superseded by the owner's 2026-11-02 approval of the complete 192-image website set. The older Phase 17 gate notes below are historical; their "6/24" counts and "next" pointers are superseded.

**Previous activity (2026-10-28, historical):** Quick task 261028-hi0 restores Release `-O` after the owner requests dropping the size-optimization commit. Preview cleanup remains; the earlier 12.35% saving describes the withdrawn experiment, and current size is unmeasured. Approved bottom edges and Archives safeAreaBar are implemented, with the final persistent Library title menu and custom circular arrow. The implemented gallery contains 18 comparison pairs and 18 additional captures. Serialization lint policy, normal parallel test plans and fixture repairs are verified; the owner deferred the device-bound runner exception discussion. Quick task incomplete; Phase 17 unchanged.

**2026-10-29 local review delivery:** The owner-requested gallery proposal now fills all 31 Home slots, and 32 fresh English/Large/portrait screenshots cover eight screens on iPhone/iPad in light/dark. The local review preserves the earlier batch and notes. [Capture evidence and website-owner handoff](phases/17-localized-screenshot-capture-harness/17-06-REVIEW-20261029.md) record the exact scope and remaining pin/preflight limits. Owner visual acceptance remains pending; Phase 17 stays 6/24, with no baseline promotion or 17-07 execution.

**2026-10-29 cover-ratio follow-up:** The owner's exact 0.707:1 cover proportion now replaces the former fixed/grid ratios without changing heights or reader/page previews. Sixteen galleries exceeding 10% crop loss were replaced; all 32 active covers pass the exact-rational audit (maximum 9.2212%). The updated fixture and 32 native screenshots pass independent data/frame checks. [Implementation, evidence and limits](quick/261029-cover-ratio/SUMMARY.md) record passing focused tests, both additional iPad UI tests, and the Duo download-launch UI failure reproduced on unchanged source. The updated main app builds and launches successfully. The local website owner has the new batch; earlier screenshots/notes and partial-archive labels remain preserved. This does not change the Phase 17 gate.

**Phase 17 current gate:** 6/24 plans complete. 17-01 passed 32/32 capture coordinates and 66/66 tests; verified public v2 fixtures are in `.capture/regression`. 17-24 measures all four real device/orientation combinations and validates the immutable tracked rendering pin. Both final measure and validate commands pass four geometry tests plus six rotation/restore tests, with 28 Python contract tests and zero compiler/lint diagnostics or runtime warnings. Pin SHA-256: `ffd7689fcaf9a312202fdfbf9787f0198711fd477d1e72a2a013851df85a394a`; evidence is `.capture/environment-measurement/` and `.capture/environment-pin-check/`. Implementation ends at 3e69dc69d3; summary/review committed in fb83037387. Four reserved staged entries remain unchanged. Devices restore portrait/original Large and their original boot states. Continue inline with 17-06; shared CAP-17-01/02/03/04/06 remain incomplete until all declaring plans finish. No baseline promotion.

**17-02 complete:** The final complete tracer `.capture/tracer-matrix-10/` captures all 576 coordinates on pin `5c507a4c…725c` (592 native invocations, all passing); its independent audit finds no problem: 2,088 reads with every owned-row digest matched, no settle pass changing a read, 3,456 artwork images exact, 576 distinct images, unchanged references and reserved entries, restored devices. The final-source gate `.capture/owned-row-gate-04/` passes 32/32 with 63/60 native tests. Owner approvals during Task 2: owned-row verification and full-content settle, Reduce Motion in the pin, Vision boxes kept to their analyzed windows (17-02-PLAN.md). Task 2 source: `6c588338c3`, `13a3645646`, `2cee63a9b8`, `990024a798`, `bee89ee82e`, `8eaea1f8ad`, each verified in a temporary tree of exactly its contents (`.capture/commit-trees-03/`). Summary: 17-02-SUMMARY.md; review: 17-02-REVIEW.md, no open finding. No baseline promoted; candidate output stays under `.capture/`. Four reserved staged entries are preserved. Next: 17-03.

**17-03 complete:** The agent assists with provisional gallery selection, review and fixture acquisition for both nonexplicit and explicit content sets; the owner confirms the final selection at Phase 17 closure. `acquire-fixtures.py` acquires an owner-declared selection anonymously into a scrubbed, checksummed, content-addressed version under the ignored `.capture/marketing/`, publishing atomically through one locked writer; `fixtures.validate_fixtures` repeats the derivation over stored files and `fixtures.resolve_fixtures` gives readers one version; `selection-review.py` writes a self-ignoring ledger and contact sheet and approves nothing. Source: `508ded6f33`, `f8114d4db8` and review fixes `d0db858a78`, `3c68e49c65`, `fa524f0a28`; 126 Python tests pass (`.capture/17-03-isolation-green-01/`), mutants killed 22/22, 18/18 and 5/5. Summary: 17-03-SUMMARY.md; review: 17-03-REVIEW.md, no open finding. Later the owner asked for random IDs (nonexplicit limited to Non-H): the agent sampled 60 Non-H galleries (seed 4767476936933364992), excluded 1 by tag and rejected 13 in visual review, and acquired the provisional nonexplicit set as `marketing-fdcb0fc6d3c54a29` (42 assets, valid review, `.capture/marketing-selection-01/`, `.capture/marketing-review-01/`). The agent assists with provisional gallery selection, review and fixture acquisition for both nonexplicit and explicit content sets; the owner confirms the final selection at Phase 17 closure. The pinned iPhone was found Booted by another process (a `sim-use` daemon, 2026-10-06T17:25Z); it was left as found and must return to Shutdown before the next simulator gate. Four reserved staged entries are preserved. Next: 17-04, which can use the nonexplicit fixture now; the agent prepares the remaining explicit fixture.

**17-04 complete:** A Debug-only capture launch takes exactly `EHPANDA_CAPTURE_CONFIGURATION` and `EHPANDA_CAPTURE_FIXTURES`, validates one fixture version completely (exact file set, lengths, SHA-256, canonical paths, links, media types, selection identity, aggregate digest) and installs an isolated offline scene before the first store: in-memory settings, inert cookie, download, analytics and logging clients, fixed clock and IDs, capture-owned reader, Kingfisher and SDWebImage caches emptied at every launch, and an exact-URL `GET` replay that refuses and records every other request. The `home` scene shows the selection through the owner-approved injected `HomeClient`; UI tests read `CaptureDiagnostics` from the invisible `capture_diagnostics` element. `CaptureIsolationUITests` shows exactly the 17 selected galleries offline, ready with no pending image or refused request, across a reset relaunch on both pinned devices; Release builds contain no capture code. Owner decisions (17-04-PLAN.md): initial nonexplicit fixture, agent-assisted selection for both sets, injected Home client, carousel arrangement in the live client, no cover on the Toplists skeleton. Source: `72f29f5f88`, `2c63c45c27`, `fbd71f24bc`, `74159f1861`, review fix `2ea65ac65f`. Summary: 17-04-SUMMARY.md; review: 17-04-REVIEW.md, no open finding. Carried to 17-05: the dark Home card gradient differs between launches (likely `ImageColors` tie order; a fix needs an owner decision before 17-05's cold-rerun gate) and readiness must cover the dark card's color analysis. The iPhone was found at AX5 and restored to Large; owner states hold. Four reserved staged entries are preserved. Next: 17-05.

**17-05 complete:** Marketing drives the actual app to all eight capture screens through its own navigation (`AppLaunchAutomation.CaptureRoute`), verifies each screen and every image through per-screen `CaptureDiagnostics`, and `MarketingCaptureUITests/testCaptureCoordinate` checks one JSON coordinate (T1: 12 coordinates on both devices, `.capture/17-05-t1-ui-04/`; Live Text and Downloads wait for 17-06). T2's `Scripts/visual/capture-native.py` validates the tracked pin before any launch, sets the status bar (9:41, Wi-Fi 3, cellular 4, charged 100), opens and quits Settings once, and runs two single-pass cold launches; each test settles the system screenshot (`XCUIScreen`, two identical renders a second apart) and attaches it, and the runner takes it from the launch's result bundle as the frame. Final gate on `051cc01132`: Home iPad light and iPhone dark each record byte-identical frames (`.capture/17-05-t2-native-09/`, `-10/`), 9:41, no capsule. The gate on `1fc626c2f5` had failed on iPad: simctl's framebuffer keeps Liquid Glass as last composed, and one of 17 cold launches recorded a glass rim one level off while every system screenshot matched (`.capture/17-05-t2-glass-probe-01/`). Owner decisions (17-05-PLAN.md): card color determinism, Large iPhone, detail-continued routes, the reader's full request set, the paging reader, the reader cache in `isCached`, the iPad date 2026-01-01 9:41 ("Sat Jan 1"), dedicated "EhPanda Visual" simulators resolved by name (the former pinned pair is unused), a Settings launch before captures (the first app after a boot shifts iPad's Wi-Fi glyph half a point), and system screenshots as frames (2026-10-09). Source through `051cc01132`, each commit verified in a temporary tree (`.capture/commit-trees-05/` to `-08/`); summary 17-05-SUMMARY.md; review 17-05-REVIEW.md (R-1 to R-8 fixed), no open finding. Open: explicit-set preparation (agent-assisted), whether the status bar should follow each coordinate's locale (17-07, owner). Four reserved staged entries are preserved; both visual simulators are Shutdown. Next: 17-06.

**17-06 implemented, owner review pending:** The reading-live-text and downloads screens show real state. Live Text is recognized once by the app's own recognizer on the pinned iPhone (`Scripts/visual/record-live-text.py`, `MarketingCaptureUITests/testRecordLiveText`, out through the diagnostics), saved as a fixture record (groups, lines, corners, IDs, page SHA-256, recognition languages, recording simulator) and replayed in every capture through the Debug-only `LiveTextCapture` seam and the reader's real overlay with Vision off. Acquisition saves the download galleries' page files; a downloads scene seeds capture-owned folders through the app's `DownloadStore` with those files and their SHA-256 manifests, and the app's own scan reads them back, completeness from the manifest alone. Owner decisions (17-06-PLAN.md, 2026-10-09): Live Text from a recording saved in the fixture, download page files, files beyond the plan's list. Fixture `marketing-4f2a1ba8efe6f7cb` (8 groups, 35 lines, `en-US`). All 16 coordinates (eight screens, English light, both visual simulators) captured with byte-identical cold reruns (`.capture/17-06-g-native-*/`); plan commands pass on both devices, every FeatureTests target except the bare VisualSnapshotTests passes, the isolation UI test passes on both visual simulators, and Release holds no capture string. Source `cf7f783e2d` to `4aa3300991`, each commit verified in a temporary tree (`.capture/commit-trees-09/` to `-14/`); summary 17-06-SUMMARY.md, review with no finding. Open: the owner's visual review of the 16 frames (sent 2026-10-09), explicit-set preparation (agent-assisted), the status bar locale question (17-07). Four reserved staged entries are preserved; both visual simulators are Shutdown.

**Reader fixes between 17-06 and its review (2026-10-10 to 10-12):** owner-requested work on the vertical reader, outside the 24 plans: `975ff2040f` (vertical resume at the top), `54773df8f3` (pages as one VoiceOver element), `3f46dd7b90` (status bar scroll to top), `f60234f0f9` (unloaded strip pages sized by width), `b67a01b712` (the list's own positioned page), `aa50f7ac3a` (UI tests restore orientation in teardown blocks), `a9730dbe08` (Auto-Play menu bound to its state), `c8b1786f74` (lint catches `.init(get:)` closure bindings), `4f6e3a0d1d` (positioned page kept on resize), `c519161f7e` (list frames read in content space), `c07920b5aa` (strip width from the offer), `eb257647a3` (pages sized from known sizes), `0e1934c988` (resumed page kept through turns), `68acf229f9` (MPV original sizes), `a45bee6085` (live-resize drift recorded as a known limitation). Owner decisions: no persistence of seen sizes; MPV sizes adopted; SwiftUI cycling diagnostics during resizes accepted; a slow Stage Manager drag through several widths can leave the positioned page one or two pages off (pre-existing, also before the realign), recorded as a known limitation. Of the owner's budget of ten self-chosen reader changes, five are used (six if the owner-adopted MPV change counts). Evidence: `.capture/known-sizes/`, `.capture/reader-size-change/`, `.capture/strip-width-source/`, `.capture/stage-manager-probe/`, `.capture/autoplay-menu/`.

**17-06 owner review (2026-10-13), changes requested:** the owner reviewed the 16 English light frames and decided: iPad stays in the matrix; the reading screen uses the vertical reader with its control panel shown (replacing the 17-05 paging-reader decision); the Live Text screen hides the panel and uses its own gallery, an English-original Non-H gallery that also exists in other languages (non-English locales translate the English page; the English locale uses another language version translated into English); Home Frontpage holds 10 galleries and Downloads 6, so Home needs 25 distinct galleries (Downloads may reuse them); the status bar shows 9:41, full signal and battery 100% not charging. The 17-06 frames show English light only; locales and dark mode are 17-07's 384 outputs. Revision order (owner go-ahead 2026-10-13): this record, the visual simulators' health, the capture changes as separate commits, the nonexplicit reselection, then a re-capture of the 16 coordinates for review; the Live Text frame keeps today's highlight until the translation overlay exists. Split off as separate owner-run sessions: a Live Text translation overlay (independent feature outside the reader budget; private APIs allowed) and a reusable screenshot CLI for other apps. The agent prepares the explicit set at the new counts alongside the nonexplicit set.

**`.capture` pruned (2026-10-13, owner-approved):** 31 GB to 4.1 GB. Removed: DerivedData build products inside run folders; `tracer-matrix-02` to `-09` (superseded; `tracer-matrix-10` kept); every `.xcresult` bundle dated before 2026-10-13 outside the fixture and environment folders (extracted frames, JSON and logs kept); `reader-drift-*` experiments; superseded unreferenced attempts (`17-05-t1-ui-01` to `-03`, `17-04-t2-gate-01`, `17-04-capture-tests-02`, `17-05-t1-unit-01`, `17-04-home-client-01`, `17-05-t1-experiment-01`). References to those paths in historical sections and phase documents now point at removed evidence.

**17-06 revision progress (2026-10-13):** capture changes, each verified in a temporary tree of exactly its files (`.capture/commit-trees-50/` onward): `d688e8fe4b` (battery not charging), `7335da9352` (the reader's page indicator stays in narrow windows: iOS 27 drops a `.title` toolbar item that does not fit), `45df76a6fb` (vertical reader with its panel), `ba699e50f3` (Live Text on its own gallery, without the panel), `d0f4048ea8` and `ea8544391d` (Frontpage 10, Downloads 6). After the first re-shoot the owner asked that the iPad lists fill too: `9456b3a32d` (Frontpage 16 in eight pairs, Downloads 7; Home shows 31 distinct galleries) and `46b7eb82d1` (download covers preloaded into the capture's Kingfisher cache at install, so a row below the screen no longer blocks readiness; the owner chose this over a recording cache subclass). Both visual simulators were erased in place with the owner's go-ahead and set up again. Nonexplicit selection `provisional-random-nonh-3` (`.capture/marketing-selection-03/`) keeps the hero, Toplists, the flow on `1979820` and Live Text on page 10 of `3615767` (the owner kept the page), and adds six Frontpage galleries and one download from the same seeded Non-H sample; fixture `marketing-ecd98e7a1571af1f`. Cold-launch flips: the Detail rating's empty star differed by one level between some cold launches on both devices. The cause is the stats strip's per-item `.drawingGroup()`, an iOS 15-era addition: 2 of 12 baseline launches differed, while 24 of 24 without it were byte-identical, and the visible change is sub-pixel antialiasing only (`.capture/agent-work/star-probe/`). It was removed in `099222846e` (owner decision, replacing the earlier "known phenomenon" choice, which rested on a hypothesis the evidence refuted). Laboratory on iPad once differed on nine Liquid Glass rim pixels of Home's "Other" cards behind the sheet. The owner decided that every sheet screen (Filters, and Detail, Comments and Laboratory on iPad) is compared across cold launches only within the sheet, while the published frame stays whole: `af00e0da93`. The app reports the top sheet's screenshot pixels from UIKit, the UI test requires a sheet exactly on sheet coordinates, and `capture-native.py` decodes the PNG to compare the sheet's pixels (AppFeatureTests 111/111, Python 185). Third re-shoot `.capture/17-06-t-native-*`: 16/16 captured, every pair of cold launches byte-identical, and sheets reported exactly on the five sheet coordinates. Review sheets: `.capture/17-06-t-review-sheets/`. Open: the owner's visual review of these frames; the explicit set (the agent prepares provisional IDs for both content sets; validate them with `acquire-fixtures.py` and `selection-review.py`); the iPad Toplists gap between Yesterday and Past Month (pre-existing layout); the status bar locale question (17-07). Four reserved staged entries are preserved; both visual simulators are Shutdown.

## Historical round-2 status snapshots

The following snapshots preserve earlier decisions and provenance. Their pending, open, current-position and implementation wording is historical: the current position above and the latest sweep owner sign-off supersede it. In particular, `f68610b270` removed the contrast helper, `ColorContrastTests` and added visible glyphs; no reverted implementation is credited as current.

Phase: 16 (dynamic-type-accessibility) — EXECUTING
Plan: 26 of 26 — Plan 16-25 walkthrough closure is closed with carried items; 16-26 D-25 measurement/documentation is complete, current-runtime closing gates passed, Task 3 owner sign-off remains; plans 16-01 through 16-25 complete — 25/26 plans complete
Status: Round 2 executing — current closure and carry-forward status are recorded above. Historical colour, audit, and candidate context follows: round-2 colour decisions recorded 2026-09-11 in `16-CONTRAST-AUDIT.md § Decisions`: `STARS=B CATEGORYCELL=A HC=A D28=ok CONTEXTMENU=not-exposed` (CONTEXTMENU is a simulator accessibility-tree read via agent-device, not a device rotor pass). D-26 contrast foundation landed (plan 16-14): `Color+Contrast.swift` in `AppTools` and the 84-variant colorset invariant with the standard-44 pin `f940492a…5363` (never changes) and the HC-40 pin, re-pinned by 16-15 under HC=A from `e81b0604…0937` to `84accf72…9407` after the 19 `lower` Increase Contrast entries were rewritten (0/40 HC variants below standard). Plan 16-15 also made both badge sites adaptive (`CategoryLabel`, `CategoryCell` as a `Button` + `.isSelected`; CATEGORYCELL=A, no visible cue). Historical D-25 candidates included `#32 Activity Logs` and `#36 Laboratory`, but the 2026-09-17 superseding ruling below limits current rendered scope to Search root, Favorites and Watched; Gallery Detail remains withdrawn. 16-23 closed every `D28=ok` id and `STARS=B` (RatingStar and CommentLink module colorsets, the `Color.mix` idiom, the Read glyph via the 16-14 helper; `log-glyph-error` fixed at the use site; the comment-link underline built at all three link-run sites; 16-22's deferred entry closed) with after-measurements in `16-CONTRAST-AUDIT.md § 16-23 result (contrast)` — no residual, no screen added to D-25. Of the two items 16-16 handed to the orchestrator, the tag-cell `.contextMenu` was routed to 16-19 and is now mirrored (`accessibilityActions` from the menu builder in `DetailView+Subviews.swift`); Torrents / Archive counters announced as bare numbers (the glyph was the unit) remain open for the owner. 16-19 established that SwiftUI exposes `.swipeActions` as custom actions and does not de-duplicate named mirrors — later plans mirror only context-menu-only items. Round 1 signed off (owner `approved` 2026-09-11T08:35Z, `16-SWEEP.md § Owner sign-off`). 16-24 closed the automated audit gate (D-31): stable audit types only, two allow-list entries, green on iPhone 17 iOS 26.5 and iPad (A16) iPadOS 26.5; the seven login-gated surfaces go to 16-25 and the D-25 re-sweep; iPadOS 27 beta Gallery Detail stall deferred.
Last activity: 2026-10-17 — D89 implements Library single-tap Detail and double-tap reading; 50 feature and 5 native UI tests pass; builds/lint clean; review iPad updated; Phase 17 unchanged.

**Current owner dispositions:** W-8 and W-35 were approved on 2026-09-22; VO-3/W-13 Comments retain their Apple-bug disposition. W-38 was approved on 2026-09-23 after the longer screen recording and is now closed. Its earlier additive-repair request and request for a current reproduction are superseded; no reader source patch is pending. The exact approval is in `16-SWEEP.md § Owner W-38 approval`. This is not whole-phase approval.

**W-38 evidence boundary:** The approved 1-to-41 recording uses native VoiceOver Scroll Down commands via Quick Nav, followed by a VoiceOver double-tap to show the controls. It is not a 40-page Next Item walk, a physical-device check or proof of an OS-upgrade cause. The earlier read-only debugger trace confirmed the existing idle callback calls `PageModel.update` during native VoiceOver movement on iOS 27. No observer, restored global synchronization or source/test change was introduced.

The following carry-forward paragraph records the historical 2026-09-21 status; the focus and W-38 approvals above supersede its open-item wording.

**Phase 16 carry-forward:** W-38 remains open and unfixed. Its 2026-09-19 position-synchronization fix was withdrawn by the owner on 2026-09-21 for last-page jitter and is retained only under `withdrawn/w38-fix-20260921`. Injected-clock autoplay and the tests comparing the visible page with its indicator remain. The formerly red iOS 27 Settings import test now passes with controlled asynchronous test input; the complete FeatureTests plan is green on both iOS 27 device classes. VO-3 and W-13 Comments retain the owner's Apple-bug disposition with no Image-label workaround adopted. W-35 still awaits the recorded owner choice; W-8 remains the deferred SpringBoard Screen Changed issue with no app-side lever identified. This quick task does not approve Phase 16 or A11Y-02.

**2026-09-17 D-25 scope correction.** The prior Activity Logs/Laboratory candidate description is historical. After
`f68610b270` reverted `1d34681a`'s rendered glyph/HStack changes, the effective current D-25 rendered scope is exactly
three W-22 screens: Search root, Favorites and Watched, using nine planned iPhone-portrait XXL / AX3 / AX5 cells.
Gallery Detail remains withdrawn; Activity Logs retains only an accessibility combine modifier and Laboratory has no
post-revert diff. Historical status at that correction was Task 7 in progress across 24/26 completed plans; current status is
documented above. The 45 → 65 Settings tap and long-press
owner ruling is unchanged.

## Historical P-VO1 handoff (superseded by c0e123c4e9 / 6f226cb1e8 and the recorded traversal amendment)

The following handoff is retained as historical evidence. Its `unverified` and `No commits` wording describes the state at that earlier handoff.

P-VO1 handoff: patch applied to `AppPackage/Sources/HomeFeature/HomeView+Sections.swift`, unverified. Strict no-cache SwiftLint found 0 violations and exited 0; isolated Xcode 26.6 before/after builds passed. The first full FeatureTests run was accidentally broader than the approved only-testing scope and failed at `DownloadContinuedSessionHeartbeatTests.heartbeatIsIdleWithoutPendingWork()` with exit 65 after a simulator diagnostics timeout; no retry. Its verified target counts were AppToolsTests 13 passed and HomeFeatureTests 24 passed, with Repetition nodes 0; the later scoped heartbeat fix run completed 489 tests / 84 suites with 8 known issues and Repetition 0. Escalated WALK preflight and install-over succeeded; the original 40-step VoiceOver walk reached Frontpage at step 8 and Toplists at step 34 but not the tab bar by step 40, so that criterion remains unmet. A diagnostic walk reached the tab bar at steps 54–58 and stopped at step 86 after an explicit-next repeat of Setting/Tab/5-of-5; no unsolicited focus reset occurred. Exact Frontpage-heading previous reached the last hero card. After relaunching the app into the foreground, six ordinary coordinate swipes each advanced one hero and the sixth returned to the starting hero; screenshots are retained under `$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo1/`. An initial cold-launch before/after pair mismatched because the reducer shuffled the six-card fixture. Under the authorized measurement-only deterministic variant (temporary removal of `shuffle()`), before and after used the same reducer ordering and settings on `GATE_IPHONE`; before hash `464842639170f44a3a266ef1d38a8ab4f659c581622cb3f6bc98267230064491`, after hash `295eabb300431141d63518f397ca9d3718ae6286fe9a5d543936cc05d61542a0`, and the visual difference was limited to asynchronous image rendering (`changed_fraction=0.07217472`, mean channel difference `0.21640442`). The reducer was restored to exact hash `5b4eb50046160ee3b4a1f4ae27fd6a4a00ec2d7535ec93ba9ba1a0107fb87f78`; no variant was committed. No commits. Initial lint reported 0 violations but exited 1 because of cache plist permission; the subsequent `--strict --no-cache` run succeeded with exit 0. In 16-25, Tasks 1–5 and Task 6 steps 1–2 completed, including VO-2 regression evidence and the `visible(_:)` hidden-content fix (`0645a87513`, `35904cfc97`, `8f8490f804`, `a618d0b100`).

Round-1 state: closed and signed. 38 findings — 32 `re-verified`, 6 `accepted` (#4, #7, #31 on 2026-09-08; #23, #35 on 2026-09-09; #37 system defect), 0 `open`. D-13 5/5 dispositioned (1–3 fixed 2026-09-09, 4 fixed 2026-09-11, 5 accepted 2026-09-09). The 504-cell matrix (397 pass / 95 historical finding references / 12 n/a) is stored historical results; `16-TARGETED-RECHECK.md` and `16-LOGIN-COVER-RECHECK.md` are sampled evidence, not a matrix replacement. Do not re-ask any recorded disposition. The sweep simulators recorded in `16-SWEEP.md § Infrastructure` no longer exist in the simulator inventory; round 2 must re-derive UDIDs.

D-01 amendment 2 authorizes agent-written fixes; the original owner-only implementation restriction is superseded. All five Dynamic Type lint rules (`no_dynamic_type_size_modifier`, `no_geometry_reader`, `no_fixed_system_font_size`, `accessibility_hardcoded_string`, `no_minimum_scale_factor`) are live at error severity with the tree at 0 for each. A11Y-01 is complete; A11Y-02 (round 2) is open; the phase is not complete. Do not push without the owner.

Progress: [███████████████████░] 319/321 plans ([█████████░] 90%), excluding the 11 superseded Phase 17 plans. GSD
counts 19 of 21 phases complete: Phase 6 is recorded as "Delivered (rescoped)"; Phase 19 is complete with deferred
items and Phase 20 has not started.
Phase 17 has 13/13 in-scope plans complete. Phase 18 has 12 of 12 plans complete (18-01 to 18-12). Phase 18.1 has
5 of 5 plans complete. Phase 19 has 15 of 17 plans executed (19-12 and 19-13 are deferred, owner msg 3428); Phase 20
has no plans yet. They keep the milestone open.
18-12's gate passed on `e3c95a3bf`, and its Task 3 live
report-page check passed on 2026-11-05 17:51Z, verified by an agent per owner rule msg 1652 (`18-12-SUMMARY.md`).
Phase 18 verification passed 10/10 on 2026-11-05 at `a1f96cb88` (tested source `e3c95a3bf`; `18-VERIFICATION.md`).

## Performance Metrics

**Velocity:**

- Total plans completed: 269
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 9 | - | - |
| 02 | 4 | - | - |
| 03 | 5 | - | - |
| 04 | 14 | - | - |
| 07 | 12 | - | - |
| 08 | 18 | - | - |
| 09 | 13 | - | - |
| 11 | 32 | - | - |
| 12 | 6 | - | - |
| 13 | 10 | - | - |
| 14 | 18 | - | - |
| 15 | 77 | - | - |
| 16 | 26 | - | - |
| 17 | 13 | - | - |
| 18 | 12 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 8min | 2 tasks | 8 files |
| Phase 01 P02 | 8min | 2 tasks | 8 files |
| Phase 01 P03 | 14min | 3 tasks | 150 files |
| Phase 01 P04 | 5min | 3 tasks | 7 files |
| Phase 01 P05 | 7min | 3 tasks | 10 files |
| Phase 01 P06 | 12min | 3 tasks | 2 files |
| Phase 01 P07 | 20min | 3 tasks | 5 files |
| Phase 02 P01 | 8 | 2 tasks | 5 files |
| Phase 02 P02 | iterative | spike + auto-load | 3 files |
| Phase 02 P03 | 6min | 2 tasks | 2 files |
| Phase 02 P04 | 12min | 2 tasks | 4 files |
| Phase 03 P01 | 13min | 2 tasks | 4 files |
| Phase 03 P02 | 12min | 2 tasks | 1 files |
| Phase 03 P03 | 14min | 2 tasks | 4 files |
| Phase 03 P04 | 10min | 2 tasks | 2 files |
| Phase 04 P01 | 11min | 2 tasks | 29 files |
| Phase 04 P02 | 9min | 2 tasks | 3 files |
| Phase 04 P03 | 25min | 2 tasks | 2 files |
| Phase 04 P04 | 18min | 2 tasks | 2 files |
| Phase 04 P05 | 22min | 2 tasks | 2 files |
| Phase 04 P06 | 7min | 2 tasks | 2 files |
| Phase 04 P07 | 8min | 2 tasks | 2 files |
| Phase 04 P08 | 10min | 2 tasks | 5 files |
| Phase 04 P09 | 9min | 2 tasks | 4 files |
| Phase 04 P10 | 7min | 2 tasks | 9 files |
| Phase 04 P11 | 7min | 2 tasks | 8 files |
| Phase 04 P12 | 7min | 2 tasks | 6 files |
| Phase 04 P13 | 8min | 2 tasks | 12 files |
| Phase 04 P14 | 20min | 3 tasks | 30 files |
| Phase 05 P01 | 6min | 2 tasks | 9 files |
| Phase 05 P02 | 9min | 2 tasks | 18 files |
| Phase 05 P03 | 4min | 2 tasks | 5 files |
| Phase 05 P04 | 4min | 2 tasks | 4 files |
| Phase 05 P05 | 7min | 3 tasks | 7 files |
| Phase 05 P06 | 12min | 2 tasks | 2 files |
| Phase 05 P07 | 6min | 2 tasks | 3 files |
| Phase 05 P08 | 15min | 3 tasks | 6 files |
| Phase 05 P09 | 10min | 3 tasks | 7 files |
| Phase 05 P10 | 7min | 3 tasks | 3 files |
| Phase 05 P11 | 3min | 1 tasks | 1 files |
| Phase 05 P12 | 2min | 1 tasks | 1 files |
| Phase 05 P13 | 2min | 1 tasks | 1 files |
| Phase 05 P14 | 4min | 2 tasks | 4 files |
| Phase 05 P15 | 2min | 1 tasks | 1 files |
| Phase 05 P16 | 8min | 1 tasks | 1 files |
| Phase 05 P17 | 3min | 2 tasks | 2 files |
| Phase 05 P18 | 9 min | 1 tasks | 0 files |
| Phase 07 P01 | 8min | 3 tasks | 3 files |
| Phase 07 P02 | 13min | 3 tasks | 7 files |
| Phase 07 P03 | 8min | 3 tasks | 11 files |
| Phase 07 P04 | 8min | 2 tasks | 9 files |
| Phase 07 P05 | 5min | 2 tasks | 5 files |
| Phase 07 P06 | 5min | 2 tasks | 7 files |
| Phase 07 P07 | 6min | 3 tasks | 11 files |
| Phase 07 P08 | 4h30m | 3 tasks | 6 files |
| Phase 07 P09 | 7min | 2 tasks | 2 files |
| Phase 07 P12 | 3min | 2 tasks | 2 files |
| Phase 07 P10 | 11min | 2 tasks | 2 files |
| Phase 08 P01 | 4min | 2 tasks | 3 files |
| Phase 08 P02 | 5min | 2 tasks | 3 files |
| Phase 08 P03 | 6 min | 2 tasks | 11 files |
| Phase 08 P04 | 6 min | 2 tasks | 7 files |
| Phase 08 P05 | 7min | 2 tasks | 5 files |
| Phase 08 P06 | 9min | 2 tasks | 18 files |
| Phase 08 P07 | 6min | 2 tasks | 10 files |
| Phase 08 P08 | 7min | 2 tasks | 14 files |
| Phase 08 P09 | 12 min | 2 tasks | 7 files |
| Phase 08 P10 | 7 min | 2 tasks | 5 files |
| Phase 08 P11 | 8 min | 2 tasks | 3 files |
| Phase 08 P12 | 7 min | 2 tasks | 10 files |
| Phase 08 P13 | 6 min | 2 tasks | 10 files |
| Phase 08 P14 | 4 min | 2 tasks | 4 files |
| Phase 08 P15 | 11 min | 2 tasks | 4 files |
| Phase 08 P18 | 4 min | 2 tasks | 5 files |
| Phase 08 P16 | 6 min | 2 tasks | 4 files |
| Phase 08 P17 | 20min | 2 tasks | 2 files |
| Phase 09 P01 | 19min | 3 tasks | 9 files |
| Phase 09 P02 | 6min | 2 tasks | 2 files |
| Phase 09 P03 | 7min | 3 tasks | 5 files |
| Phase 09 P04 | 8min | 3 tasks | 5 files |
| Phase 09 P05 | 75 | 2 tasks | 11 files |
| Phase 09 P06 | 8min | 2 tasks | 2 files |
| Phase 09 P07 | 6min | 2 tasks | 10 files |
| Phase 09 P08 | 5min | 2 tasks | 3 files |
| Phase 09 P09 | 10min | 2 tasks | 6 files |
| Phase 09 P10 | 4min | 2 tasks | 5 files |
| Phase 09 P11 | 8min | 2 tasks | 6 files |
| Phase 09 P12 | 6min | 2 tasks | 5 files |
| Phase 09 P13 | 17min | 2 tasks | 6 files |
| Phase 10 P01 | 17min | 2 tasks | 16 files |
| Phase 10 P02 | 9min | 3 tasks | 42 files |
| Phase 10 P03 | 15min | 3 tasks | 21 files |
| Phase 10 P04 | 20min | 2 tasks | 8 files |
| Phase 10 P05 | 16min | 2 tasks | 3 files |
| Phase 10 P06 | 20min | 3 tasks | 2 files |
| Phase 10 P07 | 12min | 2 tasks | 6 files |
| Phase 10 P08 | 20min | 2 tasks | 8 files |
| Phase 10 P09 | 12min | 3 tasks | 34 files |
| Phase 10 P10 | 22min | 2 tasks | 5 files |
| Phase 10 P11 | 18min | 2 tasks | 9 files |
| Phase 10 P12 | 12min | 3 tasks | 0 files |
| Phase 11 P1 | 25m | 2 tasks | 4 files |
| Phase 11 P2 | ~20m | 2 tasks | 4 files |
| Phase 11 P3 | ~30m | 2 tasks | 6 files |
| Phase 11 P4 | ~25m | 2 tasks | 7 files |
| Phase 11 P5 | ~20m | 2 tasks | 4 files |
| Phase 11 P6 | ~25m | 2 tasks | 13 files |
| Phase 11 P7 | 55m | 2 tasks | 24 files |
| Phase 11 P8 | ~95 min | 2 tasks | 24 files |
| Phase 11 P9 | ~40 min | 2 tasks | 17 files |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 11 P10 | ~70 min | 2 tasks | 28 files |
| Phase 11 P11 | ~35 min | 2 tasks | 9 files |
| Phase 11 P12 | ~25 min | 2 tasks | 8 files |
| Phase 11 P14 | ~35 min | 2 tasks | 7 files |
| Phase 11 P15 | ~40 min | 2 tasks | 13 files |
| Phase 11 P16 | ~20 min | 2 tasks | 1 files |
| Phase 11 P17 | ~60 min | 3 tasks | 18 files |
| Phase 11 P18 | ~50 min | 2 tasks | 36 files |
| Phase 11 P19 | ~20 min | 2 tasks | 2 files |
| Phase 11 P20 | ~35 min | 2 tasks | 6 files |
| Phase 11 P21 | ~50 min | 2 tasks | 41 files |
| Phase 11 P22 | ~35 min | 1 tasks | 26 files |
| Phase 11 P22.1 | 50 | 2 tasks | 24 files |
| Phase 11 P23 | ~20 min | 2 tasks | 32 files |
| Phase 11 P24 | ~15 min | 2 tasks | 5 files |
| Phase 11 P25 | 12 min | 2 tasks | 326 files |
| Phase 11 P26 | ~25 min | 2 tasks | 76 files |
| Phase 11 P27 | ~20 min | 2 tasks | 27 files |
| Phase 11 P28 | ~25 min | 2 tasks | 20 files |
| Phase 11 P29 | ~50m | 2 tasks | 3 files |
| Phase 11 P31 | ~50 min | 2 tasks | 3 files |
| Phase 12 P01 | 25min | 2 tasks | 6 files |
| Phase 12 P02 | 13 min | 2 tasks | 3 files |
| Phase 12 P03 | 13min | 2 tasks | 2 files |
| Phase 12 P04 | 11min | 2 tasks | 2 files |
| Phase 12 P05 | 14min | 2 tasks | 1 files |
| Phase 12 P06 | ~2 days (Task 1 ~35min + owner UAT) | 2 tasks | 18 files |
| Phase 13 P01 | 12 min | 2 tasks | 5 files |
| Phase 13 P02 | 11 min | 2 tasks | 6 files |
| Phase 13 P03 | 19 min | 2 tasks | 16 files |
| Phase 13 P04 | 12 min | 2 tasks | 3 files |
| Phase 13 P05 | 18 min | 2 tasks | 3 files |
| Phase 13 P06 | 7 min | 2 tasks | 5 files |
| Phase 13 P07 | 16 min | 3 tasks | 11 files |
| Phase 13 P08 | 23 min | 2 tasks | 11 files |
| Phase 13 P09 | 36 min | 2 tasks | 5 files |
| Phase 14 P02 | ~6 min | 1 tasks | 1 files |
| Phase 14 P03 | 17min | 3 tasks | 9 files |
| Phase 14 P04 | 7min | 3 tasks | 7 files |
| Phase 14 P05 | ~11min | 3 tasks | 3 files |
| Phase 14 P06 | ~17min | 3 tasks | 5 files |
| Phase 14 P07 | 40min | 2 tasks | 23 files |
| Phase 14 P08 | 18min | 2 tasks | 11 files |
| Phase 14 P09 | ~12min | 3 tasks | 9 files |
| Phase 14 P10 | 14min | 3 tasks | 4 files |
| Phase 14 P11 | 18min | 3 tasks | 5 files |
| Phase 14 P12 | 14min | 3 tasks | 9 files |
| Phase 15 P01 | 7min | 2 tasks | 5 files |
| Phase 15 P02 | 14min | 3 tasks | 16 files |
| Phase 15 P03 | 6min | 2 tasks | 2 files |
| Phase 15 P04 | 13min | 3 tasks | 7 files |
| Phase 15 P05 | 15min | 2 tasks | 6 files |
| Phase 15 P06 | 22min | 3 tasks | 5 files |
| Phase 15 P07 | 16min | 3 tasks | 2 files |
| Phase 15 P08 | 32min | 3 tasks | 3 files |
| Phase 15 P09 | 47min | 2 tasks | 4 files |
| Phase 15 P10 | 25min | 2 tasks | 10 files |
| Phase 15 P11 | 10min | 2 tasks | 2 files |
| Phase 15 P12 | 12min | 2 tasks | 7 files |
| Phase 15 P13 | 21min | 2 tasks | 5 files |
| Phase 15 P14 | 11min | 2 tasks | 7 files |
| Phase 15 P15 | 12min | 2 tasks | 2 files |
| Phase 15 P16 | 8min | 2 tasks | 1 files |
| Phase 15 P17 | 21min | 3 tasks | 6 files |
| Phase 15 P18 | 16min | 2 tasks | 10 files |
| Phase 15 P19 | 28min | 3 tasks | 18 files |
| Phase 15 P20 | 25 | 2 tasks | 4 files |
| Phase 15 P21 | 35 | 2 tasks | 1 files |
| Phase 15 P22 | 35 | 2 tasks | 4 files |
| Phase 15 P23 | 22min | 2 tasks | 3 files |
| Phase 15 P24 | 35min | 2 tasks | 4 files |
| Phase 15 P25 | 45min | 2 tasks | 6 files |
| Phase 15 P26 | 45min | 2 tasks | 9 files |
| Phase 15 P27 | 26min | 1 tasks | 2 files |
| Phase 15 P28 | 9min | 2 tasks | 13 files |
| Phase 15 P29 | 70min | 2 tasks | 6 files |
| Phase 15 P30 | 55min | 1 tasks | 3 files |
| Phase 15 P31 | 50min | 1 tasks | 9 files |
| Phase 15 P32 | 50min | 2 tasks | 24 files |
| Phase 15 P33 | 50min | 1 tasks | 4 files |
| Phase 15 P34 | 12min | 2 tasks | 5 files |
| Phase 15 P35 | 22min | 1 tasks | 2 files |
| Phase 15 P36 | 37min | 2 tasks | 4 files |
| Phase 15 P37 | 90min | 2 tasks | 9 files |
| Phase 15 P38 | 105min | 2 tasks | 4 files |
| Phase 15 P39 | 25min | 2 tasks | 5 files |
| Phase 15 P40 | 22min | 2 tasks | 5 files |
| Phase 15 P41 | 41min | 2 tasks | 8 files |
| Phase 15 P42 | 35min | 2 tasks | 3 files |
| Phase 15 P43 | 35m | 2 tasks | 5 files |
| Phase 15 P44 | 29min | 2 tasks | 4 files |
| Phase 15 P45 | 6min | 2 tasks | 6 files |
| Phase 15 P46 | 26min | 2 tasks | 3 files |
| Phase 15 P47 | 27min | 2 tasks | 12 files |
| Phase 15 P48 | 33min | 3 tasks | 9 files |
| Phase 15 P49 | 14min | 2 tasks | 5 files |
| Phase 15 P50 | 41min | 3 tasks | 9 files |
| Phase 15 P51 | 32min | 2 tasks | 3 files |
| Phase 15 P52 | 38min | 2 tasks | 3 files |
| Phase 15 P53 | 45min | 2 tasks | 3 files |
| Phase 15 P54 | ~5h | 5 tasks | 14 files |
| Phase 15 P55 | 95 min | 2 tasks | 8 files |
| Phase 15 P56 | 135min | 2 tasks | 6 files |
| Phase 15 P57 | 30min | 2 tasks | 7 files |
| Phase 15 P58 | 68min | 2 tasks | 6 files |
| Phase 15 P59 | 66min | 2 tasks | 4 files |
| Phase 15 P60 | 32 | 2 tasks | 2 files |
| Phase 15 P61 | 55min | 2 tasks | 5 files |
| Phase 15 P62 | 35min | 2 tasks | 7 files |
| Phase 15 P63 | 30min | 2 tasks | 3 files |
| Phase 15 P64 | 30 min | 2 tasks | 8 files |
| Phase 15 P65 | 40min | 2 tasks | 5 files |
| Phase 15 P66 | 45min | 2 tasks | 14 files |
| Phase 15 P67 | 25min | 2 tasks | 7 files |
| Phase 15 P68 | 40min | 2 tasks | 7 files |
| Phase 15 P69 | 35min | 2 tasks | 13 files |
| Phase 15 P70 | 30min | 2 tasks | 5 files |
| Phase 15 P71 | 22min | 2 tasks | 4 files |
| Phase 15 P72 | 76min | 2 tasks | 4 files |
| Phase 15 P73 | 22 min | 2 tasks | 4 files |
| Phase 15 P74 | 40min | 2 tasks | 10 files |
| Phase 15 P75 | 25 min | 1 tasks | 9 files |
| Phase 15 P76 | 45min | 2 tasks | 4 files |
| Phase 16 P01 | 18min | 2 tasks | 1 files |
| Phase 16 P02 | 14min | 2 tasks | 1 files |
| Phase 16 P03 | 16min | 2 tasks | 1 files |
| Phase 16 P04 | 2h 45m | 2 tasks | 1 files |
| Phase 16 P05 | 3h 5m | 2 tasks | 1 files |
| Phase 16 P06 | 2h 20m | 2 tasks | 1 files |
| Phase 16 P07 | 1h 21m | 2 tasks | 2 files |
| Phase 16 P08 | 6min | 2 tasks | 2 files |
| Phase 16 P09 | 1h 2m | 2 tasks | 2 files |
| Phase 16 P10 | 6min (closure) | 2 tasks | 1 files |
| Phase 16 P11 | 6min (closure) | 3 tasks | 2 files |
| Phase 16 P12 | 21min | 3 tasks | 2 files |
| Phase 16 P14 | 43min | 2 tasks | 3 files |
| Phase 16 P13 | two sessions | 3 tasks | 1 files |
| Phase 16 P15 | 35min | 3 tasks | 16 files |
| Phase 16 P16 | 30min | 2 tasks | 7 files |
| Phase 16 P17 | 12min | 2 tasks | 8 files |
| Phase 16 P18 | 13min | 2 tasks | 4 files |
| Phase 16 P19 | 26 min | 3 tasks | 6 files |
| Phase 16 P20 | 31min | 2 tasks | 5 files |
| Phase 16 P21 | 1h 38m | 3 tasks | 11 files |
| Phase 16 P22 | 16 min | 2 tasks | 4 files |
| Phase 16 P23 | 36min | 3 tasks | 20 files |
| Phase 16 P24 | 2d 16h | 4 tasks | 18 files |
| Phase 17 P01 | multi-session | 2 tasks | 27 files |
| Phase 17 P24 | 16min | 2 tasks | 5 files |
| Phase 18 P07 | about 2h | 2 tasks | 25 files |
| Phase 18 P01 | 4 min | 2 tasks | 4 files |
| Phase 18 P02 | about 30 min | 3 tasks | 20 files |
| Phase 18 P04 | 14 min | 2 tasks | 14 files |
| Phase 18 P06 | 3 min | 2 tasks | 5 files |
| Phase 18 P03 | about 30 min | 4 tasks | 19 files |
| Phase 18 P05 | 28 min | 2 tasks | 7 files |
| Phase 18 P08 | about 1h | 2 tasks | 8 files |
| Phase 18 P09 | about 1h | 3 tasks | 15 files |
| Phase 18 P10 | about 2h | 3 tasks | 19 files |
| Phase 18 P11 | about 1h20m (final session) | 4 tasks | 15 files |
| Phase 18.1 P01 | 20 min | 2 tasks | 11 files |
| Phase 18.1 P02 | 25 min | 1 tasks | 3 files |
| Phase 18.1 P03 | 25 min | 2 tasks | 11 files |
| Phase 18.1 P04 | several sessions | 3 tasks | 20 files |
| Phase 18.1 P05 | about 5h 25m (four live-check runs) | 2 tasks | 6 files |
| Phase 19 P01 | multi-session | 3 tasks | 11 files |
| Phase 19 P11 | multi-session | 2 tasks | 2 files |
| Phase 19 P02 | one session | 3 tasks | 19 files |
| Phase 20 P01 | 17 min | 3 tasks | 9 files |
| Phase 20 P02 | 6 min | 3 tasks | 5 files |
| Phase 20 P03 | 8 min | 2 tasks | 12 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Combine→async/await (Phase 4) stays in this milestone, sequenced after the isolated dep removals.
- Roadmap: WaterfallGrid→Layout (Phase 2) and SwiftUIPager→native paging ScrollView (Phase 3, construct per D-04 not a TabView) are spike-first — validate feasibility before committing.
- Roadmap: Fold cookies→Keychain + networking/cookie/image tests + `.private.filterValue` fix into their open seams (Phases 8–9); defer Parser/Download refactors.
- Roadmap: LINT-01 split — mechanical rules sweep last (Phase 11); refactor-gated rules land with their refactors (`optional_try`→Phase 9; binding/lifecycle/unchecked-subscript→Phases 5–7).
- [Phase 04]: 04-01: Every Request conformer stores an injected URLSession, including DataRequest, with .shared as the behavior-preserving default.
- [Phase 04]: 04-02: Parity capture accepts a closure formed on each concrete request type to avoid protocol-extension static dispatch.
- [Phase 04]: Fetch errors map inside fetch; parse errors map after fetch returns, so parse failures never retry. — Preserves Combine retry placement and one AppError mapping per thrown boundary.
- [Phase 04]: TagTranslator retries metadata but performs its payload download once. — Preserves the frozen two-step Combine chain asymmetry.
- [Phase 04]: Native URLSession structured cancellation remains attached to the caller task. — Stops cancelled HTTP work while TCA preserves identical user-visible behavior.
- [Phase 04]: Login preserves an optional HTTP response while Igneous requires an HTTP response and maps a failed cast to unknown. — Matches the distinct frozen map and compactMap semantics.
- [Phase 04]: Account form and JSON assembly remains duplicated beside temporary publishers until publisher deletion. — Keeps each intermediate commit compiling while frozen structural assertions prove parity.
- [Phase 04]: Async gallery metadata preserves 25-pair chunks, two in-flight requests, and input-order reconstruction. — These are existing flood-control and presentation-order guarantees around the shared gdata transport.
- [Phase 04]: Metadata task-group children return typed Result values. — Preserves AppError typing and structured cancellation across the task-group boundary.
- [Phase 04]: Detail chains retry their first fetch and leave their second fetch un-retried. — Preserves the frozen publisher retry placement for reverse lookup and archive funds.
- [Phase 04]: Image refetch retries its complete three-step chain four times. — Matches the publisher-level genericRetry placement and frozen per-URL attempt counts.
- [Phase 04]: Image fan-out uses a Sendable result record in its throwing task group. — The compiler crashes on the equivalent labeled-tuple expression; the record preserves identical semantics.
- [Phase 04]: Reducer Done actions and handlers remain Result-based during the async consumer switch. — Limits the migration to request acquisition and preserves literal state-machine parity.
- [Phase 04]: TCA request effects use explicit do throws AppError with no casts or unknown fallback. — Keeps typed catch binding load-bearing and makes every failure send explicit.
- [Phase 04]: Reader image effects preserve cancellation identifiers and send ordering during acquisition conversion. — Protects the highest-frequency request path from reducer behavior drift.
- [Phase 04]: DownloadClient and file-operation run/catch effects remain outside the request consumer sweep. — They do not call the request facade and changing them would exceed the plan boundary.
- [Phase 04]: TagTranslator noUpdates remains an explicit failure action during the typed consumer switch. — Exactly preserves the previous inline Result switch outcome.
- [Phase 04]: Throwing DownloadClient functions await typed responses directly while Result-returning APIs rebuild Result explicitly. — Preserves public signatures and minimizes orchestration changes.
- [Phase 04]: Request now requires typed throws and the package source tree is Combine-free. — Makes the compiler enforce async conformance completeness and removes all publisher bridges.
- [Phase 04]: The D-11 scope expanded to all 66 compiler-reported TCA deprecations. — The owner authorized the authoritative compiler inventory so CONC-02 reaches zero warnings.
- [Phase 04]: Presentation modifiers and reducer behavior remain unchanged while scope arguments use TCA 1.26 forms. — Argument-only migrations preserve UI anchors and state-machine semantics.
- [Phase 05]: DeviceType is the sole device-identity representation; boolean isPad is derived only at branch sites.
- [Phase 05]: Gallery navigation accepts the injected main-actor deviceType closure and resolves it inside its effect.
- [Phase 05]: Removed obsolete AppDelegateClient test overrides with the deleted target. — A test-only compatibility target would preserve dead architecture; affected tests pass without it.
- [Phase 05]: AppComponents declares DeviceClient directly because TagSuggestionView owns the injected device fact. — Direct Swift package dependencies make module ownership explicit and compilable.
- [Phase 05]: EhSetting fractions use current container dimensions instead of the old orientation-independent short edge. — This is the locked adaptive-layout delta for rotation and resized containers.
- [Phase 05]: Alert and placeholder widths use the nearest SwiftUI container while preserving their existing factors.
- [Phase 05]: NewDawnView observes only container width and keeps its iPad-specific factor through the injected DeviceClient.
- [Phase 05]: Direct detail width fractions use containerRelativeFrame without geometry state. — This keeps direct fractions container-relative while avoiding unnecessary view state and invalidation.
- [Phase 05]: Archive cells receive the grid's size-class-selected width. — A single selected value keeps adaptive grid metadata and rendered cell frames identical.
- [Phase 05]: Preview thumbnail downsampling uses a fixed 660-pixel cap. — The former regular-width maximum preserves fidelity without coupling image decoding to layout.
- [Phase 05]: Carousel card width, card pitch, and symmetric peek inset derive from one observed container width. — Keeps the coupled view-aligned geometry consistent during rotation and container resizing.
- [Phase 05]: Ranking layout follows horizontal size class while Toplists and title trimming retain device-class semantics through DeviceClient. — Separates adaptive layout decisions from parity-sensitive device identity branches.
- [Phase 05]: Live Text OCR paths and interactive overlays share one captured nonzero size; Canvas uses its closure size only for the full-surface tint. — This preserves normalized coordinate alignment while guarding the initial geometry pass.
- [Phase 05]: Reader gesture math consumes one outer-container size while existing gesture sources continue supplying locations until Plan 05-09.
- [Phase 05]: PageHandler requires isLandscape at every call site; the construction-time resume seed uses portrait mapping until observed geometry is available.
- [Phase 05]: Reader pinch gestures use MagnifyGesture.startAnchor directly while double taps derive their anchor from SpatialTapGesture.location. — Each native gesture source now supplies the coordinate representation its baseline-locked arithmetic expects.
- [Phase 05]: Reader landscape eligibility derives from captured container width greater than height. — One local size now governs dual-page mapping and reader controls under rotation and resized containers.
- [Phase 05]: ApplicationClient selects the last key window from foreground-active scenes, then falls back to the last window of the last scene, preserving the former behavior locally.
- [Phase 05]: Defaults.FrameSize keeps only the device-independent card height and no longer needs main-actor isolation.
- [Phase 05]: Runtime rotation and Live Text visual checks remain explicit manual gates for phase verification rather than being inferred from static or unit-test evidence.
- [Phase 05]: About metadata is the leading Form section so every navigation-bar style preserves it in the scrollable reading order.
- [Phase 05]: Reader placeholders preserve the full vertical container extent while applying the dual-page divisor only to the horizontal axis. — This lets the fixed aspect ratio choose height-bounded sizing in landscape without changing dual-page behavior.
- [Phase 05]: 05-13: CardSlideSection remains the sole owner of carousel card width, pitch, and centered peek; GalleryCardCell fills the proposed slot.
- [Phase 05]: SettingTextField uses its title only as a localized accessibility label; promptText is the sole visible placeholder source.
- [Phase 05]: Each reusable sheet root owns an untitled cancellation-role button at the stable cancellationAction toolbar placement.
- [Phase 05]: Favorites category switching remains direct while sort, date seek, and quick search move into ToolbarFeaturesMenu.
- [Phase 05]: DateSeekButton continues to own its nil-navigation disabled state, and Favorites reducer behavior remains unchanged.
- [Phase 05]: Reader window-control compensation uses the iOS 26 top-leading container corner exclusion and folds in safe-area dimensions only when that exclusion is nonzero.
- [Phase 05]: Home declares systemBackground at its content root so systemGray6 cards stay distinct without changing normal-window appearance.
- [Phase 05]: Multiple-scene support is disabled while every scene would share the single AppDelegate-owned store.
- [Phase 05]: No non-pad gallery-detail entry path bypassed GalleryNavigation; source inventory and reducer probes all resolved phone entries to push. — The no-repro branch requires human confirmation instead of a speculative source change.
- [Phase 05]: Deep-link, URL, and clipboard gallery entries remain the intentional device-independent modal baseline. — These app-route presentations are documented behavior and are separate from host gallery-tap routing.
- [Phase 07]: 07-01: The privacy-mask blur is transient in-memory state and starts at a true zero on every launch.
- [Phase 07]: 07-01: The privacyMask modifier owns a read-only SharedReader so callers need no store scope or blur argument.
- [Phase 07]: loadUserSettingsDone is the single cold-launch clipboard-detection owner; the active scene branch handles later foreground entries. — Pre-load active transitions are ignored, preventing duplicate cold-launch clipboard detection while preserving later foreground behavior.
- [Phase 07]: privacyMaskIntensity remains a version-1 Setting field with default 10 and no migration. — The pre-release schema policy accepts resetting the renamed key to its parity default.
- [Phase 07]: The Privacy Mask slider owns a localized accessibility label and treats its eye icons as decorative. — This keeps the native adjustable control concise for VoiceOver without announcing redundant symbols.
- [Phase 07]: Detail routing blur inputs temporarily default to zero so Home and Favorites can remove drilling before the DetailFeature sweep. — This keeps sequential module commits compiling without retaining blurRadius tokens in migrated modules; plan 07-06 removes the temporary inputs.
- [Phase 07]: DownloadsView keeps the plan-specified ReadingView blurRadius: 0 bridge until 07-07 while all Downloads-owned blur inputs are removed. — ReadingFeature still requires the parameter until its scheduled sweep.
- [Phase 07]: Both Detail-owned ReadingView presentations retain literal blurRadius zero bridges until 07-07. — ReadingView still requires the compatibility parameter; DetailFeature no longer owns or propagates blur state.
- [Phase 07]: 07-07: Privacy-mask coverage is counted as forty application call sites; the public function declaration and shared-key documentation remain valid non-call matches.
- [Phase 07]: 07-07: The AppActivityLogs mask stays on the RunPickerSheet presented root so native sheet accessibility and stable modal coverage are preserved.
- [Phase 07]: The no-content-leak gate combines automated forty-site coverage with owner device-level approval. — Static checks cannot prove App Switcher snapshot concealment or presentation behavior.
- [Phase 07]: Privacy-mask coverage counts forty executable application calls rather than forty-two raw tokens. — The public function declaration and shared-key documentation are valid non-application matches.
- [Phase 07]: The owner post-checkpoint refinement scopes blur animation to the blur transform and keeps Privacy Mask in the first Appearance section. — The owner intentionally refined presentation after verification; current HEAD was rebuilt and retested without rewriting the commit.
- [Phase 07]: 07-09: Scene-phase privacy writes and background latching run before the settings-loaded guard; settings-dependent effects remain gated. — Protects cold-launch App Switcher snapshots without changing initialization-dependent side-effect semantics.
- [Phase 07]: 07-11: Privacy-mask coverage is derived from 39 explicit runtime roots and reconciled against all 41 source presentation modifiers. — A duplicate can no longer compensate for an uncovered root, and preview-only presentations remain explicit exclusions.
- [Phase 07]: 07-11: Privacy blur transitions use no animation when Reduce Motion is enabled. — The true-zero blur and hit-testing threshold remain unchanged.
- [Phase 07]: 07-10: Foreground tests explicitly pause the long-lived activity-log pump after receiving every expected action, preserving TestStore exhaustivity without skipping effects.
- [Phase 07]: 07-10: Clipboard cardinality counts the unconditional changeCount dependency seam; the URL remains nil to isolate foreground dispatch behavior.
- [Phase 08]: QUAL-01 covers cookie-logging privacy only; the former at-rest migration is out of milestone rather than deferred. — D-01 reconciles the milestone contract with the sideload-distribution reliability tradeoff.
- [Phase 08]: D-06 retains URLUtil and FileUtil as pure namespaces instead of adding thin client wrappers. — Pure deterministic helpers gain no substitutability from a client wrapper.
- [Phase 08]: Host-derived Defaults.URL helpers accept GalleryHost explicitly while existing global properties remain available during caller migration.
- [Phase 08]: URLUtil uses AppUtil.galleryHost only as a transitional default; every host-dependent builder body constructs from its GalleryHost argument.
- [Phase 08]: Gallery-list reducers snapshot setting.galleryHost at request construction time. — This matches existing filter and keyword snapshot semantics while making the shared Setting the sole host source for each request.
- [Phase 08]: Setting reducers snapshot setting.galleryHost when constructing each host-dependent effect. — A request keeps one construction-time host across its asynchronous work.
- [Phase 08]: EhSettingFeature state reads shared Setting directly because it previously had no host source. — The reducer now resolves its host explicitly without retaining a global fallback.
- [Phase 08]: Account and routine request baselines use an explicit deterministic E-Hentai host. — Tests no longer depend on the transitional global host mirror.
- [Phase 08]: Detail reducers snapshot setting.galleryHost when constructing each host-dependent effect. — Each in-flight request keeps one consistent construction-time host even if shared settings change later.
- [Phase 08]: CookieClient apiuid reads the selected host URL supplied by its caller. — Explicit caller-owned host selection removes the hidden transitional global-host dependency.
- [Phase 08]: Account request baselines use an explicit deterministic E-Hentai host. — Parity tests should not depend on the transitional mutable global host mirror.
- [Phase 08]: Snapshot GalleryHost at async request construction boundaries. — A stable value keeps in-flight requests tied to the selected origin without consulting mutable global state.
- [Phase 08]: Use saved-download manifest hosts for refreshes and the current shared host for live DownloadClient fetches. — Each flow retains its existing source of truth while making host selection explicit.
- [Phase 08]: Views use existing store settings where available and read-only SharedReader state only in leaf views without store access.
- [Phase 08]: Detail download payloads snapshot state.setting.galleryHost when the start action is handled.
- [Phase 08]: GalleryInfosView reads the active host from SharedReader(.setting) at render time. — The leaf view has no parent Setting state and this matches the established host seam.
- [Phase 08]: Test-only URL fallbacks use an explicit E-Hentai host. — Deterministic tests must not recreate the removed mutable host default.
- [Phase 08]: Use one canonical DataCache actor for the live dependency and system-purge observer. — Preserves coherent cache identity while removing the public singleton seam.
- [Phase 08]: Use UUID-scoped temporary DataCache instances for the default test dependency. — Prevents cross-test cache pollution while allowing explicit per-test injection.
- [Phase 08]: Exercise ImageClient through an injected cache and URLSession while keeping one isolated DataCache actor per test. — This prevents process-global cache pollution and makes every client-layer behavior deterministic.
- [Phase 08]: Render image-test PNG fixtures at scale 1 before asserting decoded pixel dimensions. — UIImage point canvases inherit the simulator display scale; an explicit unit scale keeps the fixture exactly 2 by 2 pixels.
- [Phase 08]: 08-11: Use synthetic credential fixtures and clear every live cookie store after each test. — Keeps credential-shaped test data isolated and short-lived while exercising production cookie parsing.
- [Phase 08]: 08-11: Query skip-server cookies at their /s/ path. — Matches the production cookie path and verifies Foundation URL path filtering rather than bypassing it.
- [Phase 08]: 08-12: Resolve CookieClient at each view owner, including a function-local read in the cross-file Detail toolbar extension. — Private stored dependencies are file-scoped in Swift; local resolution preserves render-time reads without widening access.
- [Phase 08]: 08-12: Keep every login condition and control modifier unchanged apart from its predicate source. — The migration is a seam swap at behavior, appearance, accessibility, and dialog-anchor parity.
- [Phase 08]: 08-13: Preserve the legacy-device sound sequence and modern UIKit feedback calls verbatim inside HapticsClient.live.
- [Phase 08]: 08-13: Keep AppUserDefaults in AppTools as the shared key type while removing only the redundant UserDefaultsUtil wrapper.
- [Phase 08]: 08-14: Preserve Bundle metadata keys, null fallbacks, and XCTestConfigurationFilePath detection when relocating them to AppInfo. — Maintains exact About metadata and test-launch behavior while eliminating AppUtil.
- [Phase 08]: 08-14: Model AppInfo as an uninhabited pure namespace instead of an injected client. — Read-only app facts require no substitution, and a client would be a thin wrapper.
- [Phase 08]: Carry GalleryHost in refetchNormalImageURLsDone so both completion paths preserve request identity. — Response cookie routing must remain tied to immutable request-construction context across shared-host changes.
- [Phase 08]: Observe the isolated CookieClient testing store as the host-routing spy. — The behavior-level assertion proves the destination host without adding a production callback solely for tests.
- [Phase 08]: Track cookie-bearing local assignments for the rest of each Swift file so ordinary alias names cannot bypass the privacy gate. — This conservative file-scoped taint closes the demonstrated data-flow evasion while the production source scan remains green.
- [Phase 08]: Skip the production-only getCookiesDescription consumer inventory when an explicit fixture scan root is supplied. — Fixture scans should fail only for the cookie-logging rule they exercise, while the no-argument production scan retains the clipboard invariant.
- [Phase 08]: Carry GalleryHost in fetchEhProfileIndexDone and createDefaultEhProfile so every profile side effect retains request identity. — Profile completion must not re-read mutable shared host state.
- [Phase 08]: Observe selected-profile routing through an isolated CookieClient testing store while asserting default-profile routing at the follow-up action boundary. — This proves host behavior without process-global cookies or a production-only test callback.
- [Phase 16]: 16-05: [Phase 08]: 08-17: Model the clipboardChangeCount UserDefaults read as a stored @Sendable endpoint (not a generic instance method) so overrides control reads exactly as they control writes; UserDefaults.standard is read only inside live.
- [Phase 09]: Keep AppError's 12-case enum unchanged and carry per-incident diagnostics in ErrorInfo.
- [Phase 09]: Offer recovery suggestions for networking, authentication, IP restriction, quota, and not-found errors.
- [Phase 09]: Use Self.Context in SwiftUI representables so the public diagnostic Context type cannot shadow protocol context.
- [Phase 09]: 09-02: Treat Category.private as display-only: report filter-math misuse and contribute zero instead of trapping.
- [Phase 09]: 09-02: Keep filter iteration on Category.allFiltersCases, whose ten searchable cases sum to all 1023 filter bits.
- [Phase 09]: 09-03: Keep ErrorInfoView native and data-minimal: Form, LabeledContent, and only whitelisted context/environment values.
- [Phase 09]: 09-03: Route error-toast activation through a modifier closure and accessibility button trait; the Action == Never store never sends an action.
- [Phase 09]: 09-03: Declare AppModels directly on SystemNotificationExt because its public toast API exposes ErrorInfo.
- [Phase 09]: 09-04: Use PresentationFeature rather than PresentationReducer because repository reducers must carry the Feature suffix.
- [Phase 09]: 09-04: Rename appRouteState/appRoute to presentationState/presentation across the complete app-root source surface.
- [Phase 09]: 09-04: Gallery failure diagnostics expose only the action, localized reason, and URL path.
- [Phase 09]: FileClient uses fixed operation descriptors in AppError context so failures never disclose a file path.
- [Phase 09]: Missing cached translations recover through the existing remote fetch, while removal failures reach SettingFeature state.
- [Phase 09]: HTML repair, greeting, archive funds, and Chinese conversion remain optional because each has an explicit behavior-preserving fallback.
- [Phase 09]: All 16 scoped try? sites are intentional probe, metadata, validation, or cleanup fallbacks; genuine manifest and page persistence already propagates through throwing APIs.
- [Phase 09]: All 20 scoped DownloadClient try? sites are intentional parsing probes, metadata probes, optional API fallbacks, cadence writes, or cleanup operations; authoritative failures already propagate.
- [Phase 09]: Cleanup and optional probe failures preserve the primary validation or download result instead of introducing a competing error surface.
- [Phase 09]: 09-08: Keep all 13 DataCache optional operations as documented cache probes, metadata fallbacks, or fire-and-forget housekeeping so failures never replace cache hit/miss outcomes.
- [Phase 09]: 09-08: Preserve the four AppTools utility optional contracts: encoding/decoding return nil, URL detector failure is invalid, and regex failure disables suggestions.
- [Phase 09]: 09-09: Keep 42 ParserFeature try? expressions as documented per-field, per-row, or per-candidate degradations.
- [Phase 09]: 09-09: Convert MPV JSON deserialization to a typed AppError boundary because invalid JSON fails the whole parse.
- [Phase 09]: 09-09: Treat the Parser+Profile BrowsingCountry? raw match as an Optional-type substring, not an optional-try expression.
- [Phase 09]: 09-10: Keep all 17 scoped client and activity-log optional failures as documented intentional fallbacks.
- [Phase 09]: 09-10: Keep image-cache and activity-log persistence failures internal so they do not replace successful image acquisition or interrupt the pump.
- [Phase 09]: 09-11: Keep JSONValue's six sequential decode attempts as type probes because failure selects the next representation.
- [Phase 09]: 09-11: Keep the final view and markdown optional failures internal because each retains an explicit presentation or validation fallback.
- [Phase 16]: 16-05: 09-12: Gallery diagnostics retain only a validated decimal gallery ID; access-bearing route components never enter Context.
- [Phase 09]: ErrorInfo-bearing toasts remain until native Button activation or downward-swipe dismissal; ordinary success and caption-error toasts retain their three-second timeout.
- [Phase 09]: ToastInteractionState consumes only the current UUID and clears it before host routing, preventing stale, repeated, replacement, and dismissal events from routing ErrorInfo.
- [Phase 09]: The diagnostic Button keeps ToastMessageView as its visible label so Voice Control names and visible text remain aligned.
- [Phase 16]: 16-05: 10-03: Uneven corner clip relocated from custom UIRectCorner param to native .rect(bottomLeadingRadius:) with default .circular style; no continuous style added (parity preserved)
- [Phase 16]: 16-05: [Phase 10]: 10-04: \.inSheet env key removed; all former consumers collapsed to the base (inSheet==false) gray per owner decision — trait and Bool-param mechanisms both rejected; the modal DetailView surfaces intentionally shift to base gray.
- [Phase 16]: 16-05: 10-05: The three ToolbarItems buttons use a two-branch Label (icon-only when hideText); no AnyLabelStyle, so icon-only is explicit not toolbar-inferred.
- [Phase 16]: 16-05: 10-05: Menu/context-menu Image+Text rows convert to Label (house style); toolbar image-only and trailing-checkmark menu rows are left (new-key/wrong-slot parity veto).
- [Phase 16]: 16-05: 10-05: Empty-string audit (criterion 9) returned zero matches across AppPackage/Sources, App, ShareExtension; documented as the deliverable.
- [Phase 16]: 16-05: 10-06: Only 3 of 35 ZStacks convert to .overlay — flexible Color/backgroundColor size-definer under an external definite frame (aspectRatio/containerRelativeFrame); the other 32 (union peers, conditional single-child, opacity-toggled equal indicators, gesture/coordinate-critical) are KEEP, the plan's intended outcome.
- [Phase 16]: 16-05: 10-07: Paired numeric-text treatment applied inline per site (pair-check grep needs both tokens co-located); animation left ungated because contentTransition(.numericText) is itself Reduce-Motion-aware.
- [Phase 16]: 16-05: 10-08: RatingView @Previewable requirement met via a Slider driving @Previewable @State (view is display-only, no Binding)
- [Phase 16]: 16-05: 10-08: built EhPanda app scheme (whole AppPackage graph) since AppPackage-Package scheme is absent; iPhone Air OS27 sim
- [Phase 16]: 16-05: 10-09: 34 remaining PreviewProvider structs migrated to named #Preview; D-07 global grep gate at zero
- [Phase 16]: 16-05: 10-10: 7 fixed-pixel fonts scale via @ScaledMetric(relativeTo:) (5 non-exact sizes) + text-style forms (20->title3, 12->caption); first ScaledMetric uses in repo
- [Phase 16]: 16-05: 10-10: DT audit is static-derived; broke-at-AX5 subset = B1-B10 (10-11 work order); owner-signed D-03 sim pass is end-of-phase authoritative gate; live frame-height risk count is 9 not RESEARCH's 35
- [Phase 16]: 16-05: 10-11: text-bearing fixed frame(height:) reflowed via @ScaledMetric(relativeTo: dominant style) not minHeight — literal==scaled at .large for exact default parity while frame grows with Dynamic Type
- [Phase 16]: 16-05: 10-11: B1-B10 broke-at-AX5 all reflowed within D-02 (drop lineLimit/fixedSize for wrap, @ScaledMetric fixed heights); minimumScaleFactor 8->7 (B2 inert shrink removed); device D-03 pass deferred to 10-12
- [Phase 16]: 16-05: ParserFeature Group A/B optional-try removal routes through one shared Parser.degrading(_:_:) helper — inline do/catch is not expressible inside guard-let chains without changing evaluation order
- [Phase 16]: 16-05: D-04 group counts corrected: 21 Group A + 12 Group B + 9 Group C (not 23/13/6) — plan 11-02 must propagate 9 sites
- [Phase 11]: 11-02: parseDisplayMode returns String? — a missing display-mode selector is the normal toplist case, not an error
- [Phase 11]: 11-02: parseScriptVariable rebuilt with RegexBuilder — removes the runtime regex-compile failure path entirely
- [Phase 16]: 16-05: 11-03: DownloadClient manifest identity probes collapse onto one named probeManifest helper with a deliberately silent catch; scans walk arbitrary user folders so logging would be noise
- [Phase 16]: 16-05: 11-04: DownloadClient probe sites collapse onto two named helpers (probeHTMLDocument, probeFileData) — inline do/catch is not expressible in guard/if-let chains
- [Phase 16]: 16-05: 11-04: DownloadStore.closeReadHandle promoted to internal for coordinator reuse instead of duplicating the helper
- [Phase 16]: 16-05: 11-06: Activity-log pump append failures stay silent: logging inside a pump that reads its own OSLog self-feeds
- [Phase 16]: 16-05: 11-06: LogsClient's two directory guards collapse onto one helper returning [] — both fallbacks derive from an empty list
- [Phase 16]: 16-05: Presentation-driven lifecycle uses two shapes: pushed screens get onPresented from the presenting reducer's append; tab roots get it from AppReducer on tab activation and at launch-ready
- [Phase 16]: 16-05: appendGuardingDuplicate now returns the new StackElementID? so a deduped push starts nothing
- [Phase 16]: 16-05: Detail load pairing lives on GalleryPath.State.onPresentedAction + GalleryNavigation.presentationEffect, so a new gallery screen cannot silently skip a host
- [Phase 16]: 16-05: PostCommentView lost its onAppearAction parameter: focus is raised by the presenting reducer
- [Phase 16]: 16-05: Reader lifecycle: 3 of 6 sites migrated to presentation-driven; 3 kept as reason-annotated D-02 exception candidates (lazy-container prefetch, .task(id:) cancellation, view-owned handler teardown)
- [Phase 16]: 16-05: swiftlint:disable:next directives cannot land before 11-11 uncomments lifecycle_modifiers (trips superfluous_disable_command); 11-11's flip commit must carry the rule AND every exception directive atomically
- [Phase 16]: 16-05: Setting/Filters/Downloads lifecycle migrated with zero D-02 exceptions; StackAction.popFrom is the dismissal-teardown seam
- [Phase 16]: 16-05: Pitfall 4 resolved by observation: AccountSetting's jar subscription outlives the login push, so no re-check re-fire is needed
- [Phase 16]: 16-05: lifecycle_modifiers and binding_initializer flipped to error atomically with the last fixes and all six D-02 directives — a disable directive cannot precede its rule (superfluous_disable_command)
- [Phase 16]: 16-05: Toast's ToastInteractionState deleted rather than exempted: it mirrored the presentation binding, and its two lifecycle callbacks existed only to maintain the mirror
- [Phase 16]: 16-05: 11-12: unchecked_subscript_index_access directive deferred to 11-17's flip commit — a directive naming an unregistered rule is a superfluous_disable_command warning
- [Phase 16]: 16-05: 11-12: AppModels' Gallery.preview/previews/mockGalleries still mint random UUIDs; left for the owner (AppModels→PreviewSupport dep is architectural)
- [Phase 16]: 16-05: ReadingFeature subscript matches resolved by honest 'page' renames (60 Dictionary sites) + enumerated() restructure (1 Array site); no exception sites, nothing for 11-17 to insert
- [Phase 16]: 16-05: Draft rule's excluded: '[validatedIndex]' entry confirmed inert (file-path regex); recommend 11-17 delete it or move the escape into the rule regex
- [Phase 16]: 16-05: ParserFeature's 20 Parser+Detail subscript matches were one design defect: parseInfoPanel returned an 8-slot positional [String]. Replaced with a named-field InfoPanel struct.
- [Phase 16]: 16-05: parseGalleryTitle now extracts gid/token inside the guard that validates pathComponents.count >= 4, so four list-mode call sites stop indexing a scraped URL on trust.
- [Phase 16]: 16-05: Plan 11-14 created zero precondition-checked exception sites — 11-17 has no directive to insert in ParserFeature.
- [Phase 16]: 16-05: 11-16: 22 of ImageColors' 25 subscript matches were one defect — proposed[0...3] was a positional record; replaced with a named-field ProposedColors struct (11-14's pattern, 2nd use)
- [Phase 16]: 16-05: 11-16: histogram pixel walk rebuilt on makeIterator() + four-way while-let — index arithmetic removed rather than precondition-checked; tally is order-independent so parity holds
- [Phase 16]: 16-05: 11-16: doc_comment rule defect independently reproduced (2nd confirmation); no clarity loss this time only because the code change made the old subscript wording obsolete
- [Phase 16]: 16-05: 11-16: zero exception sites again — 4 waves / 172 matches with the sanctioned precondition form never once used; flagged to owner as an untested exception idiom before the flip
- [Phase 16]: 16-05: 11-16: ImageColors.colors tie-breaks nondeterministically (unstable sort over hash-seeded Dictionary keys) — pre-existing, load-bearing in the parity argument, left unchanged
- [Phase 16]: 16-05: unchecked_subscript_index_access live at error; doc-comment kind is 'doccomment' not 'doc_comment' (invalid entries silently discard the whole rule config)
- [Phase 16]: 16-05: Inert validatedIndex excluded entry deleted; 240 matches over 5 waves needed only 2 exception sites
- [Phase 16]: 16-05: labeled_tuple_elements: draft regex was mis-tuned both ways — its bracket-excluding element class hid 11 genuine sites (incl. a same-typed ([Int: URL], [Int: URL]) pair) while flagging 11 non-sites (tuple assignments via newline-crossing \s, and function-type parameter lists where Swift forbids labels)
- [Phase 16]: 16-05: (String, TagTranslation?) became a named struct TagTranslationLookup in AppModels, not a labeled typealias — a typealias satisfies the rule but leaves .0/.1 legal, and three sites read .1
- [Phase 16]: 16-05: Labeling a public positional return creates a constraint the unlabeled version silently absorbed: parseMPVKeys had to adopt ReadingReducer's pre-existing key: label, since differently-labeled tuples do not convert
- [Phase 16]: 16-05: FileClient.live became a function with injectable Application Support / Caches roots (production defaults); FileClientTests dropped .serialized for per-test UUID roots
- [Phase 11]: Plan 11-20: no Kingfisher seam needed — the production read path resolves @Dependency(\.dataCache), so the two DownloadImageParsing suites were primed against a cache the code no longer reads (their nil assertions were trivial misses, now bracketed by pre/post cache probes)
- [Phase 11]: Plan 11-20: DidLoginKey.subscribe now creates its jar stream synchronously instead of inside the consuming task, fixing a real 1-in-4 flake where a mutation published to zero subscribers was lost
- [Phase 16]: 16-05: DownloadsFeatureTests fully de-serialized: all 38 traits removed, none retained; .serialized is within-suite only, so no trait could have guarded cross-suite state
- [Phase 16]: 16-05: DownloadCoordinator gained an injectable clock (now:, defaults to Date()) so the progress-flush throttle's wall-clock branch can be frozen off in tests
- [Phase 16]: 16-05: TCA TestStore is main-actor-bound; 85/104 DownloadsFeatureTests cases legitimately require @MainActor — the sweep's ceiling is the library, not annotation hygiene
- [Phase 16]: 16-05: Annotate members, never the suite type: a @MainActor type carries a main-actor protocol conformance that @Sendable dependency closures cannot call
- [Phase 16]: 16-05: Test plan gap: EhPanda scheme silently skipped CookieClientTests, ImageClientTests and ReadingFeatureTests; added (523 -> 565 tests)
- [Phase 16]: 16-05: ImageClientTests needs no @MainActor: UIGraphicsImageRenderer/UIImage fixture rendering is not main-actor-bound; all 9 cases freed
- [Phase 16]: 16-05: DownloadsFeatureTests reaches zero optional-try; 2 of 155 sites became plain try (1.3%) — the target is IO-heavy, 83% are defer-cleanup which cannot throw
- [Phase 16]: 16-05: removeTemporaryItem moved from the DownloadFeatureTestCase protocol extension to a free function; 7 suites declare no conformance and could not reach it
- [Phase 16]: 16-05: No hidden broken tests surfaced in this target, unlike 11-09 and 11-20
- [Phase 16]: 16-05: optional_try flipped to error repo-wide (D-15, no Tests exclusion); doccomment added to excluded_match_kinds because the drafted pair flagged a real doc comment; zero exception directives repo-wide
- [Phase 16]: 16-05: sorted_imports live at error, 893 violations resolved 100% by --fix across 325 files
- [Phase 16]: 16-05: Stale top-level excluded: EhPanda/App/Generated removed — the path died with the modularization, nothing replaced it
- [Phase 16]: 16-05: 325-file autocorrect reviewed by diff-shape assertion (only import lines changed; Swift half net-zero) rather than reading every file
- [Phase 16]: 16-05: 11-26: single_line_trailing_closure Sources half — 145 sites (not ~149) rewrapped, 130 parenthesized / 7 multi-line; config untouched, flip stays with 11-27
- [Phase 16]: 16-05: 11-27: single_line_trailing_closure live at error, 0 across all four roots; Tests half was exactly 70 sites (215 phase total)
- [Phase 16]: 16-05: 11-27: doccomment added to the drafted excluded kinds — the rule contrasts two syntactic forms, so a doc comment quoting the rejected one must not fire; 0 matches today
- [Phase 16]: 16-05: 11-27: no nested-closure trap in Tests — 4 of 6 nested sites sit in accessor braces, 2 in an unpoliced dependency-override closure; parenthesizing was the only fix, not a silencing shortcut
- [Phase 16]: 16-05: multiline_function_chains live at error (SwiftLint defaults) — the seventh and final LINT-01 rule flip; 43 chained-call sites reformatted across 19 Sources files
- [Phase 16]: 16-05: The rule's ~85 raw violations deduplicate to 43 real sites — it reports once per chain-link pair, so the headline count double-counts
- [Phase 16]: 16-05: 11-31: Page-count icon parity is restored with .imageScale(.medium), not the plan's .small — .small undershoots the pre-sweep glyph by 3.25pt (~20%)
- [Phase 16]: 16-05: 11-31: The Label icon inflation is list-specific; free-standing, a Label's icon already matches a bare Image exactly (20x16). Re-deriving this outside a List gives the wrong answer.
- [Phase 16]: 16-05: 11-31: No automated parity test ships — rendering a List for measurement needs a UIWindow, and every scene-free UIWindow initializer is deprecated on iOS 26 with no window scene available in the test host
- [Phase 16]: 16-05: 12-01: AppError.cloudflareChallengeFailed carries no associated value — per-incident diagnostics stay in ErrorInfo.context, which structurally keeps the clearance value out of every user-visible string
- [Phase 16]: 16-05: 12-01: The new error's recovery suggestion names the real screen (Account Configuration), not the plan's placeholder wording, so the suggestion points somewhere reachable
- [Phase 16]: 16-05: 12-01: An unsolved Cloudflare wall is account-level fatal in the page-download batch guard — it blocks every request and the case is non-retryable; unreachable today but the safe arm when D-05 detection widens
- [Phase 16]: 16-05: 12-01: The clearance pair is a named Sendable struct, not a tuple (labeled_tuple_elements at error), and lives in an InMemoryKey whose strategy IS the C5 no-persistence guarantee
- [Phase 16]: 16-05: 12-03: ChallengeWebViewController is its own WKHTTPCookieStoreObserver — the store does not retain observers, and the view hierarchy already keeps the controller alive
- [Phase 16]: 16-05: 12-03: Observer teardown runs in dismantleUIViewController, not deinit — a MainActor-isolated deinit cannot touch WKHTTPCookieStore
- [Phase 16]: 16-05: 12-03: LoginClient.live is a named function, not a closure literal, so LoginRequest's typed throws(AppError) survives the seam
- [Phase 16]: 16-05: Folded the Cloudflare challenge flow into LoginReducer rather than a child feature: one destination, one counter and four actions would need the parent's credentials, loginState and CancelID anyway
- [Phase 16]: 16-05: One shared login effect serves the first POST and every retry, so a retry can never take a path that skips challenge classification
- [Phase 16]: 16-05: 12-05: Per-case InMemoryStorage override isolates the process-wide @Shared(.cloudflareClearance) holder — isolation by construction, no teardown a future case can forget
- [Phase 16]: 16-05: 12-05: The challenge bound is proven by walking two full rounds through the reducer, not by asserting on challengeRounds
- [Phase 16]: 16-05: 12-05: D-02 silence is proven by an exhaustive TestStore receiving nothing after the dismissal — no negative assertion to keep in sync
- [Phase 16]: 16-05: 12-05: LockIsolated mutates via withValue; withLock belongs to the @Shared projection (first-compile error worth remembering)
- [Phase 16]: 16-05: 12-06: The Cloudflare clearance is captured by polling the web view's cookie store — WKHTTPCookieStoreObserver alone never fired for page-set cookies on the live wall, and a didFinish check read an empty jar before WebKit propagated it
- [Phase 16]: 16-05: 12-06: A swipe-dismissal of the challenge sheet is detected by reading the destination BEFORE BindingReducer applies the write — every Destination case is @ReducerCaseIgnored, so PresentationAction.dismiss is never routed and SwiftUI echoes the reducer's own dismissals through the same binding
- [Phase 16]: 16-05: 12-06: loginDone applies the response's credentials before consulting didLogin — 12-02's clearance retry sets httpShouldHandleCookies = false, so URLSession no longer files the response's Set-Cookie and didLogin saw pre-login state
- [Phase 16]: 16-05: 12-06: Every login failure arm raises a toast; only the Cloudflare arm had one, and the missing surface is why the didLogin bug presented as total silence
- [Phase 16]: 16-05: 12-06: AppError.loginCaptchaRequired is deliberately separate from .cloudflareChallengeFailed — both are Cloudflare, but only the edge challenge is clearable by the in-app surface, so conflating them would point at the wrong recovery
- [Phase 16]: 16-05: 12-06: The login response body is parsed for the forum's error box under BOTH labels it uses; reading only the first is how the Turnstile requirement went unreported through several rounds of diagnosis
- [Phase 13]: GalleryURLParser.Route carries normalized url, gid, pageIndex, commentID, and isGalleryImageURL as the call-site migration contract. — Centralizes normalization and eliminates optional round-trips and empty-string failure sentinels.
- [Phase 13]: Gallery hosts are derived from Defaults.URL anchors and matched exactly with computed www variants. — Preserves the canonical hosts while rejecting substring spoofing and accepting real-world www share links.
- [Phase 16]: 16-05: 13-02: Context.unsupportedLink(url:) stores a URLComponents-sanitized rendering under ContextKey.link.
- [Phase 16]: 16-05: 13-02: Unsupported-link diagnostics retain scheme, host, and first path component only; deeper paths become one ellipsis.
- [Phase 16]: 16-05: 13-02: AppError.unsupportedDeepLink is non-retryable and non-fatal to account-wide download batches.
- [Phase 13]: Use GalleryURLParser route.url after parsing custom-scheme links. — Preserves the former HTTPS normalization while removing the injected client.
- [Phase 13]: Keep fallback, timing, cancellation, and no-op behavior unchanged during the parser seam swap. — Failure policy and deterministic timing changes belong to later Phase 13 plans.
- [Phase 13]: Reducer tests now exercise production GalleryURLParser behavior directly. — The removed deterministic dependency no longer needs noop or custom test overrides.
- [Phase 13]: Clipboard discovery validates route support before entering the explicit-open handler, preserving silence for unsolicited URLs.
- [Phase 13]: Unsupported explicit input uses the sanitized unsupported-link context directly so raw access-bearing URLs do not enter ErrorInfo.
- [Phase 13]: ShareExtension rewrites only URLComponents.scheme and completes the request when conversion cannot produce a URL.
- [Phase 13]: SwiftUI reports sheet dismissal completion as a fact; PresentationFeature alone decides whether to re-present a pending gallery.
- [Phase 13]: Gallery fetching begins immediately while only the final presentation waits for dismissal completion.
- [Phase 13]: A later deep link clears any pending replacement and cancels the superseded fetch so the latest request wins.
- [Phase 16]: 16-05: 13-06: Toast overlay animation follows the presented AppAlertState UUID, covering presence and replacement at one scoped boundary.
- [Phase 16]: 16-05: 13-06: Gallery failure reducers replace loading toasts synchronously; only successful resolution clears before routing.
- [Phase 16]: 16-05: 13-06: The existing id-keyed auto-dismiss task remains unchanged so replacement cancellation and timer restart semantics stay intact.
- [Phase 13]: Use Synchronization.Mutex for the URLProtocol fixture directory. — Foundation URLProtocol callbacks are synchronous, so checked synchronous state is the correct concurrency boundary.
- [Phase 13]: Override clipboard reads only and preserve live save endpoints. — The seam bypasses the paste prompt without changing application write behavior.
- [Phase 13]: Attach reading_page_indicator to ControlPanel's numeric Text. — That is the actual page-index element whose existing label carries current and total pages.
- [Phase 13]: Cold UI-test delivery uses XCUIApplication.open(_:) after the Xcode 26.6 / iOS 26.5 probe proved both URL and hermetic environment delivery.
- [Phase 13]: Warm UI-test delivery uses XCUIDevice.shared.system.open exactly; runner-bundled fixtures keep the UI suite offline and credential-free.
- [Phase 13]: Cold scheme tests explicitly terminate before URL delivery; warm tests prove foreground state and never relaunch after opening.
- [Phase 13]: Reader and toast identifiers are assigned after forming explicit accessibility containers so nested destination markers remain distinct.
- [Phase 13]: Comment deep-link coverage proves detail remains beneath comments by navigating back after locating the linked comment.
- [Phase 14]: D-15: the full eleven-case Category enum ships, including imageSet and private — D-07's nine-name parenthetical was incomplete recitation, not deliberate narrowing
- [Phase 14]: D-16: per-namespace tag counts ship as exact Int values, not through CountBucket — an amendment giving D-08 a second documented exception, at the cost of a larger aggregate re-identification surface
- [Phase 14]: D-17: a random 64-character salt is stored beside the app ID in the gitignored Analytics xcconfig; the value is write-once because changing it after release permanently resets retention and DAU/MAU
- [Phase 14]: D-18: the SwiftLint custom rule rejecting the TelemetryDeck SDK import outside AnalyticsClient is approved, putting plan 14-17's conditional lint task in scope
- [Phase 14]: D-19: TagNamespaceCounts(tags:) and SearchShape(keyword:) live inside AnalyticsClient as the audited reduction boundary — an amendment to D-09 permitting exactly one String parameter on the module's public API
- [Phase 16]: 16-05: [Phase 14]: 14-03: TagNamespaceCounts stores exact [TagNamespaceKey: Int] counts per D-16; the plan frontmatter's four bucketing assertions are superseded and recorded, not silently diverged from
- [Phase 16]: 16-05: [Phase 14]: 14-03: TagNamespaceKey (known/unrecognized) is a new closed key type — TagNamespace has no unrecognized case, and widening the key to String would re-admit the scraped raw namespace D-06 forbids
- [Phase 16]: 16-05: [Phase 14]: 14-03: a namespace's count is the sum of its GalleryTag contents, not the number of GalleryTag values; a zero-content tag contributes no key so absent stays absent
- [Phase 16]: 16-05: [Phase 14]: 14-03: Category gained an analyticsName spelling rather than shipping its scraped display raw values, making the eleven-case D-15 set a compile-time commitment
- [Phase 16]: 16-05: [Phase 14]: 14-03: raw values are left implicit throughout the vocabulary (redundant_string_enum_value is on by default) and every spelling is pinned in tests instead — a rename fails a test naming the dashboard column it would orphan
- [Phase 16]: 16-05: [Phase 14]: 14-03: AnalyticsErrorCategory follows failure origin — thrown-exception for a failed operation, app-state for an account/host gate, user-input for what the user supplied or asked for
- [Phase 16]: 16-05: [Phase 14]: 14-03: the reflection leak probe lives in one shared test file (Mirror.leafRenderings) rather than duplicated across three suites, and every sentinel sweep carries a vacuity guard
- [Phase 16]: 16-05: 14-04: D-17's salt rides the same path as the app ID — TELEMETRYDECK_SALT, TelemetryDeckSalt, AppInfo.telemetryDeckSalt — extending plan entries written before the decision
- [Phase 16]: 16-05: 14-04: The salt is generated by the owner on the release machine, never by the plan — a generated value in the tree would either be committed or presume a write-once choice that is the owner's
- [Phase 16]: 16-05: 14-04: Committed-outer / optional-inner xcconfig confirmed on this Xcode — #include? of an absent file is a silent no-op, so a clean clone builds warning-free (research assumption A3)
- [Phase 16]: 16-05: 14-04: Bundle.main from an SPM module reaches the app bundle's substituted keys, proven by PlistBuddy against a built bundle rather than the source plist (research assumption A2)
- [Phase 16]: 16-05: 14-04: AppInfo's analytics accessors trim before testing emptiness, so a stray space or newline in the local override cannot present as a credential the SDK would reject at runtime
- [Phase 16]: 16-05: 14-05: AnalyticsSignal is a closed thirteen-case enum no reducer can escape; the single no-default rendering switch is the only site that mints an analytics name or key (D-09)
- [Phase 16]: 16-05: 14-05: both D-08 exact-Int exceptions render decimal — keyword length (D-07) and per-namespace tag counts (D-16); Task 2's 'one permitted exact Int' wording is superseded
- [Phase 16]: 16-05: 14-06: AnalyticsClient is the single SDK import site (D-12); its live value is gated on AppInfo.telemetryDeckAppID so a nil credential resolves the whole client to no-op (D-13), and it configures the SDK with both the app ID and the D-17 salt.
- [Phase 16]: 16-05: 14-06: D-11 default parameters re-read live shared settings per signal via @Shared/@SharedReader declared inside the SDK's defaultParameters closure, never snapshotted at init.
- [Phase 16]: 16-05: 14-07: hardened all 55 DownloadsFeatureTests TestStore sites to analyticsClient = .noop ahead of wave-6 instrumentation; client testValue = .unimplemented left intact
- [Phase 16]: 16-05: [Phase 14]: 14-08: Hardened all 28 SettingFeatureTests TestStore sites to analyticsClient = .noop (via factories where present) ahead of wave-6 SettingFeature instrumentation; testValue = .unimplemented left untouched.
- [Phase 16]: 16-05: [Phase 14]: 14-08: Behavioral probe PASS — a temporary real analyticsClient.send from LoginReducer.login kept the target green, proving per-store dependency resolution, then reverted with an empty git status for AppPackage/Sources.
- [Phase 16]: 16-05: 14-09: Hardened all 24 TestStores across AppFeatureTests/HomeFeatureTests/DetailFeatureTests/ReadingFeatureTests to analyticsClient = .noop; scoped-child stores in the app-root target included; behavioral probe green from all four modules.
- [Phase 16]: 16-05: 14-10: analytics SDK initialized once from onLaunchFinish reducer effect, never a view callback (D-14)
- [Phase 16]: 16-05: 14-10: tabOpened emits only on a genuine tab switch; error-detail drill-down and caption-only toasts emit nothing (T-14-13)
- [Phase 16]: 16-05: 14-11: Home section/misc taps emit homeSectionViewed through one exhaustive mapping (no default: arm)
- [Phase 16]: 16-05: 14-11: galleryDetailOpened emits on the Home push case only, avoiding double-count with the iPad modal (T-14-13)
- [Phase 16]: 16-05: 14-12: performed-search analytics emits from the fetch-completion case (result count known there); the fetch-request and history-keyword cases stay deliberately silent to avoid double-counting and keyword leakage
- [Phase 16]: 16-05: 14-12: quick-search word usage is a payload-free QuickSearchReducer.wordTapped action — the word is forbidden content (D-06), so the signal carries nothing about it
- [Phase 16]: 16-05: 15-01: UIBackgroundModes keeps processing with an in-plist rationale comment — no Apple source says it is unnecessary for continued-processing, and a wrong removal fails every submission with notPermitted.
- [Phase 16]: 16-05: 15-01: RESEARCH A2 settled by observation — $(PRODUCT_BUNDLE_IDENTIFIER) DOES expand inside a BGTaskSchedulerPermittedIdentifiers array entry (built plist prints app.ehpanda.continued.*); no literal fallback needed.
- [Phase 16]: 16-05: 15-01: Deletions took their orphans with them — AppDelegateReducer's file-scoped logger + OSLogExt import, and the test suite's stale @MainActor rationale comment.
- [Phase 15]: 15-02: Both older background-execution mechanisms are deleted outright; hasPendingWork survives as a mechanism-free schedulable-work predicate in DownloadClient+PendingWork.swift — D-01/D-02 make the deletion the design; deleting before rebuilding keeps every intermediate commit green
- [Phase 15]: 15-02: scheduleNextIfNeeded stays a forwarder over its core, with a comment recording that its tail is the single convergence point every queue mutation reaches — Plan 15-06 re-hangs a session reconcile there; collapsing the forwarder would delete the rationale with the call
- [Phase 15]: 15-02: Shared test fixtures that non-conforming suites must reach live at file scope, reaching protocol-extension factories through a private empty conformer — Seven suites in DownloadsFeatureTests declare no DownloadFeatureTestCase conformance, and a file-scope function has no receiver for a protocol default
- [Phase 16]: 16-05: [Phase 15]: 15-03: The continued-processing launch handler and expiration handler inherit main-actor isolation directly; no MainActor.assumeIsolated is needed (settles RESEARCH Assumption A3).
- [Phase 16]: 16-05: [Phase 15]: 15-03: The session store clears its task and continuation before any terminal call, making a second terminal transition structurally impossible rather than merely guarded.
- [Phase 16]: 16-05: 15-04: Card subtitle declares completed/total/galleries as named lld substitutions, so the generated symbol takes three labeled Int parameters and no String — no gallery identity can reach the system card
- [Phase 16]: 16-05: 15-04: DownloadCoordinator stores backgroundProcessingClient with a .noop default; the live composition root injects .live, keeping every pre-existing test construction compiling
- [Phase 16]: 16-05: 15-04: The session spy takes and clears its continuation in one critical section, so a double terminal transition is structurally impossible in tests as it is in production
- [Phase 16]: 16-05: 15-05: Session lifecycle methods are public, matching the module convention, so the lifecycle suite can drive them without @testable
- [Phase 16]: 16-05: 15-05: The pushed session total is held at or above the monotonic completed count, so a queue shrink cannot report a fraction above one
- [Phase 16]: 16-05: 15-06: the card's pushed subtitle is built from the same clamped counts the progress bar receives, so a queue shrink cannot show a full bar beside a zero-of-four caption
- [Phase 16]: 16-05: 15-06: expiration parity is asserted against a per-gallery pause baseline computed from an identical fixture, never against a hard-coded display status
- [Phase 16]: 16-05: 15-06: session progress rides the throttled manifest flush (one throttle for both the manifest write and the card), because steady progress reporting is what keeps the scheduler from expiring the task as stalled
- [Phase 16]: 16-05: The topology decision is enforced by a source-tree invariant that scans the app target, package sources, package tests, the extension and App/Info.plist for eight deleted background-execution spellings, demonstrated failing on a deliberate violation before acceptance
- [Phase 16]: 16-05: App/Info.plist is exempt only from the scheduler-scope assertion and is paid for by a paired count assertion, because the system key name contains the scheduler type name by construction
- [Phase 16]: 16-05: Every scanned token is assembled from fragments at run time so the invariant file is not a self-match and the repository grep gates can still read zero
- [Phase 16]: 16-05: ROADMAP Phase 15 amended to the shipped contract: no fallback tier in SC3, session seam plus coordinator in SC4, and the open scope question recorded as resolved rather than deleted
- [Phase 15]: 15-09: The continued session carries a per-session UUID minted with the liveness flag; every late-arriving teardown, event and post-suspension resume must present it, so a superseded session can no longer detach a live one (CR-02/WR-01).
- [Phase 15]: 15-09: The non-initial cancelQueuedWorkItem branch converges through scheduleNextIfNeeded rather than reconciling inline, so it inherits the reconcile tail like every other queue mutation (WR-04).
- [Phase 15]: 15-10: The background-processing seam returns an optional identified session handle; only that handle's id may complete the store session.
- [Phase 15]: 15-10: The coordinator records the client id only after its ownership re-check and leaves it nil while start is in flight.
- [Phase 15]: 15-10: A refused start rolls back only the requesting coordinator stamp so the next queue-mobilizing action can retry.
- [Phase 15]: 15-10: Shared continued-session fixtures live in DownloadFeatureTestHelpers to preserve the hard file-length gate and support plan 15-11.
- [Phase 15]: Record accepted starts completely before parking behind the deterministic one-shot gate. — The entered signal must expose the exact in-flight identity state without polling.
- [Phase 15]: Model client refusal as an observable call that creates no session identity or event stream. — The spy must reproduce the store contract so coordinator rollback and retry remain testable.
- [Phase 15]: 15-12: Capture title, subtitle, completed count, and total count from one coordinator snapshot before submitting the continued session.
- [Phase 15]: 15-12: Every card progress mutation presents the client session id read after the coordinator's post-suspension ownership re-check.
- [Phase 15]: 15-12: Stage stale progress after seam entry but before the identity guard so S1-to-S2 rejection is deterministic.
- [Phase 15]: 15-13: Preserve the vanished-record delete's not-found contract, but publish settled state and enter scheduling convergence before returning.
- [Phase 15]: 15-13: Keep activeTask as a documented fast path while routing every disk-backed schedulable-work decision through one actor-isolated authority.
- [Phase 15]: 15-13: Observe scheduling with an injected skipped-operation runner and await observer task values instead of polling.
- [Phase 15]: Queue-intent generation is distinct from active-task generation and advances only when a user action writes fresh queue intent.
- [Phase 15]: A superseded expiration pause converges only after its scheduling block is lifted, completing the queue-mobilizing user action that superseded it.
- [Phase 15]: Blocking runners release on cancellation by default while an explicit opt-out preserves a deterministic interleave window.
- [Phase 15]: Drive expiration through the real event handler so coverage includes session teardown before the per-gallery pause.
- [Phase 15]: Hold the scheduled runner after cancellation so retry lands after the first ownership guard and before settled pause writes.
- [Phase 15]: Keep user-initiated pause last-writer-wins behavior as the explicit boundary of the expiration-only generation guard.
- [Phase 15]: Owner selected option-b on 2026-07-29: remove the unread background-processing dependency registration while preserving direct injection and the macro-generated unimplemented client.
- [Phase 15]: A queue drain that cannot name the client session is early rather than authoritative; reconciliation remains debt owned by the current coordinator session.
- [Phase 15]: The session spy records every start attempt but refuses one while an identity is held, releasing that identity only through matching finish or expiration.
- [Phase 15]: Pause error exits converge unconditionally, including expiration-owned pauses, without starting a continued-processing session.
- [Phase 15]: Interrupted-download normalization may omit scheduling only when no active task exists and its caller deliberately requested notification-only reconciliation.
- [Phase 15]: Remove gallery titles from completion and enqueue logs; neither operational message needs content names.
- [Phase 15]: Hash-mask gallery identifiers so download events remain correlatable without disclosing gallery identity.
- [Phase 15]: Keep raw errors, localized descriptions, and rejected-response snippets private throughout DownloadClient.
- [Phase 15]: Scope the log-privacy invariant to DownloadClient after auditing two non-gallery BackgroundProcessingClient fields.
- [Phase 15]: 15-20: D-G2-01 — a gallery leaving the schedulable set retires exactly the pages it finished, added to both sides of the session fraction; one formula covers every departure path
- [Phase 15]: 15-20: The retirement ledger is maintained by a push-time membership sweep, not a hook in settleCompletedDownload, so all six departure paths are covered by construction
- [Phase 15]: 15-20: D-10 is extended (not reopened) — the pushed pair carries retired pages alongside live schedulable work; the user-visible contract is unchanged
- [Phase 15]: 15-21: no production code changed — D-G2-01's single formula already covered pause, delete and rejoin, and every new case passed on its first run
- [Phase 15]: 15-21: cases driving a real product primitive assert the last pushed update; cases asserting a whole pushed series use the deterministic queue-set seam
- [Phase 16]: 16-05: 15-22: D-G2B-01: the drain branch of reconcileContinuedSession emits exactly one progress push, after the client-session deferral and before markContinuedSessionEnded — a later position compiles and silently does nothing
- [Phase 16]: 16-05: 15-22: DEC-A left unresolved: the terminal push ships with an identifier-free drain log as the discriminator; rebasing galleryCount onto the session's whole coverage is a documented-contract change withheld from the executor
- [Phase 16]: 16-05: 15-22: DEC-B: nothing in this plan closes G-15-2B — 15-UAT.md test 2 stays a physical-device gate and SC2 stays PRESENT_BEHAVIOR_UNVERIFIED
- [Phase 16]: 16-05: 15-23: The drain-branch re-check guards drain-ness (hasPendingWork() == false), not session identity — identity provably cannot change inside the terminal push's main-actor hop, while drain-ness can.
- [Phase 16]: 16-05: 15-23: The client-seam test double must suspend wherever the live main-actor-confined value does; BackgroundProcessingClientSpy now yields on start/updateProgress/finish.
- [Phase 16]: 16-05: 15-23: One terminal-shaped progress push is accepted as a transient — the push's arguments are computed before the hop and re-checking ahead of the push cannot exist, because the push is the suspension.
- [Phase 16]: 16-05: 15-24: D-G4-01: a schedulable gallery's session-completed pages are its record's count only when the record reads incomplete or this session already observed it incomplete; otherwise zero
- [Phase 16]: 16-05: 15-24: The G-15-4 fix keys on the record and an earned trust set, not on queuedModes: mode-keying would mask mid-run progress and misses the bare re-enqueue route
- [Phase 16]: 16-05: 15-24: shouldSchedule is deliberately untouched: reordering its completeness check ahead of the work-item short-circuit would make every queued redo unschedulable
- [Phase 15]: 15-25: D-G5-01 — the working manifest never claims a page whose file is absent; reconciled inside prepareWorkingSeed, the one point every start mode's run converges on, so .repair, the .initial reuse and the repair-seed materialization are covered by one rule.
- [Phase 15]: 15-25: Record honesty alone is not observable — the run announces its post-preparation basis through prepareWorkingSeedAnnouncingProgress before any page work, because trust is admitted only inside a push's reconcile and no pre-existing push is guaranteed to run during the incomplete window (deterministically none at one missing page).
- [Phase 15]: 15-25: WR-03 folded in as the one recorded trust-machinery exception — ensureContinuedSession's post-re-check seed merges (formUnion / keep-observed) instead of overwriting, so an observation recorded inside the client-start main-actor hop survives; safe because the superseded-start rule is enforced by the preceding identity guard.
- [Phase 15]: 15-25: The plan's holdNextStart/releaseHeldStart spy artifact was not added — the spy's pre-existing armStartGate() already parks the next accepted start with the identical contract, so a second pair would be a thin wrapper CLAUDE.md forbids.
- [Phase 15]: 15-26 D-G6-01: a coordinator-made basis correction withdraws its counted portion from the monotonic floor in the same synchronous stretch that lowers the basis — the floor masks only movements the coordinator did not deliberately make.
- [Phase 15]: 15-26: the withdrawal lives inside reconcileWorkingManifestAgainstPageFiles (whoever blanks, withdraws), unclamped, with the session-start floor seed converted to max(snapshot + floor, 0) so a hop-window correction is folded in rather than overwritten.
- [Phase 15]: 15-26 WR-01: schedulableDownloads() unions activeGalleryID into its queue-scoped read (dedupe, empty-queue full read preserved); the predicates and scheduleNextIfNeededCore's own read are untouched.
- [Phase 15]: 15-26 WR-02: prepareWorkingSeed is private so the announcing wiring cannot silently revert — the demonstrated suite-green revert is now a compile error.
- [Phase 16]: 16-05: [Phase 15]: 15-27: The spy's single-session guard and its one-shot refuseNextStart arm are separate refusal causes with separate guards; only the arm's own branch consumes the arm (G-15-10)
- [Phase 16]: 16-05: [Phase 15]: 15-27: When the double itself is the subject under test, the regression drives the spy's own client endpoints; a coordinator fixture would add choreography that cannot discriminate the defect
- [Phase 16]: 16-05: All nine session-lifecycle mutators drop to internal, but only six get testing forwarders: a forwarder without a test consumer is the attack surface G-15-11 removes
- [Phase 16]: 16-05: Every private helper in DownloadContinuedSessionTests.swift was exclusive to the relocated expiration family, so none was lifted into DownloadFeatureTestHelpers.swift
- [Phase 16]: 16-05: 15-29: the basis withdrawal is keyed on the pre/post downloadIndex[gid] delta (D-G7-01), never on a named mechanism — one non-async bracket wrapping prepareWorkingSeed's whole preparation and writeInitialManifest's body
- [Phase 16]: 16-05: 15-29: an absent after-reading defaults to the before-count, so a record that vanished during a movement withdraws nothing — departures stay the retirement ledger's alone
- [Phase 16]: 16-05: 15-29: the bracket is module-internal because writeInitialManifest lives in another file; one implementation stops the rule forking between the run route and the enqueue route
- [Phase 16]: 16-05: 15-30: Enumeration failure is surfaced as an optional from existingAssetFileURLs; ~10 non-destructive probe callers keep their [] fallback through existingPageRelativePaths, now a pages-only forward to pageFileScan.
- [Phase 16]: 16-05: 15-30: The wholesale-blank refusal is blankedPageCount < manifest.completedPageCount — only claimed pages are blanked, so equality means every claimed page would go: the signature of per-file probe failure en masse, not proof of loss.
- [Phase 16]: 16-05: 15-30: An all-pages-vanished repair deliberately falls back to the pre-D-G5-01 arc (empty existingPages makes the run re-fetch; honesty catches up at flush time), accepted against letting one transient enumeration failure destroy every recorded hash.
- [Phase 16]: 16-05: 15-31: The scheduling block is a per-operation reference count ([String: Int]); schedulability tests ABSENCE of a key, never a stored zero, so releaseScheduling removes the entry at zero and the three readers cannot drift from the count.
- [Phase 16]: 16-05: 15-31: commitPause's not-found exit converged nowhere and its caller returns .settled verbatim — the plan's expected 'convergence owned one frame up on every path' was false in source, so the exit was fixed rather than documented as intended.
- [Phase 16]: 16-05: 15-31: An unmatched releaseScheduling logs at .error and leaves the dictionary untouched; decrementing anyway would consume a different live operation's hold and strand that operation's download.
- [Phase 16]: 16-05: 15-31: The mid-suspension teardown window is narrowed to each operation's own suspensions but deliberately left unstaged — closing it deterministically would need production suspension hooks the gap's suggested_fix does not ask for.
- [Phase 15]: 15-32: The IN-05 union staging premise was false in source — a complete record in the persisted queue reads .queued and is schedulable, so the queued remainder is made unschedulable by a live operation's scheduling block instead.
- [Phase 15]: 15-32: A doc-comment falsifiability claim is run, not asserted — the union was temporarily reverted and the new case observed failing at exactly its first expectation.
- [Phase 15]: 15-33: D-G13-01 — destroying a recorded content hash requires a positive PER-FILE probe determination on top of the positive directory-level one; a listed-but-unanswerable page file is never blanked.
- [Phase 15]: 15-33: The per-file probe is an exhaustively switched AssetFileProbeOutcome (usable / rejected / unprobeable) rather than a second Bool, so a probe exit nobody has enumerated yet cannot default into 'positively absent'; sanitizeAssetFileIfNeeded stays as its Bool forward for the ~10 non-destructive callers.
- [Phase 15]: 15-33: unprobedPages is added ALONGSIDE scanSucceeded, not in place of it — the directory-level and per-file signals answer different questions and the reconciliation consumes them independently.
- [Phase 15]: 15-34: D-G14-01 — a zero-page payload is refused at enqueue with .notFound before any folder or queue mutation, and a zero-page mid-run refetch throws at fetchLatestPayload so the run's existing catch settles the download as failed rather than fake-completing a 0-of-0 record.
- [Phase 15]: 15-34: The zero-page range-guard invariant was swept to its whole class (four sites), so each guard's module-wide comment is derivable in source rather than aspirational.
- [Phase 15]: 15-35 WR-01: a push landing while the client identity is nil is dropped, not replayed — only the drain branch records reconciliation debt, and the next flush or convergence push repaints. The flag is deliberately not set at the skip.
- [Phase 15]: 15-35 WR-02: one canonical wording — 'same-actor calls that do not suspend today; an await introduced inside them reopens this window and needs its own re-validation' — applied at every site claiming about the hasPendingWork/schedulableDownloads chain.
- [Phase 15]: 15-35 WR-04: lastPushedCompletedPageCount names five writers including markContinuedSessionEnded's teardown zero, labeled exhaustive by grep at HEAD.
- [Phase 15]: 15-36: writeSettledPauseRecord is KEPT with a traced reason — its writers are the queue-mobilizing entry points landing inside the unbounded wait, not the cancelled run's teardown
- [Phase 15]: 15-36: commitPause is non-throwing end to end by compiler enforcement; both pause-record helpers drop throws and the unread download parameter
- [Phase 15]: 15-36: an unmatched scheduling release is reported via reportIssue with a static identity-free message before the hash-masked log; the guard still returns without mutating
- [Phase 15]: 15-37: WR-09's dispositioned removal of the superseded-arm ensure was probed and REVERTED — it fails the pinned interleave regression because the mobilizing action's own ensure is swallowed by this pause's scheduling block; the gap's second authorized remedy (observable restatement) landed instead
- [Phase 15]: 15-37: The log-privacy invariant scans BackgroundProcessingClient under the download client's rules with a per-root known member, no allowlist entry and no exemption; extended before the log fix, it failed RED on the raw error value
- [Phase 15]: 15-37: The continued-session state is module-internal; testingContinuedSessionTask() is the suites' one route to the session task, both boundary greps empty
- [Phase 15]: 15-38: The throwing-submission producer asserts a defensive take-back, not the gap's cancels-nothing expectation, which predates 15-37's identity-before-submission reorder.
- [Phase 15]: 15-38: A test double's bounded rendezvous must precede its unbounded one, so the regression the case exists to catch fails at a deadline instead of hanging the suite.
- [Phase 16]: 16-05: [Phase 15]: 15-39: materializeRepairSeed carries the source scan's non-answers across the seed copy — setupWorkingFolder returns them and prepareWorkingSeed unions them into the destination scan, so the existing D-G13-01 refusal covers laundered pages with no new refusal mechanism.
- [Phase 16]: 16-05: [Phase 15]: 15-39: A scan-selected page the pre-copy guard skips joins the carried set rather than throwing — carrying re-fetches one page, throwing fails the whole preparation.
- [Phase 16]: 16-05: [Phase 15]: 15-39: PageFileScan's collapse licence is route-scoped, not call-scoped: a caller may collapse the pairs only if its output can never feed a destructive decision, in this folder or any other.
- [Phase 16]: 16-05: 15-40: WR-03 and WR-04 both took the comment-only remedy — the gap record's own premises did not survive re-derivation (four of seven probe callers read listing-derived paths, and the suggested comparison change contradicts the verification's own detail)
- [Phase 16]: 16-05: 15-40: Every inventory a doc still carries is pinned by DownloadSourceInventoryTests, whose scanner skips comment lines so a doc citing an inventory is not part of it
- [Phase 16]: 16-05: 15-41: WR-06 took both halves — dead disjunct deleted AND the function renamed clearCancellationLikeDownloadErrors, precision over normalize* prefix symmetry
- [Phase 16]: 16-05: 15-41: IN-03 took the test pin over a recorded derivation — makeInitialManifest + updateDownloadIndex reach captureCachedPage with a zero-page record without any new seam
- [Phase 16]: 16-05: 15-41: the basis suite split cut on helper usage — landPageFiles stays, restorePermissions travels, nothing promoted; 996 lines becomes 692 + 342
- [Phase 15]: 15-42: the mid-sweep regression stages BOTH galleries queued — a gallery outside the queue is not in the sweep's gid snapshot, gets no iteration, and can express neither the defect nor the fix
- [Phase 15]: 15-42: testingContinuedSessionTask's four-consumer roster replaced by the invariant it stood for (capture before firing the expiration), so an added case cannot falsify it
- [Phase 16]: 16-05: 15-43: the announcement gate replaces the completeness test rather than OR-ing with it; the one shape that loses its announcement (record incomplete, folder holds every claimed page) fetches nothing, so trusting it would breach D-G4-01's ceiling
- [Phase 16]: 16-05: 15-43: trust is granted at the run's own preparation, after prepareWorkingSeed's D-G7-01 bracket closes, so the granting movement withdraws nothing and later movements withdraw their counted portion
- [Phase 16]: 16-05: 15-43: the failed-enumeration companion uses 0o311 and five of six page files, since 0o000 blocks the manifest read and a fully-backed folder routes to .redownload instead of .repair
- [Phase 15]: schedulableDownloads() is the SHARED READ of three named callers, not an authority the scheduler reads; only the isSchedulableDownload predicate is shared. — The scheduler performs its own queue-scoped read, so widening or narrowing this read does not move it; the false claim had survived five rounds in two files.
- [Phase 15]: WR-02's post-launch BGTaskScheduler.register timing is answered with a device-verified note, not a code change. — A per-session UUID identifier under the bundle-scoped wildcard makes pre-launch registration structurally impossible, and 15-UAT.md test 1 passed on physical iOS 26 hardware.
- [Phase 15]: 15-45: restoredIndices drops its prefix(completedCount) bound — proven equal to the whole array from the two writers of completedCount (assigned results.count immediately upstream, incremented only downstream), not asserted.
- [Phase 15]: 15-45: validPageCount(folderURL:manifest:) deleted outright — zero callers repo-wide across App/, ShareExtension/, EhPandaUITests/, AppPackage/Sources and AppPackage/Tests.
- [Phase 15]: 15-45: isReadableAssetFile(at:) deleted rather than kept-with-a-reason — it was a bare forward to the PUBLIC sanitizeAssetFileIfNeeded(at:), so remedy (a)'s precondition is satisfied by its own callee, which all seven production call sites already use.
- [Phase 15]: 15-45: the attributes-throw fallback pin is rerouted, not dropped — testSanitizeAssetFileIfNeededDoesNotDeleteFileWhenAttributesLookupFails keeps the same ThrowingAttributesFileManager staging and both assertions on the production surface.
- [Phase 16]: 16-05: 15-46: A test double that drives a state-storing production route builds its payload through the production steps that read that state — never a literal. — The normalizer's equality guard returns the payload untouched, so normalizing alone leaves a nil selection and only looks repaired.
- [Phase 16]: 16-05: 15-46: The binding between a double and the route it models is owned by a named pin case, with the production event holding the state in place named in its doc comment.
- [Phase 15]: 15-47: The session announcement is gated on the run's own pending page list, not the working folder's shortfall against its manifest — the shortfall ignores payload.pageSelection and credits a selected-page retry that fetches nothing (G-15-27).
- [Phase 15]: 15-47: The pending list is derived exactly once per run, inside prepareWorkingSeedAnnouncingProgress, and handed to performDownload via PreparedWorkingRun — pinned by a fourth census in DownloadSourceInventoryTests so a second evaluation fails a build.
- [Phase 16]: 16-05: [Phase 15]: 15-48: The proof of real page work is owned by the RUN (provenPageWorkRunGIDs) and READ by whatever session is live; the session trust set is seeded from it at every start, never the owner of it.
- [Phase 16]: 16-05: [Phase 15]: 15-48: The run-end retirement sits in processDownload's defer — the only point all FIVE run exits pass — gated on 'no live run for the same gid at a different generation', because pause/delete/folder operations null activeTask mid-run.
- [Phase 16]: 16-05: [Phase 15]: 15-48: A guard that passes vacuously before a fix is not a pin until observed failing with the fix's load-bearing half removed; the lifetime pin's sensitivity was measured, not assumed.
- [Phase 15]: 15-49: the census suite's walk was widened to the downloads test target while every census stayed scoped to the client module, because a census counts over the files the scan returns
- [Phase 15]: 15-49: the retired single-authority claim is owned by a fragment-assembled prose assertion observed RED naming both offending paths before either doc was rewritten
- [Phase 15]: 15-49: the spy's parked progress update was DELETED rather than exposed, because both arming cases already pin the parked push after release through a stronger observation
- [Phase 15]: 15-50: The run's proof of page work carries the PAGES it still owes, not a membership; a trusted complete-reading record is credited its record minus that debt (G-15-30).
- [Phase 15]: 15-50: The decrement rides flushManifestPageProgress, not flushDownloadProgress — a background page landing reaches the manifest without passing the throttle.
- [Phase 15]: 15-50: A retiring run freezes its final credited basis into observedSchedulablePages before dropping its debt and its session trust, which makes the departure retirement ordering-insensitive.
- [Phase 15]: The identifier is recorded only where scheduling.register returned true; that single placement is the whole arm split, so a refused registration records nothing and a successful one is never re-registered.
- [Phase 15]: A refused identifier is never re-attempted — the conservative reading of the store's own recorded constraint, taken because departing from it needs device evidence this plan does not have.
- [Phase 15]: The awaiting-window loss of launch discrimination is dispositioned in writing rather than mitigated, because the SDK supplies nothing that could separate a leftover launch from a live one under one identifier.
- [Phase 15]: Both dissolved-subject cases are rebuilt by staging the stale delivery behind adoption, which reaches the surviving property without two identifiers.
- [Phase 15]: 15-52: The client-double census token is the seam's endpoint LABEL, not its type name — a type-name token misses the `Self(` spelling the offending double uses, so its blind spot would sit exactly where the violation lived.
- [Phase 15]: 15-52: The timing census has two halves that fail on different events — a property half (a double stops suspending) and a population half (a new double appears in a file no table knows) — and each was falsified separately before it was trusted.
- [Phase 15]: 15-52: The macro-synthesized unimplemented value and the module's public `live`/`noop` values are classified OUT of the timing obligation; a test census must not demand yields from generated or production code.
- [Phase 16]: 16-05: [Phase 15]: 15-53: The generation-less retirement arm returns true (superseded, retires nothing); the recorded reason is the asymmetry — one stale proof bounded by the owning run's exit, against dropping a live successor's proof (the G-15-26 zero-progress card).
- [Phase 16]: 16-05: [Phase 15]: 15-53: DownloadLogPrivacyInvariantTests.scannedFiles() supplies the self-exclusion's SHAPE and binding NAME only — it carries no doc comment, so 15-REVIEW.md:443-445's block quotation of its 'rationale' has no source referent and the G-15-33 gap record inherited a false premise.
- [Phase 16]: 16-05: [Phase 15]: 15-53: The plainly-worded statement of the retired single-authority claim stays inside the excluded file, so a repository grep no longer sums to zero; the prose assertion, not a grep, is the live guard.
- [Phase 15]: D-G2C-01: the pushed continued-session gallery count is the denominator's coverage — live schedulable galleries plus retiredSessionPages entries greater than zero — via one shared coverageGalleryCount both subtitle writers call. — The OS does not repaint a push issued immediately before setTaskCompleted, so a count that is only correct on the terminal frame is never reliably correct; making every frame truthful removes the render race instead of racing it.
- [Phase 15]: A zero-page retirement is not counted in the coverage, and the boundary is pinned from both sides on production-path drains. — A gallery that departed having finished nothing left no pages in Y, so nothing of it is represented by the denominator the count describes.
- [Phase 15]: A task's file ownership must close over every file of the suites its gate runs, because -only-testing filters by suite and this tree splits suites across files via extension. — LedgerRefusalTests and RunProofTests extend DownloadContinuedSessionLedgerTests, so a gate naming that suite runs files a sibling task owned.
- [Phase 15]: Third test-literal category: a synchronization predicate must key on a facet the basis still moves. — A waitUntil keyed on the gallery count crossing at a departure stopped observing once the coverage basis held that count constant, hanging the case to its deadline; the denominator still crosses at the same production push.
- [Phase 15]: D-G5B-01 — a missingFiles validation verdict reconciles the persisted manifest through the one D-G5-01 blanking loop (fresh scan as evidence, never the first-failure verdict), inside the sibling withdrawingCountedBasisMovement bracket; validationErrors is cleared on the durable arm because it outranks the manifest in displayStatus, and kept on every refusal.
- [Phase 16]: 16-05: D-G5C-01 (15-57): DownloadInspection.retryablePageIndices unions failed+pending pages exactly at .error with a fileOperationFailed code, and canRetryPages gates on that same basis — so the inspector's retry starts the refusal family, whose pages derive .pending, not .failed
- [Phase 16]: 16-05: D-G5D-01 (15-57): DetailReducer.downloadNeedsRepair reads record honesty (completedPageCount < pageCount) instead of == 0, so a mid-run file failure with landed pages offers the non-destructive repair; a complete-claiming .error record deliberately keeps the destructive redownload
- [Phase 15]: D-SSOT-01 — positive content-level evidence (a readable file whose fresh hash mismatches its record) licenses durable blanking, so corrupt-in-place reconciles exactly as a missing file does
- [Phase 15]: D-SSOT-02 — the all-or-nothing wholesale guard is evaluated over the COMBINED prospective blank set (positively absent union positively mismatched) BEFORE any removal or blanking
- [Phase 15]: D-SSOT-04 — the refuted file is removed under containment, converting corrupt-in-place into the positively-absent shape, so the one blanking loop stays the only blanking path
- [Phase 15]: D-SSOT-05/06 — validationErrors is an operation-level signal only, and AGENTS.md's SSOT invariant was revised to match the code
- [Phase 15]: D-SSOT-07: inspector page states derive from the manifest (recorded hash, recorded page failure); the directory listing is demoted to a rendering-resource resolver and buildInspectionPages makes no file-system call
- [Phase 15]: D-SSOT-08: at the .error/fileOperationFailed shape the retry basis is the FULL page-index set, because the signal is record-wide and manifest-derived pending is empty for the wholesale-refusal family
- [Phase 15]: D-SSOT-09: the run-owned measured session series is scoped OUT of the record-completeness property families, and the exclusion is structural — every fixture uses a noop background client, so no push is observable from the suite at all
- [Phase 15]: CR-02: incomplete-record observation is evidence about one queue-intent generation, not a durable property of a gallery identifier.
- [Phase 15]: Generation mismatch is the single invalidation mechanism for stale session observations; no retry path gains a clear.
- [Phase 15]: Both observation merges keep the greater generation, so a pre-hop snapshot cannot resurrect an observation an in-hop queue intent invalidated.
- [Phase 15]: CR-01: validation evidence gathering is non-mutating; the combined wholesale guard authorizes absences, rejections and mismatches together before any file is removed
- [Phase 15]: PageFileScan.rejectedPageRelativePaths records a refuted page file only while it SURVIVES, so every discarding caller stays byte-for-byte unchanged
- [Phase 15]: The one blanking loop gained a fourth per-file refusal line rather than the caller mislabelling a surviving refuted file as unprobed
- [Phase 16]: 16-05: CR-03: the rename source is admitted by exact normalization equality, never normalized — normalizing a source selects a different folder than the caller named
- [Phase 16]: 16-05: 15-63: lexical standardization and symlink resolution are separate containment questions; both are required and both re-run inside the lock that calls moveItem
- [Phase 15]: CR-04: retryPages filters a caller's page indices against the current record's page domain immediately after the fetch and refuses an empty result before mode resolution, update delegation and every queue or session mutation — The defect was the ORDER: the update delegation and the downstream filtering were each correct where they stood, so admission had to move ahead of both rather than either being replaced.
- [Phase 15]: 15-64: a page selection's PRESENCE is the restriction, so normalizeFetchedPayload keeps an explicitly supplied selection non-nil even when filtering empties it; only nil means unrestricted whole-gallery work — Absence and empty presence are different requests; sharing one value is what let an inadmissible two-index request schedule every page.
- [Phase 15]: 15-64: an update record still refreshes as a WHOLE with no page selection, but only once the request contains at least one admissible page — the exception is documented on the public API and regression-tested from both sides — An update re-fetches against a new page count, so a subset drawn against the old one names pages that may no longer be the same pages; the valid-page requirement is what keeps the exception from being a widening.
- [Phase 16]: 16-05: 15-65: the D-G7-01 bracket wraps the queue-intent MOVEMENT (advanceQueueIntentGeneration's own increment), not its four call sites, so every present and future queue-mobilizing entrance is enclosed by construction (CR-01)
- [Phase 16]: 16-05: 15-65: sibling composition is proved by construction — the bracket's closure is non-async and all four callers are async, so nesting is a compile error rather than an inspection result
- [Phase 16]: 16-05: 15-65: a below-floor masking defect is only observable one landing at a time; the regression's baseline is the re-queue frame, because a withdrawn deliberate movement is MEANT to lower the card
- [Phase 15]: 15-66 CR-03: discardingRejected flipped to non-mutating across all 10 family declarations; entitlement is a pairing (delete only where the same act blanks the record), leaving 4 entitled sites in one actor (the repair seed); scanCompletedFolder deleted and sanitizeLocalFilesIfNeeded renamed clearStaleDownloadErrorIfNeeded
- [Phase 16]: 16-05: DEC-B (15-67): the wholesale guard's combined basis makes an authorized removal guard-NEUTRAL, so the caller's predicate and the loop's are provably one
- [Phase 16]: 16-05: DEC-C (15-67): materializeRepairSeed's SOURCE scan stays discarding — its refusals cross a folder boundary and arrive as positive absences, so neither WR-01 nor WR-02 is reachable through it
- [Phase 16]: 16-05: DEC-E (15-67): split DownloadStore.swift and +ExecutionSupport.swift before growing their contract docs; a 1000-line ceiling reached by prose means the type or the function wants its own file
- [Phase 16]: 16-05: DEC-A (15-68): the user-folder boundary is a closure-taking function (mutatingConfinedUserFolder), so a mutation has nowhere to go but through the confined resolver
- [Phase 16]: 16-05: DEC-B (15-68): userFolderURL(name:) is deleted rather than demoted — unreachability enforced by the symbol's absence, not by an access level the same module could reach
- [Phase 16]: 16-05: DEC-C (15-68): enqueue's parent-folder create is removed as redundant (writeInitialManifest already creates it with intermediates) rather than confined, which would have made a scan-derived non-normalized folder un-enqueueable
- [Phase 16]: 16-05: DEC-D: deleteFolder keeps its existence pre-check ahead of the store so an absent folder still answers .notFound without moving scheduling state
- [Phase 16]: 16-05: DEC-E: the delete escape suite installs a foreign active task, because the staged queue intent otherwise starts a run whose failure path dequeues the gid the case asserts is untouched
- [Phase 16]: 16-05: DEC-A (15-69): only the inadmissible-selection retry exit gets a distinct error; the two absence exits keep .notFound
- [Phase 16]: 16-05: DEC-B (15-69): a fetch-time page-selection collapse throws a named error at normalizeFetchedPayload instead of returning an empty-but-present payload
- [Phase 15]: 15-70 DEC-A: the user-folder admission predicate is derived from scanDownloads' promotion rule, not from the app's own name generator; normalization stays confined to sites that MINT a name
- [Phase 15]: 15-70 DEC-D: moveDownload admits its picked destination raw — rewriting a listed name created a near-duplicate folder beside the one the user picked
- [Phase 15]: 15-71: materializeRepairSeed's source page scan takes the non-mutating default (WR-02) — the source folder is the gallery's currently indexed record and nothing on that route writes its manifest, so no act there was entitled to delete; the destination's own reconciliation records the absence, and the orphan zero-byte file is accepted as IN-03's known unswept population.
- [Phase 15]: 15-71: the destructive-read entitlement rule is now a CENSUS (testDiscardingRejectedSitesMatchTheEntitlementCensus) rather than a per-site comment — exactly two production discardingRejected: true sites remain, both covers, and the census was probed by reintroducing a third site and observing both halves fail.
- [Phase 15]: DEC-A (15-72): the shared recover-once core is `recoveredBlanking` itself, made module-internal and BRACKET-FREE; `blankingPass` lost its bracket and the validate route now supplies ONE spanning bracket around both attempts, which mirrors the seed route's already-open bracket — withdrawingCountedBasisMovement composes as SIBLINGS only, so a self-bracketing helper could not be called from prepareWorkingSeed. One span withdraws exactly what two siblings would: the credited reading does not move between the attempts and both deltas are downward, so max(d1,0)+max(d2,0) == max(d1+d2,0). It opens BELOW the removal, preserving D-G7-01's rule that no deletion happens inside a bracket.
- [Phase 15]: DEC-C (15-72): exit 3 returns a Result out of prepareWorkingSeed's bracket instead of throwing through it — The bracket reads the credited count before and after the movement; a throw unwinds past the second reading and withdraws nothing. Exit 3's compensation can SUCCEED, lowering the record from C to C-k while the monotonic floor keeps holding C — G-15-7's masking shape, reintroduced through the very recovery added to close WR-03. Pre-removal steps still throw straight through, because nothing they can fail after has moved the record.
- [Phase 15]: DEC-D (15-72): scanSucceeded STAYS sourced from the post-removal rescan (15-67's DEC-F is not reverted); WorkingSeed.removedPages is subtracted in BOTH inheritedPages branches instead — Reverting the source would re-split the seed's evidence — credit rule on the pre-removal probe, blanking rule on the post-removal one — which is exactly the defect DEC-F closed. The subtraction instead ranks a removal ABOVE a rescan in the evidence order: a page whose file this pass deleted is positively absent by this pass's own act, and no probe's health can overrule an act. The basis can still under-report toward re-fetching (D-G4-01's chosen direction) and can no longer over-report at all.
- [Phase 16]: 16-05: DEC-A (15-73): the pause failure arm reuses the retry branch's mapping verbatim (toast then reload), renamed actionFailureToast for its two families
- [Phase 16]: 16-05: DEC-B (15-73): the disposition sweep is stated ONCE per reducer as a type-level enumeration, with per-case one-line anchors, so a new outcome-carrying action with no disposition contradicts a doc
- [Phase 16]: 16-05: DEC-C (15-73): DownloadsReducer.toggleDownloadPauseDone is recorded as SILENT-AND-WEAKEST rather than deliberately silent; reporting it needs a toast surface the list does not own, so it is logged as an open item instead of given a justification it does not have
- [Phase 16]: 16-05: 15-74: the counted-basis bracket's SIBLINGS-only rule is a convention with a runtime depth-counter detector (reportIssue, never a trap), not a type-system guarantee — 15-65-SUMMARY corrected in place
- [Phase 16]: 16-05: 15-74: IN-01's one-second detector bound declined on recorded evidence (13.2s wall under contention at that exact case); ten-second default kept and the derivation written at the call site — owner ratification requested
- [Phase 15]: 15-75: DownloadClient's module-local string catalog is deleted, not emptied — all 10 keys moved to the shared Resources catalog with hand-written RLocalizable symbols — The bare key-access spelling IN-02 tracked was only possible because a module-local catalog generated module-scoped symbols. Deleting it makes a bare access a compile error (falsified: BUILD FAILED with 'inaccessible due to internal protection level'), so the split closes at the type level rather than by convention.
- [Phase 15]: 15-75: the DownloadClient key-access census is 25 sites (13 prefixed, 12 rewritten), not the plan's 19 or the review's 18 — Both prior counts matched single-line 'String(localized: .X)'. Three accesses live outside that shape: one line-broken call and two '.missingFiles(LocalizedStringResource)' producers. The plan's own acceptance regex was blind to all three, in the very file the review cited for the split.
- [Phase 16]: 16-05: DEC-A: the both-exist test gate stages two case variants rather than probing fileExists — the iOS simulator reports case-SENSITIVE lookups over a case-INSENSITIVE backing store, a third regime the plan does not describe
- [Phase 16]: 16-05: DEC-B: logs-migration regime classification is a pure total function, so the merge regime is pinned by test on a host whose volume cannot represent it
- [Phase 16]: 16-05: DEC-C: the legacy logs directory name is a frozen literal, not derived from the current constant, so a future rename cannot silently redefine the migration's source
- [Phase 16]: 16-05: DEC-D: the device regime keeps a single atomic moveItem; staging is used only where atomicity is unavailable anyway
- [Phase 16]: 16-05: DEC-E: a logs merge skips a colliding name and keeps the destination copy, because run-log names embed day+time+count so a shared name is the same run and the destination copy may be live
- [Phase 16]: 16-05: DEC-F: the plan's 'no "logs" literal' criterion was replaced — a migration must name the directory it reads FROM; exactly one private literal survives, used only as a move source
- [Phase 16]: Four zero-violation SwiftLint rules (accessibility_hardcoded_string, no_dynamic_type_size_modifier, no_fixed_system_font_size, no_geometry_reader) land now; no_minimum_scale_factor deferred to 16-12 until the owner's five removals land (D-14/D-16/D-23).
- [Phase 16]: accessibility_hardcoded_string deliberately does NOT exclude the 'string' match kind — the string literal itself is the violation (D-30).
- [Phase 16]: 16-02: 16-SWEEP.md is the round-1 state machine: all 42 inventory surfaces are matrix screens (504 pending cells), partial exclusions live in the D-11 column of the host row rather than deleting the row, which is what makes plans 16-04…16-09 add up to 78/84/90 rows per device
- [Phase 16]: 16-02: The sweep's status vocabulary is written as a brace-comma set, not a pipe-separated list, so the mechanical 'no verdict cell reads pass yet' check stays meaningful
- [Phase 16]: 16-03: BUNDLE_ID = app.ehpanda.personal is derived from the project's resolved PRODUCT_BUNDLE_IDENTIFIER on this machine, never chosen; app.ehpanda is never swept
- [Phase 16]: 16-03: IPAD_LOGIN=none — iPad rows of login-gated screens are blocked: no iPad session and surfaced by 16-10; one-row amendment if the owner logs in before 16-07
- [Phase 16]: 16-03: sim-use is the primary sweep driver; § Protocol keeps agent-device vocabulary with a ### Tooling mapping table
- [Phase 16]: D-01 amended by owner in chat: agent extracts a name-free reflow-pattern catalogue and proposes pattern→finding mappings after the sweep; owner still hand-writes every fix; no diffs/patches
- [Phase 16]: 16-05: Detail stats-strip and tag-cloud D-13 cases reproduce; the reader page-counter case does not — the indicator vanishes rather than wrapping (finding #22)
- [Phase 16]: 16-05: Findings #11 and #23 stay separate: two download-delete confirmations fail in different containers (Downloads popover in portrait vs Detail alert in landscape) for different reasons
- [Phase 16]: 16-05: The D-15 collision did not materialise — the Detail header's 0.72 shrink does not visibly engage at .large for a seven-character category, and the badge never truncates at any sampled size
- [Phase 16]: 16-06: Preserve the logged-in simulator and record native Login as blocked instead of forcing logout.
- [Phase 16]: 16-06: D-13 observations move from matrix pending to open once iPhone evidence is recorded; owner disposition remains for closeout.
- [Phase 16]: 16-06: Leave the download progress-spinner D-04 site pending until a legitimate active-transfer state is available.
- [Phase 16]: Watched, Favorites, and FolderManager remain blocked because IPAD_LOGIN=none; no credential seam was used.
- [Phase 16]: Shared iPhone/iPad defects retain Findings #1, #3, #4, #5, #6, and #10; the iPad-only badge/timestamp collision is Finding #32.
- [Phase 16]: The sweep-created eight-page download remains preserved in its Default folder under the user-owned-download invariant.
- [Phase 16]: 16-08: Honor IPAD_LOGIN=none as a hard reachability boundary; no credentials and no inferred iPad modal or regular-width verdicts.
- [Phase 16]: 16-08: Record the Reading Setting sheet as blocked because its Group B entry point is the unavailable live Reading control panel.
- [Phase 16]: 16-09: Honor IPAD_LOGIN=none as a hard reachability boundary for EhSetting; no credentials and no inferred iPad verdict.
- [Phase 16]: 16-09: Block the unseen 20-point download-spinner D-04 site because no active transfer existed and user-owned downloads must not be altered solely for evidence.
- [Phase 16]: 16-09: Preserve the empty Quick Search state; an unsaved editor was sufficient to judge the iPad layout without persisted test data.
- [Phase 16]: D-01 amendment 2 (owner, chat): executor agents implement round-1 reflow fixes in root-cause batches A-F + standalones; owner reviews before/after comparison images per batch; 16-11 protocol unchanged with 'owner batch' = 'fix batch'
- [Phase 16]: Owner reflow quality bar: HStack→VStack fallbacks need deliberate vertical spacing + horizontal padding, not just fitting; A–E get a polish pass after round-I review
- [Phase 16]: Round-I review directions (owner, chat, 2026-09-03): hero card ≤ 50 % of container height, cover+title stay horizontal, only rating drops, title truncates inside the budget; Archives footer scrolls with content when short; Torrents counters wrap, never ellipsise; wrapped titles/keywords leading-aligned; list-row badge radius and cover scale with the text (no fixed points); Detail cover stacks above title at AX, namespace chip above its children; log chip on its own line when the row is short; batch-2 composites pair identical page states only
- [Phase 16]: Round-II review directions (owner, chat, 2026-09-03): thumbnail grid floor = 2 columns; Filters category cell radius scales with text; Filters evidence must show the whole sheet; reader upper panel one line with an owner-authorised Dynamic Type cap (lint exception at that site), lower-panel page numbers one line; Detail action buttons grow with their symbols; Detail stats strip keeps its horizontal ScrollView, a column ≤ 90 % width
- [Phase 16]: Thumbnail cell title = 5 lines at every size (owner, chat, 2026-09-03) — supersedes D-15 for that property (default size goes 3→5) because the designed cap never met a half-width column at an accessibility size; a repaired design, not a D-04 exemption; the tail is reached by opening the gallery
- [Phase 16]: Detail title = 3 lines at every size until expanded (owner, chat, 2026-09-03) — round-I's uncapped-above-.large policy withdrawn; the cap's remedy is in place (title is its own expand button), default-size parity untouched
- [Phase 16]: A sheet-presented screen uses a plain large title, never .inlineLarge (owner, chat, 2026-09-03) — SettingView is the only such site and the only one changed; the four tab roots keep .inlineLarge; applied via navigationTitleDisplayMode so the AX-size inline fallback (finding #7) still holds
- [Phase 16]: List gallery cell keeps cover+title on one line when the row is wide (owner, chat, 2026-09-04) — the AX-size cover-above-text stack is gated on measured row width (<550pt), so landscape phones and iPad (both orientations) stay side-by-side; portrait phones still stack
- [Phase 16]: Round 1 closed on owner ROUND1-CLEAR (2026-09-11T08:04Z); D13-4 and #28 fixed on recorded evidence; matrix labelled historical, targeted rechecks sampled
- [Phase 16]: Round 1 signed off: owner approved 2026-09-11T08:35Z covering HEAD 7e06013c, recorded as text in 16-SWEEP.md § Owner sign-off; closes 10-UAT.md test 7 (D-03), ROADMAP Phase 16 criterion 5 and A11Y-01; round 2 unblocked (D-23)
- [Phase 16]: no_minimum_scale_factor lands at error severity only with the tree at 0 sites (zero-then-ban); all five Dynamic Type lint rules live
- [Phase 16]: 16-14: better-of contrast rule exposed on a Double (contrastingForeground(forRelativeLuminance:)); Color.Resolved is Float-backed so the 0.1791 tie is pinned at the Double level (orchestrator option A)
- [Phase 16]: 16-14: category backgrounds pinned by SHA-256 in two groups — standard-44 f940492a…5363 (never re-pinned) and contrast-high-40 e81b0604…0937 (re-pin only under D-27)
- [Phase 16]: 16-15: CategoryCell excluded-state text is chosen against the linear composite over secondarySystemGroupedBackground (elevated card, verified from pixels); one excludedOpacity constant feeds wash and composite; no catalog key under CATEGORYCELL=A
- [Phase 16]: 16-15: HC=A applied — 19 contrast:high entries rewritten values-only; HC-40 pin re-derived to 84accf72…9407, standard-44 pin f940492a…5363 byte-identical; 0/40 HC variants below standard
- [Phase 16]: 16-16: comment cells are combined AX elements carrying the vote as a conditional accessibilityValue; per-link Open link actions via the accessibilityActions builder; Torrents flowed glyphs hidden (not combined) because checkmark.circle reads as 'Selected'; Hath banner is a Button with a parity ButtonStyle
- [Phase 16]: 16-16: sim-use describe-ui --point is the instrument for VoiceOver label/value/trait/custom-action evidence; the agent-device node dump lists AX-hidden nodes and Menu label nodes, so it cannot prove hidden-ness
- [Phase 16]: 16-17: Setting root rows are Buttons with SettingRowStyle drawing the pressed background from isPressed (plan's first option; .isButton fallback not needed)
- [Phase 16]: 16-17: cookie validity is an accessibilityValue on the key Text (glyph hidden, TextField kept separate) — combining a row over a TextField would remove its editing role, a value on the field would replace its text
- [Phase 16]: 16-17: custom on/off cells (ExcludeToggle, Laboratory cell) use accessibilityRepresentation { Toggle(isOn:) } with the visible/positional title; App Icon rows are plain Buttons with .isSelected and a hidden checkmark
- [Phase 16]: 16-18: reader Next/Previous page named actions are direction-agnostic +1/-1 into jump(toPagerIndex:) (the data source stays forward; RTL flips only the paging axis); the assistive zoom maps to the direction-guarded double-tap toggle, not stepped magnify calls
- [Phase 16]: 16-18: a slider's accessibilityValue string is read from agent-device snapshot -i --json (sim-use reports the numeric AXValue); .accessibilityAction(named:) on a container propagates to every descendant element
- [Phase 16]: 16-19: swipe actions are not mirrored as named accessibility actions — SwiftUI exposes .swipeActions as custom actions and does not de-duplicate (measured duplicates on 67377A20…); only context-menu-only items (Downloads row Detail, Detail tag chips) are mirrored via accessibilityActions { <menu builder> }
- [Phase 16]: 16-19: RatingView value uses a named %#@rating@ substitution with formatSpecifier .1f (generated Float parameter, locale-aware); whole ratings read 5.0 out of 5 — owner may prefer the positional formatted() fallback
- [Phase 16]: 16-20: Reduce Motion gates read the environment at the animating view and substitute nil / a non-repeating .default / an opacity-only path / .symbolEffect(.pulse); crossfades and numericText stay ungated (D-29)
- [Phase 16]: 16-20: the reader control panel has a single lower offset (the top bar is the native ReadingToolbar); under Reduce Motion the hidden offset collapses to 0 so the existing .visible(showsPanel) fade carries the transition alone
- [Phase 16]: 16-20: Reduce Motion on the simulator is toggled through the real Settings switch (knob at the row's trailing edge) and read back from com.apple.Accessibility ReduceMotionEnabled; agent-device snapshots wedge on the reader and Settings, so heavy screens are driven with sim-use and simctl
- [Phase 16]: 16-21: Home popularLoadingState animation gated (card insertion pushes sections down; crossfades kept); FolderManager editingField gated with folders; Quick Search listEditMode gated
- [Phase 16]: 16-21: ReduceMotionGatingSourceTests pins D-29 as five two-directional equalities (reads 17, ternaries 22, withAnimation 2, mentions 52, numericText 11 none gated); RepositoryWalk shared in AppToolsTests
- [Phase 16]: 16-22: six distinct level shapes for the Activity Logs glyph (ant / info.circle.fill / bell.fill / exclamationmark.triangle.fill / xmark.octagon.fill / questionmark.circle.fill) via a private view-side OSLogEntryLog.Level.symbol in SettingFeature — AppModels gains no SFSafeSymbols dependency
- [Phase 16]: 16-22: Laboratory cell carries a checkmark.circle.fill / circle state glyph leading the title, accessibilityHidden because the Toggle representation carries the state; cell height unchanged (358 × 71 pt)
- [Phase 16]: 16-22: the .error glyph colour (.orange, 2.31:1 on white in light) is handed to 16-23 as D-28 row log-glyph-error; AppModels untouched
- [Phase 16]: 16-22: absent log levels (debug, info, fault, undefined) measured source-derived from UIKit-resolved iOS 26 colours validated against the rendered gray / orange / indigo / red; labelled per row
- [Phase 16]: 16-23: STARS=B lands as the RatingStar colorset (light #A38100 stands — the Home card re-measured 3.0102, no escalation); CommentLink colorset (light #54832A) + underline at all three link-run sites; Color.mix(with: .black, by:) factors Pages 0.3 / Move 0.35 / Update 0.3 / error glyph 0.15 / NewDawn 0.25 / warning yellow 0.3 chosen from SwiftUI's own mix output and confirmed byte-exact on the simulator
- [Phase 16]: 16-24: audit runs one call per stable type (.hitRegion, .sufficientElementDescription, .trait); .contrast/.dynamicType/.textClipped/.elementDetection removed by owner (2026-09-14)
- [Phase 16]: 16-24: allow-lists are ContentUnavailableView.symbol (system-owned) and E-1.hidden-content (E-1=approve, 2026-09-13); E-2..E-9 and O-2 retired
- [Phase 16]: 16-24: gate runtimes iPhone 17 iOS 26.5 + iPad (A16) iPadOS 26.5 (owner 2026-09-15); iPadOS 27 beta excluded, its Gallery Detail stall deferred
- [Phase 18]: 18-01: DIST-18-01 stays Pending in REQUIREMENTS.md after MKSellsDigitalGoods landed; its marketplace build flavor is Phase 20 work. IN-02/IN-03 are closed (6a35afff6, 20bb9b4bc) and have no REQUIREMENTS.md entry. — A shared requirement reads Complete only when every phase that owns a part has finished it.
- [Phase 18]: 18-02: the deferred launch (liveness observation, loadUserSettings, the withheld scene-phase report) runs once, after both the age confirmation and the launch's cookie maintenance (new internal action launchPreparationFinished). Only a phase withheld while locked is replayed; a link queued while locked routes once the settings load. The hosted visual-test preset lives in configureVisualTestHost, because the prepared dependencies and the store each get their own in-memory suite. — The settings load must never precede the cookie maintenance, and an unlocked launch must keep its old order with no extra download-client call. AGE-18-01 and CONSENT-18-01 stay Pending: 18-03, 18-06 and 18-09 share them.
- [Phase 18]: 18-04: the comment report URL is rebuilt as https://<host>/g/<gid>/<token>/?report=select only for an exact GalleryHost host and a gallery path (nil otherwise); the bundled filter list is stored in natural form and normalised on load, every language group applies to every comment; block helpers are labelled author: and ignore empty names; sessionCookies(for:) reuses the cookiesForURL seam and drops expired cookies. UGC-18-01 stays Pending: 18-05, 18-10, 18-11 and later plans share it. — Pure, tested moderation core for the reducers and UI (18-05, 18-10, 18-11) to build on; T-18-09 and T-18-11 are enforced at the lowest layer.
- [Phase 18]: 18-06: the 38 approved Phase 18 keys are in the Resources, Resources Constant and DetailFeature catalogs verbatim in six languages, with RLocalizable/RConstant forwarders; 18-copy-check.py derives the expected values and the 48 retired texts from the copy files (Revision 6, 5, 2 > first table > first-launch file) and matches the retired level name only as a consent.* value. shareAnalyticsData/shareAnalyticsDataFooter stay in SettingFeature's catalog for 18-10. AGE-18-01, CONSENT-18-01 and UGC-18-01 stay Pending: later plans share them. — One script is the gate for copy drift (T-18-14), re-run in 18-12; nothing in a catalog is retyped by hand.
- [Phase 18]: 18-03: AnalyticsClient.start is now apply(level). No level does nothing; Minimal sends only the own InstallSignalSender's App.installed request (seven fields, payload App.installSource only, settled once per install) and never initialises the SDK, terminating it if running; Basic and Full initialise it once. send reads the stored level live; minimumLevel puts the 10 screen, feature and error signals at Basic and the 3 reading and download signals at Full; the five App.* parameters ride at Full only. TelemetryDeck is imported only by TelemetrySDK.swift and MarketplaceKit only by InstallSourceClient.swift. AppReducer applies the stored level in the deferred launch and the chosen level on levelChosen once that has run. CONSENT-18-01 stays Pending: 18-09 and 18-10 share it. Phase 20 carries OI-4 (newInstallDetected vs App.installed) and ANALYTICS-02 (reuse InstallSourceClient, verify on the marketplace build and a device, add the source to Basic/Full). — Minimal's description promises only an install signal, so the SDK's device payload must never leave under it (D-06b, D-06c, D-06f).
- [Phase 18]: 18-05: one CommentModerationFeature child, scoped as `moderation` into CommentsReducer and DetailReducer, owns the posting warning, Report, Block, Unblock and Show/Hide. postTapped checks CommentFilter before anything is sent; the reducer (not the view) closes the editor after .postComment, and Edit keeps the text and refocuses (P-8). Report asks with the site and author, then presents Destination.reportPage(?report=select); a gallery with no report target gets no alert (owner to confirm). Block adds the author once and re-collapses their revealed comments; Unblock is immediate; revealedCommentIDs is per screen and never stored. Own comments (editable or the signed-in name) get neither action; no moderation action sends a signal. Alerts use AppAlertState (one mechanism per screen). UGC-18-01 stays Pending: 18-10, 18-11 and Phase 20 share it. — The views (18-11) only send these actions and read this state.
- [Phase 18]: 18-08: five DEBUG-only launch keys, read only for stubbed launches: EHPANDA_UITEST_FIRST_LAUNCH=analytics (age answered, level cleared), EHPANDA_UITEST_BLOCKED_AUTHORS (JSON array; absent or malformed is empty) and EHPANDA_UITEST_DISPLAY_NAME (absent is none), both reset at every stubbed launch that is not the visual host, EHPANDA_UITEST_REQUEST_LOG (one `METHOD host path` line per stubbed request) and EHPANDA_UITEST_DROP_INITIAL_IDLE (sets ReaderUITestOptions, the default of 18-07's seam; ReadingFeature reads no key). LocalizedLaunch uses launch arguments only. ReaderRebuildUITests guards G1 (reload then turn, with and without the first idle report; direction change after auto-play, restarted because a sheet stops it) and G2 (LTR/RTL/LTR). — Later UI plans (18-09 to 18-11) isolate storage through these keys, never test order; 18-12 re-checks the keys stay out of Release.
- [Phase 18]: 18-09: RootView renders FirstLaunchGateView (age wall, then analytics choice) instead of TabBarView until both answers exist, so nothing of the app renders and no request is made before the age wall's Continue; links opened at the gate are queued (DD-07). Continue is pinned in a .safeAreaBar at every text size (D-17b, owner msg 1903, designer msg 1905); at AX sizes the age-wall footnote is the last scroll item. The titles carry a widow guard (lead msg 1900): the last two words are joined with U+00A0 when the pair fits the measured width in bold .title1, otherwise left as is; catalog strings unchanged. 48-row title table: 46 pass, 2 phone-AX5 rows (en analytics "shares", de age wall "Erwachsene") accepted by the owner (msg 1903). AGE-18-01 and CONSENT-18-01 stay Pending: 18-10 and 18-12 share them. — Later UI plans reuse FirstLaunchPage/FirstLaunchTitle patterns; 18-12 reruns both first-launch UI suites and carries the two accepted rows.
- [Phase 18]: 18-10: General → Analytics is a menu Picker over Minimal, Basic and Full (no Recommended label) with the selected level's approved description as its footer and a Privacy Policy row; shareAnalyticsDataFooter is gone. A pick sends analyticsLevelPicked, and GeneralSettingReducer stores the level and calls analyticsClient.apply once (picking the current level does nothing), so lowering to Minimal stops the SDK at once (DD-09a). Account has a Blocked Users row (count, signed in or out) pushing SettingPath.blockedUsers; the list is in localizedStandardCompare order, unblocks by full swipe or context menu with no confirmation, and switches in place to the C-12 empty state. TitleWidowGuard moved to AppComponents (with ResolvedAppLanguage) and guards the empty-state title in bold .title3. 24-row title table: 22 pass, 2 phone-AX5 rows (en "anyone.", de "blockiert.") accepted by the lead under the same principle as owner msg 1903. CONSENT-18-01 and UGC-18-01 stay Pending: 18-11, 18-12 and Phase 20 share them. — 18-11 can reuse TitleWidowGuard from AppComponents; 18-12 reruns SettingsModerationUITests and BlockedUsersTitleLayoutUITests and carries the two accepted rows.
- [Phase 18]: 18-11: comment moderation UI on 18-05's reducers. Report opens ReportPageSheet, a SessionWebView (AppComponents) on WKWebsiteDataStore.nonPersistent() seeded, before load, with sessionCookies(for:) for the report host only; nothing is written back, and stubbed launches never load. CommentModerationMenu is one item table (Report, Block / Unblock, Hide on a revealed card) for the list's AX-hidden `…` Menu, the cell and strip-card context menus and their accessibilityActions, which are declared reversed because SwiftUI hands them over last first. BlockedCommentRow (C-6/C-7) and BlockedCommentCard (C-8) take no author. The strip lost .drawingGroup() and takes a scoped StoreOf<CommentModerationFeature> (a state copy went stale on Show/Hide). PostCommentView sends postTapped and the views no longer dismiss the editor (P-8). The parser now trims the author (the site's trailing &nbsp; broke every name match). CommentModerationUITests 7/7 on phone and pad; mockups 05 to 11 match on both; the list `…` renders in the tint, not .secondary (left for the lead). UGC-18-01 stays Pending: 18-12 and Phase 20 share it. — 18-12 reruns CommentModerationUITests on both devices.
- [Phase 18]: 18-12 (owner msg 1918): comment blocking matches the poster's E-Hentai member ID, read from the `forums.e-hentai.org/index.php?showuser=<digits>` link on the author line (GalleryComment.authorMemberID), never the display name. The list is [BlockedCommentUser] (member ID + name last seen) under the new key blockedCommentUsers; blockedCommentAuthors is dropped without migration (it never shipped in a release tag). A comment without a member ID gets no Block and never collapses; Report stays. A blocked ID seen under a new name stays blocked and its stored name is refreshed by the Detail fetch. CommentModerationMenu takes CommentBlockStatus (.blocked, .notBlocked, .noMemberID). The decode is strict, so a malformed list resets to []. EHPANDA_UITEST_BLOCKED_AUTHORS became EHPANDA_UITEST_BLOCKED_USERS (JSON array of {memberID, name}). The 18-12 gate passed on e3c95a3bf (FeatureTests and UITests on phone and pad, lint 0, copy checks, Release scan PASS, no network before Continue). AGE-18-01, CONSENT-18-01 and UGC-18-01 stay Pending until the owner's report-page check. — Phase 19/20 screenshots and fixtures use member IDs for blocked comments.
- [Phase 18.1]: 18.1-01: the report POST is sent once (attempts: 1) to the gallery's ?report=<type> URL, never the page's form action; a reply is sent only when it is not a site error page and no longer shows #reportform. The form GET keeps the default retries. — Research F-1 and DD-02/DD-03: a retried POST can file duplicate reports, a page's action could point elsewhere, and an error page has no #reportform.
- [Phase 18.1]: 18.1-02: 22 report.* keys ship in DetailFeature's catalog in six languages, verbatim from 18.1-COPY-REPORT-FORM.md; report.reason.choose does not ship (lead, msgs 1980/1983: C-13 has no picker). 18.1-copy-check.py fails on a missing, reworded, empty or unapproved report.* key and on any of the six gallery-only keys or report.reason.choose. — 18.1-04 uses the generated symbols and retires comment.report.confirm_title/_body.
- [Phase 18.1]: 18.1-03: Report on a foreign comment sends CommentModerationFeature.delegate(.openReportForm(ReportFormFeature.State)) and Comments/Detail present destination .reportForm; the confirm alert is gone. ReportFormFeature.State has a failable init (nil without a report target); phases loading/ready/sending/sent/unavailable, a failed send returns to ready with Retry / Open Report Page / Cancel; canSend needs a reason, a trimmed non-empty email and Details beyond the prefill; DD-05 email check on Send; isDismissLocked while sending or edited (not once sent); the email lives only in state. — 18.1-04 renders the form, presents .reportForm in both views, removes reportPage(URL) and the retired confirm keys, and updates CommentModerationUITests (its report case expects the old alert until then).
- [Phase 18.1]: 18.1-04: ReportFormView renders every C-13 state in a NavigationStack sheet with only the leading Close, the inline "Report on {site}" title and a pinned .safeAreaBar .glassProminent button with no background (soft scroll edge top and bottom). Comments and Detail present .reportForm, and presenting sends the form's .task from the reducer. The failed alert is built in the view so Retry is the default, in the reducer's Retry / Open Report Page / Cancel order. Open Report Page presents ReportPageSheet over the kept form. reportPage(URL) and comment.report.confirm_title/_body are gone, and 18-copy-check.py lists the two keys as retired. EHPANDA_UITEST_REPORT_SCENARIO (ready, slowLoad 6 s, holdSend 10 s, failSend, unavailable) is DEBUG and stubbed-launch only. ReportFormUITests has one test per state (frames 25–31, 33, 34) and passes on both devices. — 18.1-05 runs the gate (whole UITests plan on both devices, Release scan for EHPANDA_), then the Proxyman live check. Open: at AX5 a comment link's scrollTo sometimes stops short of the comment (Phase 18 code; the tests now scroll to it).
- [Phase 18.1]: 18.1-05: the gate is green at 270d7c3d4 after two fixes to 18.1-04 test code (the report stubs' held answer without nonisolated(unsafe); ReportFormView in the Reduce Motion inventory). The live check runs behind a local mitmdump (owner msg 2066; tool change, Pluso's technical call, because Proxyman connects upstream on each HTTPS CONNECT and the owner declined handshake-only connections in card 2065): connection_strategy=lazy, upstream_cert=false, every flow answered in the request hook (three saved GET pages, a local 403 for the rest), upstream connections refused, sockets of mitmdump and the app sampled; the Mac's Wi-Fi proxy is on only for each app run. Send made exactly one POST to /g/4308676/<token>/?report=other with report_type=other, r_email, r_details and sendreport, answered locally; 693 flows, 0 upstream attempts, 0 non-loopback sockets. — The pattern for any later check that must touch the real site without sending anything; mitmproxy 12.3.1 stays installed on the Mac.
- [Phase 20]: 20-01: the channel stamp is the build setting EHPANDA_DISTRIBUTION_CHANNEL, `source` in Flavor.xcconfig and `altstorePAL` only in Marketplace.xcconfig; Beta.xcconfig keeps no stamp line. The privacy manifest declares UserDefaults CA92.1 and FileTimestamp C617.1 and three data types (ProductInteraction, DeviceID, OtherDiagnosticData; unlinked, untracked, Analytics); test_privacy_manifest.py fails on any undeclared required-reason use in the shipped sources. — The PAL build is signed before upload, so it cannot be stamped afterwards (D-12 amended); App Store Connect requires the declarations (D-18).
- [Phase 20]: 20-02: deploy.yml's build-number check reads main's three Classic-side sources and not AltStorePAL.json; build 159 = main's highest (158) + 1. bump-version.sh treats a configuration with TEST_HOST or TEST_TARGET_NAME as a test one (the old app.ehpanda.tests bundle ID matches no target). — Research §3, pitfall 4; REL-18-01.
- [Phase 20]: 20-03: the PAL entry is the filter's Classic entry with `assetURLs` after `downloadURL` and no `sha256`. The filter reads `sha256` through `$ARGS.named` (required without `assetURLs`) and drops `application-identifier` and the team identifier from a given `entitlements` list. The PAL source's public address is https://ehpanda.app/AltStorePAL.json (owner msg 2822); it is not written into the JSON. — Research §4; DIST-18-02.
- [Phase 20]: 20-04: deploy-pal.yml is workflow_dispatch only; the submit job runs in environment pal-notarization with contents: read. asc.py allows only builds/preReleaseVersions/appStoreVersions/reviewSubmissions(Items)/ADP-read paths plus GET /v1/apps/{id}/appStoreVersions (no top-level version list in OpenAPI 4.6); POST /v1/alternativeDistributionPackages is refused. Secrets: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, DIST_CERT_P12, DIST_CERT_PASSWORD, PROFILE_APP, PROFILE_SHARE_EXTENSION, TEAM_ID; variables PAL_MARKETPLACE_ID (also the --app ID), ASC_KEY_ROLE. — Research §5, §6; D-07, D-21, D-26.
- [Phase 20]: 20-05: the publish job (`inputs.mode == 'publish'`, environment pal-notarization, contents: write) reads the ADP ID, has AltStore process it, fetches it and runs pal_publish.py publish; dry_run defaults to true. ADP files map by name (manifest.json → manifest, signature, <uuid>.ipa → <uuid>); any other file, a duplicate name, a symlink or an escaping zip entry fails. Assets are never replaced (same bytes are reused, other bytes fail); a build older than the source's newest entry is refused. — Research §4, §5; D-07, D-19.
- [Phase 20]: 20-12: the 3.0 analytics vocabulary is signed off (OQ-E): FirstLaunch.completed, Analytics.levelChanged, Moderation.reportOutcome (outcome only, no reason), Moderation.posterBlocked, Moderation.posterUnblocked, Moderation.blockedCommentShown, Moderation.postingWarningAnswered, all at Basic; App.distributionChannel is a default parameter at Basic and Full; App.installed is the install count (OI-4 A); SC8 reads "nothing is sent before a level is chosen". — product lead msg 2829; owner msgs 2837, 2842; Research §10.
- [Phase 19]: 19-01: iPadOS 27 refuses in-process orientation changes (UISceneErrorDomain 101), so an iPad matrix process captures the one orientation its device was turned to before launch (EHPANDA_SNAPSHOT_ORIENTATIONS); iPhone turns in process. iPad units double to 36, shard units become 54. The block confirmation is reached through the row's own accessibility action, which needs the app accessibility runtime on; iPad pins need Full Screen Apps. — Research section 3 leaves the rotation mechanism to the developer; XCUIDevice is not authorized in an app-hosted test.

### Phase 16 transition decisions (2026-09-23)

- Owner round-2 sign-off `7020040e1f` and goal verification passed; A11Y-01/A11Y-02 are complete under the explicit best-effort scope.
- Native iOS 27 title/search policy and reader index logic remain; W-38 is accepted on the mock VoiceOver 1-to-41 recording.
- Preserve accepted/deferred/unmeasured limits and historical evidence-retention warnings in `phases/16-dynamic-type-accessibility/16-VERIFICATION.md` and `16-CLOSEOUT-NOTES.md`.

### Phase 17 transition decisions (2026-11-05)

- Phase 17 closes at its reduced scope (owner msg 1305). The moved work (CAP-17-02, CAP-17-03, CAP-17-05 and the moved parts of CAP-17-01/04/06) is recorded as moved to Phase 18, never as satisfied.
- CAP-17-04 is met by the current website image set: the 2026-11-04 recapture, 118 files serving the 192 coordinates (owner msgs 1581 and 1640). The iPad axis and the 384 export are moved to Phase 18.
- The size-class layout migration landed before snapshot coverage existed. It is accepted on reducer tests, one simulator pass and the idiom census, and the owner kept all five remaining idiom reads (msg 1409).
- Known limit accepted: at `891103afa` the reader page-sync stress ran ×5 on phone and iPad (owner msg 1640). The reader page-tracking rework and committed G1/G2 UI tests are Phase 18 Step 4b.
- Review: WR-01 and IN-01 are fixed, WR-02 is not a gap (owner msg 1627), and IN-02/IN-03 are deferred to Phase 18 Step 7. Full log: PROJECT.md Key Decisions.

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- Deferred follow-up (from Phase 8 UAT): remove dead legacy haptic code (`isLegacyTapticEngine`, `generateLegacyFeedback`) — targets unsupported devices.
- Deferred follow-up (from Phase 11 UAT, G-11-7): harden the `lastAutoFetchCount` one-shot latch in `AutoLoadNextPage` (GalleryList.swift) to re-arm on the server page cursor (`pageNumber`) rather than on `galleries.count`, so a deduped, empty or failed page cannot permanently disarm thumbnail-mode pagination — today only the manual footer retry recovers. Pre-existing (Phase 2 / D-36), not a Phase 11 regression; the detail path no longer depends on it. Needs a device check for chain-fetch regression, since the known failure mode of this tuning is an endless fetch loop pinned at the bottom.
- Standing verification item (from Phase 11 UAT, G-11-7): every future UAT touching gallery list pagination must exercise BOTH `Setting.listDisplayMode` values, `detail` and `thumbnail`. The two modes render through structurally different layouts with different fetch-more triggers, and `detail` being the default masked the thumbnail path historically and masked this regression in reverse. Testing one mode proves nothing about the other.
- Carry-forward (Phase 12 UAT, 12-06): the forum gates its login form behind Cloudflare Turnstile, which contributes a `cf-turnstile-response` field a credential POST cannot produce. While the gate is active, native username/password login cannot complete whatever the password. It is detected, named (`AppError.loginCaptchaRequired`), localized in all six locales, and routed to the web-login fallback. C1 was owner-verified PASS on the live host BEFORE the gate appeared, so Phase 12's goal was met — but C1 is not currently reproducible while the gate is active. Making native login survive an active Turnstile gate needs the form rendered in a web view to obtain a token; that is new scope for a future phase.
- Housekeeping (12-06): `.planning/research/.cache/` is tracked in git — a documentation-tool cache that arguably should be gitignored. Three of its JSON files were swept into commit 157549bb9c alongside an unrelated one-line change. Left in place (published history, inert content); needs a .gitignore decision before it accumulates.
- Deferred (12-06): the two `diag(12-06)` commits remain in the tree. The DEBUG-only redacted login-exchange dump is a useful diagnostic for this class of problem; decide whether it stays permanently once the login path is stable.
- DownloadContinuedSessionTests.swift sits at 999 of 1000 lines (file_length is error severity); the next added line fails the build. Sanctioned remedy recorded in 15-22-SUMMARY.md: relocate testEmptySchedulableSetStillPushesAPositiveTotal into the ledger suite.
- Phase 16 accepted coverage limit: Tag Detail sheet (#21) is unreachable in the English fixture because translated descriptions are empty; six historical matrix rows remain unavailable. This is not an open Phase 16 sign-off blocker.
- Phase 16 evidence limits: fifteen unreached sites, spoken Voice Control, nonreader native double-tap, W-21 and W-24 retain their owner-approved dispositions. Historical reference warnings are listed in `phases/16-dynamic-type-accessibility/16-CLOSEOUT-NOTES.md`.
- [Phase 17] Nyquist gaps G1 and G2 stay open (`nyquist_compliant: false`): the WR-01 rebuild-during-turn and RTL page-sync checks used throwaway harnesses (17-WR01-MIDTURN.md). Committed UI tests are Phase 18 Step 4b; 17-VERIFICATION.md R5-1 suggests their scope.
- [Phase 17] The fixture repository commits behind the current website set (`8ee4fc2`, `f71d108`) are local only and not pushed (R4-3). Pushing is the owner's decision.
- [Phase 17] No Debug negative-control Release scan ran at `891103afa`; the last one is at `97b31b063` (17-FINAL-VALIDATION.md section 9). Phase 20 repeats the Release scan on the final 3.0 build (was Phase 18 Step 7 before the 2026-11-05 split).

### Quick Tasks In Progress

| # | Status | Next decision | Record |
|---|---|---|---|
| 261028-hi0 | Bottom edges, Archives safeAreaBar and persistent Library title menu implemented; Release `-O` restored with preview cleanup retained; normal test plans parallel | Owner deferred the three device-bound serialization exceptions; runner migration remains partial | [Checkpoint](quick/261028-hi0-adopt-native-bottom-bars-enforce-paralle/261028-hi0-SUMMARY.md) |

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 20260908-slideshow-viewport-cap | Revised small 70%/80%, large 50%/40%; title/rating VStack, top-aligned Toplists, large landscape three-column floor; 30 new captures across five six-configuration views; owner review pending | 2026-09-08 | f24e482a | [20260908-slideshow-viewport-cap](./quick/20260908-slideshow-viewport-cap/REVISION.md) |
| 260818-ek3 | Fix G-15-2D/2E: intra-page progress + session heartbeat, and the activity-logs pump duplication race | 2026-08-18 | 2ab8d51e02 | [260818-ek3-fix-g-15-2d-2e-intra-page-progress-sessi](./quick/260818-ek3-fix-g-15-2d-2e-intra-page-progress-sessi/) |
| 260818-mjs | Fix G-15-2F/2H: freeze the gallery folder leaf across runs (no repair rename), and overlay a live run's credited page set on the published row so the Download Status sheet reads the run, not the stale record (D-SSOT-10) | 2026-08-18 | b81c52ff49 | [260818-mjs-fix-g-15-2f-and-g-15-2h](./quick/260818-mjs-fix-g-15-2f-and-g-15-2h/) |
| 260819-12o | Never delete a user's download folder: retire the completion sweep's cross-folder deletion and the repair-seed materialization (G-15-2H, guard the invariant only; no rename resolution) | 2026-08-19 | 23c22e6cef | [260819-12o-never-delete-a-user-s-download-folder-re](./quick/260819-12o-never-delete-a-user-s-download-folder-re/) |
| 260819-lq3 | Fix G-15-2I: abandon and retry a page transfer that goes 60 s without bytes (177a79b6ed), and give the continued-processing card a bounded stall nudge — one sub-unit per stalled heartbeat, cap 30, no second work condition (d35c59c757); device verification pending | 2026-08-19 | d35c59c757 | [260819-lq3-fix-g-15-2i-stall-abandon-and-card-nudge](./quick/260819-lq3-fix-g-15-2i-stall-abandon-and-card-nudge/) |
| 260819-n3y | Close DEF-15-05/06/08/09/11: the downloads list reports a refused Pause/Resume through a toast sharing the inspector's mapping (f37e7615db); `fetchDownloads`/`fetchFolders` made non-throwing at the interface, four `try` sites and the unreachable `.failed` list branch removed (eb7b17c744); `EHPANDA_UITEST_FORCE_PAUSE_REFUSAL` seam forces either refusal arm on both surfaces (b1fdd7dc4b); the two convergence detectors fenced by a sentinel instead of a wall clock (6538db3247); the row dialog pinned against reorder and leave-then-return ticks (934dca2945); doc-comment polish (21f18a1157) | 2026-08-19 | 21f18a1157 | [260819-n3y-fix-def-15-05-06-08-09-11-toast-fence](./quick/260819-n3y-fix-def-15-05-06-08-09-11-toast-fence/) |
| 260819-ovp | Close DEF-15-04/10: the pad UI test reads the idiom in the main-actor test method via `guard`/`throw XCTSkip` (the `setUpWithError` override is nonisolated, so the class `@MainActor` never reached it) — UITests build-for-testing 4 → 0 warning lines (898a49f22e); all 43 `ResourceStringSymbols` accessors forward to Xcode's generated catalog symbols with signatures and `count:`/`page:` labels unchanged, no key literal, `table:`, `defaultValue:`, bundle description or `#bundle` left, a renamed key now a compile error at its forwarder (observed, reverted) (f0c1a99e04); 1020 tests, 0 failures, unchanged | 2026-08-19 | f0c1a99e04 | [260819-ovp-close-def-15-04-10-idiom-skip-forwarders](./quick/260819-ovp-close-def-15-04-10-idiom-skip-forwarders/) |
| 260907-n39 | Unify cover roles with bounded Dynamic Type scaling and stable carousel layout; build, regression and simulator checks passed | 2026-09-07 | 9d4e4d8e | [260907-n39-unify-cover-sizing-with-bounded-dynamic-](./quick/260907-n39-unify-cover-sizing-with-bounded-dynamic-/) |
| 260921-f5u | Migrate to iOS/iPadOS 27 with native APIs and every-page soft top edges; tests verified with W-38 carried | 2026-09-21 | 241f8cd2e3 | [260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod](./quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/) |
| 260923-nnu | Build, test and lint cleanup: zero build/lint/runtime warnings; 1,057 feature passes plus 11 expected failures; 104 UI passes and 2 skips, with one intermittent iPad autoplay failed attempt passing on retry (still unresolved) | 2026-09-23 | 5f15eb244c | [260923-nnu-build-and-test-resolve-all-warnings-erro](./quick/260923-nnu-build-and-test-resolve-all-warnings-erro/) |
| 260923-shl | Restore gallery cell vertical centering; remove the uncommitted spacer/minimum-height attempt; zero build/lint diagnostics and iPhone/iPad Dynamic Type visual checks passed | 2026-09-23 | 3cb791f686 | [260923-shl-restore-vertical-centering-in-gallery-de](./quick/260923-shl-restore-vertical-centering-in-gallery-de/) |
| 260930-o3m | Align Live Text with Apple's localized names (de Live-Text, ja テキスト認識表示, zh-Hant 原況文字; en/ko/zh-Hans already matched); audit found no other string naming it; builds clean, 1,057 feature passes plus 11 expected failures, UI tests 51 + 2 skips on iPhone Air and 53 on a fresh iPad mini 6; 24 localized reader toolbar and Large Content Viewer captures untruncated | 2026-09-30 | 63eae621 | [260930-o3m-align-live-text-localized-names-with-app](./quick/260930-o3m-align-live-text-localized-names-with-app/) |
| 261013-ja0 | Live Text translation overlay accepted and integrated; translate symbol uses monochrome off and accent palette with repeating pulse on; 336 tests and 16 revert-isolation checks passed; JA0-D1 first-request stall remains deferred | 2026-10-14 | ea62005c37 | [261013-ja0-live-text-translation-overlay](./quick/261013-ja0-live-text-translation-overlay/261013-ja0-SUMMARY.md) |
| 14 | Translate the single-pass proposal into English; verify all 11 GSD documents from the appshot integration task, preserving commands, paths, commit IDs and evidence. | 2026-10-15 | 677421a8e4 | [Proposal](./phases/17-localized-screenshot-capture-harness/17-SINGLE-PASS-PROPOSAL.md) |
| 261015-tx1 | Implement shared Library categories and independent row/grid layouts | 2026-10-16 | 56f906c766 | [261015-tx1-implement-library-with-shared-favorites-](./quick/261015-tx1-implement-library-with-shared-favorites-/) |

| 261017-pjj | Implement B Home sections with selected C slideshow and shared simplified titles | 2026-10-17 | 1cc211aee6 | [261017-pjj implementation](./quick/261017-pjj-implement-b-home-sections-with-selected-/261017-pjj-SUMMARY.md) |
| 16 | Integrate all 107 app-design commits into feature/gsd-phase-17 by fast-forward; preserve SHAs and pending prototype boundaries | 2026-10-27 | a7853729fb | [D143 integration](./quick/261015-duo-session-record/SUMMARY.md#phase-17-integration--d143) |
| 261027-ci-cleanup | Remove unrequested privacy, disclosure and toolchain checks, visual tooling checks from app tests, and the visual capture workflow; squash all five prior CI commits | 2026-10-27 | 50deca5ac5 | — |
| 261027-vgt | Make CI builds independent of private local capture tooling while preserving local captures | 2026-10-27 | 391edb63ed | [261027-vgt-make-ci-builds-independent-of-private-lo](./quick/261027-vgt-make-ci-builds-independent-of-private-lo/) |
| 261031-sim | Record the iOS simulator rule in AGENTS.md: create a project-prefixed simulator when a task needs one, delete it when no task does, and never delete simulators outside this project's scope (owner request) | 2026-10-31 | 685e32e3a | — |
| 261101-ipad-reload-row | Keep Home's Reload in the iPad top tab bar row by hosting the Duo sheet presenter inside Home's NavigationStack; UI regression assertion; iPad, iPhone and Duo verified | 2026-11-01 | 350773d46 | [261101-ipad-reload-row](./quick/261101-ipad-reload-row/SUMMARY.md) |
| 261103-test-plan-repairs | Repair the 17-14 T2 test failures: the UI-test stub answers `gdata`; More matches iOS 27's overflow identifiers; UITests skips the two capture-only suites; stale capture-scene, tracer and reader-orientation tests; download helpers use a test clock and 30 s hang bounds; galleries found in any layout. Final runs have 0 failures on iPhone Air and iPad Pro 11-inch (M5), and 6 tests have passed only on a retry | 2026-11-03 | e4b63d6a5 | [261103-test-plan-repairs](./quick/261103-test-plan-repairs/SUMMARY.md) |
| 16 | Commit website screenshot recapture records and discard incomplete Phase 17 drafts | 2026-11-04 | edb77faf7 | — |
| 261104-website-recapture | Regenerate ten website screenshots with no home indicator in capture launches | 2026-11-04 | e745f38f6 + capture policy | [261104-website-recapture](./quick/261104-website-recapture/SUMMARY.md) |

### Roadmap Evolution

- Phase 10 edited: renamed to UI Polish; added POLISH-02 (ZStack->overlay/background)
- Phase 10 edited: edited fields: goal, success_criteria
- Phase 10 edited: added success criterion: remove \.inSheet environment value
- Phase 10 edited: added success criterion: sweep deprecated SwiftUI APIs (e.g. foregroundColor)
- Phase 10 edited: added success criterion: remove custom cornerRadius(_:corners:) modifier, use standard clipShape API
- Phase 10 edited: added success criterion: replace empty string literals passed to views with meaningful strings/hidden labels
- Phase 10 edited: added success criterion: convert text-only/image-only/text+image button labels to Label where fitting
- Phase 10 edited: scoped criterion 10: text+image->Label applies to all buttons; text-only/image-only->Label applies to toolbar buttons only
- Phase 11 edited: added success criterion: remove .serialized from all tests via dependency injection, run suite in parallel
- Phase 11 edited: renamed 'Lint Capstone' -> 'Infra Refactor & Lint Capstone'; goal updated to cover infra refactors (test-isolation) alongside lint ratchet
- Phase 11 edited: criterion 4: also remove @MainActor from tests unless a real main-actor need exists; run in parallel on any thread
- Phase 12 added: added Deep Link Hardening: code-review + durability fixes for deep-link routing, backed by UI automation tests
- Phase 10 edited: added success criterion: rename SystemNotificationExt module -> SystemNotification (full impl, not an extension)
- Phase 13 added: Analytics Instrumentation (TelemetryDeck) - privacy-first opt-in analytics *(historical wording — D-01 then chose on-by-default with no opt-out; the owner reversed D-01 during 14-18, so the phase shipped as Phase 14 on-by-default with a runtime opt-out in General Settings)*
- Phase 12 added (integer, Cloudflare Login Restoration): restore username/password login broken by the Cloudflare challenge wall (403 + cf-mitigated on forums.e-hentai.org); in-app browser clearance capture, in-memory cf_clearance. Cascaded existing phases: Deep Link Hardening 12→13, Analytics/TelemetryDeck 13→14, Dynamic Type Accessibility 14→15 (owner chose integer over decimal 12.1)
- Phase 15 inserted after Phase 14: Continued Background Downloads (BGContinuedProcessingTask); Dynamic Type Accessibility renumbered 15 to 16
- Phase 17 added: Localized Screenshot Capture Harness — all-language / light+dark deterministic marketing screenshots from owner-chosen real-gallery mock data under a locked clock, for the EhPanda website and AltStore
- Phase 17 edited: Expanded existing Phase 17: real-gallery fixtures, full language/Dynamic Type/orientation/device/color-scheme capture matrix, website and AltStore exports, snapshot regression tests, iOS/iPadOS 27 native API migration and app-wide soft top scroll-edge effect. Phase 16 remains active.
- Phase 17 edited (2026-11-03, owner msg 1305): reduced scope. CAP-17-04 and CAP-17-07 amended; 17-07 to 17-13, 17-15 and 17-20 to 17-22 superseded and moved to Phase 18; 17-14 reduced to T2; 17-16 to 17-19 reduced to verification and census; 17-23 rewritten.
- Phase 18 added (2026-11-03): 3.0 Release Readiness: Age Wall, Consent, Marketplace Distribution & Visual Regression — the remaining 3.0 phase, with the work moved from Phase 17 (owner msgs 1287, 1289, 1294, 1299, 1305).
- Phase 18 edited: 2026-11-05 (owner msg 1753): split into three phases. Phase 18 renamed In-App 3.0 Readiness: Age Wall, Analytics Choice, Comment Moderation & Reader Rework (directory renamed); its visual-regression and marketing-export work moved to Phase 19 and its distribution work to Phase 20
- Phase 19 added: Visual Regression & Marketing Export: the snapshot, CI gate, preview and 384 work from the original Phase 18 (moved there from Phase 17)
- Phase 20 added: 3.0 Distribution: Marketplace Build, Notarization, Listing & Release Checks: the original Phase 18's distribution, release-mechanics and device-check work, ending with the analytics revision (ANALYTICS-02)
- Phase 18.1 inserted after Phase 18: Native report form: EhPanda's own report form for comments (owner msg 1931); the site's report page stays as the fallback. Planned 2026-11-06 (5 plans); no gallery reports (owner msg 1975)

Continuation corrections (2026-09-16): W-13's earlier `pid=61210` crash/loading-error claim is withdrawn; lifecycle evidence identifies `pid=61450` as the explicit relaunch and the saved `w13-showall.png` as normal Detail. Its prior Reader return used VoiceOver off and is not a valid pass. W-22 v3 provenance is invalid because source was restored during execution; v3b completed with exit 0 in 39.433 seconds and restored five temporary files byte-exactly, with only the cold S2 AX5 second row confirmed so far. W-29 remains a read-only proposal targeting the first Frontpage gallery and profile Picker. W-35 has an approved, unimplemented title-focus probe; runtime and the W-8 idle check remain open.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Test infrastructure | Group the deep-link accessibility identifiers into one shared constants file (e.g. `AccessibilityIdentifiers.readingView`, plus a `commentCell(id:)` for the interpolated one). Today the 7 identifiers are literals in `AppPackage/Sources` and are re-typed as 18 literal call sites across the 5 `EhPandaUITests` files, with no compile-time link between the two sides — a rename fails at runtime, not at build time. | Open | Phase 13 UAT (2026-07-23) |
| Comments | Keep a comment's styles and link targets when editing it. The edit form pre-fills `GalleryComment.plainTextContent`, plain text without BBCode, so saving an edit in the app removes them. Prefer the source text the site's own edit form uses; verifying a save needs a logged-in account. See `quick/261102-comment-parser/SUMMARY.md`. | Open | 2026-11-02 |
| Compliance | **Age wall (standard for every build, not only AltStore).** On first launch, before any content is shown or any network request is made, the user must confirm they are an adult, and legally allowed to view explicit content under every law that applies to them, wherever it comes from (for example where they are, where they live, or their citizenship). Owner msgs 1235 and 1239: not just "18 or older", and not only the law of the place they live; e.g. an American citizen living abroad. Until they do, nothing else in the app works, and there is no skip. Answering no keeps them on that screen. The answer is stored on the device. Reference: Hot Tub's onboarding; notarization guideline on honest age rating and verified or declared age (Ampo msg 1211). Owner msgs 1231, 1235 and 1239, spec Ato msgs 1232, 1236 and 1240. The website's adult-mode declaration should use this same wording (Ato msg 1240), which today says only "declares they are an adult" (Ato msg 1236). | Planned: Phase 18 (AGE-18-01) | 2026-11-02 |
| Privacy | **Analytics consent (standard for every build).** No analytics are collected until the user chooses. A first-launch screen offers a few levels of sharing, including none, as in Hot Tub. The choice can be changed later in Settings. This replaces today's "on by default, switch off in Settings". Guideline 5.1.1: consent is needed even for anonymous usage data (Ampo msg 1211). Owner msg 1231, spec Ato msg 1232. | Planned: Phase 18 (CONSENT-18-01) | 2026-11-02 |
| CI / release gate | **19-10 Task 4: a green snapshot-gate run.** A hosted run of `snapshot-gate.yml` whose `aggregate` job passes and whose `triage` names only the injected shards (their retries pass); plan step 4's persistent-crash run is owed too. The release workflows refuse to ship without it: `deploy.yml` and `deploy-beta.yml` already run the gate in compare mode and need a successful `aggregate` check on the shipped commit, so 3.0 cannot ship; `deploy-pal.yml` does not exist yet and arrives in Phase 20, which gives it the same gate. **Must be done before release day.** First read run 42951290351 (still running at handoff). Owner msg 3425, product lead msg 3426; `19-10-SUMMARY.md`. | Deferred | 2026-11-11 |
| CI / visual regression | **19-12: the full hosted candidate run and the public snapshot repository.** Every shard in candidate mode on the hosted runner, and `EhPanda-Team/ehpanda-snapshot` created with its README. Needs the GitHub screenshot check. Not done; owner msg 3428. Carries T-19-24 (repository created without consent) and T-19-25 (personal data in the repository), accepted-deferred (owner msg 3573). | Deferred | 2026-11-11 |
| CI / visual regression | **19-13: the owner's approval, the pinned baseline and a green compare run.** The owner approves the candidate set once; the approved pictures are pushed and pinned (`fingerprints.json`, `manifest.json`); a hosted compare run is green. Needs the GitHub screenshot check. Not done; owner msg 3428. Carries T-19-26 (real content in a public picture) and T-19-27 (inferred approval), accepted-deferred (owner msg 3573). | Deferred | 2026-11-11 |
| Security (Phase 19) | **T-19-24, T-19-25, T-19-26, T-19-27, accepted-deferred:** carried with the deferred 19-12/19-13 screenshot publishing; must be closed before any baseline publication (owner msg 3573). Each closes with its evidence when 19-12 or 19-13 runs (`19-SECURITY.md`, Accepted-deferred threats). UF-3 stays open (low): delete `origin/ci/snapshot-gate` after run 42951290351 ends. | Accepted-deferred | 2026-11-11 |
| CI / visual regression | **19-17: the controlled regression on the hosted runner (D-18).** A one-point layout-token change on the proof branch fails the hosted gate with exactly the affected coordinates as picture changes; restoring it makes the next run green; both run IDs in `19-17-REGRESSION.md`. Needs the GitHub screenshot check with the approved baseline. 19-17's local parts are not deferred. Owner msg 3428. | Deferred | 2026-11-11 |

## Session Continuity

Last session: 2026-11-11T12:00:00.000Z
Stopped at: Completed 20-10-PLAN.md (closed by decision); main merged
Resume file: None

Earlier stop (2026-10-13T10:50:00Z, historical): 17-06 revision re-shot, 16/16 captured (`.capture/17-06-t-native-*`); superseded by the owner's 2026-11-02 approval of the 192-image website set.

The dated feedback below is historical and superseded by the Phase 16 verification and final owner sign-off.

**2026-09-17 listening feedback (recorded 2026-09-17T12:00:44Z).** With repository documentation HEAD `ea95c2a64484837e750a3fcd5f3fd468a8b39c32` and measured source `310a39625fb2cb7035415c73a91eb3ff4b7266cc`, the user said:

> Mebibytes 聽起來沒錯
> PM 那句太長了我不太確定

W-34 is accepted only for MiB pronunciation; W-33 remains uncertain. The user separately accepted only the W-31 empty uploader button capsule under Button Shapes, not other blank controls. This is follow-up status, not phase or A11Y-02 approval.

**2026-09-18 owner decision follow-up (recorded 2026-09-17T16:01:34Z).** The user accepted D-25 finding #39 as an Apple native-search bug with no app fix requested; the nine-cell result remains eight pass cells plus one accepted finding. W-8, W-35, VO-3, and W-13 require root-cause investigation; W-38 awaits an operation demonstration. W-33 is in revision toward ordinary P M pronunciation; W-34 and W-31 retain their scoped confirmations. This does not approve the phase or A11Y-02.

D101–D103 (`3673f4670652afa91bf54aa043b8ebdac2a81801`) correct Home card footnotes, Toplists uploader and
rating foregrounds. [Native verification](quick/261017-pjj-implement-b-home-sections-with-selected-/FOLLOW-UP-20261022.md)
passes two focused iPad UI cases and build/lint; review iPad is updated in place. D104 has
[three landscape slideshow proposals](sketches/002-landscape-slideshow/README.md) with portrait
preserved and no selection. Phase 17 owner gates and baselines remain unchanged.

D105–D106 (`6644232f25285fa9724d5e708b8d10f8a5e964a9`) implement the selected narrow landscape slideshow
and roomier Toplists information. [Verification and native screenshots](quick/261017-pjj-implement-b-home-sections-with-selected-/SLIDESHOW-A.md)
record 3/3 passing native iPad UI tests and clean build/lint. This supersedes D104's pending
selection; portrait, navigation and Phase 17 owner gates/baselines remain unchanged.

D107–D109 (`13e688a7ad404ea45b6099fb99f478f1f187fa93`) refine ranking spacing, slideshow aspect-fill and adaptive
tag backgrounds. [Native evidence and final-build scope](quick/261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md)
record the three passing behavioral cases and final foreground-only visual verification. Review
iPad updated in place. D111 resolves the separate gradient proposal: adjust only tags in this pass,
retaining card-wide gradient brightness/color variation and title/metadata foregrounds. The observed
contrast limitation stays recorded; no additional source change or validation run is required.

D110 (`b15f385ee83eda5c5fdb7290ae08a1e09a056b0a`) reproduces and fixes the comment preview background/frame mismatch.
[Investigation and native comparisons](quick/261022-comment-card-background/SUMMARY.md) record nine
passing test identities and sixteen render configurations; review iPad updated in place.

D112 (`2a208fd3e7f02c5aeb380ae5eef7d0f2d09f5c6e`) aligns only the stacked comment metadata row to trailing. Two native
render tests pass with 16 configurations, plus clean lint/build and visual alignment checks.
[Evidence](quick/261022-comment-card-background/SUMMARY.md); review iPad updated in place.

D113 supplies [native slideshow tag container alternatives](sketches/003-slideshow-tag-containers/README.md):
Liquid Glass and regular Material, with six light/warm-dark/cool-dark captures. The comparison page
retains the native comparison. D114 below selects A; the D113 restoration is historical. No Phase 17
approval is implied.

D114 (`75a50edd83449783730eab8931b515dd00f51c52`) implements the selected A Liquid Glass tags in both appearances.
The final source matches the reviewed prototype; fresh strict lint/native build pass and the review
iPad is updated normally. [Exact scope and evidence](sketches/003-slideshow-tag-containers/README.md).

D115 (`980ea59d687ce6219fafb0725e9a5f70842eaa80`) switches Home Frontpage covers to aspect-fill for rich and compact arrangements.
Strict lint and a clean native build pass; the review iPad is updated normally. No new UI run is
claimed. [Exact scope and evidence](quick/261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md).

D116 (`20f9f8735f18013ae994f4a2b4a919c3256d6243`) applies aspect-fill to Home Toplists covers in rich and compact arrangements.
Strict lint and a clean native build pass; the review iPad is updated normally. No new UI run is
claimed. [Exact scope and evidence](quick/261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md).

D117 (`34afba01d8219fd36e649cdb2e393c650ace25b4`) brings slideshow Pages/Category closer; D118
(`a516a4adfe88fa5fcdd67db798e6918840f0aedc`) uses official tab-placement and toolbar-title APIs to hide
Home's title only for iPad top tabs, restoring it when tabs move below. The owner-directed API
investigation, native resizing captures and two passing final-source UI tests are recorded in
[Home title/tab placement](quick/261017-pjj-implement-b-home-sections-with-selected-/HOME-TITLE-TAB-PLACEMENT.md).
Review iPad updated normally; Phase 17 review gates remain unchanged.


Website screenshot preparation is complete (192/192 verified; owner review pending): see `quick/261101-website-review/PLAN.md` and
`SUMMARY.md`. Owner revisions include tags-visible Home center, populated Comments, default
Filters, Chinese 全年齡/全年龄, screenshot-only enabled rating appearance, and the corrected
2026-10-31 adult selection. The local review is not publication or baseline approval.

Slideshow tags now exclude title-bracket duplicates and non-solid vote tiers, prioritize eligible
artist/group tags, and retain source order within the strong tier (owner confirmed). Focused tests
pass; one broader, tag-independent rich-card height assertion remains recorded for investigation.
See `quick/261101-website-review/SUMMARY.md`.

Both slideshow sets now have all 31 center candidates captured in light/dark (124 native iPhone Air
images), with paired local review and two original-image ZIPs. Full capture audit and browser review
checks pass; the existing 192-screen review remains intact. Owner selected centers 4284679 (nonexplicit) and 1320054 (explicit). See `quick/261101-website-review/SUMMARY.md`.

Frontpage review now has twenty native light-mode Home screenshots: ten seeded random arrangements
per group, with the approved center excluded from Frontpage. Capture audit and browser checks pass;
owner choice of each Frontpage version remains pending. See `quick/261101-website-review/SUMMARY.md`.

Owner Frontpage choices are applied to capture fixtures: nonexplicit version 05 and a custom explicit
six-gallery first viewport (4286547, 4294199, 4281489 / 4291491, 3760512, 3002185 in reading order).
Both centers remain fixed and fixtures validate. Custom explicit recapture and Toplists selection
remain pending; see `quick/261101-website-review/SUMMARY.md`.

### 2026-11-01 — slideshow tag translation review

Shared slideshow tags now use existing translation settings/data. Corrected the full-color
Traditional Chinese exception to match raw tag identity. Eight native light-mode screenshots
(four supported tag languages × two groups) are ready at
http://127.0.0.1:8774/tag-translations/; 31 focused tests passed. Current centers and Frontpage
choices preserved. See quick task `261101-website-review/SUMMARY.md`; owner visual review pending.

Website screenshot refresh is held at the owner’s request until the parallel app-copy update
finishes. The eight translated slideshow cards were approved; review-task changes are being committed.


### 2026-11-02 — complete website copy refresh

Owner released the copy-update hold. All 192 iPhone Air website coordinates were recaptured from
`b55058415`, with approved fixtures and unified tag database `v7.29536.1`. Native evidence audit
and all 192 browser routes pass; prior screenshots remain unchanged. New owner-review page:
http://127.0.0.1:8774/refresh-20261102/. No publication or baseline approval is implied.
See `quick/261101-website-review/REFRESH-20261102.md` for capture recovery and provenance.


### 2026-11-02 — global title preference and language-specific website review

Show Japanese Titles now applies across Home and shared gallery lists/grids, including downloads,
and Detail. Both title variants are retained; HTML list requests enrich titles through existing
batch metadata. 22 focused tests, builds and strict lint pass. Website captures use Japanese titles
for ko/ja/zh-Hant/zh-Hans, original titles for en/de; this is capture-only, not a new app default.
All 192 coordinates pass the capture audit. Review: http://127.0.0.1:8774/titles-20261102/.
See `quick/261101-website-review/TITLE-PREFERENCE-20261102.md`. Owner review remains pending.
