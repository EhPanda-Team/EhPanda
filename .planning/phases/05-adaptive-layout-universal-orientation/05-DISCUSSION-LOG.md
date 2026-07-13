# Phase 5: Adaptive Layout & Universal Orientation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 5-Adaptive Layout & Universal Orientation
**Areas discussed:** DeviceUtil removal scope, Reader geometry & landscape source, Shared size constants re-home, Orientation-lock removal & masonry

---

## DeviceUtil removal scope

### Q1 — Where should Phase 5 draw the DeviceUtil boundary?

| Option | Description | Selected |
|--------|-------------|----------|
| Metric-only | Convert only window/screen/isPadWidth/isSEWidth; leave isPad/isPhone idiom for Phase 8 | |
| Metric + layout-proxy idiom | Also convert "is there room" idiom sites to size-class | |
| Kill all DeviceUtil layout reads | Remove every device layout read this phase | |

**User's choice:** Free-text — "I want DeviceUtil to be removed. DeviceClient takes its job and no direct DeviceClient.liveValue or static method usage allowed, only use it through @Dependency."
**Notes:** Broader than the offered options → **D-01**. Deletes `DeviceUtil` entirely; `DeviceClient` becomes the injected home; consumers use `@Dependency` only. Pulls the Device slice of HYG-01 forward.

### Q2 — For layout-metric reads, what does "DeviceClient takes its job" mean?

| Option | Description | Selected |
|--------|-------------|----------|
| Native SwiftUI, DeviceClient keeps only facts | Metrics → containerRelativeFrame/size-class/onGeometryChange/ViewThatFits; client holds only irreducible facts | ✓ |
| DeviceClient absorbs window-size getters too | Route absWindowW/H through the client (conflicts with acceptance #1) | |

**User's choice:** Native SwiftUI, DeviceClient keeps only facts → **D-02**.
**Notes:** Confirmed by scout — no reducer reads window size, so nothing metric must live on the client.

### Q3 — Conversion policy for isPad/isPhone view branches (superseded)

| Option | Description | Selected |
|--------|-------------|----------|
| Native-lean, accept adaptive edge behavior | Convert "is there room" branches to size-class | |
| Parity-lock idiom via deviceClient.isPad | Keep exact idiom semantics | |

**User's choice:** Dismissed the question; replaced with a concrete directive → **D-03**.
**Notes:** Owner pasted a `DeviceType` enum (unspecified/phone/pad/watch/tv/carPlay/mac/vision, `@MainActor static var current`) to replace the `is*` accessors, used **through DeviceClient** via `@Dependency`. Idiom branches keep device-class semantics (not converted to size-class); only metric reads go native.

---

## Reader geometry & landscape source

### Q1 — How should the reader decide it's "landscape" after the lock is removed?

| Option | Description | Selected |
|--------|-------------|----------|
| Container aspect ratio: width > height | Derive from captured container size | ✓ |
| horizontalSizeClass == .regular | Width class (portrait iPad = .regular → behavior change) | |
| Interface orientation (size-sourced) | Keep orientation read natively | |

**User's choice:** Container aspect ratio (width > height) → **D-04**.

### Q2 — How should the reader capture and share its container geometry?

| Option | Description | Selected |
|--------|-------------|----------|
| Single source of truth into shared reader model | One capture → GestureHandler + dual-page + landscape all read it | ✓ |
| Per-view local geometry captures | Each view captures its own | |

**User's choice:** Single source of truth → **D-05**. Plus directive: "avoid GeometryReader even when reading size," initially with a `bindSize`/`.background(GeometryReader)` helper.
**Notes:** Helper superseded by Q3.

### Q3 — Which size-reading pattern should Phase 5 use?

| Option | Description | Selected |
|--------|-------------|----------|
| onGeometryChange | Direct modern equivalent of bindSize; no GeometryReader; satisfies acceptance #1 | ✓ |
| bindSize helper (sanctioned GeometryReader) | Encapsulated GeometryReader carve-out | |

**User's choice:** onGeometryChange → **D-06**. `bindSize` dropped.
**Notes:** Claude flagged that the pasted `bindSize` wraps a `GeometryReader`, conflicting with UIARCH-01 acceptance #1 and PROJECT.md; `onGeometryChange` is the equivalent that satisfies the criterion.

### Q4 — Convert the 3 pre-existing GeometryReader sites?

| Option | Description | Selected |
|--------|-------------|----------|
| Convert all 3 — codebase GeometryReader-free | LoginView + GalleryInfosView + LiveTextView | ✓ |
| Convert 2 easy, defer LiveTextView | Leave the Canvas overlay | |
| Leave all 3 — out of scope | New code only | |

**User's choice:** Convert all 3 → **D-06b**. LiveTextView gets a careful overlay-parity check.

---

## Shared size constants re-home

### Q1 — How should device-derived Defaults.FrameSize/ImageSize be re-homed?

| Option | Description | Selected |
|--------|-------------|----------|
| Dissolve into native per-site expressions | containerRelativeFrame / size-class / adaptive grids inline | ✓ |
| Central namespace, captured-width param | Pure functions taking captured container width | |
| Hybrid | Fractions native; breakpoint values kept in a table | |

**User's choice:** Dissolve into native per-site expressions → **D-07**. Card-width/peek coupling handled by one local `onGeometryChange`.

---

## Orientation-lock removal & masonry

### Q1 — Masonry landscape-phone column policy (Phase 2 deferred here)

| Option | Description | Selected |
|--------|-------------|----------|
| Pure width rule stands (~4 cols) | No idiom clamp; consistent with Phase 2 D-20/D-22 + D-01/D-02 | ✓ |
| Clamp phones to 2 columns | Re-add an idiom-based clamp | |

**User's choice:** Pure width rule stands → **D-08**.

### Q2 — Replace the removed enablesLandscape toggle with anything?

| Option | Description | Selected |
|--------|-------------|----------|
| Silently remove the toggle | Rotation follows the device; use Control Center to lock | ✓ |
| Leave a brief note in Reading Settings | Mirror Phase 7 auto-lock redirect pattern | |

**User's choice:** Silently remove the toggle → **D-09**. Orientation-lock machinery removal captured as **D-10** (Info.plist already permits all 4 → no plist change).

---

## Side request (routed)

**Reduce `ZStack` → `.overlay`/`.background`.** Owner asked to insert this as its own task in a
proper phase. Chosen placement: **expand Phase 10 into "UI Polish"** with a new **POLISH-02**
task (added to REQUIREMENTS.md + ROADMAP.md via `/gsd-phase`). Rationale: not purely mechanical
(overlay/background size to primary content; ZStack to the union) → per-site judgment, and should
land after the Phase 5–7 UI churn to avoid double-touch. Out of Phase 5 scope.

---

## Claude's Discretion

- `DeviceType` placement (leaning `AppTools` as a pure value type).
- `DeviceClient` residual shape / async-ness of `deviceType()`.
- Per-site native tool choice (`containerRelativeFrame` vs `horizontalSizeClass` vs `ViewThatFits` vs `onGeometryChange`).
- Plan/wave decomposition of this large phase.
- Resolving the `DeviceType` `tv`-case `identifier_name` lint disable at root (drop it if the rule is off; add a `// reason:` if it's on) — never carry an unreasoned disable.

## Deferred Ideas

- Reduce `ZStack` → `.overlay`/`.background` → new POLISH-02 in an expanded Phase 10 "UI Polish".
- Rest of HYG-01 (Haptics/UserDefaults/File/Cookie/URLUtil/AppUtil clients; `DataCache.shared`) → Phase 8.
- Root privacy mask + auto-lock removal (UIARCH-04/05) → Phase 7.
