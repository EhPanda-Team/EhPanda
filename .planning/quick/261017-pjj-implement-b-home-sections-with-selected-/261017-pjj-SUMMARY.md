---
quick: 261017-pjj
status: complete
mode: quick
recorded: 2026-10-17
implementation_commit: 1cc211aee6158251c5ae3533cc59a22e33af1dc2
---

# B Home sections with C slideshow

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

**Follow-up:** [D101–D104 correction and proposal record](FOLLOW-UP-20261022.md) supersedes the
uploader and omitted-footer choices below and removes explicit rating colors. The original
implementation/verification history is retained; new landscape slideshow alternatives are unselected.

## Owner direction and delivery scope

D99 authorizes the current B+C combination: C slideshow with B Frontpage, Toplists and Other.
D100 makes every Home gallery title follow the existing default-on simplified-title setting.
Disabling the setting restores full titles, including compact/Duo titles and cover accessibility
labels. Existing section order, data requests, routing, native titles and top scroll edges remain.
This is an iOS implementation trial for review, not a macOS port or a Phase 17 baseline update.

The existing measured `GalleryViewport.isLarge` policy selects richer sections only in a single
Home pane. Compact Home and Duo's split panes keep their prior section structure. This does not
revive the withdrawn iPad two-column Home or the rejected adaptive slideshow grouping mode.

## Implementation

- C slideshow starts at 274 points high with a 154-point-wide cover. Rating/language appear once,
  followed by labeled Pages/Category and up to three existing distinct tags. Language/category
  duplicates are excluded from chips; no Popular eyebrow, uploader, date or additional Detail
  request is introduced. Semantic fonts grow naturally, and large-text metadata can exceed the
  former compact-card height ceiling. Existing gradient and Reduce Motion behavior are retained.
- B Frontpage uses 145-point-wide covers, two-line titles and pages/language in two rows. A native
  Grid shares row heights so differing metadata lengths cannot stagger either cover row. The
  compact cover-only wall retains its existing geometry.
- B Toplists keeps the regular two-by-three arrangement, with 84-point-wide covers and existing
  uploader, category, pages, language and rating information. Its existing accessibility-size
  text reflow remains; Duo's six-item stacks and opposite-side navigation are retained.
- B Other retains three destinations with larger cards and localized purpose descriptions.
  The layout accounts for both outer margins and inter-card gaps. No redundant footer is added.
- Semantic Home cover roles leave existing compact/standard/hero consumers unchanged. Artwork
  retains bounded scaling; text is not capped. The numeric rating reuses the existing RatingView
  accessibility representation so it announces a rating rather than a generic Favorite symbol.
- Slideshow, ranking and Frontpage renderers read the same shared title setting and parser.
  The old unconditional ranking trimming and slideshow width-dependent title policy are removed.

## Verification

Evidence is retained under `.build/library/`; tests use the existing native single-pass gate.
The dedicated feature-test iPhone and task-created iPad are separate from the owner's review iPad.
No Device Hub is used, and no other session's simulator or process is operated.

| Attempt | Result | Scope and disposition |
|---|---|---|
| `large-home-feature-01` | Build failed before tests | Missing explicit property-wrapper type and incorrect shared localized pages accessor; both fixed at source. |
| `large-home-feature-02` | 50 passed, 0 failed/skipped/expected failures | Home feature/layout/navigation tests and simplified-title model tests. Build has zero warnings/errors. Predates final rich-wall alignment and rating accessibility refinement. |
| `large-home-ui-01` | 2 passed, 1 failed | Home audit and cold-entry/rotation at Large, AX1, AX3 and AX5 pass. The new title-toggle case fails because identical fixture titles are intentionally deduplicated, leaving no Frontpage section. |
| `large-home-ui-02` | 3 passed, 0 failed/skipped/expected failures | Live simplified/full/simplified setting changes, four-size cold-entry/rotation, Frontpage push/back and Home audit. |
| `large-home-feature-03` | 50 passed, 0 failed/skipped/expected failures | Feature/layout/model tests after the native Grid and rating accessibility refinements. |
| `large-home-ui-03` | 1 passed, 0 failed/skipped/expected failures | Final-source title toggle, Frontpage row alignment and all three Other destinations fitting within the viewport. |

The title fixture now retains a distinct numbered title for every gallery; Frontpage's combined
button is queried as a button while slideshow/ranking titles remain text elements. Exact simplified
and full title patterns are asserted when the setting changes. The first run's failure is retained,
not retried unchanged or converted into an expected failure. Its screenshots also reveal staggered
Frontpage columns at larger text; the final native Grid addresses the layout cause.

The final visual pass places Frontpage title alignment on the Text itself: the surrounding Button
otherwise kept multiline titles centered in the live-data review frame. The title UI test also
checks aligned cover tops and that Popular/Watched/History cards all fit horizontally, with an
additional lower-sections screenshot. The final run passes.

UI-03 source hashes match the committed code exactly. Feature-03 and UI-02 differ only in the
last two leading-alignment modifiers in `HomeGalleryInformation.swift` and the additional
UI-test assertions/screenshot in `LandscapePaneUITests.swift`. No reducer/model source changed
after those passes. Strict lint passes on all eight changed Swift files; `git diff --check`
passes. All five new localized keys contain all six supported locales.

The iPad live-size sequence changes Large → AX1 → AX3 → AX5 → Large in one process, with no fixed
content-size launch argument. Early two-second AX3/AX5 frames catch a native title transition; the
retained eight-second settled frames show the native Home title and refresh control correctly.
These captures record observations, not a proven cause or a fix for native title timing.
No title/search workaround or animation suppression is introduced. See local
`large-home-support/live-sizes/` and `live-launch.json`.

The iPhone also has cold-entry and same-process live-size captures at Large, AX1, AX3 and AX5,
followed by restoration to Large. Initial eight-second AX3 frames show an empty native title
area in both cold and live sequences. A separate cold-entry check at twenty and forty seconds
shows Home and refresh correctly. The intermittent blank remains an observation, not a claimed
root-cause fix or an assertion that every frame passed. The other size captures show the native
title normally. Evidence and process IDs are in `large-home-support/iphone-sizes/`. The first
boot status output reports Data Migration Failed despite returning success and permitting the
subsequent launches/captures; that diagnostic is retained too.

### Build-tool diagnostic boundary

Xcode's compiler/analyzer reports zero warnings and errors for the passing feature/UI builds.
UI-02 still logs one LLVM profile-writer permission diagnostic for `default.profraw`; feature-03
logs three and UI-03 logs five. An explicit temporary `LLVM_PROFILE_FILE` was supplied but did not prevent these
messages. Logs are retained, no profiling or sandbox protection was disabled, and this report
does not claim a completely diagnostic-free build log. Native result summaries report no runtime
warnings. This tooling diagnostic is separate from the app's passing assertions.

Implementation commit: `1cc211aee6158251c5ae3533cc59a22e33af1dc2`.

The original review iPad is updated in place with the final binary and launched normally, with
no fixture arguments or EHPANDA environment keys. Existing account/data are preserved. The live
review screenshot confirms remote covers load and Frontpage multiline titles align leading;
it is local ignored evidence, not a public fixture. See `large-home-support/final-review-device.json`
and `review-home-final.png`. The task-created test iPad is shut down and deleted; the dedicated
iPhone is restored to Large and Shutdown. The review iPad remains open for owner review.

## Evidence limits

Hermetic UI fixtures retain placeholder covers; these checks do not prove live remote image loading.
Duo preservation is checked by existing feature routing tests, not a new physical fold/VoiceOver run.
The unresolved Library header/context-menu issues and Phase 17 owner gates are outside this task.
No reference screenshot, full-content capture baseline or production release is promoted.
