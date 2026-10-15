> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build/duo-final-verification`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Final Duo and NewDawn follow-up

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Reproduction prerequisite: set `POSE_DRIVER` to the absolute executable path of your simulator
pose driver before running the commands below. The runner requires that path explicitly.

## Approved changes

- The owner compared actual iPad NewDawn sheet captures at 60% and 50%, then selected 50%.
- NewDawn uses its Canvas width: at least 500 pt selects 50%; narrower containers retain 60%. The measured iPad form sheet is 580 × 660 pt even though its horizontal size class is compact. No device-idiom branch was restored.
- The Duo UI driver supports `--cover-display`. Inner and cover displays require opposite hardware orientations for the same viewport aspect. The reader tests now assert the initial viewport and inspect actual rendered page pixels on the cover display.
- The settings-switch test now taps within the visible control. On the cover, the old 95% row-relative coordinate was x=364.1 pt, at the switch's outer edge; its row was x=24, width=358 pt. The failure recording showed the switch unchanged. At 90%, the interaction and existing value assertion pass.

## Completed evidence

- `cover-orientation.log`: automatic entry, rotation, page preservation and reentry passed in 112.845 seconds. Actual page pixels were checked. The opt-out case in this first run failed at the test's switch interaction, before exercising opt-out behavior.
- `cover-optout-final.log`: corrected opt-out test passed in 91.811 seconds; `TEST EXECUTE SUCCEEDED` in 98.289 seconds. It checks rotation, reentry and immediate re-enabling.
- `new-dawn/review.log`: both comparison captures passed in 22.974 seconds; identical 580 × 660 pt sheet frames.
- `new-dawn/sun-60-sheet.png`, `new-dawn/sun-50-sheet.png`: actual sheet screenshots shown to the owner. Corresponding `*-ipad.png` files preserve the full screen.
- `build-final.log`: restored-source UI test build succeeded in 44.979 seconds with no compiler or lint warnings.
- Independent read-only review found no concrete issue with the cover mapping, strengthened assertions, corrected switch point or selected sun sizing.

## Simulator state investigation

The old cover-display block matched a previously documented simulator state: after folding, XCTest still exposed the inner-display app while the cover showed SpringBoard. Restarting only the dedicated Duo restored correct display routing; the inner display became black at hinge=0 and the cover tests used a 466 × 678 pt viewport. No app workaround or Device Hub access was needed.

A process-monitor notice after the failed XCTest run corresponded to the app and test runner exiting at test completion. The result recorded assertion failures, not a crash.

## Commands

All UI runs use `-parallel-testing-enabled NO` and `-collect-test-diagnostics never`. Final diagnostic manifests limit retries to one attempt. The checked-in driver leaves the input manifest intact.

```sh
xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda \
  -testPlan UITests -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/duo-dd ARCHS=arm64

"$POSE_DRIVER" <Duo-UDID> --hinge closed --orientation portrait
python3 Scripts/run-duo-ui-tests.py --pose-driver "$POSE_DRIVER" --device <Duo-UDID> --cover-display \
  --xctestrun <built-UITests-manifest> -- -derivedDataPath .build/duo-dd \
  -collect-test-diagnostics never \
  -only-testing:EhPandaUITests/ReadingOrientationUITests/testAutomaticLayoutPreservesThePageOnRotationAndReentry \
  -only-testing:EhPandaUITests/ReadingOrientationUITests/testDisablingAutomationKeepsManualDirectionAfterRotation
```

## Existing coverage retained

The earlier reports record the half-folded Home split/crease, opposite-side sheets, six-item rankings, title isolation at standard/AX1/AX3/AX5, continuous fold transitions with a presented list, ordinary-phone exclusion, iPad and inner-display automatic layout, and eight-second slider hold/release behavior. The latest related unit run passed all 186 tests. These checks were not all repeated during this follow-up.

Physical hardware, live authenticated network content and a live RTL-language presentation remain outside this simulator verification. The earlier exploratory native-search script did not establish search-state preservation; that remains a coverage limit, not a confirmed regression.

## Final iPad result

- `build-selected.log`: `TEST BUILD SUCCEEDED` in 37.999 seconds; no compiler or lint warnings.
- `ipad-final.log`: selected 50% NewDawn capture passed in 10.991 seconds; orientation opt-out/reentry/re-enable passed in 91.728 seconds. `TEST EXECUTE SUCCEEDED` in 108.154 seconds.
- `new-dawn/selected-50-sheet.png`: produced by the actual width-based implementation, without a ratio override. Its SHA-256 matches the owner's reviewed `sun-50-sheet.png` exactly: `9d8a7f44eaa568436fd9c07692c993176dde5f7d1739264d6fa509ea52db9e33`.
- Temporary screenshot presentation code and tests have been removed from production source and retained only in the ignored evidence directory.

## Final unfolded Duo result

With the hinge at 180 degrees, `open-orientation-final.log` records automatic layout, page preservation and reentry passing in 111.880 seconds, and opt-out/reentry/re-enable passing in 91.527 seconds. Both passed on their first attempt; `TEST EXECUTE SUCCEEDED` in 210.831 seconds. This also confirms the corrected switch hit point on the inner display.

The inner-display test still relies on accessibility page state because XCTest captures the cover display there; actual inner-display numbered pages were visually checked in the previous half-folded captures. Cover and iPad runs additionally verify rendered page pixels.

## Final build and local commits

- `build-clean-final.log`: clean production source and permanent UI test target built successfully in 24.363 seconds, with no compiler or lint warnings.
- Explicit SwiftLint, Python syntax parsing and `git diff --check` all passed.
- `67f5829629 test(reader): cover folded Duo orientation` adds the cover-display driver option, viewport/pixel checks and corrected switch interaction.
- `30ef583d21 fix(ui): size NewDawn sun for wide sheets` applies the owner-selected 50% wide-sheet design.
- Worktree is clean. No push or pull request.
- Clean final app installed on both dedicated probe devices; the iPad was shut down and its status-bar override cleared. The probe iPhone remains shut down. Duo was restored to 130 degrees, hardware portrait, light appearance and fixture-backed Home; `final-home.png` records the final state.
- The successful unfolded Duo result exported no diagnostic attachments.

All requested handoff checks now have outcomes, and the NewDawn choice is resolved. Remaining coverage limits are listed above; no product decision is awaiting the owner.

## Live-network handoff correction

The owner reported all reader images failing immediately after handoff. The app process still carried `EHPANDA_UITEST_STUB_NETWORK=1` and `EHPANDA_UITEST_FIXTURE_DIR` from the final screenshot launch. `UITestStubURLProtocol` intercepts every HTTP(S) request and returns 404 for paths outside its HTML fixtures. Leaving that mode active was an agent cleanup error.

Restarted normally with no `EHPANDA_` launch flags and confirmed fresh Home network data. A temporary live-network smoke test used `app.activate()` without `launchStubbed`, opened a gallery and the reader, and passed in 29.138 seconds (`live-recovery.log`; `TEST EXECUTE SUCCEEDED`, 36.566 seconds). The actual inner-display capture shows both real images on pages 1–2, with accessibility position `1–2 of 16`. The capture is retained locally as `live-reader-restored.png`; it is not a fixture or a placeholder.

The temporary test source was removed and saved only in this ignored directory. No product code changed. Restored the original simulator accessibility preference and launched normally again, verifying the final process has no test launch flags. Future handoffs must use a normal launch after fixture captures, and verify the absence of test-network flags before returning the simulator.
