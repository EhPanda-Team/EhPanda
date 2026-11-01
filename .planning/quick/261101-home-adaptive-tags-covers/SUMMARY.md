# Adaptive Home tags and cover sizing

Implemented the owner's continuation of the Home pose review. Compact slideshow content uses native
vertical ViewThatFits: the tagged candidate measures the entire title at its intrinsic height, plus
metadata and tags. It is selected only when that complete content fits the existing cover-height
budget. Otherwise tags disappear and the prior top-aligned title/metadata layout remains. Card height,
fonts, column ordering and the rich iPad presentation remain unchanged. Tag appearance is shared
with the existing rich slideshow.

Frontpage receives a cover-height ceiling from the same Home viewport and cover metrics used by its
slideshow: compact arrangements cap at the scaled homeCompact cover; split panes cap at the scaled
hero cover and the slideshow's constrained-height budget. Covers already below the ceiling retain
size. The cap reaches both the artwork and its enclosing cell width, including loading content.

Validation: strict lint for all seven changed Swift files; clean UITests and FeatureTests builds;
27 passing focused cases across nine test definitions, zero runtime warnings, in
`/tmp/ehpanda-home-fit-tests.xcresult`. Four new cases verify Frontpage/slideshow cover-width equality
for hero and homeCompact roles at Large and AX5. Final source rebuild is clean.

Native visual review covers Duo portrait (tags present, 165-point matching covers), closed portrait
(tags absent with the complete title preserved), and open/half-open landscape (150-point matching
covers). Landscape Stage Manager and a wide free window also show the reduced compact Frontpage
covers and fitting tags. The wide-window accessibility snapshot reports the background Settings
window, so its final check is visual rather than an asserted foreground accessibility measurement.
Screenshots are in `.capture/home-adaptive-review/`; sideways iPad frames have upright copies.

No commit, final screenshot generation, approved baseline or rendering-pin change was made. Existing
approved translation changes remain uncommitted and preserved. This review is pending owner feedback.

## Maximum aspect ratio continuation

The owner selected a regular-card crop as the maximum width/height proportion. The reference is
approximately 751 × 274 points (2.74:1). `HomeSlideshowSizing` now caps preferred carousel widths
against the layout's minimum rendered height. Compact cards use the scaled cover plus padding;
regular cards use their existing minimum content height plus padding; split cards also respect the
viewport height ceiling. The old 900-point/orientation trigger is removed. Taller text remains free
to grow, so this is a maximum ratio, not a forced aspect-ratio frame. Carousel centering and snapping
use the same constrained width. Heights, typography and cover roles are preserved.

Both build-for-testing plans and strict lint pass without compiler warnings. Focused layout testing
passes 39 cases in 11 definitions, with zero skips, failures or runtime warnings
(`/tmp/ehpanda-home-aspect-tests.xcresult`). New tests measure rendered compact/regular cards at
Large, AX1, AX3 and AX5 across six widths, plus constrained split cards.

Native verification: iPad full-screen landscape 751 × 274; a 1013 × 533 native window displays
a centered 562 × 205 compact card with fitting tags. iPhone portrait remains 362 × 205 in a
402 × 874 viewport, capture-ready with no pending images or unknown requests. Native evidence is
in `.capture/home-aspect-review/`. Xcode Resize Mode is unsupported by this iPad runtime; validation
used its native Windowed Apps mode. The temporary iPad is removed after testing; the owner's
standard iPhone 18 Pro Review simulator remains running with the updated app. No commit made.

## Native top-bar refresh experiment — not retained

The owner requested trying native same-row refresh beside the iPad top tab bar. Three isolated
variations were built and installed on an iPad Pro 11-inch simulator running iPadOS 27.2:
semantic primaryAction placement; removing the single-column HStack wrapper; browser toolbar role.
All retained the same measured positions: Home tab frame y=36, height=36; Reload frame y=100,
height=36. None achieved same-row integration. All experiment source edits were restored; the
previous aspect-ratio and tag/cover changes are preserved. This result does not establish that
every native approach is impossible. Broader navigation restructuring and alternate refresh UX
were not implemented. Evidence is in `.capture/home-toolbar-review/`. The temporary iPad is deleted;
the owner's standard iPhone remains on the previously verified aspect-ratio build.

## Owner-requested commit — 2026-11-01

The owner requested committing the outstanding work. Implementation committed as `ecdc11f68`;
this supersedes the earlier uncommitted-status notes. Signature verified and both timestamps use
the repository convention. Local review evidence remains outside Git.

## iPad slideshow title alignment — 2026-11-01

Owner requested applying the compact title's maximum-height and top alignment to regular iPad
cards. The regular title now uses `maxHeight: .infinity` with `.topLeading`, without the former
two-line reservation or vertical intrinsic-size override. Metadata retains intrinsic height so
the title receives the remaining space. Existing title typography and card sizing are preserved.

Validation: simulator build-for-testing passes with no compiler warnings or errors; strict
SwiftLint reports zero violations for GalleryCardCell. No new screenshots or runtime layout tests
were run for this modifier-only change. No baseline update or commit made.

Follow-up native capture: iPad Pro full-screen portrait and landscape show the updated top-aligned
title and lower metadata. Both captures report ready, with no blockers or unknown requests.
Light-mode PNGs and accessibility evidence are retained in
`$HOME/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/ipad-title-review/`.

## Owner-requested title and Toplists commit — 2026-11-01

Toplists rating stars now use footnote, one semantic step below their inherited subheadline;
rating digits retain subheadline and one-decimal formatting. HomeGalleryRating accepts an optional
icon font so the slideshow keeps its inherited icon appearance. Dynamic Type remains native.

The owner requested committing this change with the outstanding iPad title alignment and records.
The separate slideshow color commits are preserved. Final simulator build-for-testing passes
without compiler warnings or errors, and strict SwiftLint passes for all three changed Swift files.
No additional runtime tests or captures were needed for the star-only typography adjustment.
This commit supersedes the uncommitted-status notes for the iPad title continuation above.

## Tighter Toplists metadata — 2026-11-01

Owner requested matching the rating star to the pages font and reducing metadata gaps. The
star now uses caption; category/pages/rating sit in a 4-point-spaced stack, with the remaining
flexible space above that group. Rating digits and category keep their prior font. Simulator
build and strict lint pass. Native iPad portrait capture was inspected and diagnostics are ready
with no blockers or unknown requests. Evidence is under
`$HOME/.codex/visualizations/2026/10/31/01a192a6-7c25-7c91-b3a7-e39878397f4c/toplists-spacing-review/`.
Changes await owner review and are uncommitted.
