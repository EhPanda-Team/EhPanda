# Library title prototype: orientation and scroll screenshots

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Decision D141, 2026-10-24. The owner requests iPhone, iPhone Duo and iPad screenshots in each
orientation, at the initial position and after scrolling down. This extends D140's isolated title
prototype; it is not production Library integration or acceptance of its scrolling behavior.

## Captured matrix

Each row contains an actual initial capture and an actual capture after one upward touch swipe
(0.6 seconds), moving the list toward later content. Standard Dynamic Type and light appearance
are held constant. Each initial capture follows a fresh probe launch in the requested interface
orientation. The gesture distance is proportional to the screen, not a fixed content offset.

| Device | Runtime | Posture | Interface orientation | Captures |
|---|---|---|---|---|
| iPhone 17 | 27.0 | — | Portrait / landscape-left | 4 |
| iPhone Duo | 27.1 | Closed, 0° | Portrait / landscape-left | 4 |
| iPhone Duo | 27.1 | Half, 90° | Portrait / landscape-left | 4 |
| iPhone Duo | 27.1 | Open, 180° | Portrait / landscape-left | 4 |
| iPad Pro 11-inch | 27.0 | — | Portrait / landscape-left | 4 |

Total: 10 combinations, 20 screenshots. Landscape-right and upside-down portrait were not
captured. Duo posture was set and confirmed with the hinge CLI; interface orientation and active
cover/inner display were checked with the simulator UI tree. Physical pose names can differ from
interface orientation on the inner display, so the table follows the measured interface geometry.

[Interactive screenshot gallery](evidence/library-title-matrix/index.html)

The gallery filters by device and direction, switches between header crops and full screens, and
opens the full-resolution image on click. Each pair is ordered initial then scrolled. The raw
framebuffers are retained in `evidence/library-title-matrix/raw/`. Landscape frames are rotated
90° only where needed for upright viewing; no screenshot content is reconstructed or retouched.
Header images crop the first 200 logical points.

Historical screenshot: Screenshot comparison page (image removed from repository history)

## Observed result

In every captured initial state, Library, the app-drawn circular chevron and Favorites subtitle
render together. In every captured scrolled state, the main title, subtitle and custom Menu label
are no longer visible. The large-title slot scrolls away; this prototype does not supply a
replacement compact title Menu. This is a usability limitation of the current composition, not
a completed fix or approved final behavior. The native tab bar remains visible and adapts its
position with the platform.

No adjustment was made to hide this result for the screenshots. D140 established only cold-entry
light/dark rendering; these captures add the previously missing scroll evidence. Further production
integration must resolve the source-switch entry point while preserving the owner's native title
and tab requirements. No corrective title behavior is selected on the owner's behalf here.

## Probe and verification boundaries

- Title and arrow code are unchanged from D140. The neutral list grows from 12 to 60 rows so even
  the iPad can scroll. The standalone Info.plist declares a universal app and supported phone/iPad
  orientations. These changes affect only the probe, not the production project or its plist.
- Retained [source](evidence/library-title-matrix/probe/CustomArrowProbe.swift) and
  [Info.plist](evidence/library-title-matrix/probe/Info.plist) allow the matrix to be reproduced.
  The probe uses one NavigationStack and intentionally does not reproduce the app's production
  Library sidebar, gallery content, source persistence or navigation paths.
- Compiled with Xcode 27.1's simulator SDK; final probe compile emitted no diagnostics. Project
  SwiftLint passes for the probe. The previously recorded dependency-build warning boundary in
  D140 remains unchanged.
- Actual gestures and UI-tree reads confirm movement to later gallery rows. All 20 native frames
  were inspected. One fully opened Duo landscape initial UI read reported recovered accessibility
  content; its screenshot and row labels still show the expected probe. This is not an accessibility
  acceptance test.
- Browser checks confirm 10 pairs by default, 6 Duo pairs when filtered, and correct full-image
  links when switching display mode. The gallery's JavaScript syntax and all image references
  pass checks.
- Menu activation, source switching, AX1/AX3/AX5, right-landscape asymmetry and full-app regressions
  are not claimed by this screenshot task.
- All three task-only simulators were shut down and deleted after capture. The three existing
  review devices and their app data were untouched. Device Hub was not controlled. The screenshot
  page is left open for review; the local server serves only the gallery directory.

Original capture outputs and per-pose command/UI logs remain in
`/tmp/ehpanda-title-arrow-matrix/`. To serve the retained text/metadata page from the repository root:

```sh
python3 -m http.server 53140 --bind 127.0.0.1 --directory .planning/quick/261015-duo-session-record/evidence/library-title-matrix
```


## Follow-up — D142

The owner requests persistent title controls. [The follow-up experiment](LIBRARY-TITLE-PERSISTENCE.md)
retains this baseline and supplies 20 new captures of an `.inline` alternative. It does not rewrite
D141's observed result or claim `.inlineLarge` itself has been pinned.
