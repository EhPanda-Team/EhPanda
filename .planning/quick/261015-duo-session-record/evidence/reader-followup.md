> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build/reader-followup`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Reader orientation and Duo Home follow-up

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

The Home split layout, soft crease and opposite-side sheet routing now require both a partial hinge and a landscape viewport. Portrait keeps the ordinary Home navigation stack. Existing sheet and stack state survives rotation.

Reading settings add a default-enabled orientation preference. iPad and a view hierarchy with a native hinge apply it on entry and aspect changes: landscape defaults to right-to-left with two pages, portrait defaults to vertical with one page. Both directions are configurable. Ordinary iPhones retain manual settings and expose the two-page toolbar menu in landscape, including while reading vertically. Enabling that menu selects the configured horizontal direction if necessary.

The slider preview now follows the complete touch through native `GestureState`. A held track drag emitted multiple SwiftUI editing begin/end pairs without changing the slider frame; those short editing sessions were closing the old preview before touch release. The native Slider continues to own the value and accessibility adjustment.

## Verification

- `build-unit.log`: warning-free test build.
- `unit.log`: 88 AppModels tests, 55 ReadingFeature tests and 43 HomeFeature tests passed. The model suite includes its existing expected diagnostic for the display-only private category.
- `lint-final.log`: 24 changed Swift files, no violations.
- `slider-baseline-hold4.png`, `slider-baseline-hold8.png`: original behavior reproduced during a continuous held drag.
- `slider-events.log`: unchanged slider frame; multiple editing true/false pairs during one touch.
- `slider-scrub-hold4.png`, `slider-scrub-hold8.png`, `slider-scrub-released.png`: preview remains through an eight-second hold, then collapses and commits the selected page on release.
- `phone-ui.log`: existing slider page/pixel synchronization regression passed in vertical and left-to-right modes.
- `phone-verified.log`: ordinary iPhone retains its manual direction on rotation; the landscape two-page control works from vertical. Actual numbered page pixels checked.
- `ipad-ui.log`: automatic entry, rotation and reentry preserve actual rendered pages.
- `ipad-optout.log`: disabling automation preserves manual direction on rotation and reentry; re-enabling applies immediately.
- `duo-fixed.log`: Home portrait→landscape→portrait preserves the pushed path and native Back control. Reader entry/rotation/reentry passes through the host pose driver.
- `build-toolbar-fix.log`: latest UI test build has no compiler or lint warnings.
- `duo-fixed.log`: all five selected checks passed, including both automation preference tests and screenshot captures. Exporting result attachments produced none: the prior late presentation diagnostic is gone.
- `duo-closed.log`: the initial cover-display attempt exposed stale simulator display routing. This was subsequently resolved by restarting only the dedicated Duo; `../duo-final-verification/cover-orientation.log` and `cover-optout-final.log` establish rotation, reentry, actual page pixels and opt-out behavior on the cover. Device Hub was not used.
- `duo-pane-regressions.log`: opposite-pane presentations, right-pane scroll/title isolation, and standard/AX1/AX3/AX5 root titles all passed with the final native toolbar policy. Final confirmation is recorded below.

Screen captures use the hermetic UI-test fixture's numbered placeholders. They do not depend on downloaded gallery content.

## Native toolbar and observer fixes found during verification

The native vertical toolbar moved the primary pane's Back button out of view after splitting a pushed portrait page. Each Home pane now uses a fixed horizontal toolbar policy with the native `toolbarVerticalBehavior(.disabled)` API. This also lets the system place Home's tab bar at the bottom. The NavigationStack remains stable through rotation.

A nil hinge update means the observer left a hierarchy that supplies hinge updates. It must not be interpreted as a device changing into an ordinary iPhone. The reader retains its last valid hinge capability and clears the callback when the representable is dismantled, avoiding a late presentation action after dismissal.

SDK 27.1 uses `TopOverflowBarButtonItem` for the horizontal More button. The UI probes now recognize it alongside the existing horizontal and vertical identifiers.

## Final result

- `build-final-unit.log` and `build-final-ui.log`: both final test builds succeeded with no compiler or lint warnings.
- `unit-final.log`: all 186 related tests passed again (88 model, 43 Home, 55 reader); the pre-existing expected category diagnostic is unchanged. This includes the persistent-settings tests after moving them into the matching test subdirectory.
- Final `git diff --check` and 24-file SwiftLint check passed. Temporary capture tests were removed from the committed UI target and preserved only here.
- Read-only review found no remaining concrete correctness issue. The worktree is clean.
- Local commits: `5365df2f7d` Home viewport and native toolbar policy; `c1a0139b1c` reader orientation and settings; `f0f2b435f2` complete slider scrub lifetime. No push or pull request.
- The dedicated Duo is restored to 130 degrees, hardware portrait, light appearance. The dedicated probe iPhone and iPad are shut down.

Follow-up: cover-display automation is now verified, including rendered page pixels. See `../duo-final-verification/VERIFICATION.md` for the resolved simulator state, final test-driver changes and the owner-selected 50% NewDawn sheet. No Device Hub contents were accessed or changed.

The horizontal Home toolbar policy above is superseded by `../duo-sidebar/VERIFICATION.md` and commit `0b72a1db9d`. Native side tabs are restored. Only the Home root splits; an existing pushed destination retains the full navigation host, preserving its native Back and list tools through rotation.
