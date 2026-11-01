# Cover-tinted light-mode slideshow card

Owner request: in light mode, use the cover's colors on the Home slideshow card without reusing the
dark background, which over-emphasizes the card against the pale light-mode page. After rendered
comparisons of real covers, the owner chose the pastel mesh with its most chromatic colors pulled
toward gray, at the palest of the shown steps (option 2f, chroma ceiling 0.008).

## Approach

- The focused card shows the cover-palette ColorfulX gradient in both appearances; unselected cards
  keep the gray fallback, as in dark mode. Cover-color analysis therefore runs in light mode too, and
  the deferred-analysis replay on an appearance change is no longer needed.
- `CardGradientTint` maps each palette color in OKLCH: chroma above half the ceiling is compressed
  onto the 0.008 ceiling (colors already near gray keep theirs), hue and opacity are kept, and the
  lightness is set so the color sits as far from the white page, in OKLab, as the gray fallback
  (`Color.homeCardFallback`, gray at 20% over white). Chroma is paid for with lightness, so every
  tint carries the fallback's weight and the card's text keeps the fallback's contrast to within
  0.2% (WCAG luminance follows OKLab lightness closely at this chroma).
- `CardGradientView` tones every palette on its way to ColorfulX: `CardGradientCeiling` in dark mode,
  `CardGradientTint` in light mode. The knee curve both use moves into a shared `SoftCeiling`.
- Capture readiness: Home waits for the current card's colors in both appearances.

## Verification

Unit tests for OKLab reference values, the fallback's weight, the chroma ceiling, identity near gray,
hue, neutrals, gamut and opacity, and light-mode text contrast against UIKit's label colors (standard
and high contrast). Shared color test support for both tone tests. Build, strict lint, HomeFeature,
AppFeature and AppTools tests; simulator captures of light and dark Home for owner confirmation. One
atomic commit containing only this change; the concurrent uncommitted iPad title-alignment edits and
their planning records stay out of it. Light-mode Home visual baselines change and are not promoted.
