---
phase: 07-root-privacy-mask-auto-lock-removal
verified: 2026-07-13T23:34:21Z
status: gaps_found
score: 6/11 must-haves verified
behavior_unverified: 0
overrides_applied: 0
next_action: "Gaps found. Plan the fixes, then re-run execute-phase before shipping."
next_command: "/gsd:plan-phase 07 --gaps"
gaps:
  - truth: "Every inactive transition masks content before the App Switcher snapshot, including transitions before settings initialization completes."
    status: failed
    reason: "AppReducer returns when hasLoadedInitialSetting is false before handling inactive or background, leaving privacyMaskBlur at its launch default of 0 and dropping the background latch."
    artifacts:
      - path: "AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift"
        issue: "The settings-loaded guard at line 83 precedes the inactive privacy write and background bookkeeping at lines 111-134."
      - path: "AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift"
        issue: "The helper always sets hasLoadedInitialSetting to true, so the launch race is untested."
    missing:
      - "Move the safety-critical active/inactive privacy writes and background latch outside the settings-loaded side-effect gate."
      - "Add a TestStore regression starting with hasLoadedInitialSetting false and exercising inactive then background."
  - truth: "Automated tests prove foreground greeting and clipboard effects occur exactly once and prove clipboard detection is absent when disabled."
    status: failed
    reason: "Both foreground tests use withExhaustivity(.off), which permits extra actions; one receive proves occurrence but not exactly-once, and no receive cannot prove absence."
    artifacts:
      - path: "AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift"
        issue: "Lines 29-38 and 49-54 disable exhaustivity around the asserted action sequences."
    missing:
      - "Use exhaustive action assertions or controlled counters that deterministically prove one greeting, one enabled clipboard action, and zero disabled clipboard actions."
  - truth: "Each runtime root surface has one shared-state-driven privacy mask and the coverage audit cannot be satisfied by duplicates."
    status: failed
    reason: "There are 38 runtime sheet/full-screen-cover presentations plus the app root (39 distinct roots), but 40 modifier applications because the Download Inspector is masked both at its NavigationStack root and inside DownloadInspectorView."
    artifacts:
      - path: "AppPackage/Sources/DownloadsFeature/DownloadsView.swift"
        issue: "The inspector NavigationStack applies privacyMask at line 54."
      - path: "AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift"
        issue: "DownloadInspectorView applies privacyMask again at line 102, composing the configured blur twice."
    missing:
      - "Keep a single mask on the presented root and remove the nested duplicate."
      - "Replace the raw 40-call count with an explicit one-to-one runtime presentation-root inventory."
  - truth: "ROADMAP.md and REQUIREMENTS.md describe the accepted Phase 7 behavior without contradicting locked phase decisions."
    status: failed
    reason: "The roadmap/requirements still require preserving the NavigationBar blur floor and replacing auto-lock with an iOS-lock description, while locked decisions D-03 and D-08 intentionally require the opposite. No formal VERIFICATION override exists."
    artifacts:
      - path: ".planning/ROADMAP.md"
        issue: "Phase 7 success criteria 1 and 3 conflict with D-03 and D-08."
      - path: ".planning/REQUIREMENTS.md"
        issue: "UIARCH-04 and UIARCH-05 retain the same conflicting acceptance wording."
      - path: ".planning/phases/07-root-privacy-mask-auto-lock-removal/07-CONTEXT.md"
        issue: "D-03 drops the floor; D-08 removes the control without replacement prose."
    missing:
      - "Reconcile ROADMAP/REQUIREMENTS with the locked owner decisions or record accepted verification overrides; do not silently choose either contract."
review_warnings:
  - id: WR-01
    disposition: promoted_to_gap
    evidence: "withExhaustivity(.off) remains in both scene-phase tests."
  - id: WR-02
    disposition: promoted_to_gap
    evidence: "The Download Inspector still has nested privacyMask applications."
  - id: WR-03
    disposition: unresolved_warning
    evidence: "PrivacyMaskModifier still animates unconditionally and does not read accessibilityReduceMotion."
  - id: WR-04
    disposition: unresolved_warning
    evidence: "AppFeatureTests still directly links ComposableArchitecture in addition to AppFeature."
---

# Phase 7: Root Privacy Mask & Auto-Lock Removal Verification Report

**Phase Goal:** Replace `blurRadius` parameter-drilling with one shared-state-driven mask per root surface, remove the custom auto-lock in favor of iOS's built-in per-app lock, retain background blur, and leak no content.
**Verified:** 2026-07-13T23:34:21Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | A shared in-memory blur and zero-argument self-sourcing privacy modifier exist, with true-zero blur and hit-testing protection. | VERIFIED | `AppSharedKeys.swift:74-78`; `ViewModifiers.swift:9-17,43-45`; artifact/link queries passed. |
| 2 | No view initializer or caller retains `blurRadius`, and legacy `autoBlur` is gone. | VERIFIED | Repository-wide source audit found `blurRadius=0` and `autoBlur=0`. |
| 3 | Every runtime root has exactly one mask, with an audit that cannot be fooled by duplicates. | FAILED | 38 runtime presentations + app root = 39 distinct roots, but 40 applications because Download Inspector is masked twice. |
| 4 | The mask is written before every inactive/background snapshot, including before settings load. | FAILED | `AppReducer.swift:83` returns before the inactive write and background latch when settings are not loaded. |
| 5 | The ROADMAP NavigationBar-collapse workaround is preserved. | FAILED — CONTRACT CONFLICT | Source deliberately uses true zero with no floor, as locked D-03 requires; the roadmap/requirement wording was not reconciled. Owner manual evidence confirms no collapse, but not literal preservation. |
| 6 | The custom auto-lock state machine, biometric path, client module, lock UI, and metadata are removed. | VERIFIED | Absence audit found zero `AppLockReducer`, `appLockState`, `AutoLockPolicy`, `AuthorizationClient`, `LocalAuthentication`, `LAContext`, and `NSFaceIDUsageDescription` matches. |
| 7 | The removed auto-lock control is replaced by an iOS built-in-lock description. | FAILED — CONTRACT CONFLICT | General has no Security section or replacement prose, exactly as locked D-08 requires but contrary to ROADMAP criterion 3 and UIARCH-05 wording. |
| 8 | Background/app-switcher blur remains functional for initialized settings flows. | VERIFIED | Loaded-state reducer path writes `privacyMaskIntensity` on inactive and `0` on active; targeted tests passed; owner approved the visual background checks. |
| 9 | The setting model and UI use `privacyMaskIntensity`, default 10, no coupling/migration, with localized Appearance control. | VERIFIED | `Setting.swift:16,40,59-70,90`; `AppearanceSettingView.swift:38-51`; both keys have all six translated locales. |
| 10 | Greeting/clipboard foreground effects are automatically proven exactly once, including the disabled negative case. | FAILED | The two tests pass but disable TestStore exhaustivity, so extra or forbidden actions are permitted. |
| 11 | Removed symbols, plist metadata, and dead localization keys leave no residue; retained/new localization remains complete. | VERIFIED | Removed-symbol/key audits returned zero; `seconds`/`minutes` remain; both Privacy Mask keys have `de,en,ja,ko,zh-Hans,zh-Hant`. |

**Score:** 6/11 truths verified.

## Roadmap and Requirements Conflicts

Two conflicts are explicit and must not be silently resolved by this verifier:

1. ROADMAP criterion 1 and UIARCH-04 say the NavigationBar-collapse workaround is preserved. Locked decision D-03 drops the minimum blur floor and requires a true zero. Current source follows D-03, and the owner's manual check observed no collapse.
2. ROADMAP criterion 3 and UIARCH-05 require replacement prose pointing to iOS's built-in lock. Locked decision D-08 requires removing the control outright with no replacement description. Current source follows D-08.

These are specification-governance gaps, not instructions to reintroduce the floor or add prose without owner direction. No `overrides:` entries were available to carry either conflicting roadmap truth as passed.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift` | Shared transient blur key | VERIFIED | Exists, substantive, default `0`, used by reducer and modifier. |
| `AppPackage/Sources/AppComponents/ViewModifiers.swift` | Self-sourcing privacy modifier | PARTIAL | Wired and floorless; owner commit `26c354bb` is present at current HEAD and scopes the animation to blur, but Reduce Motion remains unhandled. |
| `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` | Safe scene-phase writer | FAILED | Correct for loaded settings; unsafe early return before pre-settings inactive/background transitions. |
| `AppPackage/Sources/AppModels/Persistent/Setting.swift` | Renamed plain setting field | VERIFIED | Default 10, no auto-lock coupling, schema v1 retained. |
| `AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift` | Relocated accessible control | VERIFIED | Owner commit `26c354bb` keeps it in the first Appearance section with label/footer and hidden decorative icons. |
| `AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift` | Behavioral regression guard | FAILED | Exists and runs, but test exhaustivity is disabled and pre-settings transitions are absent. |
| `AppPackage/Package.swift` | AppFeatureTests target | PARTIAL | Target exists and runs; it directly relinks a transitive production dependency. |

All eight PLAN artifact queries reported existence/substance, and every declared key-link pattern was found. Semantic verification above overrides those presence-only results where behavior or wiring quality fails.

## Key Link and Data-Flow Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `Setting.privacyMaskIntensity` | `AppReducer.State.$privacyMaskBlur` | inactive scene transition | PARTIAL | Flows after settings load; disconnected during pre-load transitions because of the guard. |
| `privacyMaskBlur` shared key | `PrivacyMaskModifier` | `@SharedReader(.privacyMaskBlur)` | WIRED | The modifier observes the same in-memory key. |
| Presented roots | `PrivacyMaskModifier` | `.privacyMask()` | PARTIAL | Every inventoried presentation appears covered, but Download Inspector is double-wired and the call-count audit is not one-to-one. |
| `AppReducer` | `AppReducerScenePhaseTests` | `TestStore` | PARTIAL | Tests execute the reducer but do not strictly enforce the claimed action cardinality or launch race. |

## Behavioral Spot-Checks

| Behavior | Command/check | Result | Status |
|---|---|---|---|
| Current scene-phase test suite | `xcodebuild test -scheme AppPackage-Package ... -only-testing:AppFeatureTests/AppReducerScenePhaseTests` | 2 Swift Testing tests passed in 1 suite; command exited 0. | PASS, but insufficient assertions |
| Pre-settings inactive/background path | Static transition trace through `AppReducer.swift:81-134` | Guard exits before blur write and background latch. | FAIL |
| Mask and removal audit | `rg`/`jq` source checks | 40 mask applications, 38 runtime presentations, zero legacy symbols, complete locales. | PARTIAL — duplicate detected |
| Commit `26c354bb` | `git merge-base --is-ancestor 26c354bb HEAD` plus source diff inspection | Commit is an ancestor of current HEAD; both edits remain in current source. | PASS |

No phase probe scripts were declared. A fresh full-suite run was not repeated because the focused behavior suite was sufficient to confirm current test execution, while the blocking defects are directly observable in source.

## Requirements Coverage

| Requirement | Source Plans | Status | Evidence |
|---|---|---|---|
| UIARCH-04 | 07-01 through 07-08 | BLOCKED | Parameter drilling/removal, shared state, modifier wiring, normal loaded-state blur, and human observations pass; the pre-settings leak path, duplicate mask, non-proof tests, and workaround wording conflict remain. |
| UIARCH-05 | 07-02, 07-03, 07-08 | BLOCKED — CONTRACT CONFLICT | Auto-lock implementation is fully removed and blur remains, but required replacement prose is absent by locked D-08. |

No Phase 7 requirement is orphaned from the plans. Both requirement IDs are claimed and mapped.

## Review Finding Reconciliation

| Finding | Current verdict | Evidence |
|---|---|---|
| CR-01 pre-settings inactive/background leak | CONFIRMED — BLOCKER | The guard remains at `AppReducer.swift:83`; no pre-settings test exists. |
| WR-01 non-exhaustive tests | CONFIRMED — promoted to gap | Both tests still use `withExhaustivity(.off)`. |
| WR-02 Download Inspector double mask | CONFIRMED — promoted to gap | Outer mask at `DownloadsView.swift:54`; inner mask at `DownloadsView+Subviews.swift:102`. |
| WR-03 Reduce Motion ignored | CONFIRMED — warning | `PrivacyMaskModifier` has unconditional `.linear(duration: 0.1)` and no `accessibilityReduceMotion` environment read. |
| WR-04 transitive test dependency relinked | CONFIRMED — warning | `AppFeatureTests` lists both `AppFeature` and `ComposableArchitecture` in `Package.swift:838-844`. |

The review warnings are all still present. WR-01 and WR-02 directly invalidate must-have truths and are therefore promoted to structured gaps. WR-03 and WR-04 remain actionable quality warnings but are not independently responsible for the phase-goal failure.

## Human Verification Evidence

The owner's `approved` checkpoint is accepted only for the four observations it covered:

1. The manually visited App Switcher snapshots showed no readable content.
2. The large-title NavigationBar did not collapse when blur returned to zero.
3. General/Appearance placement and intensity behavior looked correct.
4. One cold launch showed one greeting and no doubled clipboard prompt.

That evidence does not override the observable pre-settings source defect, prove action cardinality under non-exhaustive tests, detect the nested double blur reliably, or resolve roadmap wording conflicts. No additional human verification is requested before the code/spec gaps are closed.

## Anti-Patterns and Quality Warnings

| File | Pattern | Severity | Impact |
|---|---|---|---|
| `AppComponents/ViewModifiers.swift` | Unconditional animated blur | WARNING | Violates Reduce Motion guidance on every inactive/active transition. |
| `AppPackage/Package.swift` | Test target relinks a transitive production dependency | WARNING | Risks duplicate runtime module warnings and conflicts with project testing guidance. |

No `TODO`, `FIXME`, `XXX`, `HACK`, `PLACEHOLDER`, or SwiftLint suppression was found on the principal Phase 7 surfaces. `git diff --check` passed and the working tree was clean before this report was created.

## Gaps Summary

Phase 7 cannot pass while the launch race can leave the App Switcher unmasked. The same closure plan should make scene safety independent of settings initialization and add the missing regression. Separate closure work must make exactly-once tests exhaustive, remove the Download Inspector's duplicate mask and replace count-only coverage with a root inventory, and reconcile the two locked-decision conflicts in ROADMAP/REQUIREMENTS. The two remaining review warnings should be fixed while touching their respective modifier and test-target files.

**Next action:** Gaps found. Plan the fixes, then re-run execute-phase before shipping.

**Next command:** `/gsd:plan-phase 07 --gaps`

---

_Verified: 2026-07-13T23:34:21Z_
_Verifier: the agent (gsd-verifier; generic-agent workaround)_
