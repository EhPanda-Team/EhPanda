---
phase: 16-dynamic-type-accessibility
plan: 20
subsystem: accessibility
tags: [reduce-motion, accessibilityReduceMotion, symbolEffect, pulse, animation, withAnimation, detail, reader, control-panel, d-29, d-31]

# Dependency graph
requires:
  - phase: 16-19
    provides: "The install-over protocol on iPhone 17e `67377A20…` (build by UDID into the evidence DerivedData, `plutil` bundle-id check, `simctl install`), the baselines to read and restore, and the evidence-root layout"
  - phase: 16-18
    provides: "The reader's native `ReadingToolbar` (the page indicator and the only top bar — there is no upper control panel any more) and `ControlPanel` as the single lower panel"
provides:
  - "Detail: the preparing-download spin (`rotationEffect` 0→360, `.linear(0.9).repeatForever`) is selected only when motion is allowed; under Reduce Motion the glyph stays upright and pulses (`.symbolEffect(.pulse, isActive:)`, opacity-only), the repeating animation never starts, and the state change settles with `.default`"
  - "Detail: the three height animations (`showsUserRating`, `showsFullTitle`, `galleryDetail`) and the deep-linked comment `scrollTo` run with `reduceMotion ? nil : .default` — instant under Reduce Motion, unchanged otherwise"
  - "Reader: the pan/zoom settle (`offset` `.linear(0.1)`, `scale` `.default`) and the page jump (`withAnimation(reduceMotion ? nil : .default) { scrollPositionID = … }`) are gated with the `performingChanges` / `echoGuardDuration` choreography byte-identical apart from the animation argument, and documented as independent of it"
  - "Control panel: the hidden panel's 50 pt offset becomes 0 under Reduce Motion so showing it is the existing `.visible(showsPanel)` fade alone; the slider-preview tray's growth animation becomes `nil`"
  - "Every crossfade, the favourite swap, the Live Text opacity swaps, `.animation(.default, value: store.showsPanel)` and every `.contentTransition(.numericText())` are byte-identical (D-29)"
  - "Live verification in both Reduce Motion states on the simulator, toggled through the real Settings switch and restored (recordings under `$HOME/Library/Caches/ehpanda-phase16/round2/reduce-motion/`)"
affects: [16-21, 16-24, 16-25, 16-26]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 2833
  tasks: 2
  commits: 2
  plan_head_before: ac916d1118b5b057a5a771df479339bdc11f2c61

tech-stack:
  added: []
  patterns:
    - "Reduce Motion gate shapes used here, all reading `@Environment(\\.accessibilityReduceMotion)` at the animating view: `.animation(reduceMotion ? nil : .default, value:)` for position/size changes; `withAnimation(reduceMotion ? nil : .default) { … }` for programmatic scrolls and jumps; a computed `Animation` that returns `.default` instead of a `repeatForever` when the spin must not start; an offset constant that collapses to 0 so an existing opacity modifier carries the transition alone; `.symbolEffect(.pulse, isActive: state && reduceMotion)` as the stand-in for a spin"
    - "A `repeatForever` animation must be switched off at its source, not only at the rotated view: left in place it re-runs every other change beneath the `.animation(_:value:)` it is attached to"
    - "Verifying Reduce Motion on the simulator: toggle the real switch (Settings › Accessibility › Motion — the switch node at the row's trailing edge, not the row label) and read `com.apple.Accessibility ReduceMotionEnabled` back with `simctl spawn … defaults read`; SwiftUI picks the change up live, no relaunch needed"
    - "Motion evidence is a screen recording tiled into a contact sheet (`ffmpeg -vf fps=10,…,tile=`), not a pair of screenshots — tool latency exceeds a `.default` animation, so `t0`/`t1` shots never land mid-animation; an intermediate frame at 6–10 fps is the observation"
    - "Driving the reader for motion evidence: `agent-device snapshot` on the reader (and on the Settings › Motion screen) exceeds the runner watchdog and wedges the session; drive those screens by coordinates with `sim-use tap` / `swipe` / `record-video` and `xcrun simctl io screenshot`, and keep `agent-device` refs for Home, Detail and Comments where the tree is light"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift

key-decisions:
  - "The spin is switched off at both ends: `spinsDownloadIcon` (`showsMetadataPreparation && !reduceMotion`) drives the `rotationEffect`, and `downloadPreparationAnimation` returns `.default` unless that same predicate holds — the plan's `.animation(…)` predicate becoming `.default` under Reduce Motion — so no `repeatForever` is ever attached while the glyph is upright. The pulse is `isActive: showsMetadataPreparation && reduceMotion`, exactly the preparation state, on the `Image` before `.font` (symbol effects apply to the symbol regardless of position in the chain)."
  - "Control panel: one computed `hiddenPanelOffset` (`reduceMotion ? 0 : 50`) feeds the single `.offset(y: showsPanel ? 0 : hiddenPanelOffset)`. The plan's second offset (an upper panel at −50) no longer exists — 16-18 confirmed the top bar is the native `ReadingToolbar` — so the `reduceMotion ? 0 :` grep reads 1 and the `≥ 2` criterion is met by the one offset that is there."
  - "The slider-preview pop is gated (`.animation(reduceMotion ? nil : .default, value: showsSliderPreview)`), not left as an opacity change: `SliderPreivew` grows from height 0 to `previewHeight + padding` while the Close button fades, so the tray's appearance is size motion; under Reduce Motion it appears in place."
  - "`.animation(.default, value: store.showsPanel)` in `ReadingView` stays as the plan wrote it: with the offset collapsed to 0 the only thing it animates on the panel is the `.visible(showsPanel)` opacity, the dissolve D-29 asks for."
  - "`requirements-completed` stays empty as in 16-15 … 16-19: A11Y-02 is the whole of round 2 and closes with the phase."

patterns-established:
  - "Re-inventory before editing paid off again: the plan's line references and its two-offset panel predate rounds 1–2; the edits followed the sites as they are at HEAD (recorded per site below)."

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Detail's preparing-download spin is replaced under Reduce Motion by an upright glyph with `.symbolEffect(.pulse)`; the spin (with `repeatForever`) is kept when motion is allowed"
    requirement: A11Y-02
    verification:
      - kind: other
        ref: "greps: `accessibilityReduceMotion` = 1, `symbolEffect(.pulse` = 2 (call + doc comment), `repeatForever` = 2 (call + doc comment) in DetailView+HeaderSection.swift; lint build `** BUILD SUCCEEDED **`, 0 `Violation:` lines"
        status: pass
      - kind: manual_procedural
        ref: "$HOME/Library/Caches/ehpanda-phase16/round2/reduce-motion/spin-off.mp4 (t≈47–50 s: rotated glyph at differing angles in consecutive 0.1 s frames, then the progress ring); spin-on.mp4 (menu-dismissal frame followed directly by the ring; no rotated glyph in any frame; the pulse itself was not caught — preparation shorter than one 10 fps frame)"
        status: pass
    human_judgment: true
    rationale: "The pulse under Reduce Motion is source-verified (predicate + `isActive`) but was not observed live; a human should confirm it on a slower preparation (e.g. a gallery whose metadata takes longer to fetch)"
  - id: D2
    description: "Detail height animations (`showsUserRating`, `showsFullTitle`, `galleryDetail`) are `nil` under Reduce Motion; their crossfades still play"
    requirement: A11Y-02
    verification:
      - kind: other
        ref: "grep `reduceMotion ? nil : .default` = 3 in DetailView.swift; `git diff` shows no change on any `.contentTransition` or favourite-swap line in DetailFeature"
        status: pass
      - kind: manual_procedural
        ref: "title-off.mp4 (8 fps sheet: one frame with the title mid-crossfade and the rows below between their two positions); title-on.mp4 (rows below move in a single frame while the title crossfade still plays). `showsUserRating` source-verified only: `Give a Rating` is `.disabled(!didLogin)` and there is no session (D-09)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Deep-linked comment `scrollTo` is un-animated under Reduce Motion and lands on the same anchor"
    requirement: A11Y-02
    verification:
      - kind: other
        ref: "grep `withAnimation(reduceMotion ? nil` = 1 in Comments/CommentsView.swift"
        status: pass
      - kind: manual_procedural
        ref: "`xcrun simctl openurl … 'ehpanda://e-hentai.org/g/4178996/918d284b74/#c8639609'`: comment-off.mp4 (6 fps sheet: one intermediate scroll frame before the target comment tops the list); comment-on.mp4 (top-of-list frame followed directly by the target at the anchor)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Reader pan/zoom settle and page jump are `nil` / un-animated under Reduce Motion with the echo-guard choreography unchanged"
    requirement: A11Y-02
    verification:
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -testPlan FeatureTests -only-testing:ReadingFeatureTests on 67377A20… — 24 tests in 5 suites passed"
        status: pass
      - kind: other
        ref: "greps: `accessibilityReduceMotion` = 1, `withAnimation(reduceMotion ? nil` = 1 in ReadingView.swift; Live Text `.animation` lines absent from `git diff`; `performingChanges` / `PageModel.echoGuardDuration` lines unchanged"
        status: pass
      - kind: manual_procedural
        ref: "zoom-off.mp4 (double-tap zoom: two intermediate scale frames at 10 fps) vs zoom-on.mp4 (every scale change a one-frame jump); jump-off.mp4 / jump-on.mp4 (slider drag 1→65 then 65→45: the page lands in one frame in both — the vertical pager's 20–64-page travel is faster than 10 fps resolves — so the jump gate is proven by source + tests, the settle gate by the zoom frames)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Control panel slide becomes an opacity-only transition and the slider-preview pop is un-animated under Reduce Motion"
    requirement: A11Y-02
    verification:
      - kind: other
        ref: "greps: `accessibilityReduceMotion` = 1, `reduceMotion ? 0 :` = 1, `.offset(` = 1 in ControlPanel.swift; `numericText` = 0 before and after (the indicator is `ReadingToolbar.swift:31`, untouched)"
        status: pass
      - kind: manual_procedural
        ref: "panel-off.mp4 (10 fps sheet: one frame with the bar below its resting position and faint) vs panel-on.mp4 (panel appears and disappears in place, no displaced frame); jump-off.mp4 rows 5–6 (tray grows over two frames) vs jump-on.mp4 row 3 (tray at full height in one frame)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Simulator idempotency: Reduce Motion toggled through the real Settings switch and restored; baselines unchanged; nothing uninstalled or erased"
    verification:
      - kind: other
        ref: "`defaults read com.apple.Accessibility ReduceMotionEnabled`: 0 before → 1 after the switch → 0 after the restore; Settings screenshots at each state; `appearance light` / `content_size large` / `increase_contrast disabled` before and after; `simctl shutdown` → Shutdown; `agent-device session list` → 0"
        status: pass
    human_judgment: false

# Metrics
duration: 31min
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 20: Reduce Motion gating — Detail and Reader Summary

**Detail and reader motion gated on `accessibilityReduceMotion` — the download spin becomes an upright pulsing glyph, the Detail heights, comment scroll, pan/zoom settle, page jump and preview pop go instant, the panel slide collapses to its existing fade — with every crossfade and `numericText` byte-identical, verified in both states on the simulator through the real Settings switch.**

## Performance

- **Duration:** 31 min
- **Started:** 2026-09-11T15:24:56Z
- **Completed:** 2026-09-11T15:55:49Z
- **Tasks:** 2
- **Files modified:** 5 (+ `deferred-items.md`)

## Accomplishments

- Six meaningful-motion sites in `DetailFeature` and `ReadingFeature` read the environment at the animating view and substitute `nil`, `.default`-without-repeat, an opacity-only path or a pulse; none is mirrored into TCA state or set in a `#Preview` (RESEARCH Pitfall 10).
- Each gate carries a comment naming the motion (rotation / height / travel / slide / growth) and what it degrades to, in the `View+Toast` / `PrivacyMaskModifier` style.
- Both Reduce Motion states observed live on iPhone 17e `67377A20…` for the spin (OFF), title expansion, comment scroll, zoom settle, page jump, panel and preview; the setting toggled through Settings › Accessibility › Motion and restored to its recorded value.
- Lint build green three times (0 violations, no suppression); `ReadingFeatureTests` 24/24 on the simulator.

## Per-site gating

| Site (at HEAD) | Motion | Gate | Degrades to |
|---|---|---|---|
| `DetailView+HeaderSection.swift` download button `.animation(downloadPreparationAnimation, value: showsMetadataPreparation)` + `downloadIconLabel` `.rotationEffect(.degrees(spinsDownloadIcon ? 360 : 0))` | spin, 1 turn / 0.9 s `repeatForever` while metadata is prepared | `spinsDownloadIcon = showsMetadataPreparation && !reduceMotion`; the animation returns `.default` unless it holds | upright glyph with `.symbolEffect(.pulse, isActive: showsMetadataPreparation && reduceMotion)` (opacity-only) |
| `DetailView.swift` body, 3 × `.animation(reduceMotion ? nil : .default, value:)` | height expand/collapse: rating row, full title, detail sections | `nil` | instant; the sections' own opacity crossfades unchanged |
| `Comments/CommentsView.swift` `withAnimation(reduceMotion ? nil : .default) { proxy.scrollTo(…, anchor: .top) }` (inside the unchanged 0.75 s `asyncAfter`) | scroll travel to the deep-linked comment | `nil` | same anchor, instantly |
| `ReadingView.swift` `.animation(reduceMotion ? nil : .linear(duration: 0.1), value: gestureHandler.offset)` / `.animation(reduceMotion ? nil : .default, value: gestureHandler.scale)` | eased settle after each pan / zoom step | `nil` | content still follows the finger; no easing |
| `ReadingView.swift` `jump(toPagerIndex:)` `withAnimation(reduceMotion ? nil : .default) { scrollPositionID = clampedIndex }` | pager travel across the pages between | `nil`; `performingChanges` / `echoGuardDuration` lines byte-identical, comment states the guard covers the index write's observer round-trip, not the travel | lands instantly |
| `ControlPanel.swift` `.offset(y: showsPanel ? 0 : hiddenPanelOffset)` with `hiddenPanelOffset = reduceMotion ? 0 : 50` | 50 pt rise paired with the `.visible(showsPanel)` fade | offset 0 | the fade alone, still driven by the reader's `.animation(.default, value: store.showsPanel)` |
| `ControlPanel.swift` `.animation(reduceMotion ? nil : .default, value: showsSliderPreview)` | preview tray growing from height 0 while the Close button fades | `nil` | tray appears in place |

Left exactly as they were (D-29): the favourite `heart` / `heartFill` opacity swap, every `.contentTransition(.numericText…)` in DetailFeature, the Live Text `enablesLiveText` / `liveTextGroups` animations, `.animation(.default, value: store.showsPanel)`, the page indicator's `numericText` + title animation (now in `ReadingToolbar.swift:31–33`), and the progress ring's static `.rotationEffect(.degrees(-90))` at `HeaderSection.swift` (the −90° start angle of a fill, not a spin) with its `.animation(.default, value: progress)`.

## Reduce Motion OFF / ON observations

Simulator: iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9` (iOS 26.5), booted from Shutdown; baselines read after boot `appearance light`, `content_size large`, `increase_contrast disabled`; `ReduceMotionEnabled` `0`. Install-over per `16-SWEEP.md § Protocol`: built by UDID into `$HOME/Library/Caches/ehpanda-phase16/DerivedData` at the Task-2 tree (committed unchanged as `449628fb`); `plutil -extract CFBundleIdentifier raw` → **`app.ehpanda.personal`**; `xcrun simctl install` over the existing bundle (the only EhPanda bundle, before and after); nothing uninstalled, erased or reset; no credential entered (D-09). Reduce Motion was turned ON through Settings › Accessibility › Motion (the switch node at the row's trailing edge, ≈(328, 146) pt — a tap on the row label does not toggle it), read back `1` from `com.apple.Accessibility ReduceMotionEnabled` and confirmed on a Settings screenshot; the `defaults write` fallback was not used. Evidence root `$HOME/Library/Caches/ehpanda-phase16/round2/reduce-motion/` (never in the repo; `git status` image count 0 before both commits). Each recording was tiled into a 6–10 fps contact sheet in the session scratchpad for reading; the sheets were not kept.

| Site | OFF (recording) | ON (recording) | Verdict |
|---|---|---|---|
| Download spin → pulse | `spin-off.mp4` (t≈47–50 s; public gallery `4183242`, folder `Second`): the glyph appears at different rotation angles in consecutive 0.1 s frames, then the progress ring | `spin-on.mp4` (public gallery `4179873`, folder `Second`, paused at 1/205 right after): the menu-dismissal frame is followed directly by the ring; **no rotated glyph in any frame**; the pulse itself was not caught — preparation shorter than one frame | pass on rotation (none under ON); pulse **source-verified, not observed live** |
| Full title expand (`showsFullTitle`) | `title-off.mp4`: one 8 fps frame with the title mid-crossfade and the rows below between their two positions | `title-on.mp4`: the rows below sit at the expanded position in the very next frame while the title's crossfade is still playing | pass |
| `showsUserRating` | — | — | **source-verified**: same `nil` predicate as the title; `Give a Rating` is `.disabled(!didLogin)` and the simulator holds no session |
| `galleryDetail` arrival | seen as the Detail filling in during the comment deep link (`comment-off.mp4` row 2) | `comment-on.mp4` row 1–2 | same predicate as the title; not separately judged |
| Deep-linked comment scroll (`#c8639609` on `4178996/918d284b74`) | `comment-off.mp4`: one intermediate 6 fps frame (yura520 half-scrolled) before vexling0 tops the list | `comment-on.mp4`: NEET☆通-at-top frame followed directly by vexling0 at the anchor | pass |
| Page jump via slider | `jump-off.mp4`: drag 1→65; the page lands within one 10 fps frame (vertical pager, 64 pages of travel — too fast to resolve) | `jump-on.mp4`: drag 65→45; lands in one frame | ON pass; OFF not resolvable at 10 fps — gate proven by source + `ReadingFeatureTests` |
| Slider-preview pop | `jump-off.mp4` rows 5–6: tray slots faint/partial in one frame, full in the next | `jump-on.mp4` row 3: tray at full height with placeholders in a single frame | pass |
| Panel show / hide | `panel-off.mp4`: one frame with the bar below its resting position and faint on show; gone in one frame on hide | `panel-on.mp4`: appears and disappears in place, no displaced frame | pass |
| Zoom settle (double-tap toggle) | `zoom-off.mp4`: two intermediate scale frames on zoom-in | `zoom-on.mp4`: every scale change a one-frame jump (in and out) | pass |
| Pan settle (`offset`) | — | — | **source-verified**: same shape as the `scale` gate; a free pan was not exercised separately |

Restore: Reduce Motion switched OFF in Settings (`ReduceMotionEnabled` read back `0`; screenshot shows the switch off), baselines read back `light` / `large` / `disabled` (nothing switched), `agent-device close` (`sessions: 0`), `xcrun simctl shutdown` → `Shutdown`. Two public galleries were downloaded to the simulator's `Second` folder as part of the spin observation (`4183242` complete, 28 pages; `4179873` paused at 1 of 205); the existing `4178996` gallery in `Default` was not touched. No D-25 screen was added (D-24): nothing here changes static layout.

## Task Commits

1. **Task 1: Detail — spin → pulse, expand/collapse heights, deep-linked comment scroll** — `9687c82d` (feat)
2. **Task 2: Reader — pan/zoom settle, page jump, panel slide, preview pop; simulator verification** — `449628fb` (feat)

**Plan metadata:** recorded in the docs commit that carries this file.

## Files Created/Modified

- `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift` — `reduceMotion` read; `spinsDownloadIcon` + `downloadPreparationAnimation`; `.symbolEffect(.pulse, isActive:)` on the glyph.
- `AppPackage/Sources/DetailFeature/DetailView.swift` — `reduceMotion` read; three `nil` predicates with one comment.
- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift` — `reduceMotion` read; `withAnimation(reduceMotion ? nil : .default)`.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` — `reduceMotion` read; offset / scale predicates; page-jump `withAnimation` with the guard-independence comment.
- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift` — `reduceMotion` read; `hiddenPanelOffset`; preview-pop predicate.
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md` — two out-of-scope observations appended (below).

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

No deviation rule (1–4) fired: no bug, missing functionality or blocker was found in the code, and no architectural question arose. The differences below are between the plan's environment / line references and HEAD, applied per the orchestrator's pre-authorisations.

1. **Re-inventory (env fact 1).** The plan's line numbers predate rounds 1–2; the sites at HEAD are listed in "Per-site gating". There is **one** panel offset (`ControlPanel.swift` `LowerPanel` `.offset(y: showsPanel ? 0 : 50)`) — the upper panel is the native `ReadingToolbar` since round 1 — so `grep -c "reduceMotion ? 0 :"` reads **1**, not ≥ 2. `grep -c numericText ControlPanel.swift` reads **0** before and after: the indicator lives at `ReadingToolbar.swift:31`, untouched. The other `.rotationEffect` (`HeaderSection.swift`, `−90°` on the progress ring) is a static start angle and was left.
2. **`showsUserRating` is login-gated (env fact 5 assumed otherwise).** `Give a Rating` is `.disabled(!didLogin)`; with no session (D-09) the toggle is unreachable, so that predicate is source-verified (it is the same expression as the observed title gate).
3. **Simulator and test destination (env fact 3).** iPhone 17e `67377A20…` for `ReadingFeatureTests`, the install-over and both passes, instead of the plan's `88B217DA…` / `IPHONE_UDID`; the test command otherwise as written.
4. **Reduce Motion route (env fact 4).** The preferred Settings route was used and succeeded, but only after two failure modes: a tap on the `Reduce Motion` row label (`@e7`) does not toggle the switch, and `agent-device snapshot` on the Settings › Motion screen and on the reader exceeded the runner watchdog (`RUNNER_BUSY`), leaving a stale global `default` session that had to be closed with `agent-device close --session default`. The switch was then pressed by coordinates on its knob. The `defaults write` fallback was **not** used.
5. **Instruments for the ON pass and the reader.** Because of (4), every reader interaction and the ON-pass captures were driven with `sim-use tap` / `sim-use swipe` / `sim-use record-video` and `xcrun simctl io screenshot`, with `agent-device` kept for Home / Detail / Comments navigation (light trees) and `xcrun simctl openurl` for the deep link. The three `agent-device record` files produced while the runner was wedged were empty (0.07 s) and were deleted before re-recording.
6. **Evidence form (env fact 6).** Screen recordings (`.mp4`, full scale) rather than paired screenshots: a `.default` animation is shorter than the tool round-trip, so `t0`/`t1` shots cannot land mid-animation; the recordings were read as 6–10 fps contact sheets. Twelve recordings, none in the repo (image check 0 before both commits).
7. **Comment id (env fact 5).** Read from the gallery's public page (`curl https://e-hentai.org/g/4178996/918d284b74/`, `id="comment_8639609"`), no credential involved; the deep link `ehpanda://e-hentai.org/g/4178996/918d284b74/#c8639609` opened Comments and scrolled as designed.
8. **Spin under Reduce Motion not observed live (env fact 5 fallback).** Two download starts were needed for the two states; the ON start's preparation window was shorter than one frame, so the pulse is source-verified with the negative evidence that no rotated glyph appears in any frame. No third download was started and nothing was deleted.
9. **`git add` staged the two `Support/…` files by path** as the protocol requires; nothing else changed in `git status` besides the untracked `.gsd/` and `.planning/state.json`.

## Issues Encountered

- `agent-device` 0.20.10: `snapshot -i` (and the implicit capture of `open` / `--settle`) on the reader and on Settings › Motion trips the runner watchdog and leaves the session unusable until closed; a stray non-cwd `default` session then blocks re-opening (`DEVICE_IN_USE` + `SESSION_NOT_FOUND`). Recorded in `patterns` for later plans.
- Carousel and Toplists refs on Home report `off-screen and not safe to press` even when drawn; a coordinate tap from a `simctl` screenshot worked.
- The first `agent-device press` after the Download menu opened failed on a superseded ref generation; a fresh `snapshot -i` fixed it (the spin-off recording is therefore 55 s long; the observation is in its last 8 s).

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-20 mitigated (echo-guard lines byte-identical; `ReadingFeatureTests` 24/24; page jump observed in both states). T-16-21 mitigated (the out-of-scope list honoured; Live Text and `.contentTransition` lines absent from the diff; `numericText` count unchanged). T-16-03 mitigated (bundle id checked before the single install-over; nothing uninstalled, erased or reset; Reduce Motion and baselines restored and read back).

## Deferred items appended

- Download button: in the OFF recording the header alternated ring → rotated glyph → ring over ≈0.4 s right after the folder was chosen (`downloadBadge` appears to flip non-nil → nil → non-nil once during the queued/active hand-off). Pre-existing, cosmetic; downloads owner.
- Home tab on the logged-out simulator shows a generic `Unknown Error` / `Retry` section below Toplists (most likely the login-gated Watched section). Not an accessibility item.

## User Setup Required

None.

## Next Phase Readiness

- 16-21 (lists, sheets, settings + source-scan pin test) can reuse the five gate shapes above and the simulator route (Settings switch by coordinates; `sim-use` for heavy screens). The pin test should count `accessibilityReduceMotion` reads: HEAD has 4 pre-existing + 5 from this plan.
- Open for the owner: whether to observe the pulse live on a slower preparation (D1 `human_judgment`), and the two deferred observations.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-11*

## Self-Check: PASSED

SUMMARY present; all five modified files present; commits `9687c82d` and `449628fb` found in history; 0 absolute home paths in the SUMMARY and `deferred-items.md`; 0 image files in `git status`.
