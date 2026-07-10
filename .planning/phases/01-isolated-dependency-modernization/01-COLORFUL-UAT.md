# DEP-07 Colorful — Visual UAT

> User-facing visual verification for the Colorful update (DEP-07). Automated build/test
> checks are deterministic (D-18); the final subjective judgment of the animated gradient
> belongs to the user during `$gsd-verify-work` (D-19). This document lists the exact checks.

---

## What changed

- `Colorful` was updated from `1.0.1` to the research-approved latest official tag `1.1.1`
  (official remote `https://github.com/Lakr233/Colorful.git`, pinned `exact: "1.1.1"`).
- `AppPackage/Package.resolved` (and the app workspace mirror) now record that pin
  (revision `d673ab1b5aaaf2f968fdd73830e318fd4c6910f3`, the peeled commit of the annotated
  `1.1.1` tag).
- `GalleryCardCell` still renders the gray fallback plus the animated multicolor
  `ColorfulView` gradient, driven by the same colors from `HomeReducer`; color extraction
  still flows through `LibraryClient.analyzeImageColors` (unchanged). No color state
  (`rawCardColors`) or extraction path was moved.

## Known blocker: upstream deprecation (not suppressed)

`ColorfulView` is marked deprecated on non-watchOS in Colorful 1.1.x:

```
'ColorfulView' is deprecated: This library hurts CPU alot,
use Metal program from https://github.com/Lakr233/ColorfulX instead.
```

The whole `ColorfulView` struct is deprecated and the package ships no non-deprecated view
API, so building `HomeFeature` emits two deprecation warnings
(`GalleryCardCell.swift:45` and `:72`). The build still succeeds and the gradient renders as
before. Plan 01-07 forbids satisfying DEP-07 through another gradient path or deleting
Colorful, so a fully warning-free adoption is out of this plan's scope; the warning is
documented here rather than suppressed.

**User decision at verification** — pick one:

- (a) Migrate the gallery gradient to the upstream-recommended ColorfulX (Metal) package.
- (b) Implement an app-owned SwiftUI gradient view reproducing the same animated concept.
- (c) Accept the deprecation notice and keep Colorful 1.1.1 as-is.

Options (a) and (b) remove the warning but are out of scope for the
isolated-dependency-modernization phase; both are logged in `deferred-items.md`.

---

## Visual checks

Run the app on the confirmed simulator (iPhone Air, iOS 26.5) or a device, open the **Home**
tab, and confirm each of the following. Compare against the pre-update behavior (Colorful
1.0.1) — the intent is parity of the animated-gradient concept and fallback colors (D-17).

### 1. Dark mode — animated gradient (current card)

- [ ] Switch the system appearance to **Dark**.
- [ ] On Home, the currently-focused gallery card shows a soft, blurred, multicolor gradient
      behind the cover image and title.
- [ ] The gradient **animates** (colors drift/re-randomize roughly every few seconds) for the
      focused card only.
- [ ] The gradient colors relate to the card's cover image (derived from the extracted card
      colors), and text/rating stay readable on top.

### 2. Light mode — static fallback

- [ ] Switch the system appearance to **Light**.
- [ ] Gallery cards show the gray fallback (`Color.gray.opacity(0.2)`) with the gradient
      **not animating** (light mode is intentionally non-animated: `animated` is only true in
      dark mode for the current card).
- [ ] Cards still look correct and readable; no flicker or missing background.

### 3. Representative gallery cards

- [ ] Scroll through several Home cards (different covers). Each card's gradient/fallback
      renders without artifacts, clipping issues, or wrong corner radius.
- [ ] Rounded corners (card `cornerRadius(15)`, cover `cornerRadius(5)`) and layout match the
      pre-update look.

### 4. Identity reset behavior

- [ ] As focus moves between cards (or between dark/light), the gradient resets cleanly for
      the newly-focused card (`.id(currentID + animated.description)` behavior) — no stale
      animation state bleeding across cards.

### 5. Overall parity judgment (D-19)

- [ ] The animated gradient concept and fallback colors are close enough to the pre-phase
      (Colorful 1.0.1) behavior to accept. Note any subjective regressions here:

  _User notes:_

---

## Sign-off

- [ ] Dark-mode animated gradient verified.
- [ ] Light-mode fallback verified.
- [ ] Representative cards verified.
- [ ] Deprecation-blocker decision recorded (a / b / c above).
- [ ] DEP-07 subjective visual parity accepted (or follow-up filed).
