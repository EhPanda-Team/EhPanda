> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build/duo-refresh`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Home refresh in the native side toolbar

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

The owner clarified that Refresh belongs to the whole Home, including Toplists. A shared toolbar item now lives in the primary navigation host for a single-pane Home and in the edge-reaching Toplists host for the split Home. Exactly one item is present. Its unchanged `fetchAllGalleries` action concurrently requests Popular/slideshow, Frontpage and every Toplists category.

No forced axis or vertical-bar opt-out is needed. The native container places the item in the side toolbar.

- `build-final.log`: warning-free `TEST BUILD SUCCEEDED` (9.731 seconds).
- `refresh-final.log`: `testHomeKeepsPhysicalPaneOrderAndSixRankings` passed (19.665 seconds). Checks exactly one Reload, its horizontal alignment with the native Home tab, placement on the right half, successful tap, physical pane geometry and six ranking entries.
- `ui.log`: the portrait/landscape navigation test passed (24.830 seconds) and right-scroll title/left-content isolation passed at standard/AX1/AX3/AX5 (44.811 seconds). Its initial refresh-location check failed because the system did not expose the optional `house.circle` identifier on cold entry; the final check uses the accessible Home button and retains the geometry assertions.
- Explicit SwiftLint for both changed Swift files and `git diff --check` passed.
- Read-only source review found no issues: hosts are mutually exclusive and the action still refreshes all Home sections.

UI runs used `Scripts/run-duo-ui-tests.py`, the dedicated Duo and `.build/duo-dd/Build/Products/EhPanda_DuoSidebar.xctestrun`, with `-collect-test-diagnostics never`. The final narrow run selected `EhPandaUITests/DuoHomeUITests/testHomeKeepsPhysicalPaneOrderAndSixRankings`; the earlier run selected it together with `testPortraitUsesOnePaneAndPushesLists` and `testRightPaneScrollKeepsHomeTitleAndLeftPaneStill`.

Visual evidence: `refresh-side-toolbar.png`, using synthetic cover fixtures. The simulator is restored to closed/hardware-portrait and the app is relaunched in normal network mode; the process environment is checked for absence of test flags. Physical hardware was not tested.
