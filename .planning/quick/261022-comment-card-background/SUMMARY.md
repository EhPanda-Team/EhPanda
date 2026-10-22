# Comment preview background repair — D110

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Implementation: `b15f385ee83eda5c5fdb7290ae08a1e09a056b0a`.

## Cause and repair

The user reports occasional square comment cards in the horizontal Detail Comments strip.
The original modifier order paints the content background before assigning the card's fixed
width. A header that falls back to stacked author/metadata, paired with a short body, can have
an intrinsic width smaller than the allocated card. Its rectangular background stays centered
inside the wider frame; the rounded clip at the frame's outer edges does not intersect those
background corners. This is content-dependent layout, not an intermittent renderer failure.

The native reproduction confirms the same narrow square background. Long comments also expose
unfilled side edges at AX3/AX5. The fix lets content fill the available width with top-leading
alignment, establishes the existing final card frame, then paints its background and applies the
existing 15-point rounded clip. Card dimensions, font scaling, header reflow, accessibility
semantics and the containing strip's drawing group remain intact.

## Verification

- Before: the two new rendering tests fail on missing side-edge background coverage. Their native
  screenshots reproduce the reported square card. The seven capture-fixture tests pass.
- After: the final single-pass run passes all nine selected test identities, with zero failures,
  skips, expected failures or runtime warnings; build/compiler/analyzer and strict lint are clean.
- The two rendering cases cover short body/stacked header and long body/short author, in light and
  dark at Large, AX1, AX3 and AX5: 16 native renders. Pixel assertions check the four straight
  edges are filled and all four rounded corners remain transparent.
- The final source-hash manifest matches the committed source tree. Evidence is retained under
  `.build/library/comment-card-final/`, including xcresult, build/test summaries, source hashes,
  exact enumeration and all render attachments. Earlier failure records remain under
  `.build/library/comment-card-before/`, `comment-card-reproduction/` and `comment-card-fixed/`.

These are native SwiftUI component renders on the test iPad runtime, not full-screen interaction
captures. This scoped change does not claim a fresh full Detail scroll/navigation or VoiceOver
sweep. The user review iPad was updated in place and launched normally with all fixture environment
keys removed; account/data remain intact. The task-created test simulator was deleted afterward.

## Verification infrastructure repairs

The initial feature build exposed a pre-existing missing required orientation argument in a probe
fixture after a local protocol dependency changed. `e76ae8a400337d2d8fdaa81298c0134ad3581289` explicitly
sets portrait in that fixture; no application behavior changes. The affected seven test identities
are included in verification.

The first post-fix native test run passed, but the verifier rejected XCTest result URLs because they
omit empty argument parentheses that enumeration and Swift Testing retain. `2812de17c41edee8b3ed224dce9ca147f18dad0c`
normalizes this method spelling while preserving exact-set and duplicate checks. The final run
reruns the complete nine-test selection with the corrected verifier and matching source hashes.
No failing check was suppressed or relaxed. Raw Xcode SDK-record messages remain in build/test logs.

## Native comparisons

| Appearance | Before | After |
|---|---|---|
| Dark, Large | Narrow square background (image removed from repository history) | Full rounded card (image removed from repository history) |
| Light, Large | Before (image removed from repository history) | After (image removed from repository history) |
| Dark, AX5 | Before (image removed from repository history) | After (image removed from repository history) |

All examples use neutral synthetic comment text. No owner account/gallery content is copied into
the repository. Phase 17 gates and screenshot baselines remain unchanged.
