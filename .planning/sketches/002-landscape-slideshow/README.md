# Landscape slideshow alternatives — 2026-10-22

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Status: A selected by the owner under D105 and implemented in `6644232f25285fa9724d5e708b8d10f8a5e964a9`.
These A/B/C labels are new alternatives within
slideshow, independent of sketch 001's selected B sections plus C slideshow.

## Scope

Keep the current portrait slideshow, section order, gallery fields and navigation. Compare three
ways to use excess landscape width, without adding uploader, upload date, a Popular source label,
repeated metadata or fabricated statistics. The original native arrangement was C from sketch 001; D105 selects A for wide viewports.
The owner separately requests D101–D103 corrections; the preview's lower fragments reflect them.

Open `index.html?v=a` through the sketch server; the same gallery is retained when switching
alternatives. Previous/next cycle galleries; gallery and destination buttons show illustrative
navigation feedback. Width, text scale, light/dark and boundary controls support comparison.
The Frontpage fragment is deliberately one row for vertical-position comparison, not a proposal
to change the production two-row wall. Data and original SVG covers are fictional. No remote
media, analytics, dependencies or account data are used.

## Alternatives

| Variant | Treatment | Tradeoff |
|---|---|---|
| Current | Existing C arrangement approximated with a 90%-width card and 154-wide cover | Baseline for the owner's sparse-landscape observation |
| A | Cap card width at 720 and reveal neighboring, different galleries | Keeps card height and information grouping; neighboring cards are partially clipped |
| B | Enlarge cover to 212 and starting card height to 356 | Stronger artwork, but Frontpage moves down 82 |
| C | Keep cover/title/rating/language left; move existing pages/category/tags right | Maintains height, but reduces title width and spreads reading across two groups |

A was recommended and the owner subsequently selected it (D105). It uses the excess width for the
carousel and leaves the accepted information grouping intact. B makes the artwork stronger but
still leaves broad whitespace with short metadata. C distributes existing content horizontally.
At 834, all variants revert to the current C geometry. The 900-wide switch was a proposal starting point. Native implementation additionally requires
a wider-than-tall local viewport, preserving portrait on larger iPads too.

## Visual evidence

- Current landscape (image removed from repository history)
- A: narrower cards (image removed from repository history)
- B: larger cover (image removed from repository history)
- C: horizontal information groups (image removed from repository history)
- Portrait preserved (image removed from repository history)
- C with 140% text and dark appearance (image removed from repository history)

Screenshots are browser-rendered HTML proposals, not SwiftUI/device captures. Current/A/B/C are captured
at the same 1194×834 viewport and initial gallery. No image edits
or image-generation transformations were used. Native sizing, gesture, Dynamic Type and VoiceOver
behavior are verified separately in the native implementation record.

## Browser verification

`geometry.json` retains all sixteen measurements: current/A/B/C at widths 600, 834, 1194 and 1450.
No document horizontal overflow was observed. At 1194:

| Variant | Card width × height | Cover width | Frontpage heading Y |
|---|---|---|---|
| Current | 1074.59 × 274 | 154 | 506 |
| A | 720 × 274 | 154 | 506 |
| B | 1074.59 × 356 | 212 | 588 |
| C | 1074.59 × 274 | 154 | 506 |

All four variants measure 750.59 × 274 with a 154-wide cover at 834. At 600 they use 540 × 274
and a 116-wide cover. The controls were exercised: next/previous, variant switching with the same
gallery, title/detail feedback, 140% text, dark/light, and boundary annotations. The C dark/large
text capture has no overlapping visible fields. Browser warning/error log was empty. The viewport
override was reset after checks and the interactive tab was retained for owner review.

## Related implementation

D101–D103 are implemented in `3673f4670652afa91bf54aa043b8ebdac2a81801`: original B Other divider/footnotes restored,
Home Toplists uploader removed, and rating foregrounds inherited throughout the app.
See [native correction verification](../../quick/261017-pjj-implement-b-home-sections-with-selected-/FOLLOW-UP-20261022.md).


## Owner selection — D105–D106

The owner selects A and also requests a modest spacing increase within Home Toplists metadata.
[Implementation plan and verification](../../quick/261017-pjj-implement-b-home-sections-with-selected-/SLIDESHOW-A.md)
records the native 720-point cap and 8-point ranking information gap. Original comparison captures
are preserved, including the former C layout; B/C alternatives are not selected.
