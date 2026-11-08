---
phase: 19-visual-regression-marketing-export
plan: "08"
subsystem: testing
tags: [snapshot, scenarios, xctest, swiftui, tca, settings]

requires:
  - phase: 19-02
    provides: "scenarios.json (schema 2), the group catalog files, SnapshotMatrixCase and run-snapshot-local.sh"
  - phase: 19-07
    provides: "The fixed Swift hash seed in SnapshotMatrix.xctestplan"
provides:
  - "Factories for all 30 `plan: 19-08` scenarios in `ScenarioCatalog+Settings.swift`, on SettingView and SettingReducer and their pages' reducers"
  - "Four matrix classes in `SettingsSnapshotTests.swift`: Settings, SettingsPages, SettingsPagesMore, AppWide (27 methods)"
  - "Synthetic Activity Logs entries and runs, site-settings profiles, favorite names, blocked members and sign-in values in `Fixtures/SettingsFixtures.swift`"
affects: [19-10, 19-12, 19-13]

actuals:
  tokens: 260000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Settings pages are pushed on SettingReducer's stack as their rows push them, and each page's own presentation action is sent to its element"
    - "A menu that opens in its own window has every list's scroll indicator held hidden for a second after the first list appears"

key-files:
  created:
    - AppPackage/Sources/VisualSnapshotSupport/Fixtures/SettingsFixtures.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/SettingsSnapshotTests.swift
  modified:
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift

key-decisions:
  - "Account signed in or out follows the scenario's cookie client (`previewLoggedIn` or `noop`, from SnapshotMatrixCase); Log Out's confirmation is the user's tap sent to Account."
  - "The three Login scenarios are registered on the Login reducer but have no matrix method: the page's backdrop is two waves drawn in TimelineView(.animation) from the wall clock, so it never stands still and the settle times out. 19-10 decides between a not-applicable rule and an app change (see Proposed rules)."
  - "General's Minimal, Basic and Full footers are captured at the page's bottom; the clear-cache and remove-translations confirmations are the page's own dialogs."
  - "Toasts are held by reducer state, not a timer (Research Pitfall 6). The app alert is Toplists' jump-page alert with its page field focused."
  - "Laboratory waits for its interactive glass shadow: one settle, a one-second rest, then the capture's own settle."

patterns-established:
  - "One class per group, the settings pages over two classes, one method per scenario; `capture(scenario:)` reads the catalog"

requirements-completed: []

coverage:
  - id: D1
    description: "30 factories on real views and reducers; 27 matrix methods in four classes (Login has none)"
    requirement: VIS-18-01
    verification:
      - kind: integration
        ref: "run-snapshot-local.sh --device phone --config en-large, Task 1 and Task 2 classes: candidate then compare"
        status: pass
    human_judgment: false
  - id: D2
    description: "Deterministic on both devices in en-large and on the phone in ja-accessibility5 and de-xSmall"
    requirement: CAP-17-01
    verification:
      - kind: integration
        ref: "Task 3 on the final code (fb300b56b): phone en-large 108 / 108 + 108; pad en-large 54 / 54 + 54; ja-accessibility5 108 / 108; de-xSmall 108 / 108; 0 changed, timeout or error; 1 flaky (ja-accessibility5)"
        status: pass
    human_judgment: false
  - id: D3
    description: "No account detail, member name or real profile in a picture"
    requirement: VIS-18-01
    verification:
      - kind: manual
        ref: "19-13 pre-check of every picture (T-19-16)"
        status: pending
    human_judgment: true

duration: two sessions
completed: 2026-11-08
status: complete
---

# Phase 19 Plan 08: Settings, Settings pages and app-wide scenarios Summary

**27 of the 30 Settings, Settings-page and app-wide scenarios capture through their real views and reducers and
pass two compares on both devices in `en-large` and one compare each in `ja-accessibility5` and `de-xSmall` on the
phone, with no changed, timed-out or errored picture. The three Login scenarios have factories but no method: their
backdrop never stands still.**

## Performance

- **Tasks:** 3, with two fixes found in Task 3
- **Files:** 2 created, 1 modified

## Accomplishments

- **Settings root, Account, Blocked Users and Login** (Task 1, 9 scenarios, 6 captured). Settings root; Account
  signed in, signed out and with Log Out's confirmation; Blocked Users filled (three synthetic members, by member ID)
  and empty. Login empty, filled and error are built on the Login reducer but not captured (see Proposed rules).
- **Settings pages and app-wide** (Task 2, 21 scenarios). General (Minimal, Basic and Full footers, the clear-cache
  and remove-translations confirmations), Activity Logs (list, empty, run picker), Appearance, App Icon, Download,
  Reading, Laboratory, About, and the site settings (loaded, delete-profile confirmation, error). App-wide: the
  jump-page app alert over Toplists, Error Info, and the success and failure toasts.
- **Both devices and other configurations** (Task 3). Final runs, on the final code, all four classes:

| Run | Candidate | Compare 1 | Compare 2 |
|-----|-----------|-----------|-----------|
| `$PHONE` en-large | 108 recorded (182 s) | 108 passed (215 s) | 108 passed (307 s) |
| `$PAD` en-large (portrait) | 54 recorded (294 s) | 54 passed (262 s) | 54 passed (325 s) |
| `$PHONE` ja-accessibility5 | 108 recorded (243 s) | 108 passed, 1 flaky (289 s) | — |
| `$PHONE` de-xSmall | 108 recorded (234 s) | 108 passed (268 s) | — |

Wall times include the build, the simulator preparation and waits for another project's xcodebuild on the host.

**Per-class capture seconds** (sum of picture seconds from `results.jsonl`, en-large compare 1; captured / not
applicable):

| Class | `$PHONE` | `$PAD` portrait |
|-------|----------|-----------------|
| SettingsSnapshotTests | 31.7 s (24 / 0) | 19.5 s (12 / 0) |
| SettingsPagesSnapshotTests | 53.5 s (32 / 0) | 30.7 s (16 / 0) |
| SettingsPagesMoreSnapshotTests | 50.1 s (36 / 0) | 28.3 s (18 / 0) |
| AppWideSnapshotTests | 32.3 s (16 / 0) | 19.2 s (8 / 0) |
| **Total** | **167.6 s (108 / 0)** | **97.7 s (54 / 0)** |

That is about 1.6 s per picture on the phone and 1.8 s on the iPad.

**Proposed not-applicable rules (for 19-10):**

- `settings-login-empty`, `settings-login-filled`, `settings-login-error`, all coordinates. Reason: the Login page's
  backdrop (`WaveForm`) is drawn in `TimelineView(.animation)` from the wall clock, so the page never stands still
  and no settle can finish; freezing layers does not stop it. The alternative is an app change: draw the waves still
  when Reduce Motion is on (the app does not read Reduce Motion there today), and capture with Reduce Motion on.
  Without one of the two, 19-09's aggregate reports these coordinates as `missing-result`.

- **Verification:**
  - SwiftLint (strict): `AppPackage/Tests/VisualSnapshotTests/Matrix` and `AppPackage/Sources/VisualSnapshotSupport`
    0 violations.
  - Every `plan: 19-08` ID in `scenarios.json` (30) has a factory; every method names a 19-08 ID; the 3 Login IDs
    have no method.
  - No app-target file changed. Activity Logs entries and runs, profiles, favorite names, blocked members and the
    sign-in values are synthetic (T-19-16).

## Task Commits

1. **Task 1: Settings root, Account, Blocked Users and Login** - `9982fe43f` (test)
2. **Task 2: Settings pages and app-wide** - `7da43a371` (test)
3. **Task 3: Both devices and other configurations** - `fb300b56b` (test) settle Laboratory's glass and hold the
   Runs menu's indicator

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **Counts differ from the plan's text.** `scenarios.json` (19-02) has 30 `plan: 19-08` scenarios, not 29, and 17
   settings-page scenarios, not 16. All are covered; 27 are captured.
2. **Task 3's fixes are in `ScenarioCatalog+Settings.swift`**, not in `SettingsSnapshotTests.swift` (the plan's file
   for Task 3), because both are scenario interactions:
   - Laboratory's interactive glass shadow could still step after the settle's 500 ms of stillness on the phone in
     landscape (flaky, landscape light, in Task 2's run). The page now settles, rests a second, then the capture
     settles.
   - In `ja-accessibility5` the Activity Logs Runs menu is taller than the phone in landscape and builds its lists
     over its opening animation; only the first list's scroll indicator had been hidden, so compare 1 had
     `settings-pages-activity-logs-run-picker` landscape dark `changed` on both attempts (the candidate showed the
     indicator, the compare did not). Every menu list is now held hidden for a second. Check:
     `SettingsPagesSnapshotTests` in `ja-accessibility5`, candidate then three compares, 32 / 32 each. All Task 3
     runs in the table were repeated after this change.
3. **Verify runs used `/tmp/ehp19/r08f/…` output directories instead of `$TMPDIR/ehp19-08c`**; the commands are
   otherwise the plan's. iPad runs are portrait only, as in 19-05 to 19-07.

## Issues Encountered

- **Site settings' error page is blank** (`settings-pages-site-settings-error`). The scenario sets the reducer's
  `loadingState` to `.failed(.networkingFailed)` as a failed fetch does, and the page shows only its title and
  toolbar: no error message and no Retry. In `EhSettingView` the `ErrorView` is an overlay of a `ZStack` that is
  empty until the settings load, so it likely gets no space. This looks like a real app issue (a failed load leaves
  the user on a blank page). The picture is kept as the app draws it; the fix is app code, outside this phase.
- **Account signed in shows every cookie marked invalid** (`settings-account-signed-in`). The shared
  `CookieClient.previewLoggedIn` answers every cookie with the value "preview" and a non-empty localized string,
  which `CookieValue.isInvalid` reads as invalid, so the rows show "preview" with a red cross. A real signed-in
  account shows its values with check marks. 19-13 should decide before the baseline is approved: either accept,
  or give this scenario a cookie client with synthetic valid values (a change to SnapshotMatrixCase, a 19-02 file).
- **Version churn:** Error Info shows the app version, build and iOS version, and About shows the app version.
  Both pictures change with a version bump or another runtime (19-12, hosted runs).
- **Flaky pictures** (first attempt differed, the retry passed):
  - In final runs: `app-wide-app-alert` ja-accessibility5 portrait light (compare 1).
  - Seen while building: `settings-pages-laboratory` landscape light (fixed, see Deviations).
- **The host** was shared with another project's xcodebuild; `run-snapshot-local.sh` waits for it.

## User Setup Required

None.

## Next Phase Readiness

- 19-10 has one proposed rule set (the three Login scenarios) or an app change to choose.
- 19-12 and 19-13 should look at the site-settings error and Account signed-in pictures before approval.
- VIS-18-01 and CAP-17-01 stay Pending (later plans share them).
