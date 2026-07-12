---
phase: 04-concurrency-framework-migration
plan: 12
subsystem: networking-consumers
tags: [tca, download-client, typed-throws, settings, facade]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Parity-proven typed async request layer
provides:
  - Typed async request consumption across 11 Setting effects
  - Direct typed async request consumption across seven DownloadClient sites
  - Zero production callers of the legacy request facade
affects: [04-13, 04-14]

tech-stack:
  added: []
  patterns:
    - Typed Result reconstruction for nonthrowing public client APIs
    - Direct response awaiting in already-throwing orchestration functions

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-12-SUMMARY.md
  modified:
    - AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift
    - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
    - AppPackage/Sources/SettingFeature/Login/LoginReducer.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift

key-decisions:
  - "TagTranslator noUpdates remains an explicit failure action, exactly matching the previous inline Result switch outcome."
  - "Already-throwing DownloadClient functions await typed responses directly; the Result-returning metadata API rebuilds success and failure explicitly."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "Eleven Setting effects preserve Result sends, login behavior, and TagTranslator noUpdates handling"
    requirement: CONC-01
    verification:
      - kind: build
        ref: "AppFeature iOS Simulator build"
        status: pass
      - kind: other
        ref: "Zero SettingFeature facade grep gate with explicit noUpdates branch"
        status: pass
    human_judgment: false
  - id: D2
    description: "Seven DownloadClient sites preserve public signatures and orchestration behavior"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "Full AppPackage iOS Simulator test suite including DownloadSchedulingTests"
        status: pass
      - kind: other
        ref: "Sources facade count equals one definition"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 12: Final Request Consumer Migration Summary

**The final 18 consumers now use typed-throws requests, leaving the legacy facade with no production caller.**

## Performance

- **Duration:** 7 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 6

## Accomplishments

- Converted all 11 SettingFeature request effects, including Login, EhSetting, profile, greeting, and translator flows.
- Preserved TagTranslator's explicit noUpdates outcome while moving its inline Result switch to typed do/catch.
- Converted seven DownloadClient call sites without changing public function signatures.
- Reduced `legacyResponse` references in Sources to its single definition.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `04cdc78f` | Switch Setting effects to typed async |
| 2 | `0248a6e5` | Migrate final DownloadClient consumers |

## Deviations from Plan

### [Rule 1 - Bug] Followed authoritative DownloadClient source shapes

- **Found during:** Task 2 source inventory
- **Issue:** The plan described five ExecutionSupport sites as inline Result switches, but the current source had direct `.legacyResponse().get()` calls in already-throwing functions.
- **Fix:** Applied the Group 4 direct-await conversion to those five sites. The one nonthrowing Result-returning API uses explicit typed do/catch; all public signatures remain unchanged.

**Total deviations:** 1 stale inventory correction. **Impact:** The minimal source-appropriate conversion was used; orchestration behavior is unchanged.

## Validation Results

- SwiftLint over all six modified files — **passed**, 0 violations.
- Setting facade grep gate — **passed**, zero matches and 11 typed sites.
- Sources facade count — **passed**, exactly one definition remains.
- AppFeature generic iOS Simulator build — **passed**.
- Full AppPackage iOS Simulator suite — **passed** (`TEST SUCCEEDED`); no tests changed.

## Issues Encountered

None.

## Next Phase Readiness

- Production no longer exercises the Combine request layer.
- Plan 04-13 can safely remove publishers, facade code, and Combine imports.

## Self-Check: PASSED

- All 18 scoped sites are migrated.
- DownloadClient signatures are unchanged.
- Only the facade definition references `legacyResponse` in Sources.
