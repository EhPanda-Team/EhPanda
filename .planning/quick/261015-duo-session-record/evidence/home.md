> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Duo Home verification — 2026-10-14

Worktree: `$HOME/Fork/EhPanda/.claude/worktrees/iphone-duo-support-c0b23d`.
Starting commit: `b564f590a`. No push or pull request requested.

## Behavior

- Only a partially open hinge selects the split Home layout. Left: slideshow, Frontpage, Other.
  Right: Toplists, with six galleries stacked vertically per category.
- The split stays at the physical midpoint after accounting for each side's own safe-area inset.
  Reading direction within either pane remains inherited; physical left/right placement is mapped
  to the system's semantic leading/trailing placement for RTL.
- Home gallery taps and all five full-list entry points use the opposite half. A gallery selected
  in a list opens on the opposite half again; closing it retains the list. Each gallery owns its
  detail navigation and reader state.
- Hinge changes retain the presented list and navigation state. Outside the partially open posture,
  existing sheets use automatic native sizing and placement; subsequent Home navigation follows
  the original window-size-class policy.
- iOS 27.1 `toolbarVerticalCompressionBehavior(.prefersToolbarItems)` lets the native vertical bar
  compress tabs before list tools when vertical space is insufficient. In closed landscape the
  tabs compressed to the selected Home item; tapping it expanded the tabs and Favorites worked.
  This is space-driven compression, not scroll-driven hiding. The trial scroll-minimization
  modifiers did not collapse the vertical tabs and were removed.
- Existing global modal gallery routing shares the gallery reducer/view without adding the Home
  sheet's Close button to ordinary global presentations.

## Implementation and reference lessons

Consulted the installed Xcode 27.1 app-resizability guidance and a reference project's foldable
layout notes and implementation. Used local geometry, asymmetric safe areas and retained navigation
state. Size classes continue to select ordinary layouts; only the hinge callback activates this
posture-specific layout. No device-name check or global screen/window lookup was introduced.

A native presentation owner (`HomePaneSheet`) controls its own `UIHostingController` form sheet,
`UISheetPresentationController.preferredPlacement`, and measured preferred content size. The
UIKitNavigation item binding keeps presentation state synchronized with dismissal. It explicitly
forwards layout direction and the app's viewport sampling environment to the new hosting root.

The original nested SwiftUI sheet approach placed the second gallery on the same left half when
opened from a left-side Toplists sheet, despite requesting trailing placement. An isolated plain
sheet placed correctly, but the actual Detail view with its reader cover reproduced the mismatch.
The native owner fixes both directions without introspecting private controllers or changing Detail's
internal presentations. These observations establish the failing composition, not a general SDK
root cause.

## Validation

Builds and tests use the installed Xcode 27.1 SDK, arm64 Simulator products, `.build/duo-dd`,
`-parallel-testing-enabled NO`, and `-collect-test-diagnostics never`.

Device IDs:
- Duo: `05422A43-8575-4BA6-A791-FAC2D5D3BA19` (27.1).
- Probe iPhone: `6CE1E40A-7090-484E-8C49-B7BCBDC5E684` (27.0).
- Probe iPad: `114E0258-098C-4C26-B2FF-0B5CECEA4810` (27.0).

```sh
xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda \
  -testPlan UITests -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/duo-dd ARCHS=arm64

foldctl <Duo-UDID> --hinge half --orientation portrait
xcodebuild test-without-building \
  -xctestrun .build/duo-dd/Build/Products/EhPanda_DuoUITests.xctestrun \
  -derivedDataPath .build/duo-dd -only-testing:EhPandaUITests/DuoHomeUITests \
  -destination 'platform=iOS Simulator,id=<Duo-UDID>' \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

The custom test-run file sets `EHPANDA_DUO_UI_TESTS=1` (half portrait) and
`EHPANDA_DUO_COMPACT_UI_TESTS=1` (closed landscape) and limits retries to one attempt.
Run the matching class for the matching pose; the two opt-ins are not interchangeable.
`foldctl` is now installed on PATH; the previously supplied scratch location was moved during this work.

Earlier complete FeatureTests run, excluding VisualSnapshotTests: **1,200 tests passed** across
22 targets (`duo-home-unit-full.log`, `TEST EXECUTE SUCCEEDED`, 141.074 seconds). Its 13 explicitly
recorded known issues predate this change. Final changed-target and UI results follow below.

Live half → open → half → closed transition with Frontpage kept open: passed in 18.487 seconds,
`duo-home-live.log`, `TEST EXECUTE SUCCEEDED` (22.632 seconds). The first host-driver attempt failed
because the CLI path had moved; retrying with the installed command passed.

Live Duo Dynamic Type changes AX1 → AX3 → AX5 → standard: passed in 27.626 seconds,
`duo-home-duo-live-size.log`, `TEST EXECUTE SUCCEEDED` (31.640 seconds). Images `duo-size-1.png`
through `duo-size-4.png` show the actual inner display; the Home title remained visible and sections
reflowed within their physical panes.

Closed-landscape toolbar compression, expand, Favorites selection: passed in 17.145 seconds,
`duo-toolbar-final.log`, `TEST EXECUTE SUCCEEDED` (22.282 seconds).

## Test-driver corrections

The carousel exposes offscreen duplicate cards. The direct-gallery test now chooses a card whose
center lies inside the visible carousel. It reveals the reader control panel before pressing Close.
The native compressed bar retains offscreen tabs in accessibility and may report them hittable;
the test checks actual tab positions and then performs expansion and selection. Reader Close
lookups are scoped to `reading_view`, so sheets behind the reader cannot satisfy the query.
No content/page assertions or product behavior were weakened to make those tests pass.

## Coverage limits

Tests use deterministic stubbed gallery data on simulators. Physical hardware, live authenticated
network responses, and VoiceOver gestures were not exercised. RTL physical placement has unit
coverage; an Arabic/Hebrew live UI run was not performed. Existing NewDawn sun-size and dual-page
indicator-normalization decisions from the earlier handoff remain documented separately in
`DUO-VERIFICATION.md`; this Home change does not resolve those owner decisions.

## Phone final UI results

```text
Test Case '-[EhPandaUITests.DuoVerificationUITests testLiveDynamicType]' passed (28.033 seconds).
Test Case '-[EhPandaUITests.DuoVerificationUITests testOrdinaryRootsAtAllSizes]' passed (29.114 seconds).
Test Case '-[EhPandaUITests.ReaderPageSyncUITests testReadingAgainResumesOnThePageLeft]' passed (41.120 seconds).
Test Case '-[EhPandaUITests.ReaderPageSyncUITests testScrollingKeepsTheIndicatorOnThePageShown]' passed (65.144 seconds).
** TEST EXECUTE SUCCEEDED ** [171.518 sec]
```

## Ipad final UI results

```text
Test Case '-[EhPandaUITests.DuoVerificationUITests testLiveDynamicType]' passed (30.027 seconds).
Test Case '-[EhPandaUITests.DuoVerificationUITests testOrdinaryRootsAtAllSizes]' passed (29.986 seconds).
** TEST EXECUTE SUCCEEDED ** [77.300 sec]
```

Temporary pose/size probes were copied to ignored `.build/DuoVerificationUITests-final.swift` and removed from the source target. Permanent Duo tests remain opt-in and the reader regression keeps its page assertions.

## Final build and unit checks

- `duo-home-final-ui-build.log`: `TEST BUILD SUCCEEDED` (10.125 seconds), no compiler/lint warnings or errors.
- `duo-home-final-feature-build.log`: `TEST BUILD SUCCEEDED` (22.443 seconds), no compiler/lint warnings or errors.
- `duo-home-final-unit.log`: AppFeature **117 tests passed**, HomeFeature **38 tests passed**;
  `TEST EXECUTE SUCCEEDED` (18.486 seconds). This reruns the final affected targets after the
  native placement mapping and populated ranking fixture changes.
- Explicit SwiftLint of all **29 changed/new Swift files**: exit 0. `git diff --check`: exit 0.
- Final read-only review: no actionable findings. The review checked native ownership and dismissal,
  environment forwarding, posture state preservation, gallery navigation/progress flush, the
  Home-only Close button, and the scoped reader Close query.

Final related-target command:

```sh
xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda \
  -testPlan FeatureTests -skip-testing:VisualSnapshotTests \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/duo-dd ARCHS=arm64
xcodebuild test-without-building \
  -xctestrun .build/duo-dd/Build/Products/EhPanda_FeatureTests_iphonesimulator27.1-arm64.xctestrun \
  -derivedDataPath .build/duo-dd -only-testing:HomeFeatureTests -only-testing:AppFeatureTests \
  -destination 'platform=iOS Simulator,id=<Duo-UDID>' \
  -parallel-testing-enabled NO -collect-test-diagnostics never
```

Reader regression uses the UI command above with
`-only-testing:EhPandaUITests/ReaderPageSyncUITests/testReadingAgainResumesOnThePageLeft`
and `testScrollingKeepsTheIndicatorOnThePageShown`.
The earlier complete eight-test reader regressions on Duo and Probe iPhone are recorded in
`DUO-VERIFICATION.md`; this change repeats the relevant modal-host/progress and scrolling checks.

## Final Duo reader regression

`duo-home-reader-resume-final.log`: `testReadingAgainResumesOnThePageLeft` passed
(40.835 seconds); `TEST EXECUTE SUCCEEDED` (45.025 seconds).
The scrolling check passed in the earlier targeted run (62.439 seconds in
`duo-home-reader-regression.log`); that run also exposed the now-corrected unscoped Close query.
The final iPhone targeted run passed both checks together (see its results above).

## Final six-test Duo Home suite

```text
Test Case '-[EhPandaUITests.DuoHomeUITests testDirectGalleriesAndReaderReturnKeepTheirPhysicalSide]' passed (27.813 seconds).
Test Case '-[EhPandaUITests.DuoHomeUITests testHomeKeepsPhysicalPaneOrderAndSixRankings]' passed (15.143 seconds).
Test Case '-[EhPandaUITests.DuoHomeUITests testListsAndGalleriesPresentAcrossTheFold]' passed (32.473 seconds).
Test Case '-[EhPandaUITests.DuoHomeUITests testOtherListsPresentOnTheRight]' passed (43.675 seconds).
Test Case '-[EhPandaUITests.DuoHomeUITests testRootTitleAndPaneOrderAtAccessibilitySizes]' passed (31.230 seconds).
Test Case '-[EhPandaUITests.DuoHomeUITests testWarmLinkWhileHomeSheetIsOpen]' passed (10.749 seconds).
** TEST EXECUTE SUCCEEDED ** [165.326 sec]
```

Executed 6 tests with 0 failures in 161.092 seconds. All six passed on the first attempt in this final run.

## Commit

`fbfc01d1f feat(home): support Duo split presentations`. Local commit only; no push or PR. The worktree is clean.
