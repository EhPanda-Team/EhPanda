# Grid appearance and simplified titles

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Owner decisions: D79–D81. Current appearance correction: `428897f452ea32c300c39b0657db354ad01287fd`
on `agent/app-design`; the initial D79–D80 implementation is `7b58987a7de4bcd164bf1c3f33bc93ebb57a27cb`.

## Current appearance — D81

- All four cover corners are rounded at the original 15-point radius, including the category overlay.
- Cover width:height is 2117:3000, matching the owner's reference image's original metadata.
- Grid titles stop at two lines. Transparent containers, adaptive cover backgrounds, vertically
  centered short titles, aligned row edges and default-enabled row/grid simplification remain.

The initial-delivery sections below retain the prior square-corner interpretation, 2:3 ratio and
three-line limit as history only; D81 supersedes those three values. Final evidence appears under
[Cover correction verification](#cover-correction-verification--d81).

## Initial D79–D80 scope and plan (historical)

1. Add default-enabled Appearance → Gallery simplified titles, decoding older settings without
   resetting other preferences. Localize the control in all six existing locales.
2. Parse balanced, nested bracket pairs for display only. Use Unicode paired-bracket data plus
   compatibility forms and common enclosing marks. Trim removal-boundary whitespace, preserving
   untouched spaces within the retained title. Preserve malformed unmatched text and fall back to
   the original title if removal would leave no name.
3. Remove the grid card background and rounded outer clip. Give only the cover the same adaptive
   background used by GalleryCover, with square corners. Keep metadata and existing interactions.
4. Limit grid titles to three lines at all sizes. Use native row height proposals and flexible title
   space to align sibling card tops/bottoms, including cards with different metadata heights.
5. Verify title/whitespace cases and setting persistence; verify native grid geometry with short/long
   neutral titles, standard and accessibility text sizes, row/grid switching and the setting toggle.
   Preserve the running proposal preview. Record actual evidence and source revisions at completion.

## References and boundaries

Apply app-resizability and iphone-duo guidance on local offered size, stable identity and native
containers; no global-screen sizing or unrelated modernization. SwiftUI specialist guidance governs
stable gallery IDs and view composition. The owner explicitly restricts changes to the listed items.

- [Unicode paired brackets](https://www.unicode.org/Public/17.0.0/ucd/BidiBrackets.txt)
- [SwiftUI LazyVGrid](https://developer.apple.com/documentation/swiftui/lazyvgrid)

This supersedes the earlier five-line grid-title budget only. Row title limits and native navigation
remain as designed; the separate known header displacement remains deferred.

## Initial D79–D80 delivered behavior (historical)

Appearance → Gallery now includes Simplified Titles in all six supported locales. It defaults to
on for fresh installs and older settings without resetting unrelated preferences. The optional
stored field follows the existing additive-setting pattern; explicitly turning it off survives
relaunch. Both shared list cells use the display transformation, including Downloads. Original
stored titles, searches and detail text remain unchanged.

The parser handles balanced nested Unicode paired brackets, compatibility forms and common enclosing
marks. It normalizes only delimiter lookup, preserving the retained title's characters and interior
spacing. Whitespace next to a removed group is trimmed or reduced to one joining space. Malformed
unmatched groups stay literal; the engineering fallback for an otherwise empty result is the original
trimmed title, keeping a card identifiable.

The grid container is transparent. Covers retain the established adaptive background colors and
2:3 letterboxing, with square outer corners. The existing category badge keeps its inward corner.
A vertically ideal cover fixes its height from the offered column width. Native LazyVGrid row heights
and a flexible title frame align card tops and bottoms; short titles center vertically between the
cover and metadata. Titles stop at three lines. Metadata, typography, tag/rating policies, actions,
column sizing and navigation otherwise remain as before. Downloads extends the same row-height
proposal through its enclosing card and retains the Actions menu below it.

## Initial D79–D80 verification (historical)

Xcode 27.1, iOS/iPadOS 27.0 simulators. All final selections execute each enumerated identity once,
without retries or skips. The final production source matches the implementation commit above;
the subsequent Downloads correction changes only its test's element query.

| Evidence under `.build/library/` | Result |
|---|---|
| `grid-titles-model-01` | 97 AppModelsTests identities passed, including 20 bracket/whitespace argument cases, legacy settings and explicit true/false persistence. |
| `grid-titles-ui-02` | 2 iPad UI tests passed: short/long title alignment at standard, AX1, AX3 and AX5; setting updates row/grid immediately, survives relaunch, and restores simplification. |
| `grid-titles-downloads-02` | Existing Downloads management test passed: row inspector, grid Actions, folder move, grid inspector, local reader, cancellation and confirmed deletion of test-owned data. |
| `grid-titles-iphone-01` | Existing compact native title/grid test passed at standard, AX1, AX3 and AX5, including horizontal bounds and toolbar usability. |

Every final build reports zero compiler/analyzer warnings and errors. Strict SwiftLint reports zero
violations across the nine changed Swift source/test files. The iPad geometry test requires equal
first-row top/bottom edges where two columns fit; AX5's single column is checked against the viewport
instead of requiring an unmaterialized offscreen sibling. The screenshots show three-line truncation
and vertically centered short titles. These are cold-size checks; this follow-up does not repeat the
full prior rotation/live-size matrix or constitute physical-device/Phase 17 sign-off.

### Failures retained and corrected

- `grid-titles-ui-01`: the new test incorrectly required an offscreen second card in AX5's single
  column, and tapped the center of a row-wide native switch instead of its trailing control. The
  test now respects native lazy loading, activates the switch, waits for its actual value and
  dismisses the settings sheet before inspecting the list. No assertions are waived.
- Those first screenshots also exposed a real layout error: flexible title space compressed the
  aspect-ratio cover's width. Giving the cover its vertical ideal size fixes the proposal conflict;
  the final screenshots show full-column covers and only the title taking spare row space.
- `grid-titles-downloads-01`: the pre-existing move test selected the last matching Reading button,
  which was the background sidebar folder on this device. The retained native hierarchy shows the
  menu action and sidebar item separately. The test now selects the menu's label/empty identifier
  explicitly, eliminating ordering dependence; the full operation test then passed.

## Initial D79–D80 review artifacts and runtime state (historical)

The eleven original neutral-fixture screenshots are recorded with source paths and SHA256 hashes in
[screenshots/grid-titles-manifest.json](screenshots/grid-titles-manifest.json). They are exported
unchanged from the passing xcresult bundles; no live account/gallery content is committed.

- iPad mixed title lengths (image removed from repository history)
- iPad setting enabled (image removed from repository history)
- iPad Downloads (image removed from repository history)
- iPhone grid (image removed from repository history)

The review iPad was updated in place, preserving its login/data, and opened to Library Favorites.
Its live screenshot confirms the selected background, square corners, simplified titles and aligned
metadata. That account screenshot remains local only. A fresh disposable iPad ran the fixture tests
and was deleted afterward; the dedicated iPhone was restored to Shutdown. sim-use preflight reported
an incompatible installed version, so native XCTest and Xcode simctl provided verification; no
Device Hub or global tool upgrade was needed. The historical proposal preview remains running.

The separately recorded native sidebar/header displacement remains owner-deferred (D75–D76).

## Cover correction verification — D81

D81 corrects the prior misunderstanding of “four corners”: every outer cover corner is rounded.
The completed image/background/category composition is clipped together, keeping the badge's
existing inward corner while rounding the cover's top-trailing corner too. No other list style,
metadata, setting or navigation policy changes.

The [owner's reference gallery](https://e-hentai.org/g/1272615/fe3eace134/) points to a
[cover page](https://e-hentai.org/s/c14674c2bf/1272615-1) reporting the original as 2117 × 3000.
That exact original ratio is used instead of its rounded 250 × 354 thumbnail or 1280 × 1814 display
image. [Reference metadata](reference-cover-metadata.json) retains the public dimensions; no
reference artwork was downloaded or committed.

| Final evidence under `.build/library/` | Result |
|---|---|
| `rounded-cover-ipad-02` | One existing grid geometry test passed at standard, AX1, AX3 and AX5; mixed short/long titles, equal sibling top/bottom edges where multiple columns fit, and single-column viewport bounds. |
| `rounded-cover-iphone-02` | One existing native title/grid test passed at all four text sizes, including horizontal bounds and usable layout toolbar. |

Both final selections ran each enumerated test once, with no retries or skips and unchanged source
hashes. Both builds report zero compiler/analyzer warnings or errors. Strict SwiftLint reports zero
violations in the one changed Swift file with Xcode 27.1 explicitly selected. The 97 model tests,
setting-persistence and Downloads operation tests above belong to the prior delivery and were not
rerun for this view-only refinement. Cold-size checks do not replace the broader live resize/rotation
matrix, physical-device verification or Phase 17 review.

### Visual correction retained

The initial `rounded-cover-ipad-01` and `rounded-cover-iphone-01` test selections passed geometry,
but manual screenshot review found that the category overlay's nested clip still left a square
outer top-right corner. A native compositing group before the final rounded clip corrects that
composition. This follows [SwiftUI compositingGroup](https://developer.apple.com/documentation/swiftui/view/compositinggroup())
semantics; no custom mask or drawingGroup is introduced.

The final standard iPad image visibly rounds all four corners and shows a two-line long title beside
vertically centered short titles with aligned metadata. On the orientation-normalized 2420 × 1668
image, corner samples (675, 411), (1080, 411), (675, 987), (1080, 987) are all white page background;
the top-right sample was blue before grouping. Interior samples retain the cover and badge colors.
At AX3/AX5, much of the card extends below the first viewport; those screenshots alone do not prove
bottom-edge appearance. The geometry assertions remain the alignment evidence at those sizes.

One standalone lint invocation omitted DEVELOPER_DIR and failed to load SourceKit from the machine's
obsolete default Xcode location. Rerunning with the same explicit Xcode 27.1 toolchain as the builds
passed without source changes or rule suppression.

Eight unchanged neutral-fixture screenshots and their SHA256 hashes are retained in
[screenshots/rounded-cover-manifest.json](screenshots/rounded-cover-manifest.json).

- iPad final grid (image removed from repository history)
- iPad AX1 (image removed from repository history)
- iPhone final grid (image removed from repository history)

The review iPad was updated in place and opened to Library Favorites with its original account/data.
Its local-only live screenshot confirms the new corners, ratio, two-line titles and alignment.
The disposable iPad was removed after export; the dedicated iPhone returned to Shutdown. The
historical proposal remains available. D75–D76's native sidebar/header issue stays owner-deferred.
