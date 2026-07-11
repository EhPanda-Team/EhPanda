---
phase: 2
slug: native-masonry-grid-swap
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-11
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (project standard — e.g. `ImageColorsTests`, `MarkdownExtTests`) |
| **Config file** | `AppPackage/Package.swift` test targets; `AppPackage/Tests/FeatureTests.xctestplan` (app scheme) |
| **Quick run command** | `xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:GalleryListComponentsTests` |
| **Full suite command** | `xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` |
| **Estimated runtime** | ~5–15 s (quick, pure functions) · full suite minutes |

> Run exactly **one** `xcodebuild test` invocation at a time (project memory: overlapping invocations wedge `testmanagerd`, needing a Mac reboot). `xcodebuild` buffers stdout until exit — no output ≠ hang. Bare `swift build`/`swift test` fails for this package; Xcode toolchain only.

---

## Sampling Rate

- **After every task commit:** Run the quick command (`-only-testing:GalleryListComponentsTests`, pure functions) + clean build.
- **After every plan wave:** Run the full suite command.
- **Before `/gsd-verify-work`:** Full suite green **and** spike sign-off (SR-1) **and** manual scroll observation (SR-3).
- **Max feedback latency:** ~15 s for the pure-function quick run.

---

## Per-Task Verification Map

*Task IDs bind after planning; rows below map DEP-04 behaviors to their verification and are the contract the plans' tasks must satisfy.*

| Behavior (DEP-04) | Wave | Requirement | Threat Ref | Test Type | Automated Command | File Exists | Status |
|-------------------|------|-------------|------------|-----------|-------------------|-------------|--------|
| `columnCount(for:)` is a pure fn of width (adaptive rule `max(2, floor((w+15)/(185+15)))`) | 1 | DEP-04 | — | unit | `…/MasonryColumnCountTests/columnCount` | ❌ W0 | ⬜ pending |
| Degenerate widths (`0`, negative, `∞`, `NaN`) clamp to min 2 (D-32) | 1 | DEP-04 | — | unit | `…/degenerateWidthsClampToMin` | ❌ W0 | ⬜ pending |
| Placement = leftmost-shortest-column + exact `CGFloat` tie + height `max(0, tallest−15)` (D-26/D-27) | 1 | DEP-04 | — | unit | `…/placementIsLeftmostShortestColumn` | ❌ W0 | ⬜ pending |
| `cellWidth` = exact division, no rounding (D-21/D-28) | 1 | DEP-04 | — | unit | `…/cellWidthExactDivision` | ❌ W0 | ⬜ pending |
| Masonry balances + reflows on cover load; no placement animation on append; scroll not regressed | 2 | DEP-04 | — | manual / spike | Spike observation on simulator + device (SR-1, SR-3) | N/A (visual) | ⬜ pending |
| WaterfallGrid removed from dependency set (SR-4) | 3 | DEP-04 | — | build | Full package build green + `grep` confirms zero `WaterfallGrid` refs in `Package.swift` / `Package.resolved` | build gate | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift` — Swift Testing coverage for DEP-04 pure-function behavior (`columnCount(for:)`, degenerate clamp, placement planner, `cellWidth`)
- [ ] `AppPackage/Tests/GalleryListComponentsTests/.swiftlint.yml` — `parent_config: ../../../.swiftlint.yml` (project rule for new modules/targets)
- [ ] `AppPackage/Package.swift` — add `Module` case `galleryListComponentsTests` + a `.testTarget(module: .galleryListComponentsTests, dependencies: [.module(.galleryListComponents)])`
- [ ] (If the phase's test command uses the app scheme) add `GalleryListComponentsTests` to `AppPackage/Tests/FeatureTests.xctestplan`
- [ ] Spike harness — temporary `proposal.width` logging in `MasonryLayout.sizeThatFits` for the sign-off table (removed before implementation lands)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Masonry re-flows when a Kingfisher cover settles (A2) | DEP-04 | Live `LayoutSubviews` + async image load cannot be synthesized in a unit test | Run the app, open Home/Popular, watch covers load — cells must re-balance with no gaps/overlap, no scroll-nudge needed |
| No placement animation on fetch-more append (A1, D-31) | DEP-04 | Requires a live transaction/animation environment inside `List` | Scroll to trigger fetch-more; existing cells must not slide to new positions (parity with WaterfallGrid) |
| Scrolling not regressed (SR-3, Success Criterion 3) | DEP-04 | No automated perf-assertion harness in the repo | Fetch 100+ eager cells, scroll fast; compare dropped frames/hitches vs. a current WaterfallGrid build. Optional Instruments (Animation Hitches / Core Animation FPS) for a numeric read |
| Column-count sign-off table (SR-1 step 3, D-23) | DEP-04 | `m=185` must be frozen against **measured** `proposal.width` per reference device | Run spike step 1 logging across SE / 15–16 Pro / iPad mini / 11" / 13" + Split View / Slide Over / Stage Manager; produce table for owner sign-off before freezing `m` |

---

## Validation Sign-Off

- [ ] All tasks have an automated verify or a Wave 0 dependency (visual/spike behaviors explicitly listed as Manual-Only)
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (new `GalleryListComponentsTests` target)
- [ ] No watch-mode flags
- [ ] Feedback latency < ~15 s (pure-function quick run)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
