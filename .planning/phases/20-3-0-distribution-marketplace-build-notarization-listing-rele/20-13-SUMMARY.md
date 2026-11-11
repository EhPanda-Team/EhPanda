---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "13"
subsystem: analytics
tags: [analytics, telemetrydeck, consent, moderation, readme]

requires:
  - phase: 20
    provides: "20-12-VOCABULARY.md, signed off (OQ-E): the contract this plan implements"
provides:
  - "Seven Basic `AnalyticsSignal` cases with closed-enum values, rendered and level-gated as signed off"
  - "`App.distributionChannel` as the one default parameter at Basic, beside the five settings at Full"
  - "Call sites in the first-launch, Settings, Report form, comment moderation and Blocked Users flows"
  - "README Analytics section in six languages; COVERAGE.md lists the signals and records OI-4"
affects: [20-14]

actuals:
  tokens: n/a
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns: ["`pendingFirstLaunchLevel` latch so the first-launch signal follows the apply on whichever path runs second"]

key-files:
  created: []
  modified:
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Level.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Rendering.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsVocabulary.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingReducer.swift
    - AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersReducer.swift
    - AppPackage/Sources/DetailFeature/Moderation/ReportFormFeature.swift
    - AppPackage/Sources/DetailFeature/Moderation/CommentModeration.swift
    - README.md
    - READMEs/README.de.md
    - READMEs/README.jpn.md
    - READMEs/README.ko.md
    - READMEs/README.chs.md
    - READMEs/README.cht.md
    - .planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/COVERAGE.md

key-decisions:
  - "Implements exactly `20-12-VOCABULARY.md` as signed off (product lead msg 2829; owner msgs 2837, 2842). No signal, parameter or value beyond it; no level description changed; the install signal is untouched."
  - "OI-4 answer A: no code. COVERAGE.md names `App.installed` as the install count; `TelemetrySDK.swift` is unchanged."

patterns-established:
  - "A reducer offers a first-launch or level-change signal only for Basic and Full, so `Analytics.level` and `Analytics.to` never render `minimal`; the client's level gate stays the real control."

requirements-completed: []

coverage:
  - id: D1
    description: "The seven signals exist, closed and level-gated (rendering, levels, vocabulary spellings, leak probe, Basic channel parameter)"
    requirement: ANALYTICS-02
    verification:
      - kind: unit
        ref: "AnalyticsClientTests: 104 tests, 102 passed, 2 expected failures, 0 failed (iPhone)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Each flow sends its signal from the signed-off action and nothing on the excluded paths"
    requirement: ANALYTICS-02
    verification:
      - kind: unit
        ref: "FirstLaunchGateTests, GeneralSettingReducerTests, BlockedUsersReducerTests, ReportFormReducerTests, CommentModerationReducerTests; AppFeatureTests, SettingFeatureTests, DetailFeatureTests green in the full runs"
        status: pass
    human_judgment: false
  - id: D3
    description: "README in six languages and COVERAGE.md"
    requirement: ANALYTICS-02
    verification:
      - kind: other
        ref: "18-copy-check.py --readmes: exit 0 (6 Analytics sections hold the three levels verbatim; no retired text)"
        status: pass
    human_judgment: true

duration: n/a
completed: 2026-11-11
status: complete
---

# Phase 20 Plan 13: the signed-off signals, call sites and README Summary

**The seven 3.0 signals of 20-12 are implemented and sent from their flows. All are Basic, carry closed values only,
and are covered by the existing level descriptions. `App.distributionChannel` now rides on every SDK signal at Basic
and Full. The README says so in six languages. FeatureTests pass on the iPad; on the iPhone the only failures are five
VisualSnapshotTests that pass when run on their own.**

## Accomplishments

- **Signals (Task 1).** `firstLaunchCompleted(level:)`, `analyticsLevelChanged(from:toLevel:)`,
  `commentReportOutcome`, `commentPosterBlocked`, `commentPosterUnblocked(from:)`, `blockedCommentShown` and
  `commentPostingWarningAnswered`, each with an explicit arm in `minimumLevel` (Basic) and in `rendered`. Names and
  keys are minted only in `AnalyticsSignal+Rendering.swift`. `ReportOutcome`, `UnblockSurface` and
  `PostingWarningChoice` are closed enums whose spellings are pinned. `AnalyticsDefaultParameters.snapshot` returns
  nothing before a choice and at Minimal, the channel alone at Basic, and the channel plus the five settings at Full.
- **Call sites (Task 2).**
  - First launch: `AppReducer` keeps `pendingFirstLaunchLevel` when the level is chosen before the deferred launch has
    run; the deferred launch applies the stored level and then sends the signal. When the deferred launch has already
    run, the choice applies and then sends. Either way it is sent once, after the apply, and a relaunch with a stored
    level sends nothing.
  - Settings: `GeneralSettingReducer.analyticsLevelPicked` sends the old and new level after `apply`.
  - Report form: `sent`, `failed` (each failed attempt), `unavailable`, and `reportPageOpened` (from the failed alert
    and from the unavailable form).
  - Comment moderation: confirmed block, show, unblock (`comment`), and the posting warning's two answers.
    `BlockedUsersReducer.unblockTapped` sends `blockedUsers` after its guard.
  - The two "no analytics" headers (`CommentModeration.swift`, `ReportFormFeature.swift`) now describe the record.
- **README, COVERAGE (Task 3).** The Basic "screens and features" bullet gains the flows, with the report clause
  without a reason; a new Basic bullet says every event carries where the app came from. COVERAGE.md gets a "3.0
  signals" section as a list (the capability matrix and its counts are unchanged), the `defaultParameters` row now
  mentions the channel, and OI-4 answer A is recorded.

## Task Commits

All are signed (`%G?` = G) with +0800 offsets.

1. **Task 1 RED:** `b46bc23e7`. **GREEN:** `fb121e04d`.
2. **Task 2 RED:** `b9767160e`. **GREEN:** `f71372dbe`.
3. **Task 3 (README, six languages, COVERAGE):** `b4d4967f7`.
4. **Docs:** the commit that adds this summary and updates ROADMAP and STATE.

The RED commits were not run: they do not compile before the cases exist, which is their failure. The first run is
the GREEN commit's.

## Verification

| Check | Result |
|-------|--------|
| `AnalyticsClientTests` (iPhone) | `TEST SUCCEEDED`, 104 tests: 102 passed, 2 expected failures, 0 failed |
| `DetailFeatureTests` (iPhone) | `TEST SUCCEEDED`, 174 tests, 0 failed |
| AppFeature, SettingFeature, Analytics with Detail (first run, before a test fix) | the only failures were three of my new Detail tests, which used `skipReceivedActions()` with no received actions; fixed, and rerun above |
| Full FeatureTests, iPad (`$PAD`) | `TEST SUCCEEDED`, 2034 tests: 1885 passed, 9 expected failures, 140 skipped, 0 failed |
| Full FeatureTests, iPhone (`$PHONE`) | `TEST FAILED`: 2034 tests, 1880 passed, 9 expected failures, 140 skipped, 5 failed. All five are in `VisualSnapshotTests` (four in `RenderServerCaptureTests`, one in `FixtureArtworkTests`); `BandedWindow.activeScene()` finds no scene in the full run. Run alone, the two classes pass (24 of 24). Nothing in this plan touches that target. |
| `swiftlint lint --strict` on AnalyticsClient, AppFeature, SettingFeature, DetailFeature and all of `AppPackage/Tests` | 0 violations |
| `18-copy-check.py --readmes` | exit 0 |

## Deviations from Plan and from the Vocabulary

1. **The first-launch signal is sent from `AppReducer`, not `FirstLaunchReducer`.** The plan's file list names
   `FirstLaunchReducer.swift`, but `20-12-VOCABULARY.md` (the contract) names `AppReducer`, and only `AppReducer`
   calls `apply`. `FirstLaunchReducer` still calls no client.
2. **A label, not a spelling.** The case is `analyticsLevelChanged(from:toLevel:)`, because the strict lint forbids an
   identifier named `to` (and a lint disable needs the owner's permission). The wire key is still `Analytics.to`.
3. **Existing assertions that expressed the old behaviour were replaced, none weakened.** They say what changed:
   Basic carries exactly `App.distributionChannel` instead of nothing (the §3 decision); Full has six keys instead of
   five; the signal count is 20 instead of 13; `moderationSendsNoAnalyticsSignal` and
   `aFullReportFlowSendsNoAnalyticsSignal` are now exact-sequence tests; the report suite's default analytics client is
   `.noop` instead of `.unimplemented`. The first-launch tests gained the new `pendingFirstLaunchLevel` state change.
4. **Three small interpretations of the record.**
   - `unavailable` is sent when the form ends up unavailable, which includes a form that loaded without both reasons
     (the record's cell says `.loaded(nil)`).
   - The comment-surface unblock is sent only when the poster was blocked (the Blocked Users list already had this
     guard).
   - The reducers offer first-launch and level-change signals only for Basic and Full, so `Analytics.level` and
     `Analytics.to` never read `minimal`; the client's gate would drop them anyway.
5. **No `TelemetrySDK.swift` change** (OI-4 option A); the plan's file list names it for option B only.
6. **Toolchain.** Builds used a private DerivedData path (`/tmp`) and SwiftLint from the package artifact bundle in an
   existing DerivedData; `swiftlint` is not on PATH.

## Requirements

- **ANALYTICS-02:** the implementation is done. It stays Pending in REQUIREMENTS.md because 20-14 lists it too, as
  DIST-18-01 and REL-18-01 do.

## Open items

- **Translations.** The five README translations follow each file's register (Taiwan usage in zh-Hant) and use the
  app's own words for block, unblock, show and report. A native reader should look over the new clauses, especially
  the Japanese and Korean, where the existing "and searches as a shape" list continues into the new items.
- **iPhone full run.** The five VisualSnapshotTests failures are an environment issue in the full parallel run, not
  caused by this plan. Whether they also fail on the base commit was not run.
- 20-14 can start once 20-09's open items allow it.
