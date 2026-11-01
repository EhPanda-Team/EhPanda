# Website screenshot review — in progress

Private local review page: `http://127.0.0.1:8774/` (opened beside chat). Target: 192 native
1260 × 2736 iPhone Air portrait screenshots, eight screens × six locales × two themes × two sets.
Notes and review status persist in the browser and can be exported. Updated image hashes require
fresh approval. Nothing has been published or accepted as a marketing baseline.

## Owner revisions implemented

- Nonexplicit Home center: 1892938, showing tags.
- Nonexplicit Comments: 4290276, scrolled past the long uploader index to show multiple comments.
- Filters: default categories, superseding the earlier Non-H-only selection requirement.
- Chinese Non-H: 全年齡 / 全年龄.
- Detail rating control: enabled appearance only in the DEBUG Detail capture route; authentication
  and other logged-out controls are unchanged.
- Adult selection corrected to the owner's final 2026-10-31 list of 31 galleries. Earlier adult
  captures were withdrawn. New Detail/Comments use 4197368 (13 comments), with Comments scrolled beyond the link index to
  ordinary comment 8664741; reader/translation use
  the approved 4223235. The latest adult fixture was exported entirely from saved archive bytes.

## Capture support

The fixture format now supports optional `detailGallery` and `commentsGallery`, independently of
reader pages. Their genuine preview assets remain strictly validated. Legacy selections retain
existing behavior. This avoids acquiring adult book pages just to show their Detail/Comments.

Downloads cold captures exposed delayed Favorites initialization replacing an explicit Downloads
selection. Default selection is now set synchronously, stale initialization is ignored, and
Favorites index synchronization cannot switch a selected Downloads page back to Favorites.
Two regression tests cover the stale actions; the original initial-entry test verifies atomic setup.

## Verification

- Final isolated ARM simulator build passed. Library navigation, capture-scene and screen
  diagnostics suites: 41 tests passed, zero failures or skips, including the navigation and
  requested-preview regressions.
- Fixture acquisition/validation suite: 53 tests passed, including independent detail/comment
  selection without unrelated book-page acquisition.
- Strict SwiftLint passed for changed Swift files.
- Review browser navigation, notes persistence, and JavaScript checks passed.
- Native-capture contract tests: 35 passed; shared contract tests: 44 passed.
- Native Downloads capture passed after the navigation fix.
- All 192 screenshots passed native dimensions, SHA-256, byte count, decoded image, readiness,
  locale/theme, scene/gallery selection and image-settlement checks. No failed or pending
  coordinates remain. Every adult Home matches the exact 31 IDs in the final owner list.
- Comments positioning and translation records were verified. Representative light/dark
  screenshots in both sets were visually inspected, including enabled Detail rating and
  replaced Live Text lettering.

## Delivery

All 192 coordinates are ready in the local review page. Existing notes are retained and changed
images require fresh review. Owner review remains pending. The local server and review artifacts
are retained. All five task-created simulators and their test clones were removed; the existing
user simulator was preserved. Final regression evidence is `website-final-regressions.xcresult`; the final ARM
simulator build is in the temporary `ehpanda-website-preview-build` directory.

## Lazy preview readiness

The final adult Detail gallery has a long lazy preview row. Capture readiness previously demanded
every archived preview atlas, even those never requested by offscreen thumbnails. The Detail
check now waits for metadata and its cover, while the shared delivered-image check still blocks
on every requested image until it is cached. The regression verifies both an unrequested
offscreen preview and a requested-but-not-cached preview; no image failures are ignored.

## Slideshow tag selection — owner continuation

The owner confirmed excluding the site's dashed/dotted tags and ordering by this gallery's
weighted-vote tier, with source order retained within a tier. Only solid (100+ power) tags qualify.
The parser now retains strong/active/weak independently of the user's own up/down vote. The
optional field decodes older cached records without fabricating strength; unknowns are omitted
from slideshow chips until a normal refresh supplies the metadata.

Slideshow selection excludes language/category, normalized duplicates and names already inside
balanced title brackets, including nested and common CJK/full-width brackets. Eligible artist/group
tags precede other tags; all remaining eligible tags share the strong tier and keep source order.
The cap remains three. The current nonexplicit hero consequently has no chips: both creator names
are already in its title. The selected gallery itself is unchanged.

Final focused run: 16 tests passed, zero failures/skips, with parameterized bracket/strength cases,
public list/detail parsing and legacy-cache decoding. Build and strict lint passed. Evidence:
`slideshow-tag-focused-tests.xcresult`.

A broader run also exposed the existing `richSlideshowGrowsForMetadataWithoutClipping` height
expectation at standard text size: it measures 2000 rather than <300. That case uses no tags and
the rich-card layout is untouched by this continuation. The failure remains recorded in
`slideshow-tag-tests.xcresult` for separate layout investigation; its assertion was not weakened.
All 24 Home screenshots have been refreshed across both groups, six locales and both themes.
The other 168 screenshots are unchanged. All 192 entries passed the final hash, dimensions,
readiness, stable-frame and fixture-provenance audit. Prior Home images and diagnostics are
archived alongside each entry; review notes remain available.

## All center candidates — ready for owner selection

Owner requested 31 galleries in each of two sets, in both themes (124 screenshots). A separate
local slideshow review pairs native English iPhone Air light/dark captures and records one
candidate per set. The existing 192-screen review stays intact. Each candidate uses a validated,
provisional content-addressed fixture permutation: swap its Home position with the current hero
center, preserve all 31 members and all saved source assets. No app source changes are required.

The review page passes desktop/mobile checks, including both groups' 31 pairs, search, independent
persistent choices, JSON export, original-image loading and no horizontal overflow or JavaScript
errors. All 124 native images pass the final audit: exact matrix membership, centered title identity,
fixture version, theme, readiness, stable consecutive frames, PNG dimensions and checksums.
Rendered status bars are identical within each theme; accessibility exposes the real clock despite
the rendered 9:41 override. The two initial Settings breadcrumbs were removed by recapture.
Two verified ZIP archives each contain 62 originals and an ID/title index. Original website review
also still passes its 192-image audit. Owner subsequently selected nonexplicit 4284679 and explicit 1320054; see the Frontpage continuation below.

## Approved centers and random Frontpage arrangements — ready

The owner selected nonexplicit candidate 21 / gallery 4284679 and explicit candidate 18 /
gallery 1320054. The local active capture pointers now reference those center permutations;
this confirms the centers only, not the entire provisional arrangement or publication.

Prepared ten randomly ordered Frontpage versions per group, twenty native light-mode English
iPhone Air screenshots total. Each has the approved center fixed and excluded from its sixteen
Frontpage entries. All thirty-one original Home members remain represented exactly once across
the hero, Frontpage and Toplists. Random seed 17564956245193933813 and each complete order are
retained in the local review manifest. Earlier screenshot matrices remain available.

The new review page shows full Home or a Frontpage-focused viewport, all sixteen ordered gallery
names per version, one persistent choice per group, original PNG access and JSON choice export.
All twenty screenshots pass centered-gallery, visible first-six ordering, membership, metadata,
image-readiness, stable-frame, dimensions, checksum and status-bar consistency checks. Browser
checks pass for both ten-version groups, approved center labels, complete lists, independent
persistent selections, export, native image loading, focus mode and mobile layout. Capture waits
for both lazy Frontpage rows, as data readiness can precede the second row's appearance.

The owner's Frontpage version choices remain pending. No marketing baseline or publication
approval is implied.

## Frontpage choices applied to capture fixtures

Owner approved nonexplicit version 05 and the six custom explicit galleries recorded in the plan.
Version 09's bottom-right identity was verified from its native accessibility geometry as 3002185.
The explicit six are ordered left-to-right across the upper row, then the lower row, matching the
owner's list. The other Home slots remain provisional; all original 31 members are retained exactly
once and each center remains excluded from Frontpage. Both selected fixtures pass validation.
Active local capture pointers and the review's owner-choice record now contain these choices.
The existing random screenshots remain historical evidence; the custom adult composition has not
yet been recaptured. Toplists choices and final screenshot regeneration remain outstanding.

## Explicit Frontpage shuffle 01

At the owner's request, keep 3002185 bottom-right and shuffle the other five selected galleries.
New reading order is 4281489, 4286547, 4294199 / 3760512, 4291491, 3002185. All five other positions
changed. The center and nonexplicit version 05 remain unchanged. The new content-addressed fixture
validates, and one native light-mode Home screenshot passes image/stability checks and the exact
visible-grid order assertion, including 3002185 at the maximum visible column and lower row.
The local review links to the new screenshot; this arrangement awaits owner visual review.

## Explicit Frontpage arrangement 02

Owner specifies upper row Kutsukake / Bondage vol. 2 / Pirates Cat and lower row
Malfoid / asdxz / 3002185. The selected fixture is updated and validates. A new native
light-mode screenshot verifies all six exact visible positions, settled pixels, dimensions
and checksum; the review points to this latest image. Center and nonexplicit choice are retained.

## Both groups, arrangement 03

Owner moves Malfoid to bottom-middle, swapping it with asdxz. Explicit reading order is now
4281489, 4291491, 3760512 / 4294199, 4286547, 3002185. Nonexplicit version 05 and both centers
are retained. Both new native light-mode screenshots pass exact visible-order, stable-frame,
dimensions and checksum checks. The local review points to this two-image comparison.

## Nonexplicit slot swap and translation inspection

Owner swaps nonexplicit bottom-left 4252139 with top-right 4126416. The new content-addressed
fixture validates and the active pointer/owner-choice record are updated; previous native images
precede this swap. Explicit arrangement 03 remains unchanged.

Read-only translation investigation: TranslatableLanguage includes English, Japanese, Simplified
Chinese and Traditional Chinese; Traditional converts the Chinese table through OpenCC. German
and Korean have no built-in source. Imported tables are decoded without a language restriction.
Public latest-release API checks returned 200 with db.raw.json for EN, JPN and the Chinese source;
EN/JPN release dates are February 2022. HomeSlideshowTags directly renders tag.text and does not
call the translator. No translation implementation was changed during this inspection.

## Slideshow tag translation review — 2026-11-01

- Wired shared slideshow tags to the existing `translateTags` setting and `tagTranslator`, using
  raw tag identity for lookup and translated display text for rendering. Existing ranking,
  deduplication and title-first fitting remain intact; missing translations retain original text.
- Added optional hash-pinned database/release inputs to DEBUG capture configuration. Isolated
  capture storage uses the production FileClient decoder/OpenCC path and replays the actual
  release metadata/data for the app's normal update check. Personal caches are not used.
- Native verification exposed the existing full-color exception matching converted text instead
  of `other:full color`. Corrected it to preserve 全彩, with tests using real Chinese source text
  and the English identity value.
- Sources: EN release 1, JPN release 3, Chinese v7.29508.1; raw file and release metadata hashes
  are retained in `website-review/tag-translations/sources.json` and each capture manifest entry.
- Built FeatureTests successfully; focused CaptureSceneTests, CaptureTagTranslationTests and
  FileClientTests passed: 31 tests, zero failures/skips. Result: `/tmp/tag-translation-tests-v3.xcresult`.
- Captured 8 native iPhone Air light-mode images: en/ja/zh-Hans/zh-Hant × both groups, from one
  verified build. Every capture is ready with no blockers, pending images or unknown requests;
  two consecutive frame hashes match. All expected translated tags are visible and titles are
  untruncated. Selected centers and both Frontpage orders are preserved, including the latest
  nonexplicit lower-left/upper-right swap.
- Review: http://127.0.0.1:8774/tag-translations/ — card crops are CSS views into the untouched
  full native screenshots; click a card to open its full original. Desktop/mobile page checks
  pass (8 loaded images, no JavaScript errors or horizontal overflow). Codex right-panel opening
  requested; the desktop tool reports it queued.
- Earlier attempted captures are archived under `tag-translations/attempts/before-full-color-fix/`.
  No publication or commit. Owner visual approval remains pending.
- Temporary review simulator removed after verification; the owner’s simulator and local review server remain untouched.

## Owner acceptance and capture hold — 2026-11-01

Owner approved the eight translated slideshow cards and requested refreshing the website
screenshot set. Recapture is now explicitly held until the parallel app-copy update completes.
Commit the changes from this review work while preserving the other session’s edits.
