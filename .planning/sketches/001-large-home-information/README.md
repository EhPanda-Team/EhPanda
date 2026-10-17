---
sketch: 001
name: large-home-information
question: "How should existing Home sections use more room for gallery information?"
winner: null
status: slideshow-direction-selected
tags: [home, ipad, macos-future, information-density, section-sizing]
---

# Large-window Home information proposals

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner brief and boundaries

D92–D94, 2026-10-17: explore iPad and a future macOS Home with larger-window section sizing
and richer information. Preserve the established navigation and page framework. The owner’s
original description is the reference; inspecting the Mac App Store is unnecessary and stopped.

All three variants keep Slideshow → Frontpage → Toplists → Other in one vertical Home scroll.
Frontpage stays a two-row horizontal shelf. Each Toplists category keeps two columns of three
ranked galleries at large widths. Popular / Watched / History remain the three Other destinations.
The iPad Home split rollback remains active. App code, reader controls, Library, Duo behavior,
macOS window chrome and navigation policy are not being implemented or reopened here.

These are HTML design studies, not native SwiftUI screenshots or proof of a macOS port.
The top navigation is a fixed comparison frame. D98 selects the C slideshow while leaving B's other sections in the preferred combination.
D96–D97's slideshow field exclusions remain active. Responsive design is deferred for now.
Original A/B/C remain historical comparisons; the B+C section mix is the current default.
This section choice does not authorize implementation in the app.

## Four comparison questions

| Section | Design question | Comparison | Tradeoff |
|---|---|---|---|
| Slideshow | How much height helps additional metadata? | Compact flowing lines / larger cover / labeled fields | First-screen space versus legibility and field scanning |
| Frontpage | How much information belongs beside a preview cover? | Cover with brief metadata / larger cover with title below / cover and text beside it | Visible gallery count versus readable identifiers |
| Toplists | How should a rank row use extra space? | Compact metadata / larger cover and type / additional tags | Row height versus comparison detail |
| Other | How should a destination card explain its contents? | One sentence / larger card and footer / separate purpose and scope | Helpful explanation versus repeated wording |

## How to view

Serve `.planning/sketches/` with a local HTTP server and open
`001-large-home-information/index.html`. It can also be opened directly as a local HTML file.
The page is self-contained apart from the sibling theme CSS; it requests no remote media or data.

Use original A/B/C and the current B+C mix to compare, the section selector to keep a section in view while switching, and the
width selector for 1194, 1450, 1680, 834 or 600 CSS-pixel content widths. The browser window must be at
least that wide; the canvas never forces the containing page to overflow. Theme, annotations,
slideshow arrows, card taps, section actions and refresh provide working prototype feedback.
Destination taps deliberately show a labeled simulation message rather than inventing new Detail
or list navigation. There are no fake tabs for the other app features.

## Original variants and measured starting dimensions

The following values are comparison starting points at the normal text scale, not implementation
constants. A native implementation must let text grow, retain Dynamic Type and measure available
window space. The Home cover ratio remains 8:11; the separate list-grid ratio decision is unchanged.

| | A — Balanced information | B — Cover-led | C — Grouped information |
|---|---|---|---|
| Slideshow height at 1194 | 244 | 312 | 277 measured; 274 minimum |
| Slideshow cover width | 136 | 177 | 154 |
| Slideshow information | Title, uploader/date, category/pages/language/rating, up to 3 tags | Same fields with larger cover and title | Title, rating/language, labeled uploader/pages/date/category, up to 3 tags |
| Frontpage cover width | 109 | 145 | 100 within a 268-wide horizontal card |
| Frontpage information | Page/language badge; category; rating/uploader | Two-line title; pages/language | Two-line title; uploader; pages/language; rating/category; 1 tag |
| Toplists cover width | 70 | 84 | 77 |
| Toplists information | Title, uploader, category/pages/language/rating | Same fields with larger cover and type | Same fields plus up to 2 tags |
| Other card minimum height | 137 | 186 | 178 |
| Other information | Purpose sentence | Purpose plus a scope footer | Purpose plus a labeled scope/order row |

A stays closest to the existing cover-wall scan behavior. B gives each cover/title more room and
requires more vertical scrolling. C reduces the number of covers visible horizontally in exchange
for direct metadata comparison. Sections can be selected independently; none of the three is a
mandatory whole-page bundle. The Other wording is provisional and must be localized if selected.

## Grounding in the current app

Baseline production commit: `ee11c8e800474bddfb5cb1054870ccb9ae9c242f`.

- `HomeSectionsView.swift` owns the current ordered sections and visible viewport measurement.
- `GalleryCardCell.swift` currently shows title/rating, uses a viewport height budget and adaptive
  text arrangements. The proposals add fields already represented by `Gallery`.
- `HomeView+Sections.swift` supplies the two-row wall, per-category ranking groups and three
  destination cards. The design preserves these section roles.
- `GalleryRankingCell.swift` currently supplies rank, cover, title and uploader.
- `GalleryCoverStyle.swift` supplies current Home cover roles: compact height 90, standard 120,
  hero 150 at base scale, with an 8:11 ratio and a bounded artwork scale.
- `AppModels/Gallery/Gallery.swift` represents title, rating, category, uploader, pageCount,
  postedDate and tags; language is derived from tags. The displayed uploader is not asserted to
  be the original artist or author. Tags/language/uploader can be absent in actual responses.

A future implementation should omit unavailable optional fields rather than fetching every
Detail merely to populate Home. No synopsis, editor-written story, trend arrow, ranking change,
watched-result count or invented remote statistic is assumed. Other gains honest destination
context without a new count/preview data dependency. Sample names and all abstract SVG covers are
original fictional fixtures. No live gallery artwork, account data or reference-app screenshots
are included.

## Visual and interaction verification

- The three final 1194-wide renderings show identical section order and no outer page overflow.
- Final 600-wide renderings of A/B/C also have no outer overflow; horizontal section shelves
  retain their own scrolling. B additionally has a 1450-wide screenshot and geometry record.
- A/B/C selection, slideshow next, section selector, refresh feedback and theme switching were
  exercised through the browser UI. Section comparison retains the selected section after switching.
- Cards remain labeled for accessibility even when A omits visible Frontpage titles. Controls have
  visible keyboard focus. The sketch respects reduced-motion preferences for CSS transitions.
- `geometry-verification.json` contains the measured DOM evidence. These checks are browser-only;
  they are not native accessibility audits, simulator results or validated Dynamic Type behavior.
- No app build/test is needed for these documentation-only artifacts. No capture baseline is promoted.

## Screenshots

- A, iPad-width (image removed from repository history)
- B, iPad-width (image removed from repository history)
- C, iPad-width (image removed from repository history)
- B, large window (image removed from repository history)

## B revision — owner feedback D95–D97

Historical iteration from `9a2db8c723`; D98 supersedes its adaptive slideshow layout below.
The screenshots and measurements are retained as evidence of that iteration.

The owner currently prefers B. Retain C's slideshow information grouping only when there is
substantially more usable space. Slideshow galleries already come from Popular; repeating that
source label adds no useful information or meaningful decorative value. Remove it. Uploader and
upload date are explicitly low-priority and excluded from slideshow metadata.

The revision keeps B's 312-high minimum slideshow, 177-wide cover and all other sections. Its
metadata is one set of title, category, pages, language, rating and up to three tags. The default
presents flowing metadata below the title. With a very wide text region, the same values become
a labeled two-by-two group beside the title and tags. There is no parallel summary row repeating
those values. This is a presentation alternative, not a second source of information. Repeated
values must not be introduced merely to fill space; decorative repetition needs a meaningful
visual role. Optional/missing fields still do not justify Detail fetches or invented metadata.

The HTML switches at **1000 CSS pixels of actual slideshow text-region width**, as a provisional
sketch value, not a selected production threshold or a device identity check. Native layout must
account for real text sizes and available region geometry. The grouping does not automatically
apply to every iPad or every landscape orientation. The named Home and slideshow containers keep
their responsive rules independent.

### Revision verification

- At canvas widths 600 and 1194, metadata is flowing; at 1680 it is grouped. No outer overflow.
- At 1194/1680, the same four metadata values occur once each in one description list; title and
  tags also appear once in the metadata area. No Popular eyebrow, uploader or date appears there.
- Both comparison screenshots use the same gallery. The slideshow remains 312 high in these
  standard-text fixtures. Tags remain visible at 600 after scoping nested container queries.
- Next gallery changes the title and all fields together. Original B remains selectable and
  unchanged; B revision is separately selectable. Dark mode and return to narrow width work.
- Browser console reports no warnings/errors in the focused revision checks. These remain HTML
  checks, not native Dynamic Type, VoiceOver or platform implementation validation.
- Measurements are in [revision-geometry-verification.json](revision-geometry-verification.json).
  Earlier screenshot/geometry artifacts remain historical, not regenerated native baselines.

### Revised screenshots

- Slideshow, normal 1194-wide canvas (image removed from repository history)
- Slideshow, extra-wide 1680 canvas (image removed from repository history)
- Complete B revision, normal width (image removed from repository history)
- Complete B revision, extra-wide window (image removed from repository history)

## Selected C slideshow — D98

The owner selects C for the slideshow and asks to set space-dependent adaptation aside for now.
The current B+C preview uses C's 274-high starting card, 154-wide cover and 25-point title. Rating
and language sit below the title; Pages and Category form the next labeled row, followed by tags.
Popular, uploader and upload date stay excluded under D96–D97, and no field is repeated.
Frontpage, Toplists and Other continue to use B. The former 1000-pixel switch and right-side
metadata group have been removed from the live preview. Basic overflow protection remains, but
no new responsive design choice is made by this iteration.

At 1194 and 1680 canvas widths, browser measurements show the same 274-high card, 154-wide cover
and 240/240 field columns, with no outer overflow. At 1194, Frontpage's cover remains 145 wide and
Toplists' cover remains 84 wide, matching B. No browser warnings/errors were recorded. These are
HTML proposal checks only; no app source, native baseline or production test is changed.

- Current slideshow screenshot (image removed from repository history)
- Current complete B+C preview (image removed from repository history)
- [Current geometry evidence](selected-c-geometry.json)

## Remaining design scope

Slideshow C is selected, with the existing field exclusions. The remaining sections continue to
reflect the owner's B preference. Responsive adaptation is deferred; production implementation
has not been requested. The iPad single-pane Home rollback remains unchanged.
