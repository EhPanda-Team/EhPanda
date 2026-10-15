> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build/duo-panel`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Duo reader lower panel

## Change

- Native hinge observation now reports both automatic-layout capability and partial-open status.
- Only partial-open plus a landscape reader viewport constrains the lower panel to the physical
  right half, accounting for asymmetric safe areas and RTL layout direction.
- The slider and preview tray share the narrowed panel size. The full-sized reading pager is unchanged.
- That mode removes the lower duplicate Close and sends accessibility focus to the slider;
  other modes retain the centered panel and lower Close.
- The same LowerPanel instance survives fold changes, retaining its scrubbing gesture state.
- The test pose driver accepts native open, half and closed hinge requests in addition to rotations.

## Verification

Build command:

```sh
xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda \
  -testPlan UITests -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/duo-dd ARCHS=arm64
```

`build-final.log`: `** TEST BUILD SUCCEEDED ** [23.218 sec]`, no warnings or errors.
An earlier build's geometry closure captured the whole generic view. The final implementation
captures only the Sendable layout direction; those warnings are resolved.
`build-capture.log` and `build-other-devices.log` also completed without warnings or errors.
SwiftLint was run directly on all changed Swift files; `git diff --check` and Python AST parsing passed.

Duo command (the wrapper additionally captures the held gesture):

```sh
python3 Scripts/run-duo-ui-tests.py --device "$DUO_UDID" \
  --xctestrun .build/duo-dd/Build/Products/EhPanda_DuoSidebar.xctestrun -- \
  -derivedDataPath .build/duo-dd -collect-test-diagnostics never \
  -only-testing:EhPandaUITests/DuoReadingPanelUITests \
  -only-testing:EhPandaUITests/DuoPanelCaptureUITests \
  -only-testing:EhPandaUITests/ReadingOrientationUITests/testAutomaticLayoutPreservesThePageOnRotationAndReentry
```

`ui-final.log`: 4 tests, 0 failures; `** TEST EXECUTE SUCCEEDED ** [195.064 sec]`.

- Partial landscape → portrait → landscape → fully open → half-folded: correct panel side,
  Close count and usable slider; native toolbar Close exits the reader.
- Forced RTL: panel and slider remain physically right, lower Close absent.
- Existing automatic orientation/reentry test: page and configured reading mode preserved.
- `panel-hold-4.png` and `panel-hold-8.png`: preview remains visible throughout the held touch,
  constrained to the right half. `panel-released.png`: preview closes after release.
  These screenshots intentionally use the existing network fixtures with numbered placeholder pages.

Normal-device command, run separately on the dedicated ordinary iPhone and iPad:

```sh
xcodebuild test-without-building \
  -xctestrun .build/duo-dd/Build/Products/EhPanda_DuoSidebar.xctestrun \
  -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
  -derivedDataPath .build/duo-dd -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:EhPandaUITests/DuoPanelCaptureUITests/testOrdinaryPanelRemainsCentered
```

`phone-panel.log`: test passed (13.589 sec), `** TEST EXECUTE SUCCEEDED ** [24.307 sec]`.
`ipad-panel.log`: test passed (22.368 sec), `** TEST EXECUTE SUCCEEDED ** [78.874 sec]`.
The normal-device probe checks panel centering, both Close controls, and slider hit testing.

## Cleanup and limitations

The temporary capture/probe test source is retained in this ignored directory, not in the committed
test target. The permanent Duo regression tests remain in `EhPandaUITests`.
The Duo app was relaunched normally with no EHPANDA test environment flags; live Home images loaded.
The dedicated ordinary-device simulators are shut down after their verification runs.
No Device Hub was used. No real hardware or live VoiceOver focus navigation was tested.
The one-page-gallery branch was reviewed but not exercised with a one-page fixture in this pass.

Fully-open ArrangementView feasibility and screenshots are recorded in `ARRANGEMENT-RESEARCH.md`.
No fully-open behavior change was adopted into the application.
