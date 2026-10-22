# Home cell finishes — 2026-10-22

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner decisions and execution

- D107 supersedes D106's fixed gaps: distribute the rich Toplists information through the cell's
  available height. Keep an 8-point minimum between fields; preserve intrinsic growth for long
  titles and the existing stacked accessibility arrangement.
- D108: slideshow covers preserve their aspect ratio while filling and cropping to the existing
  cover frame. Apply the shared cover's native fill mode to rich slideshow too.
- D109: match the proposal's light tag background and fine outline, accounting for the focused
  slideshow card's animated cover-derived colors in dark mode. Use semantic system background
  in light appearance and native regular material in dark appearance, with a hierarchical outline.
  Keep tag selection and font unchanged; use primary foreground in dark mode for sufficient contrast.

The ranking HStack takes its intrinsic height from the tallest content and gives its information
column that height. Flexible spacers divide the remaining space without imposing a text-height
ceiling. The accessibility arrangement keeps intrinsic sizing and minimum gaps. Tag materials
are local to Home; shared TagCloudCell styling and other tag contexts remain unchanged.

Validation planned: strict lint, clean native build, existing Home rotation/simplified-title and
accessibility regressions, plus neutral loaded-cover captures in light and dark appearances with
warm and cool cover-derived gradients. Update the review iPad in place and record the exact code
commit and evidence after completion.

## Delivered result and verification

Implementation commit: `13e688a7ad404ea45b6099fb99f478f1f187fa93` (three production Home view files).

Strict lint passes. The native single-pass gate reports three passing iPad UI tests, zero failures,
skips, expected failures or runtime warnings. These cover simplified-title changes, aligned
Frontpage rows, Other destinations, Large/AX1/AX3/AX5 cold entry and rotation, and centered slideshow
width/selection through rotation and swiping. The Toplists screenshot confirms the expandable
spacing and rating aligned at the cover's bottom. No test-only production layout hooks were added.

The subsequent neutral warm/cool captures exposed weak secondary tag text over material. The final
refinement changes only dark tag foreground to primary. All 923 source hashes were compared: only
HomeGalleryInformation.swift differs from the UI-test run, by that foreground expression. The final
source was rebuilt with zero compiler/analyzer warnings or errors and visually checked again in
light, warm dark and cool dark appearances. The three behavioral UI tests were not rerun after this
color-only refinement. Both builds have zero LLVM profile-writer diagnostics; raw runner/tool logs
are retained, including existing Xcode SDK-record and runner launch-configuration messages.

Evidence directories:

- `.build/library/home-finishes-20261022-ui/`: three-test gate, source hashes, xcresult, exported
  attachments and compiler/runtime diagnostic reports.
- `.build/library/home-finishes-20261022-final/`: final build, source hashes, explicit post-test
  delta, native loaded-cover captures and review-device launch record.

Toplists flexible spacing (image removed from repository history) is the landscape UI-test capture.
Light appearance (image removed from repository history),
warm dark palette (image removed from repository history) and
cool dark palette (image removed from repository history) are final native portrait captures.
The latter use neutral 640×360 artwork with a circular marker: slideshow crops to fill while the
circle remains circular; Frontpage continues to fit the same source. They exercise loaded artwork
and cover-derived gradients locally, not external network availability. Dark tag material visibly
adopts the palette while primary text remains clear. No exhaustive contrast-ratio or Reduce
Transparency sweep is claimed.

The installed sim-use version did not meet its skill's preflight minimum; no sim-use interaction
or upgrade followed. Native simctl provided the appearance changes and screenshots. The pose CLI
rejects iPad as non-foldable, so additional loaded-cover shots remain portrait; the UI suite already
covers landscape. No Device Hub operation was needed.

The existing review iPad was updated in place and launched with no fixture arguments or environment
keys; account/data remain intact. The task-created test iPad was shut down and deleted after evidence
capture. Preview pages and Phase 17 owner gates remain unchanged.

## Separate finding awaiting owner direction

Bright cover-derived gradients can still reduce contrast of the card's existing white title and
metadata. The warm/cool evidence demonstrates it. The agent proposed darkening the gradient while
preserving color variation; no owner choice has arrived, so no card-wide dimming or foreground
policy change is included. This is distinct from the completed tag-background correction.
