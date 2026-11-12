# 19-01 local measurement: tracer, controlled shift and clones

Local, advisory data (D-13, D-15). 19-04 decides on the hosted runner. Host: Apple silicon Mac, Xcode 27.2,
iOS 27.0 simulators `$PHONE` (EhPanda iPhone Air) and `$PAD` (EhPanda iPad Pro 11-inch (M5)), one `xcodebuild` at a
time. Tracer: `home-populated`, `agewall-unticked`, `comments-block-confirmation`.

## Simulator setup before a matrix run

| Setting | Why | Command (booted simulator) |
|---|---|---|
| Reduce Motion on (both) | D-15 pin; asserted per process (`reduce-motion`) | `xcrun simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true` |
| App accessibility runtime on (both) | scenarios that reach their state through a row's own accessibility action (the block confirmation); asserted per process (`accessibility-runtime`) | `xcrun simctl spawn <udid> defaults write com.apple.Accessibility ApplicationAccessibilityEnabled -bool true` |
| Full Screen Apps (iPad) | pinned bottom inset 25 pt; Windowed Apps gives 20 pt | `xcrun simctl spawn <udid> defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool NO`, then reboot |
| iPad orientation | see "iPad orientation" below | `VisualCaptureOrientationUITests/testRotateToLandscape` or `testRotateToPortrait` in the UITests plan |

Any UI test run (including the rotation test) turns `ApplicationAccessibilityEnabled` back off, so the runner sets
it again before every matrix process. Reduce Motion survives UI test runs.

## iPad orientation (deviation from Research §3)

`UIWindowScene.requestGeometryUpdate(.iOS(interfaceOrientations:))` turns the iPhone in process, but iPadOS 27
refuses it in every windowing mode, Full Screen Apps included: `UISceneErrorDomain` 101, "The current windowing mode
does not allow for programmatic changes to interface orientation." `XCUIDevice` is not authorized in an app-hosted
test ("Not authorized for performing UI testing actions").

Technical call (Research §3 leaves it to the developer, owner informed): an iPad process captures one orientation,
the one its device was turned to before launch by the existing rotation UI test (Phase 17's mechanism), named by
`EHPANDA_SNAPSHOT_ORIENTATIONS=portrait|landscape`. The window must still match the pin before any picture. iPhone
keeps both orientations in one process. Effect on later plans: iPad has 2 × 18 = 36 units instead of 18, so 19-02's
shard units become 54 (18 iPhone + 36 iPad), and the runner rotates `$PAD` between its two passes.

## Geometry proof

Every captured coordinate waited for the pinned geometry (points, safe-area insets top/left/bottom/right, size
classes) before capture; a mismatch fails the coordinate with reason `geometry`.

| Device | Orientation | Window points | Insets | H/V size class | Reached |
|---|---|---|---|---|---|
| `$PHONE` | portrait | 420×912 | 68/0/34/0 | compact/regular | yes, in process |
| `$PHONE` | landscape | 912×420 | 0/68/20/68 | regular/compact | yes, in process |
| `$PAD` | portrait | 834×1210 | 32/0/25/0 | regular/regular | yes, device turned before launch |
| `$PAD` | landscape | 1210×834 | 32/0/25/0 | regular/regular | yes, device turned before launch |

## Tracer runs (`en-large`, worker count 1)

| Device | Run | Coordinates | Result | Median s / picture | Flaky |
|---|---|---|---|---|---|
| `$PHONE` | candidate | 12 | 12 recorded | 1.46 | 0 |
| `$PHONE` | compare 1 | 12 | 12 passed | 1.42 | 0 |
| `$PHONE` | compare 2 | 12 | 12 passed | 1.44 | 0 |
| `$PAD` landscape | candidate, compare 1, compare 2 | 6 each | 6 recorded, 6 passed, 6 passed | 1.65 / 1.49 / 1.51 | 0 |
| `$PAD` portrait | candidate, compare 1, compare 2 | 6 each | 6 recorded, 6 passed, 6 passed | 1.40 / 1.44 / 1.44 | 0 |
| `$PHONE` | candidate `ja-accessibility5` | 12 | 12 recorded, configuration checks hold | 1.44 | 0 |
| `$PHONE` | candidate `de-xSmall` | 12 | 12 recorded, configuration checks hold | 1.42 | 0 |

The block confirmation is chosen on the first comment: at `ja-accessibility5` the second comment is below the fold
and its alert never appears.

## Controlled shift

`EHPANDA_SNAPSHOT_SHIFT=agewall-unticked` pads the age wall's root by 1 point at the top; compare against the
recorded references:

| Device | Coordinates of `agewall-unticked` | Status | Attempts | Other tracer coordinates |
|---|---|---|---|---|
| `$PHONE` | 4 | changed | 2 on each (both attempts differ) | 8 passed |
| `$PAD` landscape | 2 | changed | 2 on each | 4 passed |
| `$PAD` portrait | 2 | changed | 2 on each | 4 passed |

Without the variable, the next `$PHONE` compare is 12 passed again. A difference picture is written for each changed
coordinate under `difference/`.

## Clones (`$PHONE`, compare, three tracer classes)

`-parallel-testing-enabled YES -parallel-testing-worker-count N`; memory as `memory_pressure` free percentage
(before / lowest during / after). "Pictures identical across N" compares each coordinate's SHA-256 with N = 1.

| N | Clones used | Wall s | xcodebuild s | Median s / picture | Max s | Flaky | Free % before / min / after | Pictures identical across N |
|---|---|---|---|---|---|---|---|---|
| 1 | 0 (source device) | 45 | 37.5 | 1.42 | 1.76 | 0 | 90 / 89 / 90 | baseline |
| 2 | 1 | 89 | 75.5 | 1.57 | 9.26 | 1 | 87 / 85 / 91 | yes (12/12) |
| 3 | 1 | 103 | 84.5 | 1.58 | 10.47 | 1 | 89 / 87 / 91 | 11/12; `comments-block-confirmation` landscape light differs within tolerance (passed) |
| 4 | 1 | 107 | 89.3 | 1.64 | 10.42 | 1 | 89 / 87 / 91 | 11/12; same coordinate |

Findings:

- With three classes, XCTest started one clone whatever the worker count: the count is a ceiling, and all three
  classes went to `Clone 1`. Cloning costs about 40 to 50 s of wall time per invocation here, so clones only pay off
  with many classes per invocation; this tracer cannot show their speed-up. 19-04 measures with full shards.
- Every N passed all 12 coordinates. The one flaky coordinate in the clone runs (and once in a non-clone candidate
  run) is the first `comments-block-confirmation` landscape picture after rotation: the first attempt times out
  settling (about 8 s), and the retry passes. At N = 3 and 4 its passing picture differed from N = 1 by less than
  the 0.9999 precision. Watch this scenario in 19-07; a scenario-level fix (waiting for the alert to finish
  appearing before settling) is preferable to raising the settle cap.
- Memory stayed above 85 % free in every run.

Local recommendation (advisory): run each shard's classes in one invocation with a worker count of 2 to 4 once a
shard holds dozens of classes; for small local runs (`run-snapshot-local.sh`), use no parallel testing.
