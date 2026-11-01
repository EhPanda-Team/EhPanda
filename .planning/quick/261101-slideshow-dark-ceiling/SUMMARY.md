# Readable dark-mode slideshow gradient — 2026-11-01

## Owner request

The focused Home slideshow card's dark-mode gradient, built from the cover palette, became too light
behind the card's white text on some covers. The owner asked for an algorithm that keeps the text
readable, reviewed simulated before/after cards of eight real covers, and chose the recommended
per-color design for dark mode. Light-mode cover tinting remains under discussion (the owner asked
to see the pastel mesh with its most chromatic colors pulled toward gray; rendered, not implemented).

## Cause

`ImageColors` returns a background plus three colors picked to contrast with it, falling back to
white. Every palette therefore carries a light color: thirteen sampled covers all had one at L* 62–100,
four had pure white, and the worst-case white-text contrast was 1.00:1 (secondary text 1.01–1.85:1).

## Change

- `CardGradientCeiling` (HomeFeature): colors at or below a knee (0.7 × ceiling) are unchanged; above
  it a C1 power curve compresses the range so L* 100 lands on the ceiling. Dimming scales linear
  light, keeping hue and purity, inside the sRGB gamut.
- Ceilings derive from the targets over the whole sRGB gamut, since ColorfulX blends speckles in
  CIE L*a*b* and the blends take hues the palette lacks: standard L* 32.2 (white ≥ 4.5:1, secondary
  label ≥ 3:1), Increase Contrast L* 27.1 (secondary label, which turns more opaque, ≥ 4.5:1).
  Saturated blue binds both; neutral gray alone would allow L* 41.1 and 32.3.
- `CardGradientView` limits every palette on its way to ColorfulX, so the bloom, Reduce Motion seeding
  and ColorfulX's own transitions carry the limited colors. `ImageColors` is unchanged.

The approved mockup used L* 41.1, derived on gray. Unit tests against UIKit's label colors showed
saturated colors fall below 3:1 there (pure red 2.5:1), and that per-color, chroma-aware limits let
Lab blends dip below target (2.93:1). The hue-independent ceiling is the provable form of the
approved design; on the eight real covers it gives 3.82–4.20:1 for secondary text, slightly darker
than the mockup. Comparison renders: `.capture/agent-work/slideshow-tone/dark-mode-2.png`.

## Verification

- `CardGradientCeilingTests`: 7 tests × 2 settings, all pass. Text stays readable over limited palette
  colors, grays and the gamut surface; every hue at the ceiling is readable; blue just above it is
  not (no slack); colors below the knee are untouched; white lands on the ceiling; order and
  chromaticity are kept.
- HomeFeatureTests and AppToolsTests on a new `EhPanda iPhone Air Tests` simulator (iOS 27.2): all
  pass except `GalleryCoverLayoutTests.richSlideshowGrowsForMetadataWithoutClipping(.large)`
  (height 2000 ≥ 300). That comes from the concurrent, uncommitted iPad title-alignment edit in
  `GalleryCardCell.swift` (`maxHeight: .infinity` title); the measured light-mode card never
  creates the gradient view. No compiler warnings; strict SwiftLint clean on the changed files.
- The shared DerivedData's PIFCache still pointed 24 package targets at the Xcode 27.0 swift-syntax
  prebuilt after the 27.2 prebuilt arrived, failing macro builds; it was moved aside (kept in
  `.capture/agent-work/slideshow-tone/`) and regenerated.
