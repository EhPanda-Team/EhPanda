---
phase: 07-root-privacy-mask-auto-lock-removal
fixed_at: 2026-07-14T02:53:08Z
review_path: .planning/phases/07-root-privacy-mask-auto-lock-removal/07-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 07: Code Review Fix Report

**Fixed at:** 2026-07-14T02:53:08Z
**Source review:** `.planning/phases/07-root-privacy-mask-auto-lock-removal/07-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 2
- Fixed: 2
- Skipped: 0

## Fixed Issues

### WR-02: Animated privacy blur may not render before iOS captures the App Switcher snapshot

**Files modified:** `AppPackage/Sources/AppComponents/ViewModifiers.swift`
**Commit:** 9848e75e
**Status:** fixed; verified on a physical device 2026-07-14 (App Switcher card fully masked)
**Applied fix:** The scoped blur animation is now disabled whenever the blur becomes nonzero, so the privacy mask is applied immediately. The 0.1-second linear animation runs only when the blur becomes zero and Reduce Motion is disabled.

**Verification:** Re-read the modified source and confirmed the surrounding modifier chain remained intact; `git diff --check` passed; the `AppComponents` scheme built successfully for a generic iOS Simulator destination with code signing disabled.

### IN-01: `AppReducerScenePhaseTests` relies on `.serialized` over process-global `@Shared` storage

**Files modified:** `AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift`
**Commit:** a4ce8b12
**Status:** fixed
**Applied fix:** Each `makeStore` call now creates fresh app and in-memory storage, uses those dependencies while constructing shared state, and installs the same storage on the `TestStore`. With no process-global storage left to coordinate, the suite-level `.serialized` trait was removed.

**Verification:** `git diff --check` passed; the focused `AppReducerScenePhaseTests` run passed all three tests concurrently through the `FeatureTests` test plan. The successful Xcode build also ran the module's SwiftLint build-tool plugin.

---

_Fixed: 2026-07-14T02:53:08Z_
_Fixer: Codex (gsd-code-review)_
_Iteration: 1_
