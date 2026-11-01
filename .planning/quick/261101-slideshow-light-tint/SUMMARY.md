# Cover-tinted light-mode slideshow card — 2026-11-01

## Owner request

In light mode, use the cover's colors on the Home slideshow card, but not the dark background, which
over-emphasizes the card against the pale light-mode page. From rendered comparisons of real covers
the owner picked the pastel mesh, asked for its colors farthest from gray to move toward gray, and
asked twice more for paler versions before choosing option 2f (OKLCH chroma ceiling 0.008).

## Change

- `GalleryCardCell`: the focused card shows the cover-palette ColorfulX gradient in both appearances;
  unselected cards keep the gray fallback, now `Color.homeCardFallback`. Cover-color analysis runs in
  both appearances, so the retained image result and its replay on an appearance change are removed.
- `CardGradientTint` (HomeFeature): each palette color keeps its hue and opacity; chroma above half the
  ceiling is softly compressed onto 0.008 (colors already near gray are untouched); lightness is set so
  the color sits as far from the white page, in OKLab, as the gray fallback (D ≈ 0.0675). Chroma is
  paid for with lightness, so every tint has the fallback's weight and neutrals land on a neutral gray
  of that weight. All hues stay inside the sRGB gamut.
- `CardGradientView` tones every palette on its way to ColorfulX: `CardGradientCeiling` in dark mode,
  `CardGradientTint` in light mode. The knee curve both use is the shared `SoftCeiling`.
- Capture readiness: Home now waits for the current card's colors in both appearances.
- Tests: shared color support (`CardColorTestSupport.swift`) for both tone suites; the dark suite is
  rewritten on it unchanged in substance.

Text contrast is not held exactly: WCAG luminance follows OKLab lightness only closely once chroma
enters, and secondary text composites the background's RGB. A sweep over every hue and chroma up to
the ceiling finds the largest drop against the gray card at 0.146% (primary text, hue ≈ 354°);
secondary text drops at most 0.12%. Light secondary text stays at ≈ 3.18:1, as on the gray card.

## Verification

- `CardGradientTintTests`: 9 tests (contrast under standard and Increase Contrast) pass: OKLab
  reference values, the gray card's weight, the chroma ceiling, identity near gray, hue, neutrals,
  gamut, opacity, and text contrast within 0.2% of the gray card's. `CardGradientCeilingTests` pass.
- HomeFeatureTests, AppFeatureTests and AppToolsTests on `EhPanda iPhone Air Tests` (iOS 27.2): 367
  pass, 1 fails: `GalleryCoverLayoutTests.richSlideshowGrowsForMetadataWithoutClipping(.large)`, from
  the concurrent, uncommitted iPad title-alignment edit (as in the dark-mode task). The Reduce Motion
  source census is unchanged. No compiler warnings; strict SwiftLint clean on the changed files.
- The marketing Home capture on the test simulator reported ready but never held still: that run used
  parallel clones without the native runner's fixed status bar. The owner chose to review the card
  directly in the simulator instead; the app runs there in light mode on live data.
- Light-mode Home visual baselines and marketing captures change with this commit; none are promoted.
  With Reduce Motion on, the light gradient freezes like the dark one.

## Revision: option 2a — 2026-11-01

After viewing 2f in the simulator, the owner asked to go back to option 2a (chroma ceiling 0.035).
At that chroma about 40% of hues (light reds, blues, purples and pinks) leave the sRGB gamut on the
weight curve, the earliest near chroma 0.029 (hue ≈ 270°). The render reduced chroma at fixed
lightness; the app instead bisects along the weight curve for the most chroma that fits, so every
tint still carries the gray card's weight. `OKLab` exposes its linear components (`SIMD3<Double>`)
and an `isInGamut` check for this. A new test shows pure blue keeps less than the ceiling with one
component on the gamut's edge. The contrast bound is unchanged: the largest drop stays 0.147% near
chroma 0.009, because more chroma also makes the tint lighter.
