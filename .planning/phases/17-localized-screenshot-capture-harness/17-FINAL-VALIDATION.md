# 17-FINAL-VALIDATION: reduced-scope Phase 17 gate and requirement trace

Plan 17-23, run 2026-11-03 to 2026-11-04. This record covers what Phase 17 still owns after the owner
reduced its scope on 2026-11-03 (msg 1305). Moved work is listed as moved, never as satisfied.

This plan does not mark the phase complete. 17-VERIFICATION.md is written for the GSD close steps at
the orchestrator's direction, not as a product of this plan. The close steps come after this record:

1. `/gsd-execute-phase 17`'s phase gates: code review through `gsd-code-review`, the regression gate,
   and the verifier's 17-VERIFICATION.md.
2. `/gsd-verify-work 17` (UAT).
3. `/gsd-secure-phase 17`.
4. `/gsd-validate-phase 17`.

## 1. Final gate (17-23-T1)

**Source commit: `52df81fa3`** (`feature/gsd-phase-17`). Every check below ran at this commit, from a
clean tree (only the untracked `.claude/` folder, which is not built).

**What changed since 17-14's `50c794b53`.** Nine source commits, all ancestors of `52df81fa3`
(`git merge-base --is-ancestor`). The other commits in the range touch only `.planning/` and `docs/`.

| Commit | Change | Built into Release |
|---|---|---|
| `3708ac32c` | reader: hold a page turn while the pager animates to the last one | yes |
| `4cc9925e1` | reader: send the pager again when it rests short of the index | yes |
| `a7627790a` | reader: let the index follow the screen when the pager keeps missing it | yes |
| `b2c958838` | reader: seed the pager at the first measurement it can lay out in | yes |
| `bc67ddf14` | reader: soften the bottom edge under the control panel | yes |
| `3642b8cec` | reader: hold the bottom edge bar until the reader has a reading area | yes |
| `33dbf648b` | reader: hide the home indicator with the reader's controls | yes |
| `59bd409a9` | capture: hide the home indicator in every screenshot (quick task `261104-website-recapture`) | no, `#if DEBUG` only |
| `562344ed7` | capture: hide system overlays on the Filters sheet (same quick task) | no, `#if DEBUG` only |

- The four pager fixes come from reader page desyncs that ReaderPageSyncUITests found while this gate
  ran: a slider drag could leave the indicator one page off the screen, and a cold vertical reader
  could open on page 1 under a resume page of 2. `PagerTurnGateTests` and `PagerSeedTests`
  (FeatureTests) pin them.
- `bc67ddf14` gives the bottom of the reader the soft scroll edge the top already has. `3642b8cec`
  fixes the landscape regression it caused (the phone rotation test failed 19 of 20 runs on
  `bc67ddf14`).
- The two capture commits read `captureSystemOverlayVisibility`, an environment value that exists
  only in DEBUG and is set only in a capture launch (`CaptureScenePreparation.installed`). UI-test
  launches that are not capture launches, including every ReaderPageSyncUITests launch, leave it
  `nil`, so the reader keeps its own home-indicator rule.

**Toolchain.**

- Xcode 27.2 (27B52) and iOS Simulator 27.2.
- Simulators: `EhPanda iPhone Air` and `EhPanda iPad Pro 11-inch (M5)`. Their UDIDs were resolved on
  this host and are not recorded.
- SwiftLint 0.65.1, the plugin binary in this checkout's DerivedData folder.

### Behavior tests

Each plan ran through the project's `runtest` recipe, one invocation at a time, in the plan's order:
FeatureTests then UITests on the phone, then the same two on the tablet.

```sh
runtest <project-id> --script app --additional-options "-testPlan FeatureTests -destination id=$PHONE_UDID"
runtest <project-id> --script app --additional-options "-testPlan UITests -destination id=$PHONE_UDID"
runtest <project-id> --script app --additional-options "-testPlan FeatureTests -destination id=$TABLET_UDID"
runtest <project-id> --script app --additional-options "-testPlan UITests -destination id=$TABLET_UDID"
```

| # | Plan, device (iOS 27.2) | Exit | Cases | Passed | Failed | Skipped | Expected failures | Repetition nodes |
|---|---|---|---|---|---|---|---|---|
| 1 | FeatureTests, EhPanda iPhone Air | 0 | 1535 | 1526 | 0 | 0 | 9 | 0 |
| 2 | UITests, EhPanda iPhone Air | 0 | 88 | 68 | 0 | 20 | 0 | 0 |
| 3 | FeatureTests, EhPanda iPad Pro 11-inch (M5) | 0 | 1535 | 1525 | 0 | 0 | 10 | 0 |
| 4 | UITests, EhPanda iPad Pro 11-inch (M5) | 0 | 88 | 71 | 0 | 17 | 0 | 0 |

- **Interrupted first attempt.** A first set of these four runs started at 12:18 UTC was cut off at 12:23 when an AirBuild update took its build gateway down (`Could not reach the Environment gateway`); no test had failed. The four runs above are a full rerun from the start at the same commit, 12:49 to 13:24 UTC.
- **Retries.** "Retries disabled" is met as it was in 16-24 and 17-14. `UITests.xctestplan` keeps its
  `retryOnFailure` policy unchanged, and each result bundle shows every test ran once: 0 Repetition
  nodes. A Repetition node would have failed the gate. No run had zero tests.
- **Case count.** FeatureTests grew from 17-14's 1522 cases by the new `PagerTurnGateTests` and
  `PagerSeedTests`.
- **Expected failures.** The expected failures are intentional issue-reporting tests, the same set as
  in 17-14's final run:
  - unimplemented clients for downloads and analytics;
  - the download series and ownership guards;
  - `SettingPresentationTests.pushingAccountLoadsCookies`;
  - `SettingReducerTests.defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges`. This one
    reports only when its live request is still in flight.
- **Skips.** The UITests skips are the existing device-gated suites.
- **Result bundles.** They are kept locally (`f23c-feature-phone`, `f23c-ui-phone`,
  `f23c-feature-tablet` and `f23c-ui-tablet`, each `.xcresult` with summary and test JSON) and are not
  committed.

### Reader page-sync stress

ReaderPageSyncUITests (8 tests) ran repeatedly through the same recipe, with
`-only-testing:EhPandaUITests/ReaderPageSyncUITests -test-iterations N`. Every test case is counted
once per iteration. In these bundles each iteration is a Repetition node under its test; a retry
would show as a failed node followed by an extra one, so a test with exactly N passing nodes ran
without a retry.

| Device | Source | Iterations | Test runs | Passed | Failed | Retries |
|---|---|---|---|---|---|---|
| EhPanda iPhone Air | `33dbf648b` | 20 | 160 (8 × 20) | 160 | 0 | 0 |
| EhPanda iPad Pro 11-inch (M5) | `52df81fa3` | 5 | 40 (8 × 5) | 40 | 0 | 0 |

- The phone run's source, `33dbf648b`, differs from `52df81fa3` only by the two DEBUG capture commits
  above, which no ReaderPageSyncUITests launch reaches, and by documentation.
- **Reduced iPad coverage (known limit).** The owner chose a 5-iteration iPad run to close the phase on
  2026-11-04, instead of 20. The iPad page-sync evidence is therefore 5 iterations, plus the single
  iPad UITests run above. Earlier iPad stress runs found one desync in 20 (`4cc9925e1`) and one cold
  opening on page 1 in 160 (`b2c958838`), so 5 iterations cannot rule out a rate that low.
- RTL reading is not in ReaderPageSyncUITests; `ReaderPageProbe` covers only the vertical strip and the
  left-to-right pager.

### Strict lint

```sh
"$SWIFTLINT" lint --strict --no-cache --config .swiftlint.yml \
  AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests
```

Exit 0: `Found 0 violations, 0 serious in 759 files.` No suppression was added.

### Release isolation

The built source is no longer 17-14's `50c794b53`, so the Release scan ran again on a Release build
of `52df81fa3`. The builds come from the clean detached worktree `.airbuild/worktree/ehpanda-1723-final`
at `52df81fa3`, through `runbuild --source` with the same git-ignored build script as 17-14 (Release with
`CLANG_COVERAGE_MAPPING=NO LD_GENERATE_MAP_FILE=YES`, then Debug). Both build logs end in `** BUILD SUCCEEDED **`. The
scan is the command in 17-RELEASE-ISOLATION.md ("Scan"), with the four link maps.

- `--device` names a temporary iPhone Air simulator, `EhPanda Release Probe` (iOS 27.2). It was
  created for the probe, booted, and deleted after the app was uninstalled. The T1 phone runs were
  using clones of `EhPanda iPhone Air` at the time.
- A first scan attempt stopped at the launch probe with `simctl install` exit 149, because the
  simulator it named was shut down. That is the probe's precondition, not a finding; the scan above
  is the complete rerun.

- Release scan: exit 0, `PASS: 0 finding(s)`. 377 payload files; 150 targets, none a test, snapshot or UI-test target; 31 packages, `swift-snapshot-testing` resolution-only; 1613 compiles, none defining `DEBUG` or instrumented; link maps: app 187 objects / 291 135 live symbols (arm64), 187 / 279 623 (x86_64), share extension 24 / 338 and 24 / 307, no test or snapshot object; `UITestAutomation`'s inert shell accepted as in 17-14 (11 symbols per app slice); the Release app was still running after the launch with every capture key set, and the Debug control had ended.
- Debug negative control (the Debug app and log, with the Release arm64 link map, as in 17-14): exit 1, 991 findings (483 `debug-define`, 492 `instrumented`, 11 capture strings, 4 payload files, 1 build-log), the same as 17-14.

The scanner tests ran at `52df81fa3`:

```sh
python3 -B -m unittest discover -s Scripts/visual -p test_release.py
```

Exit 0: `Ran 19 tests … OK`. That includes the seeded bad payload.

**T1 verdict:** Pass. All four runs exit 0 with 0 failures and 0 Repetition nodes at `52df81fa3`; strict lint, the Release scan and the scanner tests pass at the same commit.

## 2. Amended requirement wording (owner approval 2026-11-03, msg 1305)

- **CAP-17-04:** met by the 192 owner-approved website images of 2026-11-02 (iPhone Air portrait; eight
  screens × six locales × two themes × two content sets). The website contract drops the iPad axis.
  The 384 export tooling and regeneration move to Phase 18 (MKT-18-01).
- **CAP-17-07:** the idiom → size-class layout migration landed through quick task
  `261015-duo-session-record` (`8fb2374536`, `e89e896634`, `0a42b7fbb4`, `7015d62cd3`). It landed
  before snapshot coverage existed, not after it as D-27 intended. It is verified by 17-16 to 17-19,
  with Release isolation by 17-14 T2. Snapshot measurement moves to Phase 18 (VIS-18-01).

The same wording is in `.planning/REQUIREMENTS.md` and the Phase 17 section of `.planning/ROADMAP.md`.

## 3. Website images: the owner's approval of 2026-11-02

[`quick/261101-website-review/APPROVAL-20261102.md`](../../quick/261101-website-review/APPROVAL-20261102.md)
records the owner's approval of the complete local review.

- **The images.** 192 iPhone Air portrait images at 1260 × 2736: two content groups × six locales ×
  two themes × eight screens. All artifact and browser checks passed.
- **The fixtures.** They come from 16 immutable fixture versions in the private fixture repository,
  indexed by `website-capture-20261102.json` through `active-fixtures.json.websiteCaptureIndex`. That
  index records:
  - coordinate routing and title and source-language rules;
  - tag translation asset hashes;
  - all 192 approved image hashes.
- **The contract.** The website contract that drops the iPad axis is
  [`quick/261101-website-review/PLAN.md`](../../quick/261101-website-review/PLAN.md).
- **Approved exception to real content.** In the Comments scene of gallery 2758456, the third comment
  is manually inserted (synthetic ID 9000000001, author CedarComet91). Its image B was edited to remove
  a Chinese subtitle. The approval record states both and keeps the originals in the private
  `overrides/website-comments-20261102/`.
  - This is an owner-approved exception to the spec-less prohibition "Marketing MUST NOT invent gallery
    content" (17-SOURCE-AUDIT.md). It is flagged here, not treated as satisfied silently.
- **Scope.** The approval covers screenshot content only, not a regression baseline or a rendering-pin
  change.

## 4. Layout census and the owner's decisions (17-19)

Evidence: [17-LAYOUT-AUDIT.md](17-LAYOUT-AUDIT.md), 17-16 to 17-19 summaries.

- **17-16:** the five view-layout sites read size classes, the system's suggestion placement or
  container fitting. No idiom read remains in them.
- **17-17 and 17-18:** Home, Library, Search and Downloads gallery taps reach one app-root decision,
  `WindowSizeClasses.presentsModally`. Regular in both dimensions gives a sheet; otherwise Detail is
  pushed. The idiom helper `routeGalleryDetail` is gone.
- **17-19:** Settings and Detail follow the same rule in the simulator pass. Detail is a 580×660 pt
  sheet at iPad full width. It pushes in a 375 pt iPad window and in iPhone landscape.

Census of the remaining idiom reads. The owner was asked on 2026-11-03 (msg 1408) and answered **keep
all five** (msg 1409).

| # | Place | Decision | Reason recorded |
|---|---|---|---|
| 1 | Reader lower Close (`ReadingView.swift`, `deviceState == .pad`) | keep | Does what D36 asks; a size class can't tell iPad landscape from an open Duo |
| 2 | Library sidebar (`LibraryFeature.swift`, `usesSidebar`) | keep | Matches D132; the narrow iPad window collapses through the split view itself |
| 3 | Home title (`HomeNavigationView.swift`, `hidesTitle`) | keep | Behaves as D118 says; the optional `.pad` cleanup is not taken |
| 4 | Device name in error details (`ErrorInfoView.swift`) | keep | Diagnostics, not layout: a bug report names the hardware |
| 5 | Duo/iPad capability (`WindowDevice.swift`, `WindowDeviceObservation.swift`) | keep | A hinge isn't a size class; D91 and D26 depend on it |

No change plan follows and no app source changed for the census. The Duo branch can't be simulated;
unit tests cover it.

## 5. 17-06 leftovers, superseded by the 2026-11-02 approval

| Item (17-06-SUMMARY.md, Unresolved Gates) | Disposition |
|---|---|
| Owner visual review of the 16 frames | Superseded: the owner approved the complete 192-image website set on 2026-11-02. |
| Explicit-set preparation | Superseded: both content groups are in the approved 192 images and their 16 fixture versions. |
| Whether the status bar follows each coordinate's locale | Resolved for the website: the approved images use one fixed 9:41 status bar per theme. Any formal decision for the 384 export moves with 17-07 to Phase 18. |
| Final owner selection | Done for the website set (approved). The 384 reacquisition moves with 17-21 to Phase 18. |
| iPad Toplists gap between Yesterday and Past Month (STATE.md, 17-06 revision) | Resolved 2026-11-03 by the owner: fixture-caused (three galleries per period against a six-place iPad grid). No app change; Phase 18 fixtures carry six per period. |

## 6. Requirement trace

| Requirement (Phase 17 part) | Status in Phase 17 | Evidence |
|---|---|---|
| **CAP-17-01**, fixture part: explicit acquisition and refresh, provenance, checksums, offline replay without account or credentials | Evidenced | 17-03 (anonymous acquisition into scrubbed, checksummed, versioned fixtures; offline review); 17-04 (the app launches on one validated fixture version, offline and isolated from the device's account, settings, caches and downloads; every image from the fixture, none refused); 17-06 (Live Text records and download page files with SHA-256 manifests, which alone decide completeness). The download suites in FeatureTests pass in section 1; this record does not separately re-prove the same-run folder deletion invariant. The 16 owner-approved website fixture versions (APPROVAL-20261102.md). |
| **CAP-17-04**, amended | Evidenced | Section 3: 192 owner-approved iPhone Air website images of 2026-11-02, their 16 fixture versions and the website contract without the iPad axis. Capture foundation: 17-05 (eight screens through the app's own navigation, 9:41 and no capsule, byte-identical cold reruns), 17-06 (all eight screens capturable on both visual simulators). |
| **CAP-17-06**, bounded part: iOS/iPadOS 27, Swift 6.4, native navigation, search, toolbar and top-edge behavior preserved | Evidenced within bounds | Section 7 (D-25, D-26 rows): deployment target 27.0, Swift tools 6.4; behavior suites pass in section 1; the standard/AX1/AX3/AX5 title, search and top-edge checks recorded in quick task 260921-f5u (260921-f5u-VERIFICATION.md) and the Phase 16 verification. |
| **CAP-17-07**, amended | Evidenced | Release isolation: the Release scan at `52df81fa3` (section 1), after 17-RELEASE-ISOLATION.md's run at `50c794b53`. Layout: section 4 and 17-LAYOUT-AUDIT.md. No lint or warning suppression. |

### Moved to Phase 18, not satisfied here

These are **moved to Phase 18**. They are not satisfied by Phase 17 and nothing in this record claims
them.

| Requirement or part | Phase 18 requirement | Moved plans |
|---|---|---|
| CAP-17-02 (SnapshotTesting coverage at 576 coordinates per scenario) | VIS-18-01 | 17-08, 17-09, 17-10, 17-11, 17-12 |
| CAP-17-03 (reviewed public baselines and the complete matrix on every PR and release) | VIS-18-01 | 17-12, 17-13, 17-14 T1/T3; 17-20 folded into Phase 18's single baseline approval |
| CAP-17-05 (AltStore promotional composition and designer handoff) | MKT-18-01, DIST-18-02 | 17-22 |
| CAP-17-01, moved part: public regression test-data dispatch and the final 384 reacquisition | VIS-18-01, MKT-18-01 | 17-11, 17-21 |
| CAP-17-04, moved part: the 384 export tooling, handoff validator and regeneration | MKT-18-01 | 17-07, 17-21 |
| CAP-17-06, moved part: snapshot-measured native visual policy and preview review | VIS-18-01 | 17-09 T2, 17-15 |

All moved plan files carry `status: superseded` with a pointer to Phase 18: 17-07 to 17-13, 17-15 and
17-20 to 17-22. 17-14 keeps only T2, and its T1/T3 are moved to Phase 18.

## 7. Locked decisions D-01 to D-27 against the split

"Delivered" means a kept plan carries evidence for the Phase 17 part. "Moved" means the decision's
remaining obligation is moved to Phase 18 with its plans.

| Decision | Disposition |
|---|---|
| D-01 SnapshotTesting for tests; marketing as a separate actual-app workflow | Delivered in part: clean SnapshotTesting integration and the actual-window tracer (17-01); the separate actual-app capture workflow (17-04, 17-05). Baseline comparison moved to Phase 18 (17-12). |
| D-02 test data real, synthetic or mixed; marketing content real | Delivered for marketing fixtures (17-03), with the owner-approved synthetic-comment exception in section 3. Public test-data dispatch moved to Phase 18 (17-11). |
| D-03 explicit acquisition into versioned, checksummed fixtures | Delivered (17-03, 17-04, 17-06). Final 384 reacquisition moved to Phase 18 (17-21). |
| D-04 gallery quantities and characteristics | Delivered for the website set (17-03; 16 approved versions). The 384 set moved to Phase 18 (17-21). |
| D-05 provisional galleries, owner-confirmed before closure | Met for the website set by the 2026-11-02 approval. Final 384 selection moved to Phase 18 (17-21). |
| D-06 Live Text and downloads simulated through the real UI | Delivered (17-06). |
| D-07 inventory of screens and states | Moved to Phase 18 (17-08 to 17-11). 17-02's tracer matrix is the delivered runner. |
| D-08 full-content height capture | Feasibility delivered (17-01, 32 coordinates). Scenario coverage moved to Phase 18 (17-08, 17-09). |
| D-09 no reduced-window iPad snapshot dimension | Delivered in the runner and pin (17-01, 17-02, 17-24). Expansion moved to Phase 18 (17-10). |
| D-10 frozen rendering environment | Delivered (17-24 pin, 17-02, 17-05). Expansion moved to Phase 18 (17-08, 17-09, 17-11). |
| D-11 committed public baselines | Moved to Phase 18 (17-12, 17-13, 17-20). |
| D-12 complete agent review and owner approval of baselines | Moved to Phase 18 (17-12, 17-13, 17-20). |
| D-13 complete matrix on every PR and release | Moved to Phase 18 (17-14 T1/T3, 17-13, 17-20). 17-02's runner is delivered. |
| D-14 comparison report | Moved to Phase 18 (17-12). |
| D-15 the eight screen identities | Delivered (17-05, 17-06; the eight screens of the approved website set). |
| D-16 every combination, iPad included (384) | **Superseded for CAP-17-04 by the website contract**, which drops the iPad axis (192 images). The 384 export moved to Phase 18 (17-07, 17-21). The pin (17-24) is delivered. |
| D-17 reuse existing mechanisms; capture setup isolated from Release | Delivered (17-04, 17-05; Release isolation by 17-14 T2). |
| D-18 pinned status bar 9:41, timestamps, ordering | Delivered (17-04, 17-05; fixed 9:41 per theme on the website images). The 384 export moved to Phase 18 (17-07, 17-21). |
| D-19 chrome-identical content sets and explicit asset sharing | Moved to Phase 18 (17-07). |
| D-20 native image format | Moved to Phase 18 (17-07, 17-21). The website images are the capture tooling's PNG. |
| D-21 inventory including failures, instructions, results | Moved to Phase 18 (17-07, 17-21). The website set's index records all 192 hashes. |
| D-22 one documented export command | Moved to Phase 18 (17-07, 17-21). |
| D-23 deliberately designed AltStore images | Moved to Phase 18 (17-22). |
| D-24 designer chooses screens, matrix and composition | Moved to Phase 18 (17-22). |
| D-25 preserve the landed iOS 27 / Swift 6.4 / native behavior | Delivered within bounds: deployment target 27.0 in every app target, `swift-tools-version: 6.4`, `platforms: [.iOS(.v27)]`; behavior suites pass (section 1); 17-16 to 17-19. Snapshot-measured checks moved to Phase 18 (17-09, 17-10, 17-15). |
| D-26 soft top-edge policy at each effective host | Delivered within bounds: a soft top edge (`.scrollEdgeEffectStyle(.soft, for: .top)` or `for: [.top, .bottom]`) appears 55 times in 37 source files at `52df81fa3`; the reader adds a soft bottom edge under its control panel (`bc67ddf14`, `3642b8cec`); the recorded AX checks in 260921-f5u. Snapshot-measured checks moved to Phase 18 (17-08 to 17-10, 17-20). |
| D-27 audit idiom layout **after** snapshot implementation | **Ordering not followed.** The migration landed before snapshot coverage, through quick task `261015-duo-session-record`. The owner amended CAP-17-07 on 2026-11-03 (msg 1305) to accept that. Verified by 17-16 to 17-19 with the owner's keep decisions. Snapshot measurement moved to Phase 18 (17-20 folded, VIS-18-01). |

## 8. Remaining assumptions and human gates

- **CAP-17-07 "unclassified" edge (17-SOURCE-AUDIT.md, spec-less edge coverage).** The audit leaves it
  "unresolved — manually classify the probe before closure", without saying which probe.
  - Classified against the two probes Phase 17 has: the Release launch probe (17-14, repeated at `52df81fa3`:
    Release keeps running with every capture key set, and the Debug control ends) and the idiom census (17-19: every
    read has an owner decision).
  - No acceptance predicate is invented. The verifier should confirm this classification.
- **Spec-less prohibitions (flagged-unverified, unchanged).**
  - "Marketing MUST NOT invent gallery content": flagged, with the owner-approved synthetic comment in
    section 3.
  - "Generated image equality MUST NOT substitute for review and owner baseline acceptance": moved to
    Phase 18 with 17-12.
  - "Raw captures MUST NOT be represented as designer artwork": moved to Phase 18 with 17-22.
- **Known test risks (from 17-14 and this gate).** None failed this gate.
  - `ReaderPageProbe` can't read an iPad landscape two-page spread, and ReaderPageSyncUITests does not
    cover right-to-left reading.
  - **Reduced iPad page-sync coverage:** 5 stress iterations on the iPad instead of 20 (owner's choice,
    2026-11-04). See section 1.
  - DeepLinkScheme depends on starting in portrait.
  - A diagnostic iPad run once saw the long-press "Inspect downloaded pages" and the Front Page (Show
    All) title not appearing. Neither recurred.
- **Known reader behavior, not fixed in Phase 17.**
  - The slider's preview gesture ends before the finger lifts, so the rest of a drag seeks the pager
    live. `3708ac32c` to `a7627790a` keep the indicator on the page shown; the gesture is unchanged.
  - The pager check after a turn sends the pager at most twice more before the index follows the
    screen. A rotation or a two-page spread could add one such correction.
- **Human gates still ahead.** The GSD close steps, including UAT (`/gsd-verify-work 17`). No owner
  approval is inferred from this record.
- **Not claimed.** Phase completion, any moved requirement, and any snapshot or baseline evidence.
