> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build/landscape-panes`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Landscape pane verification

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Verified on 2026-10-15 in the isolated iPhone Duo worktree.

## Delivered behavior

- Landscape Home uses two panes on open or partially open Duo, and on iPad when the native tabs are at the top and the content width is at least 640 points.
- Every split Home displays the crease, regardless of hinge posture. Portrait and the closed Duo cover retain the single-column layout.
- Existing Home actions present on the opposite physical side. Native sheet width accounts for the system's outer margin so the sheet remains inside its destination half; nested presentations were checked in both directions.
- The reader's half-width controls can move left and right using an equally tall glass button. The selected side survives rotation within the same reader session. Ordinary iPhone controls retain their original layout.

## Results

- Warning-free UI and unit test builds: `build-sheet.log`, `build-capture-final.log`, and `build-unit.log`.
- 99 unit tests passed: HomeFeatureTests (44) and ReadingFeatureTests (55), recorded in `unit.log`.
- Nine UI checks passed: Duo half-fold Home routing, Duo reader posture transitions, Duo RTL physical placement, fully open Duo Home, fully open Duo reader, iPad Home, iPad reader, eight-second held scrub, and ordinary iPhone landscape controls.
- Duo ran iOS 27.1; iPad and ordinary iPhone probes ran iOS 27.0.
- SwiftLint and `git diff --check` passed. Independent source review reported no findings.
- Held scrub preview remained visible at eight seconds and disappeared after release.

## Captures

- `duo-reader_left.png` and `duo-reader_right.png`: fully open Duo controls on either physical side.
- `ipad-reader_right.png`: iPad reader controls.
- `panel-hold-8.png` and `panel-released.png`: held preview and release behavior.

Reader captures intentionally use synthetic placeholder pages. They are layout evidence, not network-loading checks.

## Cleanup and limits

- All three dedicated simulator installations were relaunched without EHPANDA test environment flags. The Duo was restored to its closed portrait posture and normal Home with live content; the iPad and ordinary iPhone probes were shut down.
- No Device Hub was used. No changes were made to the primary checkout during this task.
- iPad split-policy changes have unit coverage; interactive window resizing and a complete manual VoiceOver pass were not part of these UI checks.
- Temporary capture-only test source is retained under this ignored build directory and is excluded from the commit.
