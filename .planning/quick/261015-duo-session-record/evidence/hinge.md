> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Duo Home title and hinge review

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Request

While partially folded, right-pane scrolling must leave the Home title's size and position unchanged.
Produce multiple native crease treatments at the hinge, with screenshots for owner review.

## Investigation and implementation

- A regression test reproduced the original shared navigation host hiding Home after a right-pane swipe.
- Native `.toolbarMinimizationBehavior(.never)` kept the title visible but still shrank its height from
  34 pt to 20.67 pt. It did not satisfy the owner's explicit size/position requirement and was removed.
- Partially folded Home now uses sibling native navigation hosts. Home belongs to the left; Toplists
  and its Show All action belong to the right. Toplists supports native pull-to-refresh.
- The left navigation host remains the first child of one stable HStack across postures. Its path,
  local view state and presentation controller are not replaced merely because the right pane appears.
- Reload stays in the left horizontal toolbar on partially folded iOS 27.1, using the native axis API.
- Existing physical pane placement, opposite-side sheets and top scroll-edge policies remain in force.

## Review artifacts

`hinge-review/index.html` compares three native SwiftUI treatments with light/dark screenshots:

- A: one physical pixel using the system separator color.
- B: an 18 pt soft central crease fading outward.
- C: a 28 pt asymmetric highlight/shadow fold resembling a book spine.

All overlays are decorative, hidden from accessibility and do not intercept gestures or consume layout
width. Screenshots use synthetic book-cover fixtures to keep attention on the UI. Prototype sources
and capture helpers are retained only in the ignored `hinge-review/` directory. The owner selected B; it is now the production style.

## Verification evidence

- Baseline reproduction: `duo-title-baseline-ui.log` failed because Home was not hittable after scrolling.
- Incomplete native-minimization experiment: `duo-title-fixed-ui.log`; `before_scroll.png` / `after_scroll.png`.
- Independent navigation fix: `duo-title-host-ui.log` passed exact title and left-content geometry checks.
- Full Duo Home suite: 7 tests passed during the title-fix verification, recorded in the session.
  That earlier log was replaced during final-style capture; Xcode has also pruned its older result bundle.
- Final four-size independent scroll regression: `duo-title-geometry-final.log`, standard / AX1 / AX3 / AX5;
  checks title x/y/width/height, left-content position, right scroll movement and physical pane boundaries.
- Opposite sheet survived half/open/half/closed transitions and dismissal: `duo-title-sheet-transition.log`.
- A pushed list retained its route and first gallery across open/half/open: `duo-title-pushed-path.log`.
- Ordinary iPhone and iPad each passed cold entry at standard / AX1 / AX3 / AX5 and live changes through
  those sizes: `duo-title-phone-sizes.log` and `duo-title-ipad-sizes.log`.
- An exploratory search-preservation script could not establish a reliable native search interaction.
  Its failed setup is retained in `duo-title-pushed-transition.log`; it is not evidence of search-state
  preservation. The separate pushed-route test above verifies navigation continuity without that claim.
- SwiftLint and whitespace checks passed. Independent source review found no issues.

## Final state

- Title fix committed as `7319a710b4` (`fix(home): isolate Duo pane navigation`).
- Final source tree built without compiler warnings: `duo-title-clean-build.log`.
- Working tree is clean; review prototypes and temporary verification helpers remain ignored.
- The dedicated Duo was restored to 130 degrees in portrait; ordinary probe simulators were shut down.
- The owner selected B (soft crease); the production overlay preserves its approved gradient and width.

## Selected crease verification

- Production component: `AppPackage/Sources/HomeFeature/HomeHingeCrease.swift`.
- Visible only while partially folded, centered using the same physical pane geometry.
- Does not participate in layout, hit testing or accessibility; increased contrast adds a one-pixel separator.
- Captures: `hinge-review/selected-light.png` and `hinge-review/selected-dark.png`.
- Three UI checks passed in `duo-hinge-selected-ui.log`: native capture/geometry, opposite-side list/detail
  presentations and independent title geometry at standard / AX1 / AX3 / AX5.
- Simulator restored to 130 degrees portrait, light appearance; status bar override cleared.
- Selected style committed as `2d298eeba6` (`feat(home): add soft Duo hinge crease`).
- Final build passed without warnings: `duo-hinge-selected-clean-build.log`; working tree clean.
