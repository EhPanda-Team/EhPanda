---
phase: 261122-iew-e-hentai-settings-saves-each-option-on-i
plan: 01
subsystem: SettingFeature / EhSettingClient
tags: [e-hentai-settings, autosave, tca, dependency-client, swift-testing]
requires: [GalleryClient precedent (06b4747a3)]
provides: [EhSettingClient module, EhSettingReducer.Option, per-option save]
affects: [EhSettingReducer, EhSettingView and sections, CategoryView, VisualSnapshotTests settings scenarios]
tech-stack:
  added: [EhSettingClient local module]
  patterns: [BindingReducer().onChange(of:) as the only save trigger, latest-wins revisions, draft controls]
key-files:
  created:
    - AppPackage/Sources/EhSettingClient/EhSettingClient.swift
    - AppPackage/Sources/EhSettingClient/.swiftlint.yml
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer+Option.swift
    - AppPackage/Tests/SettingFeatureTests/EhSettingReducerTests.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections1.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
    - AppPackage/Sources/AppComponents/CategoryView.swift
    - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
    - AppPackage/Tests/SettingFeatureTests/AnalyticsEmissionTests.swift
    - AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift
    - .planning/quick/260921-f5u-migrate-to-ios-27-and-ipados-27-with-mod/SCROLL-EDGE-INVENTORY.md
decisions:
  - "D-01 to D-07 implemented as written (see below for the accepted adaptations)."
  - "Excluded-language rows use a private named struct (ExcludedLanguageRow), not a 3-member tuple: SwiftLint large_tuple forbids it (orchestrator decision A)."
metrics:
  tasks: 2
  completed: 2026-11-22
status: complete
estimate:
  tokens: 190000
  tasks: 2
actuals:
  tasks: 2
  commits: 2
plan_head_before: 102d1709c1b18ecca38a9afe2cf2819ff49d3f29
plan_head_after: c6c078a6b4d96ad8dec9abc6e9bfba49bf6d8d6b
commits: 2
---

# Quick Task 261122-iew: E-Hentai Settings saves each option on its own

Every option of the E-Hentai Settings form now saves on its own through an injected `EhSettingClient`. Only the changed control is disabled until the site answers, the newest answer wins, and a failed latest save quietly refetches. The Save and Website toolbar buttons, the web view and the page-wide save loading state are gone.

## Commits

- `874ae2d44` Inject E-Hentai settings requests (Task 1, tracer)
- `c6c078a6b` Save each E-Hentai setting on its own (Task 2)

Both are signed (`G`) with +08:00 author and committer dates.

## What was built

**Task 1 (tracer).** `EhSettingClient` has three closures (`fetchSettings`, `submitChanges`, `performProfileAction`) and live, noop, unimplemented and `failing(_:)` values, plus the dependency key. It is registered in `Package.swift` like `galleryClient`, with a `.swiftlint.yml` that points to the root config. The reducer's three effects call it. `EhSettingReducerTests` proves the first load and its failure through a stubbed client.

**Task 2.**
- `EhSettingReducer.Option` has one case per saved control and `Option.changes(from:to:)` is the only option-to-field mapping.
- The save trigger is `BindingReducer().onChange(of: \.ehSetting)`. It sees only the form's own writes, so no site answer can start a save.
- State holds `updatingOptions` and `latestRevision`. `updateDone` and `refetchDone` apply only the latest revision. A failed latest save refetches quietly under the same revision.
- `setEhSetting(_:resettingProfileName:)` resets the typed profile name only for the first load and profile-action answers.
- Every section takes `updatingOptions` and disables its own controls. A `profile` update disables the profile section's five controls. `CategoryView` takes `disabledIndices`.
- `ValuePicker` keeps a draft and writes once at drag end. The new `DraftTextField` writes on Return. The excluded uploaders editor writes when focus leaves.
- Removed: `Destination`, `presentWebView`, the web view sheet, the toolbar, `submittingState`, the haptics call, `import HapticsClient`, and the `save` string.

## Verification

All commands ran from the checkout root with the logs in `.build/261122-iew/`.

| Run | BUILD | LINT (strict, Sources + Tests) | TEST (SettingFeatureTests) |
|-----|-------|------|------|
| Baseline (untouched tree) | succeeded, no unexpected warning | exit 0, empty | succeeded: 127 passed + 1 expected failure |
| Task 1 | succeeded, no unexpected warning | exit 0, empty | succeeded: 128 passed + 1 expected failure |
| Task 2 | succeeded, no unexpected warning | exit 0, empty | succeeded: 144 passed + 1 expected failure |

- The expected failure is the existing `SettingPresentationTests/pushingAccountLoadsCookies`, present at baseline.
- This runner prints XCTest-style `Test case ... passed` lines and no Swift Testing `Test run with <n> tests` line, so the counts above are counted from those lines. A line split by interleaved output can shift a count by one. `EhSettingReducerTests` shows 16 distinct passing cases.
- TESTBUILD 2 (all FeatureTests targets, VisualSnapshotTests and NetworkingFeatureTests included) succeeded with no unexpected warning.
- The new tests were written first and failed to compile (red) before the implementation.
- All grep gates in both `<verify>` blocks print their EXPECT values, except the xcstrings numstat (below).
- No `.serialized`, `swiftlint:disable` or `withKnownIssue`. The largest touched Swift file is 562 lines.
- Not run: the manual `human-check` (needs a signed-in E-Hentai account).

## Deviations from Plan

All items below were accepted by the orchestrator.

1. **[Lint-forced, decision A] Excluded-language row type.** The plan's `(title:, bindings:, firstIndex:)` tuple fails the `large_tuple` rule (max 2 members). `ExcludedLanguagesSection.rows` now returns a small private struct, `ExcludedLanguageRow { title, bindings, firstIndex }`, declared next to the section. Everything else is as planned: `firstIndex = cells.startIndex - leading.count`, and the doc sentence is kept.
2. **Client closure literals (Task 1).** The four-argument literals in `EhSettingClient.noop` and `.failing` are written `{ (_, _, _, _) async throws(AppError) -> EhSetting in`, because the typed-parameter form is 128 columns and `closure_parameter_position` forbids wrapping it.
3. **Typed-throws closures.** The request closures passed to `startUpdate` carry `() async throws(AppError) in`. Without it Swift infers `any Error` and the build fails.
4. **Test helper.** `HeldAnswers.init` builds its streams with `map`, because a captured `var` cannot go into `LockIsolated`'s `@Sendable` autoclosure. `HeldAnswers`, `StubbedSite` and `ProfileCall` are file-private, and `HeldAnswers.waitForRequests(_:)` orders two in-flight requests deterministically.
5. **Order of work.** Task 1 edits were made before the baseline run. They were reverted file by file with `git checkout -- <paths>` plus moving new files aside, the baseline was run on the clean tree, and the edits were reapplied (verified byte-identical). No stash and no `git clean`.
6. **Contention.** Other projects' `xcodebuild` runs repeatedly held the "one at a time" wait. Nothing was killed.
7. **xcstrings gate.** The planned `git diff --numstat` expectation `0 42` was off by one. The `save` entry is exactly 41 lines (4723 to 4763), and exactly that entry was removed. The JSON still parses.

## Planner additions (named, as the plan requires)

- `ValuePicker` writes immediately when a change arrives with no drag in progress (for example a VoiceOver adjustment). A drag still writes once, at its end. This is within D-02 and was accepted.
- `ExcludeLanguageToggle`'s doc comment no longer claims a site answer never flips an exclusion, because the quiet refetch can.
- The dead `save` string was removed from the SettingFeature catalog (`website` stays, since Account and Login use it).
- `SCROLL-EDGE-INVENTORY.md` no longer lists the EhSetting web view sheet.

## Orchestrator answers recorded

- The ValuePicker immediate write when no drag is in progress stays.
- The ExcludeLanguageToggle comment correction stays.
- The profile-name field stays enabled during profile actions.
- Disabled category and exclusion cells get `.disabled` only. The orchestrator confirmed that `.disabled` also disables the `onTapGesture` of the default-size exclusion cell, so no extra guard is needed. I did not verify this on a device.
- The `save` string removal and the inventory edit stay.

## Expected visual change

The three scenarios `settings-pages-site-settings`, `settings-pages-site-settings-confirmation` and `settings-pages-site-settings-error` lose the two toolbar buttons (Website and Save). The snapshot baselines were not refreshed, as instructed. `ScenarioCatalog+Settings.swift` now calls `setEhSetting(_, resettingProfileName: true)`.

## Known Stubs

None.

## Threat Flags

None. No new endpoint or trust boundary was added. The threat register's mitigations are covered:
- T-01: latest-wins revisions, tested.
- T-02: the save trigger is `BindingReducer().onChange` only, and a test shows a site answer starts no save.
- T-03: drafts write once per drag, Return or focus loss, and an updating option starts no second save, tested.
- T-04: `testValue` is unimplemented and no test uses `live`.

## Self-Check: PASSED

- Created files exist: `EhSettingClient.swift`, `.swiftlint.yml`, `EhSettingReducer+Option.swift`, `EhSettingReducerTests.swift`.
- Both commits are ancestors of HEAD and signed with +08:00 dates.
- `git rev-list --count 102d1709c..HEAD` is 2.
