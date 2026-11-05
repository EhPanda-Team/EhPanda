---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "02"
subsystem: first-launch
tags: [age-wall, analytics-level, setting, launch-gate, deep-link-queue, ui-test-preset]

requires: []
provides:
  - "`AnalyticsLevel` (`minimal`, `basic`, `full`; no `none`) and `AgeDeclaration` (`currentVersion = 1`, `isConfirmed` true only on equality) in AppModels"
  - "`Setting.ageDeclarationVersion: Int?` and `Setting.analyticsLevel: AnalyticsLevel?` (nil = never answered); `shareAnalyticsData`/`isSharingAnalyticsData` removed, no schema bump, no migration"
  - "`FirstLaunchReducer`: derived step `ageWall` → `analyticsChoice` → `complete`, `isDeclarationTicked`, `selectedLevel` (no default), delegates `.ageConfirmed` and `.levelChosen(AnalyticsLevel)`"
  - "`AppReducer` gate: `firstLaunch` scope, `isUnlocked`, a one-shot deferred launch (liveness observation, `loadUserSettings`, replay of a withheld scene phase), `openURL(URL)` with a one-slot pending link routed after the settings load"
  - "`analyticsClient.start()` no longer runs at launch (18-03 adds `apply`)"
  - "DEBUG `UITestAutomation.FirstLaunchPreset` (`answered` / `cleared`), `firstLaunchPreset(environment:isAutomatedLaunch:)`, `applyFirstLaunchPreset(_:)`, `configureVisualTestHost(_:firstLaunch:)`; `UITestConstants.firstLaunchEnvironmentKey`"
affects: [18-03, 18-08, 18-09, 18-10, 18-12, phase-19-capture]

actuals:
  tokens: 60000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "First-launch answers on the v1 Setting, decoded absent-tolerant; the gate state is derived, never stored"
    - "Deferred launch: local work always, network-opening work once behind a latch after both the unlock and the cookie maintenance"

key-files:
  created:
    - AppPackage/Sources/AppModels/Persistent/AnalyticsLevel.swift
    - AppPackage/Sources/AppModels/Persistent/AgeDeclaration.swift
    - AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchReducer.swift
    - AppPackage/Tests/AppModelsTests/SettingFirstLaunchFieldsTests.swift
    - AppPackage/Tests/AppFeatureTests/FirstLaunchGateTests.swift
  modified:
    - AppPackage/Sources/AppModels/Persistent/Setting.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsDefaultParametersTests.swift
    - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift
    - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/AppReadingFlushTests.swift
    - AppPackage/Package.swift
    - EhPandaUITests/Support/UITestConstants.swift
  deleted:
    - AppPackage/Tests/AppModelsTests/SettingAnalyticsOptOutTests.swift

key-decisions:
  - "The unknown-level decode is `do { try decodeIfPresent } catch { nil }`, not the plan's `try?`: the project's SwiftLint `optional_try` rule rejects `try?` at build time. Same behavior, and it also covers a level stored with the wrong JSON type."
  - "The locked launch ends its cookie maintenance with a new internal action, `launchPreparationFinished` (state `didFinishLaunchPreparation`). The deferred launch runs after both the unlock and that action, whichever comes last, so the settings never load before the cookie maintenance. When the age is already confirmed at launch, `onLaunchFinish` runs the deferred half inline in the old order (liveness at once, `loadUserSettings` after the cookie run), with no extra action."
  - "`recordedScenePhase` holds only a download-client report that was withheld while locked (`.active` or `.background`). The deferred launch replays it and clears it; a live report after the unlock also clears it. An unlocked launch never replays, so it sends no extra `setIsInBackground(false)` (the state's initial phase is `.active`)."
  - "While locked, the privacy-mask blur and the background latch are still written. They are local and protect the app-switcher snapshot; only the download-client calls are gated."
  - "An `openURL` received while unlocked routes at once and clears any queued link (the newer link wins). A queued link routes at the top of `.runLaunchAutomation` once the app is unlocked and the settings have loaded. It does not wait for the automation's other conditions (window size classes, igneous). `TabBarView.onOpenURL` is unchanged; 18-09 moves it to the root and sends `.openURL`."
  - "The hosted visual-test preset is written inside `configureVisualTestHost`. The prepared dependencies and the app store each call it, and each call makes its own `UserDefaults.inMemory` suite, so a preset written in `prepare` alone would miss the store. The one-argument overload keeps `.answered`, so its existing callers (including the function reference in `UITestStubTests`) are unchanged, and `AppDelegate` passes the resolved preset."
  - "A capture launch gets its preset after `CaptureScenePreparation.install`, so it lands in the capture's isolated storage on top of the scene's `Setting`. A stubbed-network launch writes into the simulator's real storage, which is why `show` clears both answers instead of leaving them."
  - "`FirstLaunchReducer.Delegate` is `@CasePathable`, so tests and 18-03 can match `\\.firstLaunch.delegate.levelChosen`."
  - "The `shareAnalyticsData` / `shareAnalyticsDataFooter` strings stay in SettingFeature's string catalog for 18-10 to reuse or remove; no code reads them now."
  - "REQUIREMENTS.md is not marked: AGE-18-01 and CONSENT-18-01 are shared with 18-03, 18-06 and 18-09, which have no SUMMARY yet (shared-ID gate)."

patterns-established:
  - "AppReducer tests that drive `.onLaunchFinish` or the scene phase state the gate explicitly, either an unlocked Setting or the locked default (P-2)"

requirements-completed: []

coverage:
  - id: D1
    description: "Setting stores both answers as optionals. Absent keys decode as nil, an unknown or wrongly typed level decodes as nil without resetting the other fields, and the retired `shareAnalyticsData` key neither resets the blob nor sets a level nor is written again."
    requirement: CONSENT-18-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppModelsTests/SettingFirstLaunchFieldsTests.swift (AppModelsTests green on phone and pad)"
        status: pass
    human_judgment: false
  - id: D2
    description: "AgeDeclaration.isConfirmed is true only for the current version (P-10), and AnalyticsLevel is exactly minimal, basic, full"
    requirement: AGE-18-01
    verification:
      - kind: unit
        ref: "SettingFirstLaunchFieldsTests#onlyTheCurrentWordingVersionCountsAsConfirmed, #theLevelsAreMinimalBasicFullInThatOrder"
        status: pass
    human_judgment: false
  - id: D3
    description: "A locked launch and a locked scene phase touch no download-client endpoint, make no analytics call and send no loadUserSettings"
    requirement: AGE-18-01
    verification:
      - kind: unit
        ref: "FirstLaunchGateTests#aLockedLaunchRunsOnlyLocalWork (unimplemented DownloadClient() and AnalyticsClient.unimplemented, exhaustive TestStore)"
        status: pass
      - kind: other
        ref: "Mutation check: with the locked branch calling setIsInBackground and the liveness observation (working copy only, restored), the case fails with 'Unimplemented: DownloadClient.setIsInBackground' and '…observeContinuedSessionLiveness'"
        status: pass
    human_judgment: false
  - id: D4
    description: "The deferred launch runs once (liveness, loadUserSettings, the withheld phase replayed), after both the confirmation and the cookie maintenance; a second confirmation does nothing"
    requirement: AGE-18-01
    verification:
      - kind: unit
        ref: "FirstLaunchGateTests#confirmingTheAgeRunsTheDeferredLaunchOnce, #aSecondConfirmationReceivesNothing, #aConfirmationBeforeThePreparationFinishesWaitsForIt, #anUnlockedLaunchRunsTheDeferredLaunchAtOnce"
        status: pass
    human_judgment: false
  - id: D5
    description: "A link opened while locked is queued (one slot, the latest wins) and routed once through presentation(.handleDeepLink) after the settings load; unlocked links route at once"
    requirement: AGE-18-01
    verification:
      - kind: unit
        ref: "FirstLaunchGateTests#aLinkOpenedWhileLockedIsQueuedAndTheLatestWins, #aQueuedLinkWaitsForTheSettingsToLoad, #aQueuedLinkIsRoutedOnceAfterTheSettingsLoad, #anUnlockedLinkRoutesAtOnceAndReplacesAQueuedOne"
        status: pass
    human_judgment: false
  - id: D6
    description: "FirstLaunchReducer derives its step from storage, resumes at the analytics choice, writes the version only when ticked, stores the chosen level and reports each answer"
    requirement: CONSENT-18-01
    verification:
      - kind: unit
        ref: "FirstLaunchGateTests (FirstLaunchReducer section: 8 step cases, tick gate, stale version, 3 level cases, choice unreachable before the wall)"
        status: pass
    human_judgment: false
  - id: D7
    description: "DEBUG preset: stubbed, capture and visual-host launches are written past the first launch unless EHPANDA_UITEST_FIRST_LAUNCH=show; client-only launches get none; existing UI suites still reach the app"
    requirement: AGE-18-01
    verification:
      - kind: unit
        ref: "UITestStubTests (preset cases and the hosted-store regression, now unlocked)"
        status: pass
      - kind: ui
        ref: "xcodebuild test -testPlan UITests -only-testing:EhPandaUITests/DeepLinkEntryUITests on the phone (2/2 passed)"
        status: pass
      - kind: other
        ref: "Release simulator build (-derivedDataPath .build/phase18-release): BUILD SUCCEEDED, 0 warnings; `strings` on the Release binary finds no EHPANDA_UITEST_FIRST_LAUNCH"
        status: pass
    human_judgment: false

duration: about 30 min
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 02: First-Launch Gate Logic and Storage Summary

**The two first-launch answers now live on `Setting` without a migration, and `AppReducer` keeps the download
client, the settings load and links behind the age wall, running them once at the unlock. Every automated DEBUG launch
is preset past the gate unless it asks for the real first launch.**

## Performance

- **Duration:** about 30 min of execution, after the context reads
- **Started:** 2026-11-05T06:59:50Z
- **Completed:** 2026-11-05T07:27:00Z
- **Tasks:** 3
- **Files modified:** 20 (5 created, 14 modified, 1 deleted)

## Accomplishments

- **Storage (Task 1).** `AnalyticsLevel` has `minimal`, `basic` and `full`, in that order, with no `none` and no
  default. `AgeDeclaration.currentVersion` is 1 and `isConfirmed` is true only on equality. `Setting` has two
  optionals decoded with `decodeIfPresent`. The old toggle, its computed property, its coding key and its decode line
  are gone, with no schema bump or migration. A 2.x blob decodes with both answers nil, so every upgrader answers
  again. As a bridge until 18-03, `AnalyticsClient.send` and `AnalyticsDefaultParameters` pass only basic or full,
  each marked `// Replaced by the level gate in 18-03.`. The Settings toggle section is gone and marked
  `// The level picker returns in 18-10.`.
- **Gate (Task 2).** `FirstLaunchReducer` derives its step from the stored answers. `AppReducer` scopes it and splits
  `onLaunchFinish` into two halves. The local half always runs: the log pump and the cookie maintenance, plus the
  history prune and the image-cache setup in `AppDelegateReducer`. The deferred half (the liveness observation, which
  is the first download-client access, `loadUserSettings`, and the withheld phase report) runs once, behind
  `didRunDeferredLaunch`. The scene phase reaches the download client only when unlocked; otherwise it is recorded.
  `openURL` queues while locked. `analyticsClient.start()` is gone from the launch.
- **Preset (Task 3).** DEBUG-only `FirstLaunchPreset`. Stubbed-network, capture and visual-host launches get
  `.answered` (the current version and `.minimal`), or `.cleared` with `EHPANDA_UITEST_FIRST_LAUNCH=show`; any other
  value is ignored. Clipboard-only and pause-refusal launches get none. The decision is a pure function,
  `firstLaunchPreset(environment:isAutomatedLaunch:)`.

## Task Commits

1. **Task 1: Storage: AnalyticsLevel, AgeDeclaration, Setting fields, retire the toggle** - `8a305ca63` (feat)
2. **Task 2: FirstLaunchReducer and the AppReducer gate** - `4ea1815a3` (feat)
3. **Task 3: DEBUG preset for automated launches** - `4a462cb9b` (feat)

**Plan metadata:** recorded in the `docs(18-02)` commit that adds this file.

All three commits are signed (`G`) with `+08:00` author and committer dates.

## Files Created/Modified

- `AppModels/Persistent/AnalyticsLevel.swift`, `AgeDeclaration.swift` (new): the level and the wording version.
- `AppModels/Persistent/Setting.swift`: the two fields, their keys and decoding; the toggle removed.
- `AnalyticsClient/AnalyticsClient.swift`, `AnalyticsDefaultParameters.swift`: the basic-or-full bridge (18-03).
- `SettingFeature/GeneralSetting/GeneralSettingView.swift`: the analytics toggle section removed (18-10).
- `AppFeature/FirstLaunch/FirstLaunchReducer.swift` (new): the step machine.
- `AppFeature/DataFlow/AppReducer.swift`: the gate, the deferred launch, the phase recording and the link queue.
- `AppFeature/DataFlow/AppDelegateReducer.swift`: no SDK start, and the visual host gets the resolved preset.
- `AppFeature/UITestSupport/UITestAutomation.swift`: the DEBUG preset.
- Tests: `SettingFirstLaunchFieldsTests` (new, replaces the deleted `SettingAnalyticsOptOutTests`),
  `FirstLaunchGateTests` (new), `AnalyticsDefaultParametersTests` (`baseSetting()` is `.full`; the opt-out cases are
  now level-gate cases for nil and minimal), `AppReducerScenePhaseTests`, `UITestStubTests`,
  `DownloadAutomationTests`, `AppReadingFlushTests`.
- `AppPackage/Package.swift`: AppFeatureTests depends on ApplicationClient and DFClient.
- `EhPandaUITests/Support/UITestConstants.swift`: `firstLaunchEnvironmentKey`.

## Verification

- Task 1 RED: the new suite failed to compile (`cannot find 'AnalyticsLevel'`, `no member 'ageDeclarationVersion'`).
  GREEN: AppModelsTests and AnalyticsClientTests 178 total, 176 passed, 2 expected failures (existing known issues),
  0 failed.
- Task 2/3: AppFeatureTests and DownloadsFeatureTests on the phone: 665 total, 659 passed, 6 expected failures,
  0 failed. FirstLaunchGateTests: 29 cases, including parameterized ones.
- Plan verification on the phone, then the pad: AppModels, AppFeature, AnalyticsClient, SettingFeature and
  DownloadsFeature tests. Phone: 908 total, 898 passed, 10 expected failures, 0 failed. Pad: 908 total, 899 passed,
  9 expected failures, 0 failed. These five targets compiled with 0 Swift warnings.
- `DeepLinkEntryUITests` (UITests plan, phone): `** TEST SUCCEEDED **`, 2/2.
- Mutation check of the locked-launch test (see coverage D3). The source was restored, and `grep` confirms the
  mutation is gone.
- Strict no-cache lint (0.65.1 plugin binary) on `AppPackage/Sources/AppModels`, `Tests/AppModelsTests`,
  `Sources/AnalyticsClient`, `Tests/AnalyticsClientTests`, `Sources/SettingFeature/GeneralSetting`,
  `Sources/AppFeature`, `Tests/AppFeatureTests`, `Tests/DownloadsFeatureTests` and `EhPandaUITests/Support`:
  0 violations.
- `grep -rn "isSharingAnalyticsData\|shareAnalyticsData:" AppPackage/Sources AppPackage/Tests --include=*.swift | wc -l`
  → 0. `grep -c "case minimal"` → 1 and `grep -c "case none"` → 0 in `AnalyticsLevel.swift`.
  `grep -n "analyticsClient.start" AppDelegateReducer.swift` → none.
- `EHPANDA_UITEST_FIRST_LAUNCH` appears only in `UITestAutomation.swift`, inside its `#if DEBUG` scope (lines 36 to
  the file's last `#endif`), and in `UITestConstants.swift` (UI-test target). The Release simulator build succeeds
  with 0 warnings, and `strings` on its binary finds no such key. 18-12 runs the full Release scan.

## Decisions Made

See `key-decisions` above. The ones that shape later plans:

- the deferred launch waits for both the unlock and `launchPreparationFinished`;
- only a withheld phase is replayed;
- a queued link waits only for the settings;
- the visual-host preset lives in `configureVisualTestHost`.

## Deviations from Plan

1. **[Rule 3, blocking] `try?` replaced with `do`/`catch` in `Setting.init(currentFrom:)`.** The build-time SwiftLint
   plugin fails `optional_try`. The behavior is the plan's.
2. **[Rule 3, blocking] `AppPackage/Package.swift` (not in the plan's files): AppFeatureTests gains `ApplicationClient`
   and `DFClient`.** The deferred-launch tests receive `.setting(.loadUserSettings)`, whose effects call
   `applicationClient` and `dfClient`. Their test values report unimplemented calls, and the target could not
   override them without importing the modules.
3. **[Rule 2] Tests outside the plan's files now state an unlocked Setting (P-2).** These are `DownloadAutomationTests`
   (`testAppForegroundReturnReconcilesDownloads`, `testLaunchFinishImportsAutomationCookiesBeforeLoadingSettings`)
   and the three `AppReadingFlushTests` stores. Without it, the launch test fails, because a locked launch no longer
   loads the settings. The others would have kept passing, but on an impossible combination: settings loaded while
   locked.
4. **Extra gate state and action beyond the plan's list:** `didFinishLaunchPreparation` and
   `launchPreparationFinished`, which order the settings load after the cookie maintenance (key-decisions).
5. **`AppDelegateReducer.swift` also carries a Task 3 change** (the preset passed to `configureVisualTestHost`). It
   was committed with Task 3; Task 2's commit has only the SDK-start removal.
6. **`UITestConstants.swift`** is named in Task 3's action but not in `files_modified`; it was edited as the action
   says.

**Total deviations:** 6, none of them product decisions.

## Issues Encountered

- **Pre-existing, not fixed (outside this plan):** the full FeatureTests plan on the phone has 2 failures in
  `AppToolsTests/ReduceMotionGatingSourceTests` (`environmentReadsMatchTheRecordedInventory`,
  `gateMentionsMatchTheRecordedInventory`). The cause is `ReadingFeature/ReadingView.swift`: it now has 2
  `accessibilityReduceMotion` reads and 5 gate mentions, against an inventory of 1 and 4. That file was last changed by
  18-07 (`b7a759bd8`), and 18-02 does not touch it. The one inventoried file 18-02 edits, `GeneralSettingView.swift`,
  still matches its row. The inventory needs a D-29 re-derivation for the reworked reader, which belongs to an 18-07
  follow-up. Full run: 1594 total, 1583 passed, 2 failed, 9 expected failures.

## User Setup Required

None.

## Next Phase Readiness

- 18-03 can replace the two bridge guards with the level gate, and add `analyticsClient.apply` at
  `.firstLaunch(.delegate(.levelChosen))` and wherever the launch already has a stored level. There is a placeholder
  case in `AppReducer`.
- 18-08 extends `FirstLaunchPreset`: `analytics` keeps the age answer and clears the level. Today any value other
  than `show` reads as `.answered`.
- 18-09 renders `FirstLaunchReducer`'s steps from `RootView` and moves `onOpenURL` to the root, sending `.openURL`.
- 18-10 adds the level picker where the toggle section was.

## Self-Check: PASSED

- Every created file exists, and the deleted test is gone. Commits `8a305ca63`, `4ea1815a3` and `4a462cb9b` are on
  `feature/gsd-phase-18`.
- Each task's acceptance criteria re-ran and passed (results above).
