---
phase: 3
slug: native-reader-paging-swap-spike-gated
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-11
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Detailed strategy lives in `03-RESEARCH.md` § Validation Architecture — this file is the execution-time sampling contract derived from it.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test` / `@Suite` / `#expect`) — Xcode-only (bare `swift test` fails) |
| **Config file** | none — SwiftPM test targets declared in `AppPackage/Package.swift` |
| **Quick run command** | Xcode test of the affected suite (e.g. new `PageHandlerTests`) via the `AppPackage-Package` scheme |
| **Full suite command** | `xcodebuild clean test -skipMacroValidation -skipPackagePluginValidation -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'` (CI) — run **one** xcodebuild test invocation at a time |
| **Estimated runtime** | ~full-suite minutes (Xcode build + sim boot); the new pure-mapping suite alone is sub-second |

---

## Sampling Rate

- **After every task commit:** run the affected suite (`PageHandlerTests` / reading reducer tests) — must be green.
- **After every plan wave:** full suite green **and** clean build under SwiftLint-as-error.
- **Before the dependency-removal wave AND before `/gsd-verify-work`:** full suite green **and** the D-11 go/no-go checklist signed off (every parity item passes). A gap on any item ⇒ D-02 all-or-nothing skip, documented.
- **Max feedback latency:** the pure-mapping suite is designed to be sub-second so the central `PageHandler` regression guard samples fast; full-suite/simulator parity is the slower wave gate.

---

## Per-Task Verification Map

> Task IDs are assigned by the planner. The DEP-05 behavior → test mapping below is authoritative;
> the planner threads each row into a task's `<verify>` / `must_haves`. See `03-RESEARCH.md`
> § Validation Architecture "Phase Requirements → Test Map" for the full table.

| Behavior | Requirement | Test Type | Automated Command | File Exists | Status |
|----------|-------------|-----------|-------------------|-------------|--------|
| `PageHandler.mapToPager`/`mapFromPager` correct: single-page, dual-page, exceptCover cover-exception, boundary | DEP-05 | unit | `PageHandlerTests` (new) | ❌ W0 | ⬜ pending |
| `mapToPager` ↔ `mapFromPager` round-trip identity per mode | DEP-05 | unit | same suite, table-driven | ❌ W0 | ⬜ pending |
| RTL index mapping stays logical (data forward, `layoutDirection` flipped) | DEP-05 | unit | same suite (assert direction-agnostic) | ❌ W0 | ⬜ pending |
| `containerDataSource` stack collapsing (dual-page / exceptCover strides) matches expected `[Int]` | DEP-05 | unit | reducer-level (state func is pure) | ❌ W0 | ⬜ pending |
| Reducer contract unchanged — `syncReadingProgress` fires with correct reading-page after a scroll | DEP-05 | integration | TCA `TestStore` (reuse reading scaffolding) | ✅ partial | ⬜ pending |
| SwiftUIPager fully removed (no import, no `Package.swift` entry, `Package.resolved` regenerated, acknowledgement + xcstrings gone) | DEP-05 | build gate + grep | clean build + `grep -r SwiftUIPager` returns only historical docs | ❌ W2 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` — dedicated pure-mapping suite (dual-page / cover / RTL / boundary / round-trip). **No `ReadingFeatureTests` target exists today** — the planner must add the test target to `AppPackage/Package.swift`; a new module dir carries a `.swiftlint.yml` with the correct-depth `parent_config`.
- [ ] `containerDataSource` stack-math coverage — same new suite (state func is pure and callable).
- [ ] D-11 go/no-go checklist artifact (committed markdown alongside the spike, Phase 2 SR-1 style) enumerating every D-10 parity item with a pass/gap mark.
- [ ] Framework install: none — Swift Testing is already in use.

---

## Manual-Only Verifications

> The "feel" parity items that cannot be asserted headlessly — validated on device + simulator via the D-11 go/no-go checklist, signed off by the owner. A gap on any item triggers the D-02 skip.

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Programmatic-jump smoothness / `.scrollPosition(id:)` landed-id fidelity (autoplay, slider seek, tap-to-turn, resume-seed) | DEP-05 | Requires observing real scroll landing; spike must **log** the landed id (evidence, not vibes) | Trigger each programmatic jump; confirm the landed leading-item id equals the target with no glitch/off-by-one |
| Reader gesture coexistence under zoom (paging frozen at `scale != 1`, pan works while zoomed, RTL edge single-tap page-turn) | DEP-05 (SC #3) | Multi-gesture composition — headless test cannot exercise touch | Zoom in → swipe (no page change); pan (moves); single-tap RTL edges (turns correct direction) |
| Horizontal + RTL + dual-page-landscape paging & snapping | DEP-05 | `.paging` landscape misalignment (FB16486510) is a device-observable risk | Page in each mode/orientation; confirm exact snap and correct index |
| Home carousel: peek + 0.2 opacity fade + 20pt spacing + snap + `pageIndex` sync + **infinite loop invisibility** (D-08) | DEP-05 | Loop re-center invisibility (tripled buffer) cannot be asserted headlessly | Scroll the carousel through the wrap boundary repeatedly; confirm no visible jump and `pageIndex` stays in sync |

---

## Validation Sign-Off

- [ ] All automatable tasks have an `<automated>` verify or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers the missing `PageHandlerTests` target + go/no-go checklist
- [ ] No watch-mode flags
- [ ] D-11 go/no-go checklist signed off before dependency removal
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
