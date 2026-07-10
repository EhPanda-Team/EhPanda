# DEP-07 Colorful → ColorfulX — Visual UAT

> User-facing visual verification for the gallery-card gradient. Automated build/test
> checks are deterministic (D-18); the final subjective judgment of the animated gradient
> belongs to the user during `$gsd-verify-work` (D-19). This document lists the exact checks.

---

## What changed

- **01-07 (DEP-07):** `Colorful` was updated to the official `Lakr233/Colorful.git` exact
  `1.1.1`. That release deprecated the whole `ColorfulView` struct on non-watchOS
  (*"This library hurts CPU alot, use Metal program from
  https://github.com/Lakr233/ColorfulX instead"*), leaving two live deprecation warnings
  with no in-package replacement. The residual was recorded here as a user-decision blocker.
- **01-08 (this migration):** the user chose **option (a)** — the gallery-card gradient now
  renders through **ColorfulX `6.1.0`** (Metal), the upstream-recommended successor. Colorful
  was removed from the manifest; both `Package.resolved` files pin ColorfulX exactly.
- `GalleryCardCell` still renders the gray fallback plus the animated multicolor gradient,
  driven by the same colors from `HomeReducer`; color extraction still flows through
  `LibraryClient.analyzeImageColors` (unchanged). No color state (`rawCardColors`) or
  extraction path moved.
- **Behavior mapping:** Colorful's `animated: Bool` flag became ColorfulX's `speed` binding —
  ColorfulX animates continuously via Metal, and `speed = 0` freezes it. `GalleryCardCell`
  passes `speed: animated ? animationSpeed : 0`, so only the focused dark-mode card animates,
  exactly as before. `animationSpeed` (currently `0.5`) and ColorfulX's `bias` are the
  subjective, user-tunable knobs for this UAT.

## Deprecation blocker — RESOLVED (option a)

The upstream `ColorfulView` deprecation that blocked a warning-free build in 01-07 is
resolved: migrating to ColorfulX removes the deprecated API entirely, so `HomeFeature` now
builds with **no gradient deprecation warning** (verified: clean `AppPackage-Package` build,
0 warnings). Nothing is suppressed — the deprecated package is gone.

The remaining item below is **subjective visual parity**, which is a user judgment (D-19),
not a build blocker.

---

## Visual checks

Run the app on the confirmed simulator (iPhone Air, iOS 26.5) or a device, open the **Home**
tab, and confirm each of the following. Compare against the pre-migration behavior (Colorful
`1.1.1`) — the intent is parity of the animated-gradient concept and fallback colors (D-17).
ColorfulX is a Metal renderer, so the gradient may look **smoother** than Colorful's; that is
expected and acceptable as long as the concept and colors read the same.

### 1. Dark mode — animated gradient (current card)

- [ ] Switch the system appearance to **Dark**.
- [ ] On Home, the currently-focused gallery card shows a soft, blurred, multicolor gradient
      behind the cover image and title.
- [ ] The gradient **animates** (drifts continuously — ColorfulX runs the Metal animation at
      `speed = animationSpeed`) for the focused card only.
- [ ] The gradient colors relate to the card's cover image (derived from the extracted card
      colors), and text/rating stay readable on top.

### 2. Light mode — static fallback

- [ ] Switch the system appearance to **Light**.
- [ ] Gallery cards show the gray fallback (`Color.gray.opacity(0.2)`) with the gradient
      **frozen** (light mode passes `speed = 0`; only the focused dark-mode card animates).
- [ ] Cards still look correct and readable; no flicker or missing background.

### 3. Representative gallery cards

- [ ] Scroll through several Home cards (different covers). Each card's gradient/fallback
      renders without artifacts, clipping issues, or wrong corner radius.
- [ ] Rounded corners (card `cornerRadius(15)`, cover `cornerRadius(5)`) and layout match the
      pre-migration look.

### 4. Identity reset behavior

- [ ] As focus moves between cards (or between dark/light), the gradient resets cleanly for
      the newly-focused card (`.id(currentID + animated.description)` behavior is preserved) —
      no stale animation state bleeding across cards.

### 5. Overall parity judgment (D-19)

- [ ] The animated gradient concept and fallback colors are close enough to the pre-migration
      (Colorful 1.1.1) behavior to accept. If the motion feels too fast/slow, adjust
      `animationSpeed` in `GalleryCardCell`; if the color spread feels off, adjust ColorfulX's
      `bias`. Note any subjective regressions here:

  _User notes:_

---

## Sign-off

- [ ] Dark-mode animated gradient verified.
- [ ] Light-mode fallback verified.
- [ ] Representative cards verified.
- [x] Deprecation-blocker decision recorded: **option (a) — migrated to ColorfulX (01-08).**
- [ ] DEP-07 subjective visual parity accepted (or follow-up filed).
