# Cover review revision

Owner requirements supersede the initial viewport-cap plan:

| Viewport | Portrait maximum | Landscape maximum |
| --- | --- | --- |
| Small | 70% | 80% |
| Large | 50% | 40% |

Use the actual Home scroll viewport. A large viewport has regular horizontal size class,
width at least 744 points and height at least 600 points; smaller tablet windows adopt
small-viewport rules. Orientation follows the viewport aspect ratio.

Keep slideshow title and rating in one VStack at every Dynamic Type size, retaining
system text scaling and the compact numeric rating fallback. Top-align Toplists periods.
Thumbnail lists retain width/text-driven columns, with a floor of three in large landscape
viewports and two otherwise. The same viewport definition applies to both surfaces.

Investigate the existing iPad AX5 detail capture before changing cover metrics: current
standard/hero ceilings are 150/187.5 points, while the supplied capture shows larger
background list artwork. Rebuild and compare the same gallery in list and detail.

Implemented in `55c840b4`.

## Verification

- App build succeeded. SwiftLint and `git diff --check` passed.
- All five Home cover/viewport test methods passed, including all text sizes for role
  hierarchy, eight card title/width cases and six height-budget cases.
- All seven masonry test methods passed, including the new large-landscape AX5 floor.
- Added a two-line stacked candidate before the narrow horizontal fallback: a small portrait
  AX5 card can use the available height to keep a readable text column. Its actual iPhone
  screenshot measures 426 points; the iPad portrait AX5 card measures 356 points.
- Thirty native screenshots cover five affected views in six configurations: iPhone portrait,
  iPad portrait, iPad landscape, each at Large and AX5. Every PNG passed CRC and decompression
  checks; the comparison-page JavaScript passed syntax validation.
- Current same-gallery detail screenshots show a 188-point AX5 artwork height (187.5-point
  hero rounded to pixels), versus the standard 150-point list ceiling. The old oversized
  background list capture does not represent the current implementation. Cover metrics were
  therefore left unchanged.
- Large landscape AX5 Frontpage renders three columns. Toplists period headings share the
  same y coordinate at Large and AX5 in the recorded comparisons.
- Capture output is in `$HOME/.codex/visualizations/2026/09/07/01a07ac6-2537-7ac2-9d9e-27cf7712377a/cover-revision/`.
  The prior comparison page is marked historical and links to the revision. Other views in
  that earlier collection were not recaptured for this revision.
- Actual resized-window capture was not accepted into the formal comparison: a gesture moved
  the landscape window offscreen. Window classification is covered by narrow/short viewport
  tests. Full Screen Apps was temporarily used to recover full-window landscape capture;
  the original Windowed Apps preference is restored afterward.
- No PDF, injected gallery data, altered screenshot layout, or fabricated populated states.

