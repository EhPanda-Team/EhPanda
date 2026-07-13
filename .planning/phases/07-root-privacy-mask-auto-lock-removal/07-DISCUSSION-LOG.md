# Phase 7: Root Privacy Mask & Auto-Lock Removal - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 7-root-privacy-mask-auto-lock-removal
**Areas discussed:** Mask source, Blur reducer fate, Lock section UI, Field + coupling

---

## Mask source — how each root obtains the blur value

| Option | Description | Selected |
|--------|-------------|----------|
| Self-sourcing modifier | `@Shared(.inMemory, default: 0)` key + a zero-arg modifier that reads it internally; uniform/unmissable call sites; hidden `@Shared` dependency in the modifier | ✓ |
| Explicit `@Shared` read | Same key, each root declares `@Shared(.inMemory)` and passes it to `.autoBlur(radius:)`; pure modifier, more per-root boilerplate | |
| SwiftUI `@Environment` | Env value at app root; fragile across sheet/cover boundaries — the exact boundary that made per-root masking necessary | |

**User's choice:** Self-sourcing modifier
**Notes:** Matches the established `greeting`/`tagTranslator`/`appActivityLogs` in-memory-key idiom. Modifier renamed `.autoBlur` → `.privacyMask()` (every call site changes anyway).

## Navbar-collapse floor — where the `0.00001` workaround lives

| Option | Description | Selected |
|--------|-------------|----------|
| Inside the modifier | Shared value stays 0=off; modifier applies `max(0.00001, radius)` | |
| In the state write | Stored value floored to `0.00001`, modifier thin | |
| (User override) | Workaround no longer needed | ✓ |

**User's choice:** "the issue is gone now, no need to apply this workaround anymore"
**Notes:** The NavigationBar-collapse issue no longer reproduces on iOS 26 + the Phase 5 navigation/layout modernization. Floor dropped entirely; value is a true `0` when off. **Overrides UIARCH-04's "workaround preserved" criterion** (light visual check in planning). `allowsHitTesting(radius < 1)` guard kept.

## Blur reducer fate — after lock removal

| Option | Description | Selected |
|--------|-------------|----------|
| Delete + fold | Delete `AppLockReducer`/`AppLockState`; `AppReducer` writes the shared blur in its scenePhase handler; remove Scope, `.appLock` action, lock-button overlay; greeting/clipboard → became-active | ✓ |
| Slim + rename | Keep a tiny `PrivacyMaskReducer` scoped into `AppReducer` owning the two writes | |

**User's choice:** Delete + fold
**Notes:** Matches "remove emptied actions" + de-globalize. On-unlock side effects (greeting fetch, clipboard detect) re-home to the became-active branch.

## Lock section UI — replacing the auto-lock control

| Option | Description | Selected |
|--------|-------------|----------|
| Section footer text | Footer with iOS per-app-lock enable instructions (Home Screen icon → Require Face ID) | |
| Prominent inline row | Higher-emphasis callout above the blur slider | |
| Text + external help link | Footer + link to Apple's support article | |
| (User override) | Remove the control; move blur slider to Appearance as "Privacy Mask" under tint color | ✓ |

**User's choice:** "removed. background blur radius goes to appearance setting page as something related to 'privacy mask', under the tint color row"
**Notes:** Auto-lock control removed outright (no pointer text) — **overrides UIARCH-05 crit. 3**. Now-empty `Section(.security)` removed. iOS built-in per-app lock has no Settings deep-link target (enabled via Home Screen icon long-press), which motivated dropping the pointer prose. Blur slider relocates to Appearance page, reframed "Privacy Mask", keeps slider mechanics + eye icons + a short footer.

## Field + coupling — property name & model changes

| Option | Description | Selected |
|--------|-------------|----------|
| Rename → `privacyMaskIntensity` | v1 in-place rename of `backgroundBlurRadius`, vocabulary-consistent | ✓ (with "Intensity" chosen for the value word) |
| Keep `backgroundBlurRadius` | No persisted-key churn; UI label only | |

**Value-word sub-choice** (user asked for alternatives to "radius"): Intensity ✓ / Strength / Radius / Blur

**User's choice:** Rename to `Setting.privacyMaskIntensity`; value word = "Intensity"
**Notes:** Also a hard directive — "please be sure to remove l10n keys and code that going to be unused after this removal." `autoLockPolicy` + `AutoLockPolicy` removed in place at v1 (enablesLandscape precedent); the `backgroundBlurRadius ↔ autoLockPolicy` `didSet` coupling deleted; `privacyMaskIntensity` default `10` (parity, mask on by default).

---

## Claude's Discretion

- Exact `@Shared(.inMemory)` key string, `.privacyMask()` file location, and Appearance footer copy.
- Whether to add a unit test for the scenePhase→shared-blur write (not a test phase; Phase 8 owns client-seam tests).

## Deferred Ideas

None — discussion stayed within phase scope.
