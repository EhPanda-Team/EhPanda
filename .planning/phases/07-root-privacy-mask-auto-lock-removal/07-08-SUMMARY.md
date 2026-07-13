---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 08
subsystem: testing
tags: [swift-testing, tca-teststore, privacy-mask, security-audit, human-verification]

# Dependency graph
requires:
  - phase: 07-07
    provides: forty self-sourcing privacy-mask application sites with all blur parameter drilling removed
provides:
  - AppFeatureTests coverage for inactive and active scene-phase privacy behavior
  - Automated proof of forty application mask sites and zero removed-symbol or localization residue
  - Owner-approved no-content-leak, navigation-bar, settings-placement, and launch-behavior verification
affects: [phase-08, UIARCH-04, UIARCH-05, app-privacy]

# Tech tracking
tech-stack:
  added: [AppFeatureTests Swift package test target]
  patterns: [TestStore coverage for shared scene state, application-site privacy audits, human security sign-off]

key-files:
  created:
    - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift
    - AppPackage/Tests/AppFeatureTests/.swiftlint.yml
  modified:
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan
    - AppPackage/Sources/AppComponents/ViewModifiers.swift
    - AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift

key-decisions:
  - "07-08: The no-content-leak gate is satisfied only by combining automated forty-site coverage with the owner's device-level approval of every judgment-dependent check."
  - "07-08: Privacy-mask coverage counts forty application calls; the public function declaration and shared-key documentation are valid non-application tokens."
  - "07-08: The owner's post-checkpoint presentation refinement scopes blur animation to the blur transform and keeps the Privacy Mask control in the first Appearance section."

patterns-established:
  - "AppReducer scene-phase behavior is tested through TestStore with controlled dependencies and locked shared-state mutations."
  - "Leak-critical modal coverage is audited as executable modifier applications rather than raw text-token totals."

requirements-completed: [UIARCH-04, UIARCH-05]

coverage:
  - id: D1
    description: AppFeatureTests proves inactive writes the configured mask intensity, active clears it, and foreground greeting and clipboard actions follow their configured paths.
    requirement: UIARCH-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift#scenePhaseWritesPrivacyMaskAndStartsForegroundEffectsOnce"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift#activeSceneSkipsClipboardDetectionWhenDisabled"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package (506 tests in 100 suites)"
        status: pass
    human_judgment: false
  - id: D2
    description: The source tree has exactly forty privacy-mask application sites and no legacy blur, lock, Face ID usage, or dead localization residue.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "rg application-site audit: privacyMask=40, removed symbols=0, NSFaceIDUsageDescription=0"
        status: pass
      - kind: integration
        ref: "localization audit: dead keys absent; privacy_mask and privacy_mask_footer each contain six locales"
        status: pass
    human_judgment: false
  - id: D3
    description: App Switcher snapshots conceal all forty surfaces, the navigation bar survives blur zero, settings placement is correct, and cold-launch effects do not double-fire.
    requirement: UIARCH-04
    verification:
      - kind: manual_procedural
        ref: "Plan 07-08 Task 3 owner verification"
        status: pass
    human_judgment: true
    rationale: "App Switcher snapshot concealment, navigation-bar presentation, settings placement, and perceived launch behavior require device-level human judgment; the owner returned approved."
  - id: D4
    description: The custom biometric auto-lock surface and its supporting code, entitlement copy, settings control, and localization are absent while background masking remains.
    requirement: UIARCH-05
    verification:
      - kind: integration
        ref: "removed-symbol, Face ID usage, and localization absence audits"
        status: pass
      - kind: manual_procedural
        ref: "Plan 07-08 Task 3 General and Appearance settings verification"
        status: pass
    human_judgment: true
    rationale: "Source absence is automated, while the final user-visible settings hierarchy was confirmed by the owner."

# Metrics
duration: 4h30m
completed: 2026-07-14
status: complete
---

# Phase 07 Plan 08: Privacy Verification and No-Leak Sign-Off Summary

**Scene-phase privacy behavior now has deterministic TestStore coverage, all forty root/modal masks and removals pass automated audits, and the owner approved the block-on-high no-content-leak gate.**

## Performance

- **Duration:** 4h 30m elapsed, including the blocking human-verification checkpoint; final continuation verification took 7 min.
- **Started:** 2026-07-13T18:37:17Z (first task commit)
- **Completed:** 2026-07-13T23:07:11Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Added the reusable `AppFeatureTests` target, its required parent SwiftLint configuration, and two Swift Testing cases covering shared mask writes and configured foreground actions.
- Re-ran the complete package suite at current HEAD: 506 tests in 100 suites passed, including both new `AppReducerScenePhaseTests`; the AppFeature simulator graph also built successfully with SwiftLint enabled.
- Proved exactly forty executable `.privacyMask()` application sites, zero legacy blur/lock symbols, zero Face ID usage-description residue, and complete six-locale Privacy Mask strings.
- Recorded owner approval for no readable App Switcher content on all audited surfaces, no large-title navigation-bar collapse at blur zero, correct settings removal/placement, and single-fire launch behavior.
- Verified the owner's post-checkpoint presentation refinement (`26c354bb`) without rewriting it: blur animation is scoped to the blur transform, and the Privacy Mask row remains in the first Appearance section.

## Task Commits

Each automated task was committed atomically; the human gate records approval rather than source changes:

1. **Task 1: Stand up AppFeatureTests and cover scene-phase privacy behavior** - `949a236d` (test)
2. **Task 2: Verify privacy-mask coverage, removals, and regressions** - `926a2a71` (test; verification-only empty commit)
3. **Task 3: Human-verify the no-content-leak property and owner overrides** - approved by the owner; no task commit

**Post-checkpoint owner adjustment:** `26c354bb` (refactor) - refined mask animation and Appearance presentation.

## Files Created/Modified

- `AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift` - Covers inactive/active shared blur writes, greeting/clipboard foreground actions, and clipboard-disabled behavior.
- `AppPackage/Tests/AppFeatureTests/.swiftlint.yml` - Inherits the repository SwiftLint rules for the new test module.
- `AppPackage/Package.swift` - Registers the `AppFeatureTests` module and test target.
- `AppPackage/Tests/FeatureTests.xctestplan` - Includes `AppFeatureTests` in the app-scheme feature plan.
- `AppPackage/Sources/AppComponents/ViewModifiers.swift` - Owner-authored refinement scopes animation to the blur visual effect.
- `AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift` - Owner-authored refinement keeps the Privacy Mask control in the primary Appearance section.

## Forty-Site Coverage Audit

| Module | Count | Masked application roots |
|--------|------:|--------------------------|
| AppFeature | 4 | app root plus new-dawn, settings, and detail presentations |
| DetailFeature | 13 | detail sheets/covers, comments, detail search, previews, torrents, sharing, archives, folders, and reading |
| DownloadsFeature | 4 | download presentations, reader cover, and subview modal |
| FavoritesFeature | 2 | both Favorites modal roots |
| HomeFeature | 6 | Frontpage, Popular, and Watched roots/filter presentations |
| ReadingFeature | 2 | reading settings and share presentations |
| SearchFeature | 5 | search roots plus quick-search and filter presentations |
| SettingFeature | 4 | Account, EhSetting, Login web views, and the AppActivityLogs run-picker |
| **Total** | **40** | **app root plus every separately presented runtime root in the D-16 inventory** |

Raw `privacyMask()` text totals 42 because the public function declaration and the shared-key documentation are intentionally present. The security invariant counts the forty executable applications.

## Human Verification Approval

The owner returned **approved** for all four blocking checks:

1. Every audited app root and modal App Switcher snapshot was blurred with no readable content, including the reader and AppActivityLogs run-picker.
2. A large-title navigation bar remained intact after backgrounding and foregrounding with the mask clearing to a true zero.
3. General settings contained no Security/auto-lock control, while Appearance exposed the Privacy Mask control and explanatory footer with working intensity changes.
4. Cold launch showed the daily greeting once and did not double-fire clipboard URL detection.

This closes threat T-07-17's block-on-high information-disclosure gate and confirms the T-07-18 exactly-once launch behavior at the user-visible layer.

## Decisions Made

- Combined TestStore evidence, static source audits, full regression coverage, and the explicit human approval; none alone is treated as sufficient proof of the leak-critical property.
- Preserved the owner's two post-checkpoint presentation edits as an independent commit and verified them at current HEAD through the AppFeature build and full suite.
- Continued to count executable mask applications, not raw token matches, so valid API/documentation text does not distort the forty-surface D-16 invariant.

## Deviations from Plan

### Owner-Authored Post-Checkpoint Refinement

- After approving the manual gate, the owner committed `26c354bb` to scope the linear animation directly to blur rendering and merge the Privacy Mask control into the primary Appearance section.
- The continuation inspected but did not rewrite that commit, then reran the AppFeature build, complete package suite, coverage audit, and orphan audit against the resulting HEAD.
- This is an intentional presentation refinement, not an executor auto-fix or scope expansion.

**Total auto-fixed deviations:** 0.
**Impact on plan:** The final verification includes the owner refinement and all planned guarantees remain satisfied.

## Issues Encountered

- The plan's literal raw-token count also sees the public `privacyMask()` declaration and shared-key documentation. The application-site audit correctly reports forty executable calls while retaining both valid non-call tokens.
- The first sandboxed Xcode build could not access DerivedData/CoreSimulator services. It was rerun with simulator access and isolated `/tmp` DerivedData; the AppFeature build and full package suite then passed. An initial full-suite invocation also used an unsupported `-packagePath` option and was immediately corrected by running the documented command from `AppPackage/`.
- The full-suite build emitted Xcode metadata-extraction warnings for targets without an AppIntents framework dependency; there were no SwiftLint violations, compile errors, or test failures.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 7 is complete: UIARCH-04 and UIARCH-05 have automated evidence plus the required owner sign-off.
- Phase 8 can reuse `AppFeatureTests` for upcoming client-seam work.
- No high-severity privacy findings, code-review findings, stubs, or deferred issues remain from this plan.

## Self-Check: PASSED

- Commits `949a236d`, `926a2a71`, and owner adjustment `26c354bb` exist in git history.
- The new test source, test-module SwiftLint config, package target, and feature-test-plan entry exist.
- Both AppReducer scene-phase tests passed; the complete package run passed 506 tests in 100 suites.
- The AppFeature simulator build succeeded after the owner adjustment with SwiftLint enabled.
- The application-site audit reports exactly forty masks; legacy symbols, Face ID usage text, and dead localization keys report zero.
- `privacy_mask` and `privacy_mask_footer` each contain `de`, `en`, `ja`, `ko`, `zh-Hans`, and `zh-Hant` localizations; shared seconds/minutes keys remain.
- `git diff --check` passed and the reviewed files contain no new stubs or lint suppressions.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
