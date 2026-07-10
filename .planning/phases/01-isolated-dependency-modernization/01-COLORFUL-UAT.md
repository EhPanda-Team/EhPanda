# DEP-07 Colorful → ColorfulX — Visual UAT

> User-facing visual verification for the gallery-card gradient. Automated build/test
> checks are deterministic (D-18); the final subjective judgment of the animated gradient
> belongs to the user during `$gsd-verify-work` (D-19). This document lists the exact checks
> and records their result.

---

## Verification result (verify-work, 2026-07-11) — PASS

Verified live on the simulator (iPhone Air, iOS 26.5). The initial ColorfulX migration was a
mechanical API swap that did **not** mirror Colorful's behavior (regression **G-01-1**, see
`01-UAT.md`): every card and light mode painted a full opaque gradient. It was fixed inline in
`GalleryCardCell.swift` and re-verified by the user. The checks below describe the **fixed**
behavior.

**Root cause & fix (G-01-1):** Colorful drew 32 translucent (opacity 0.5) blurred circles and
effectively rendered only the focused *animated* card; ColorfulX (`AnimatedMulticolorGradientView`)
always paints a full-bleed **opaque** Metal gradient, and `speed = 0` only freezes motion. The fix:
1. Gate `ColorfulView` on `animated` — only the focused card in **dark mode** paints; unselected
   cards and **all** of light mode show only the `Color.gray.opacity(0.2)` fallback.
2. Skip `analyzeImageColors` in light mode (view-layer gate on `colorScheme`), re-triggered on
   switch to dark so the focused card's colors compute on demand.
3. A neutral seed + real palette on appear makes ColorfulX **lerp** the colors in (a gradual
   *bloom* over `transitionSpeed`, user-tuned to `6`) instead of snapping to full intensity.

---

## What changed

- **01-07 (DEP-07):** `Colorful` was updated to the official `Lakr233/Colorful.git` exact
  `1.1.1`. That release deprecated the whole `ColorfulView` struct on non-watchOS
  (*"This library hurts CPU alot, use Metal program from
  https://github.com/Lakr233/ColorfulX instead"*), leaving two live deprecation warnings
  with no in-package replacement. The residual was recorded here as a user-decision blocker.
- **01-08:** the user chose **option (a)** — the gallery-card gradient now renders through
  **ColorfulX `6.1.0`** (Metal), the upstream-recommended successor. Colorful was removed from
  the manifest; both `Package.resolved` files pin ColorfulX exactly.
- `GalleryCardCell` still renders the gray fallback plus the animated multicolor gradient,
  driven by the same colors from `HomeReducer`; color extraction still flows through
  `LibraryClient.analyzeImageColors` (now backed by the local `ImageColors` module). No color
  state (`rawCardColors`) or extraction path moved.
- **Behavior mapping (fixed, G-01-1):** Colorful's `animated: Bool` flag now gates whether the
  `ColorfulView` is *present at all* (not just its `speed`), reproducing Colorful's effective
  "only the focused card renders" behavior. The focused dark-mode card animates at
  `speed = animationSpeed` (`0.5`) and blooms in over `transitionSpeed` (`6`); everything else is
  the bare gray fallback. `animationSpeed`, `transitionSpeed`, and ColorfulX's `bias` are the
  subjective, user-tunable knobs.

## Deprecation blocker — RESOLVED (option a)

The upstream `ColorfulView` deprecation that blocked a warning-free build in 01-07 is resolved:
migrating to ColorfulX removes the deprecated API entirely, so `HomeFeature` now builds with
**no gradient deprecation warning** (verified: clean `AppPackage-Package` build, 0 warnings).
Nothing is suppressed — the deprecated package is gone.

---

## Visual checks

Run the app on the confirmed simulator (iPhone Air, iOS 26.5) or a device, open the **Home**
tab, and confirm each of the following. ColorfulX is a Metal renderer, so the focused card's
gradient looks **smoother** than Colorful's; that is expected and acceptable (D-17).

### 1. Dark mode — animated gradient (current card)

- [x] Switch the system appearance to **Dark**.
- [x] The currently-focused gallery card shows a soft, blurred, multicolor gradient behind the
      cover image and title, and it **blooms in gradually** (not a sudden pop) as the card
      becomes current.
- [x] The gradient **animates** (drifts continuously) for the focused card only.
- [x] The gradient colors relate to the card's cover image (from the extracted card colors),
      and text/rating stay readable on top.
result: pass

### 2. Light mode — no gradient (fixed behavior)

- [x] Switch the system appearance to **Light**.
- [x] Gallery cards show **only** the gray fallback (`Color.gray.opacity(0.2)`) — **no** ColorfulX
      gradient renders in light mode (the view is gated on `animated`, which is dark-mode only),
      and no color computation runs.
- [x] Switching **back to dark** recomputes the focused card's colors and blooms the gradient in.
- [x] Cards look correct and readable; no flicker or missing background.
result: pass

### 3. Representative gallery cards

- [x] Swipe through several Home cards (different covers). Only the centered card shows a
      gradient; unselected/peeking cards show just the gray fallback (no gradient).
- [x] Each focused card renders without artifacts; rounded corners (card `cornerRadius(15)`,
      cover `cornerRadius(5)`) and layout match the pre-migration look.
result: pass

### 4. Focus-change reset behavior

- [x] As focus moves between cards, the previous card's gradient is removed and the newly-focused
      card blooms its own gradient in cleanly — no stale animation state bleeding across cards.
      (Mechanism: the `if animated` gate + a fresh-`@State` `CardGradientView` per focus, replacing
      the former `.id(currentID + animated.description)`.)
result: pass

### 5. Overall parity judgment (D-19)

- [x] The animated-gradient concept and fallback colors reproduce the pre-migration
      (Colorful 1.1.1) behavior — only the focused dark-mode card shows the gradient, it blooms in
      gradually, and unselected/light-mode cards show just the gray fallback.
result: pass

  _User notes:_ Accepted. `transitionSpeed` tuned to `6` for the bloom; behavior verified live
  (dark focus + animation, side-card suppression, light-mode absence, dark↔light toggle).

---

## Sign-off

- [x] Dark-mode animated gradient verified.
- [x] Light-mode fallback (no gradient) verified.
- [x] Representative cards verified.
- [x] Deprecation-blocker decision recorded: **option (a) — migrated to ColorfulX (01-08).**
- [x] DEP-07 subjective visual parity accepted (regression G-01-1 fixed and re-verified).
