# Phase 3: Native Reader Paging Swap (spike-gated) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-11T23:20:17+09:00
**Phase:** 3-native-reader-paging-swap-spike-gated
**Areas discussed:** Home carousel scope, Reader native construct, Gesture-under-zoom parity, Spike scope & gate

---

## Reader native construct

| Option | Description | Selected |
|--------|-------------|----------|
| Paging ScrollView primary | ScrollView(.horizontal) + .scrollTargetBehavior(.paging) + .scrollPosition + .scrollDisabled; read DEP-05 "TabView" as mechanism, not literal API | ✓ |
| TabView(.page) literal | Hold to .tabViewStyle(.page); deviate only if spike proves it can't disable swipe-under-zoom / handle RTL | |
| You decide | Let the spike's findings pick | |

**User's choice:** Free-text redirect → "a horizontal paging scrollview is a better fit than page styled tabview. let's change direction to it." Then clarified the purpose and that it "applies to both homeview pager and readingview pager."
**Notes:** User first interrupted to ask whether SwiftUI now has a paging ScrollView; after confirming `.scrollTargetBehavior(.paging)` (iOS 17+), chose it. Two overriding intents stated: (1) the whole point is to replace SwiftUIPager with **standard components only**, and if that's impossible the task can be **skipped**; (2) "be sure to try harder before you claim it's impossible." (3) The construct decision applies to **both** call sites. This resolved the Home-carousel-scope area (in scope, converted with paging ScrollView) and the `Page`-seam sub-question (Page deleted → plain index) at the same time.

---

## Home carousel scope — loop parity

| Option | Description | Selected |
|--------|-------------|----------|
| Loop is nice-to-have | Peek/opacity/spacing must match; infinite loop droppable if not clean | |
| Loop is mandatory parity | Infinite wrap-around preserved exactly; if tripled-buffer can't do it smoothly → parity gap → skip whole task | ✓ |
| Spike decides | Attempt tripled-buffer loop; fall back to bounded + flag if janky | |

**User's choice:** Loop is mandatory parity
**Notes:** Under all-or-nothing, this makes the carousel's infinite loop a potential blocker for the entire phase — accepted deliberately.

---

## Gesture-under-zoom parity

| Option | Description | Selected |
|--------|-------------|----------|
| Full parity, all three | Paging frozen while zoomed + pan while zoomed + RTL-aware edge single-tap page-turn; criterion #3, non-negotiable | ✓ |
| Freeze-while-zoomed only | Must-have is paging can't fight pan; tap-to-turn reworkable if it conflicts | |
| You decide | Hold full parity; flag genuine incompatibilities | |

**User's choice:** Full parity, all three
**Notes:** `.scrollDisabled(scale != 1)` covers the freeze; pan + RTL edge-tap page-turn must also match today.

---

## Spike scope & gate

| Question | Options | Selected |
|----------|---------|----------|
| Spike order | Risk-first early-exit / **Full-surface then judge** | Full-surface, then judge |
| Spike fate | **Spike-to-keep (Phase 2 style)** / Throwaway prototype | Spike-to-keep |

**User's choice:** Full-surface build of both replacements end-to-end, judged holistically; if parity passes, the spike code becomes the implementation (committed with a go/no-go checklist).
**Notes:** Consistent pairing — build the real thing end-to-end, judge parity, keep it if it passes. Go/no-go checklist is the sign-off artifact; any genuine gap triggers the all-or-nothing skip (SwiftUIPager retained).

---

## Claude's Discretion

- RTL implementation mechanism (`layoutDirection` env flip vs reversed data) — default to the flip.
- Shared index as bare `Int` binding vs thin `@Observable` wrapper — planner decides on call-site churn.

## Deferred Ideas

- Reconciling the literal "page-style TabView" wording in ROADMAP.md / REQUIREMENTS.md (DEP-05) / PROJECT.md with the paging-ScrollView decision — separate `/gsd-phase` edit if desired.
- De-globalizing `DeviceUtil` (`isLandscape`/`windowW`) — Phase 5 (UIARCH-01).
