---
phase: 5
slug: adaptive-layout-universal-orientation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-13
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `05-RESEARCH.md` § Validation Architecture. Per-task IDs are linked once `05-*-PLAN.md` files exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Suite`/`@Test`) |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan` |
| **Quick run command** | `xcodebuild test -scheme AppPackage-Package -only-testing:ReadingFeatureTests` |
| **Full suite command** | `xcodebuild test -scheme AppPackage-Package` |
| **Estimated runtime** | Minutes (Xcode simulator build + test — not sub-second; bare `swift test` fails for this project) |

> **Never overlap test invocations.** Run exactly one `xcodebuild test` at a time; do not `pkill -9` one mid-launch (it wedges `testmanagerd`). `xcodebuild` buffers stdout until exit, so quiet output is not a hang.

---

## Sampling Rate

- **After every task commit:** Run the `ReadingFeatureTests` quick run (add `GestureHandlerTests` to it once written).
- **After every plan wave:** Run the full suite; must be green before merging the wave.
- **Before `/gsd-verify-work`:** Full suite green **plus** device rotation UAT for UIARCH-03.
- **Max feedback latency:** Minutes (Xcode build+test cycle).

---

## Per-Task Verification Map

> Requirement → behavior → automated check is fixed now (from research). The Task ID / Plan / Wave cells are populated when the planner emits `05-*-PLAN.md`; the plan-checker's validation dimension enforces the linkage.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD (plan-time) | — | — | UIARCH-01 | — / N/A | N/A (parity refactor) | unit | `-only-testing:ReadingFeatureTests/PageHandlerTests` (dual-page `mapToPager`/`mapFromPager` cover math unchanged after `isLandscape` default removal) | ✅ exists | ⬜ pending |
| TBD (plan-time) | — | — | UIARCH-01 | — / N/A | N/A | unit | `-only-testing:ReadingFeatureTests/ContainerDataSourceTests` (unchanged) | ✅ exists | ⬜ pending |
| TBD (plan-time) | — | — | UIARCH-01 | — / N/A | N/A | unit | `-only-testing:ReadingFeatureTests/GestureHandlerTests` (pan-clamp `edgeWidth`/`edgeHeight`, scale-anchor, RTL `< 0.2 / > 0.8` tap-edge zones identical for a fixed captured size vs old `absWindowW/H`) | ❌ **W0** | ⬜ pending |
| TBD (plan-time) | — | — | UIARCH-01 | — / N/A | N/A | unit | Dual-page eligibility flag `= width > height` (D-04) matches the old portrait=single / landscape=dual truth table (+ enables dual on landscape phone) | ❌ **W0** | ⬜ pending |
| TBD (plan-time) | — | — | UIARCH-01 | — / N/A | N/A | manual + snapshot-if-cheap | `LiveTextView` OCR-box mapping pixel-identical across the GeometryReader → `onGeometryChange` swap (Canvas render) | ❌ manual | ⬜ pending |
| TBD (plan-time) | — | — | UIARCH-03 | — / N/A | N/A | manual UAT | Device rotation of reader + grid + detail; dual-page toggles on rotation; no orientation lock remains, no snap-back | n/a (runtime) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/ReadingFeatureTests/GestureHandlerTests.swift` — **new**. Baseline-lock (Wave-0 method from Phases 1–4): refactor `GestureHandler` to take an injected `containerSize` / `location` (pure methods), then assert the new pure outputs equal the pre-swap `DeviceUtil.absWindowW/H`-based results for representative sizes (portrait phone, landscape phone, iPad both orientations) and scales — covering `edgeWidth`/`edgeHeight` clamps, `correctScaleAnchor` ↔ `MagnifyGesture.startAnchor` equivalence, and the `< 0.2 / > 0.8` RTL tap-zone decisions.
- [ ] `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` — **extend**. Add the D-04 aspect-ratio flag as the `isLandscape` source: prove the flag threads through unchanged and that removing the `DeviceUtil` default param is behavior-neutral (maps are already frozen).
- [ ] Framework install: **none** — the `ReadingFeatureTests` target already exists.

*This phase adds no new module, so no new `.swiftlint.yml` is triggered (net deletions).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `LiveTextView` OCR-box mapping stays pixel-accurate after GeometryReader → `onGeometryChange` | UIARCH-01 | `Canvas` rendering over live-text boxes; automated pixel assertion only feasible if a cheap snapshot fixture exists | On device/sim, open a page with live-text, confirm selection boxes align with glyphs in portrait & landscape, single & dual-page. Add SnapshotTesting only if a fixture is cheap. |
| All pages rotate with the device; reader dual-page toggles on rotation; no orientation "snap-back" | UIARCH-03 | Orientation governance is a runtime OS behavior with no unit surface after the lock is removed | Rotate reader in portrait/landscape, single & dual-page, RTL; rotate the grid to confirm ~4-column landscape phone (D-08); rotate detail/home; confirm no forced-portrait snap-back and no lock remnants. |

---

## Validation Sign-Off

- [ ] All tasks have an `<automated>` verify or a Wave 0 dependency (reader gesture/geometry unit locks) or a documented manual-only entry above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers the MISSING references (`GestureHandlerTests` new; `PageHandlerTests` extended)
- [ ] No watch-mode flags in any command
- [ ] Feedback latency acceptable (Xcode build+test cycle; single-invocation)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
