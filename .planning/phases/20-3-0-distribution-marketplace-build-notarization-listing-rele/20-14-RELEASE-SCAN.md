# 20-14: Release isolation scan and phase gate

Closing record of Phase 20 (step h; D-09, D-20). Nothing here submits, releases, tags or pushes (D-03). Raw logs, result
bundles and scan outputs stay under `.capture/release-20/` (ignored, never committed).

## Build under test

- **Commit.** `feature/gsd-phase-20` at `9b912b5a6`, which has the 20-13 analytics revision and the three TCA
  deprecation refactors (`7f7b709b5` to `3352a7a0f`). `dfda0e3f4` (README wording only, six files) landed on the branch
  while the scans and runs were in progress; it changes no source, so every result below holds for it as well.
- **Toolchain.** Xcode 27.2 (27B52), iOS 27.0 simulators `EhPanda iPhone Air` (`$PHONE`) and
  `EhPanda iPad Pro 11-inch (M5)` (`$PAD`), both Shutdown before and after.

## Task 1: Release isolation scan, both flavors

Each flavor built Release and the Debug control into its own DerivedData (`.capture/release-20/<flavor>/`), with the full
log, `CODE_SIGN_IDENTITY=- CLANG_COVERAGE_MAPPING=NO LD_GENERATE_MAP_FILE=YES`, and `-xcconfig Config/Marketplace.xcconfig`
on both builds for the marketplace flavor. `verify-release.py` took all four link maps (EhPanda and ShareExtension, arm64
and x86_64) and `--device $PHONE`.

| | default | marketplace |
|---|---|---|
| Release build | `** BUILD SUCCEEDED **` | `** BUILD SUCCEEDED **` |
| Debug control build | succeeded | succeeded |
| App identity in the built plist | `app.ehpanda.store`, stamp `source` | `app.ehpanda.marketplace`, stamp `altstorePAL` |
| `release-isolation.json` | `passed: true`, **0 findings** | `passed: true`, **0 findings** |
| Link maps | 4 | 4 |
| Payload files scanned | 379 | 379 |
| Target dependency graph | 150 targets | 150 targets |
| Accepted names | `UITestAutomation`, kind `inert-shell` (one) | same |
| Probe launch, Release | alive after the wait | alive after the wait |
| Probe launch, Debug control | ended | ended |

The one accepted name is the inert shell the README allows. The Debug control ending proves the probe would have
activated capture had Release read it.

## Task 2: Phase gate

| Gate | Result |
|---|---|
| `actions-tool` tests (`unittest discover -s tests`) | 201 tests, OK |
| `Scripts/visual` tests (all 22 `test_*.py`; none was touched by this phase) | 384 tests, OK |
| FeatureTests on `$PHONE` | `TEST SUCCEEDED`: 2034 tests, 1885 passed, 9 expected failures, 140 skipped, **0 failed** |
| FeatureTests on `$PAD` | `TEST SUCCEEDED`: 2034 tests, 1885 passed, 9 expected failures, 140 skipped, **0 failed** |
| `swiftlint lint --strict --no-cache --config .swiftlint.yml` on every tracked Swift file (867) | `Found 0 violations, 0 serious` |
| `actionlint` on the 10 workflows (`.github/actionlint.yaml` applies) | no output, exit 0 |

Notes:

- The 140 skipped are the `SnapshotMatrix` classes, which skip unless a snapshot mode is set; the next section runs them.
- The iPhone run did not repeat 20-13's five `VisualSnapshotTests` failures (`RenderServerCaptureTests`,
  `FixtureArtworkTests`): all 108 of that bundle's runnable tests passed in the same full run. Nothing was rerun.
- The run included `DetailFeatureTests` (174), `SettingFeatureTests` (85), `AppFeatureTests` (194) and
  `AnalyticsClientTests` (104) on each device, which cover the TCA refactors' reducers (comments and detail).
- `swiftlint` and `actionlint` are not at the paths `20-VALIDATION.md` names. SwiftLint 0.65.1 came from the package
  artifact bundle in an existing DerivedData, and `actionlint` 1.7.12 from `/opt/homebrew/bin`. A bare
  `swiftlint lint` from the root also walks untracked package checkouts and `.planning` evidence, so lint ran on
  `git ls-files '*.swift'`.

## TCA refactors: Detail, Comments and Settings snapshots

There are **no recorded references** to compare with: `AppPackage/Tests/VisualSnapshotTests/Baseline` does not exist,
because Phase 19's approved baseline is a deferred item (owner msgs 3425 and 3428), and no earlier local candidate run
exists on this Mac. So the local comparison the refactors call for was made against a fresh before-state instead, which
re-records no tracked reference:

1. A candidate run (`run-snapshot-local.sh --mode candidate`) from a source copy of `db476cdba`, the commit before the
   refactors, into `.capture/release-20/snap/`.
2. A compare run at the branch head against it (`--mode compare --refs`).

Classes: `CommentsSnapshotTests`, `TracerCommentsSnapshotTests`, `ReportFormSnapshotTests`,
`DetailPagesSnapshotTests`, `DetailPagesMoreSnapshotTests`, `GalleryDetailSnapshotTests`, `SettingsSnapshotTests`,
`SettingsPagesSnapshotTests` and `SettingsPagesMoreSnapshotTests`, configuration `en-large`.

| Device | Before-state | Compare at head |
|---|---|---|
| iPhone Air (portrait and landscape, light and dark) | 248 recorded, 4 not applicable | 248 passed, 0 changed, 0 missing, 0 timeout, 0 error, 0 flaky |
| iPad Pro 11-inch (M5), portrait | 126 recorded | 126 passed, 0 changed, 0 missing, 0 timeout, 0 error, 0 flaky |
| iPad Pro 11-inch (M5), landscape | not run | not run |

**Reference diff: none.** The refactors left every compared picture identical.

iPad landscape could not run locally, before and after alike: every coordinate ended `error` with reason `geometry`
before any picture was taken. The orientation log shows `testRotateToLandscape` passing on "Clone 1 of EhPanda iPad Pro
11-inch (M5)", a parallel clone of the UITests plan, so the device the matrix run then used stayed in portrait. That is
a limit of the local script on this host, not a rendering finding, and it is not retried. The hosted gate still owns
iPad landscape.

## What remains, in release order (not set here)

1. **The Classic release (D-26).** Phase 19's passing `snapshot-gate / aggregate` check, which `deploy.yml` and
   `deploy-pal.yml` require, does not exist yet: no approved baseline and no green hosted run (deferred items, owner
   msgs 3425 and 3428). Until then every release and PAL dispatch is refused by design (`20-11-GATE.md`). Then the
   3.0 GitHub release and AltStore Classic, with ehpanda.app going live.
2. **The PAL submission of the same build, 20-08 (D-03, D-26):** the App Manager key test, Apple's verdict, and a dry-run
   publish.
3. **The first look at `altstorePAL` on the dashboard**, from a live PAL install (D-20).

Still open in the phase: 20-06 (collaborator's account setup and the GitHub environment), 20-07 (website URLs live) and
20-08.
