---
phase: quick-261123-3tn
plan: 01
subsystem: settings
tags: [swiftui, tca, github-api, about, localization]

requires: []
provides:
  - Settings > About lists the live top-five GitHub code contributors (AboutFeature reducer, CodeContributorsClient seam, GitHubContributorsRequest, GitHubContributor model)
  - About contacts section without the AltStore source row; both AltStore catalog keys and the ten code_contributor keys deleted
affects: [settings, networking, visual-snapshot-scenarios]

actuals:
  tokens: 60000
  tasks: 3
  commits: 3
plan_head_before: 13ccc1fab263808a8343e372420190c41bac3295
plan_head_after: 21a3cfadbd78818e58088e5e89649353627ceaa1

tech-stack:
  added: []
  patterns:
    - "Substitutable client seam over a Request (CodeContributorsClient, as LoginClient)"
    - "Screen load driven by SettingPath.State.onPresentedAction instead of a view lifecycle modifier"

key-files:
  created:
    - AppPackage/Sources/AppModels/Support/GitHubContributor.swift
    - AppPackage/Sources/SettingFeature/Components/AboutFeature.swift
    - AppPackage/Sources/SettingFeature/Components/CodeContributorsClient.swift
    - AppPackage/Tests/NetworkingFeatureTests/GitHubContributorsRequestTests.swift
    - AppPackage/Tests/SettingFeatureTests/AboutFeatureTests.swift
  modified:
    - AppPackage/Sources/AppTools/Defaults.swift
    - AppPackage/Sources/AppModels/Utilities/URLUtil.swift
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Sources/NetworkingFeature/Request+Report.swift
    - AppPackage/Sources/SettingFeature/Components/AboutView.swift
    - AppPackage/Sources/SettingFeature/SettingPath.swift
    - AppPackage/Sources/SettingFeature/SettingView.swift
    - AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings
    - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
    - AppPackage/Tests/SettingFeatureTests/SettingPresentationTests.swift
    - AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift

key-decisions:
  - "D-01: AltStore source row and its keys (altStore_source, contact.altStore_link) removed; distribution files untouched"
  - "D-02: Translation Contributors stay fixed; AboutFeature.translationContributorLogins pinned to AboutView.translationContributors by a test"
  - "D-03: Code Contributors are GitHub's first five all-time contributors after excluding bots, maintainers and translators (case-insensitive), one per_page=100 request"
  - "D-04: ten code_contributor keys deleted from Constant.xcstrings"
  - "Fetch trigger is SettingPath onPresentedAction (lifecycle_modifiers lint bans .task/.onAppear)"
  - "requireSuccessStatus moved into the shared Request extension so a 403 rate-limit answer maps to .networkingFailed"

patterns-established:
  - "A GitHub-backed list on a Setting screen: request, client seam, reducer with in-flight/loaded guard, ErrorView with Retry"

requirements-completed: [QUICK-ABOUT-LIVE-CONTRIBUTORS, QUICK-ABOUT-ALTSTORE-REMOVAL]

status: complete
---

# Phase quick-261123-3tn Plan 01: Refactor About view Summary

**Settings > About now shows the live top five GitHub code contributors (bots, maintainers and translators excluded) through a new AboutFeature reducer, and the AltStore source row is gone.**

## Accomplishments

- `GitHubContributorsRequest` (one GET, `per_page=100`, unfiltered) decodes `GitHubContributor` values; a non-2xx answer (GitHub's 403 rate limit) maps to `.networkingFailed`, malformed JSON to `.parseFailed`.
- `AboutFeature` loads when the screen is presented (once, never while in flight, never after success), keeps the featured five via `featuredCodeContributors(from:)`, and drives `AboutView`: a native `ProgressView` row while loading, the shared `ErrorView` with Retry on failure, login rows (`Text(verbatim:)`) opening each `html_url`, and no section when nobody is eligible. No catalog gained a key.
- The AltStore row, `altStore_source` (Localizable) and `contact.altStore_link` (Constant) are removed, plus the ten `code_contributor.*` keys; `git diff --numstat` shows zero added lines in both catalogs and `translation_contributor.*` still has its 8 keys.
- The `settings-pages-about` snapshot scenario is seeded with five contributors (`SettingsScenarios.aboutState`) so its picture is the loaded list.

## Commits

| Task | Commit | Message |
| ---- | ------ | ------- |
| 1 | d2d5b4efd | Load About code contributors from GitHub |
| 2 | 74838db0b | Offer retry when contributors fail to load |
| 3 | 21a3cfadb | Remove the AltStore source from About |

All three carry +0800 author and committer dates; nothing was pushed.

## Verification

- `xcodebuild build -scheme AppFeature` succeeded after each task; no warning in the touched modules.
- Standalone SwiftLint `--strict` over the touched source and test directories (run from the repo root so the root config applies) exited 0 after each task.
- FeatureTests `SettingFeatureTests` + `NetworkingFeatureTests` passed after Tasks 1 and 2; `SettingFeatureTests` + `NetworkingFeatureTests` + `AppFeatureTests` passed after Task 3 (615 test cases reported passed in the log). `build-for-testing` for the whole FeatureTests plan succeeded after Task 2.
- `AccessibilityAuditUITests/testAboutAudit` passed (UITests plan) after Task 3.
- Simulator `EhPanda iPhone Air (261123-3tn)` was created for the run and deleted afterwards.

## Deviations from Plan

### Ordering deviation (disclosed)

**1. The Task 2 view step landed in the Task 1 commit.** While writing `AboutView` in Task 1, the not-loaded branch was written as the final three-way form (`ErrorView` with Retry when `codeContributorsLoadingState.failed` holds an error, otherwise the `ProgressView` row). Plan Task 1 specified only the `ProgressView` row there and Task 2 Step 2 the `ErrorView` branch. The final tree is exactly what the plan describes; only the commit that introduced the `ErrorView` branch differs. Task 2's own commit therefore carries no `AboutView.swift` change. Task 2's acceptance line `grep -c 'ErrorView(' ... [HEAD=0 EXPECT==1]` holds at the end state (1) but its HEAD baseline was already 1.

### Auto-fixed issues

**2. [Rule 1 - Bug] Test reading `AboutView.translationContributors` warned about main-actor isolation.** The drift-guard test was nonisolated and read a static of a `View`, which is main-actor isolated. Fixed by annotating that one member `@MainActor` (the module's convention; the suite type stays unannotated). Commit d2d5b4efd.

**3. [Rule 1 - Bug] Typed-throws closure literal in a test.** `$0.codeContributorsClient.fetch = { throw .networkingFailed }` inferred `any Error`; spelled `{ () async throws(AppError) -> [GitHubContributor] in ... }`. Commit 74838db0b.

**4. Naming choice, not a behavior change.** The private computed property that renders the section's rows is named `featuredContributorRows`, because the plan's acceptance grep `codeContributor[A-Z]` (expect 0) would otherwise match a name such as `codeContributorRows`.

### Plan acceptance items that cannot hold literally

- Task 3 acceptance "`git log 0d2f52d4f..HEAD` lists exactly three commits": the range also contains the planning docs commit `13ccc1fab` (+0800), so it lists four. The three execution commits are exactly those above (`git rev-list --count 13ccc1fab..HEAD` is 3).
- Task 2's `build-for-testing` gate greps VisualSnapshotTests for any warning and so trips on the pre-existing `ScenarioCatalog+Library.swift:208:13 'quickSearch' was never mutated` (not touched by this plan). The build itself succeeded; no warning comes from a file this plan changed.

## Warnings seen in build logs (all pre-existing, not touched)

- `AppPackage/Sources/AppComponents/TitleWidowGuard.swift:2:8` public import of Foundation not used in public declarations
- `AppPackage/Sources/VisualSnapshotSupport/SnapshotCoordinate.swift:1:8` same
- `AppPackage/Sources/TestNetworkGuard/TestNetworkGuard.m:82:18` NSURLErrorFailingURLStringErrorKey deprecated
- `AppPackage/Tests/AppFeatureTests/UITestStubTests.swift:412:20` and `:482:17` optional_data_string_conversion
- `AppPackage/Tests/DetailFeatureTests/BlockedCommentPresentationTests.swift:305:22` and `RevealedCommentLineLayoutTests.swift:153:22` init(frame:) deprecated
- `AppPackage/Tests/DetailFeatureTests/HeaderSectionActionSpacingTests.swift:51:38` large_tuple
- `AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Library.swift:208:13` variable never mutated

## Known Stubs

None.

## Threat Flags

None beyond the plan's threat model: the one new network surface (GET api.github.com contributors) is T-261123-3tn-01/-04/-05 as registered; mitigations (typed decoding, status check, `Text(verbatim:)`, one request per presentation with a reducer guard) are implemented.

## Live check (for the orchestrator or owner, not a gate)

On a simulator with network, Settings > About > Code Contributors should show aalberrty, xioxin, Jimmy-Prime, vvbbnn00, remlostime (2026-11-23 data), each opening its GitHub profile, and the contacts section should list Website, GitHub, Discord and Telegram only. Not run here (the UI-test launch stubs every request, so the audit saw the error view).

## Self-Check: PASSED

- Created files present: GitHubContributor.swift, AboutFeature.swift, CodeContributorsClient.swift, GitHubContributorsRequestTests.swift, AboutFeatureTests.swift.
- Commits d2d5b4efd, 74838db0b and 21a3cfadb are ancestors of HEAD.

## Landing on develop (2026-11-23)

The task branch was cut from `main` (`0d2f52d4f`), a snapshot that shares no history with `develop`, so the
commits were replayed onto `develop` instead of merged; the hashes above are the replayed ones. Conflicts
resolved while replaying:

- `develop` had added `dyphire` to the hardcoded Code Contributors list; that list and all twelve
  `code_contributor.*` keys (including `dyphire`'s) are gone, since the section now reads GitHub.
- `SettingPath.onPresentedAction` keeps `develop`'s `.myTags(.onPresented)` beside `.about(.fetchCodeContributors)`,
  and `SettingPresentationTests` asserts both.
- `ScenarioCatalog+Settings.swift` keeps `develop`'s cookie fixtures beside `aboutState`.
