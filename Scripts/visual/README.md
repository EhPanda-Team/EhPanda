# Rendering environment

`regression-environment.json` is the tracked, immutable rendering contract shared by
regression, CI and marketing. It was authored from successful real measurements after
17-24 Task 1 committed its producer. Validation never regenerates or rewrites the pin.
Run-local `environment.json` files are observations, not alternative pin inputs.

## Measure the current environment

From the repository root, select Xcode and run:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer
python3 -B -m unittest discover -s Scripts/visual -p test_environment.py
python3 -B Scripts/visual/environment.py measure --output .capture/environment-measurement
```

Use a new output directory for each run. `--derived-data PATH` is optional; by default the
command queries the project's simulator build settings for its normal DerivedData directory.
The command resolves currently available simulator IDs from the model and runtime metadata.
It requires exactly one available simulator per selected model on that runtime; it never
uses a historical UDID or a previous `.capture/` directory to select a destination.

`GeometryTests.swift` belongs to the existing app-hosted **VisualSnapshotTests** target in
**FeatureTests.xctestplan**. The probe creates a full-size real window through FullContentHost,
waits for stable native geometry and records actual points, pixels, safe areas, scale,
size classes, appearance and system font metrics. It rejects a hardware rectangle mismatch
rather than resizing the window to an expected value. The rectangles are 1260×2736 pixels
for iPhone Air and 1668×2420 for iPad Pro 11-inch (M5), with axes exchanged in landscape.

The command reuses the verified native invocation and simulator lifecycle code in
`Scripts/verify-full-content-capture.py`. It builds FeatureTests and UITests, then runs
phone followed by tablet, one xcodebuild at a time. A native UI test rotates the device
before each hosted geometry invocation; another restores portrait afterward. Test repetition
policies are removed from run-local xctestrun copies. Missing, failed, skipped, repeated or
misattributed tests/attachments fail the command. Original text size and Booted/Shutdown
ownership are restored, including on errors.

Each successful run retains four named `phase17-geometry` JSON attachments and their
xcresults, plus six rotation/restore results, complete logs, commands, source hashes and
simulator lifecycle records. `environment.json` separates public rendering characteristics
from local destination IDs and evidence paths. It records exact Xcode/Swift and SDK versions,
runtime identifier/build, model/hardware identifiers, both orientations and deterministic
reference settings. Its source digests identify the measurement producer; its timestamps
are run metadata and do not enter the pin.

## Validate the tracked pin

```sh
python3 -B Scripts/visual/environment.py validate \
  --environment Scripts/visual/regression-environment.json \
  --output .capture/environment-pin-check
```

Validation reads the explicitly supplied pin, resolves fresh IDs by its model/runtime,
measures both families and orientations again, and compares every pinned characteristic.
The output records the original pin bytes' SHA-256 as `pinSHA256`. Success requires the
input bytes to remain unchanged. A mismatch produces a separate failed observation with
an actionable field path; it never repairs or updates the pin. A run-local observations
file is rejected when supplied as `--environment`.

If validation fails, inspect its error and retained results. Select the pinned Xcode,
install the matching runtime, and ensure each named model has exactly one available
simulator. Correct configuration drift before retrying into a new output directory.
A deliberate rendering-contract change requires explicit new measurement, review and a
separate tracked pin edit; ordinary validation and CI do not perform that edit.

The current reference settings are English (`en_US`), GMT, fixed fixture date
2025-01-01T00:00:00Z, system fonts, Large Dynamic Type, light appearance and disabled
animations. The text size comes from the simulator/app setting, not a window override.
Font names, point sizes and line heights for body, caption1 and title1, Bold Text,
legibility weight and display gamut are observed and pinned. The locale, appearance and
Dynamic Type matrix axes are later capture inputs; validating this reference environment
does not reduce their approved coverage.

Reduce Motion is pinned on (owner approval, 2026-10-06). Disabling UIView animations does
not reach time-driven Metal animation such as the dark Home card's gradient, which the app
freezes only under Reduce Motion; without it a capture can race the gradient's bloom.

The pin also depends on device settings that a new or erased simulator does not have.
Validation detects each one; restore them on the pinned simulators instead of editing the pin:

| Setting | Pinned value | Restore on a booted simulator |
|---|---|---|
| Reduce Motion (both) | on | `xcrun simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true` |
| iPhone system appearance | dark | `xcrun simctl ui <udid> appearance dark` |
| iPad multitasking (bottom safe area 25 pt) | Full Screen Apps | `xcrun simctl spawn <udid> defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool NO`, then reboot |

Return each simulator to its original power state afterwards; the runner and gate restore
only the state they found.

Measured native geometry at the initial pin:

| Family | Orientation | Points | Pixels | Insets top/left/bottom/right | H/V size class |
|---|---|---|---|---|---|
| iPhone Air | Portrait | 420×912 | 1260×2736 | 68/0/34/0 | compact/regular |
| iPhone Air | Landscape | 912×420 | 2736×1260 | 0/68/20/68 | regular/compact |
| iPad Pro 11-inch (M5) | Portrait | 834×1210 | 1668×2420 | 32/0/25/0 | regular/regular |
| iPad Pro 11-inch (M5) | Landscape | 1210×834 | 2420×1668 | 32/0/25/0 | regular/regular |

These are measurements, not library presets or new window-size axes. The pin has no
host-specific UDIDs or paths. Plan 17-02 owns regression-runner integration; 17-05 and
17-07 consume the same unchanged `--environment` input for marketing. This directory's
measurement tooling does not yet implement those runners or approve screenshot baselines.
