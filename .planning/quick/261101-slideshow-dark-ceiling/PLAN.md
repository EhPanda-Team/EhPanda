# Readable dark-mode slideshow gradient

Owner request: the focused Home slideshow card's dark-mode ColorfulX gradient, built from the cover
palette, becomes too light behind the card's white text on some covers. Design an algorithm that
adjusts it so the text stays readable. Owner chose the recommended per-color design after reviewing
simulated before/after cards of real covers; light-mode cover tinting is still under discussion and
out of scope here.

## Approach

- Cause: `ImageColors` returns a background plus three colors picked to contrast with it (white when
  none qualifies), so nearly every palette carries a light color. Thirteen sampled covers all had a
  color at L* 62–100; four had pure white, leaving white text at 1:1 in the worst case.
- ColorfulX blends speckles as a weighted average in CIE L*a*b*, so a ceiling on each palette color's
  L* bounds every pixel of the animated gradient.
- `CardGradientCeiling` keeps colors at or below a knee (0.7 × ceiling) unchanged and compresses the
  rest with a C1 power curve that lands L* 100 exactly on the ceiling. The color is dimmed by scaling
  its linear light, which keeps hue and purity and stays in gamut.
- Targets: white text ≥ 4.5:1 and secondary label ≥ 3:1 (the light-mode gray card's secondary text
  contrast); with Increase Contrast, secondary label ≥ 4.5:1. Selected from `colorSchemeContrast`.
  Each ceiling is the highest L* at which every sRGB hue meets its targets, because ColorfulX's
  blends produce hues the palette does not contain.
- Applied in `CardGradientView` on the way to ColorfulX, so the bloom, Reduce Motion seeding and
  ColorfulX's own transitions carry the limited palette. `ImageColors` stays unchanged.

## Verification

Unit tests for text contrast against UIKit's dark label colors (standard and high contrast), knee
identity, white landing on the ceiling, lightness order and chromaticity. Build, strict lint, the
HomeFeature and AppTools test targets. One atomic commit containing only this change; the concurrent
uncommitted iPad title-alignment edits in the same file stay out of it.
