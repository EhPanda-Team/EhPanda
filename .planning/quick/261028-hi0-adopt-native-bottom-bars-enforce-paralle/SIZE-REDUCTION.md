# Applied size reductions — 2026-10-28

Commit links in this report identify the corresponding retained changes after history rewriting.
The measured binaries used the recorded `-Osize` experiment configuration; their byte counts
and artifact hashes are historical evidence, not measurements of the rewritten `-O` branch.

The owner authorized the recommended reductions after reviewing the audit. The unsigned Release
payload with `-Osize` and the preview cleanup represented by `279897ed0c` was **29,793,340 bytes (29.79 MB / 28.41 MiB)**, down **4,196,392 bytes (12.35%)**.
These are archive payload measurements, not an installed-device or App Store download measurement.
The later UI adoption is outside this exact byte comparison; it does not change the applied size optimizations.

## Applied changes and measured effects

| Stage | App payload | Main executable | Saving from previous stage |
|---|---:|---:|---:|
| Current-source baseline, `-O` | 33,989,732 B | 22,126,576 B | — |
| Build-wide `-Osize` | 29,908,452 B | 18,045,256 B | 4,081,280 B |
| Preview-only helpers excluded from Release | 29,859,028 B | 17,995,832 B | 49,424 B |
| Preview-only identifier table also excluded | **29,793,340 B** | **17,930,144 B** | **65,688 B** |

`Config/SizeOptimization.xcconfig` supplies a Release-only build-wide override. Both deployment
workflows now pass it and no longer force `-O`. Project Release settings and the local package's
Release-only Swift settings align with it. Every observed shipping Swift module used `-Osize`:
78 device modules, including the extension and third-party packages. Six build-host macro modules
also used it; they are not installed payload. Normal Debug build settings still report `-Onone`.

The five gallery/home/search cell preview helper sections and their PreviewSupport imports are now
Debug-only. Their 1,000-entry identifier table is also Debug-only. All 1,000 original UUID literals
are byte-for-byte preserved in the same order. The Release executable contains neither the table's
first UUID nor `PreviewIdentifiers`; PreviewSupport's remaining live link-map contribution is two
bytes of module-version data. No application runtime feature depends on these preview helpers.

The app still contains 289 files. Assets.car remains 9,488,728 bytes; all catalog variants, dimensions
and stored sizes match. Its generated rendition names/digests and build timestamp vary across
compilations, so whole-catalog hash equality is not claimed. Every other non-executable file is
byte-identical to the baseline. The extension grows by 40 bytes under `-Osize`; the net app reduction
above includes that increase. No artwork, localization, alternate icon, image codec or dependency
was removed.

SFSafeSymbols is retained: its live-symbol contribution falls from 2,364,736 to 1,797,452 bytes.
Kingfisher falls from 1,136,967 to 764,312 bytes. These include virtual storage and are attribution
clues, not additional savings to add to the exact payload delta.

## Verification and limits

- Current-source `-O` baseline exactly reproduced the earlier 33,989,732-byte measurement.
- All optimized archives succeeded with zero compiler/lint warnings. The final archive uses
  Xcode 27.1 (27A9275), iphoneos27.1, arm64, version 3.0.0 (158), and signing disabled.
- The feature suite was built with `SWIFT_OPTIMIZATION_LEVEL=-Osize` while retaining Debug test
  fixtures: 1,431 identities, 1,421 passed and 10 existing expected outcomes; zero unexpected
  failures, skips or Repetition nodes. There were 2,059 parameter-expanded executions.
- The additional expected diagnostic versus the prior run is the existing
  `SettingReducerTests/defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges()` test's
  explicit `skipInFlightEffects(strict: false)`. It appears when its live request remains in flight.
  No expected-failure annotation or skip was added. This is existing test behavior, not evidence of
  a new optimizer failure or a controlled throughput measurement.
- Xcode logged two unused hosted-worker launch failures; all selected identities executed and the
  result bundle contains no repeated test case or unexpected failure. The logs remain available.
- Strict SwiftLint and source diff checks pass. Normal Debug compilation verifies the preview code
  remains available. The frozen identifier list is checked against the original source.
- No controlled on-device parser, image-decoding or download-throughput benchmark was performed;
  the optimized suite verifies behavior, not a quantitative performance budget.

The native device-thinning export was attempted with `method=debugging` and
`thinning=<thin-for-all-variants>`. Xcode returned **No Team Found in Archive** because this is an
unsigned archive. Signing configuration was not changed and no upload occurred. A signed development
archive is required for the device variants described in
[Apple's size-report guidance](https://developer.apple.com/documentation/xcode/reducing-your-app-s-size).

Exact stage counts, compiler flags and changed-file accounting are in
[SIZE-REDUCTION-MEASUREMENTS.json](SIZE-REDUCTION-MEASUREMENTS.json). Source base: `f195b7eaaf`, with the
size changes recorded in `32bf2a30` (optimization) and `279897ed0c` (preview exclusion). Native evidence:

- `/tmp/ehpanda-261028-size-current/EhPanda.xcarchive`
- `/tmp/ehpanda-261028-size-osize/EhPanda.xcarchive`
- `/tmp/ehpanda-261028-size-final/EhPanda.xcarchive` (helper-only intermediate)
- `/tmp/ehpanda-261028-size-complete/EhPanda.xcarchive` (final)
- `/tmp/ehpanda-261028-osize-feature-tests.xcresult`
- `/tmp/ehpanda-261028-debug-final-build.log`
- `/tmp/ehpanda-261028-size-thinning.log`

## Optional approaches for owner consideration

| Option | Potential benefit | Cost / decision |
|---|---|---|
| Signed device-thinning report and installed-device check | Establishes the actual device variants and installed footprint; may show much less icon payload than this unthinned archive | Requires a suitable signing team/profile and device. This measures existing distribution behavior; it does not itself reduce the universal archive. |
| Optimize icon artwork after thinning measurement | Asset catalog is still 9.49 MB; icons dominate it. Savings are unmeasured | Compare equivalent compression/layers across default, dark and tinted appearances and supported devices. Owner visual approval is needed for any appearance change. Keep alternate icons. |
| Consolidate the two image stacks | Could remove some duplicate decoding/caching infrastructure; saving is unknown | Larger feature refactor with animated images, WebP, caching, reader behavior and performance coverage. Keep both current capabilities until parity is demonstrated. |
| Add a normalized archive-size budget to CI | Prevents future growth beyond a chosen tolerance | Choose a measurement stage and allowance above the 29.79 MB baseline. It prevents regressions rather than reducing today's payload. |
| Add controlled on-device performance baselines | Quantifies the size/speed tradeoff for parsing, image processing and downloads | Requires stable representative workloads and hardware; no percentage speed claim is inferred from ordinary test durations. |

Removing localization copies, OpenCC dictionaries, alternate icons, typed symbols or image formats
is not recommended: those bytes currently provide supported behavior.
