# Installed app size reduction audit

Measured 2026-10-28. **The unsigned, unthinned Release app payload is 33,989,732 bytes
(33.99 MB / 32.42 MiB).** This is an archive measurement, not the footprint reported by iOS Settings.
This is the original baseline audit. The [size experiment](SIZE-REDUCTION.md) measured a
**29,793,340-byte** payload with `-Osize`, saving **4,196,392 bytes (12.35%)**. The owner subsequently
[drops that optimization](SPEED-PRIORITY.md) to prioritize speed, retaining the preview cleanup.
Current Release builds use `-O` and have not been remeasured; these audit findings are historical.

## Baseline

| Item | Logical bytes | Decimal MB | Share of payload |
|---|---:|---:|---:|
| Main executable | 22,126,576 | 22.13 | 65.10% |
| Main asset catalog (`Assets.car`) | 9,488,728 | 9.49 | 27.92% |
| OpenCC dictionaries/configuration bundle | 1,214,084 | 1.21 | 3.57% |
| Entire share extension, including its executable | 73,278 | 0.07 | 0.22% |
| Everything else | 1,087,066 | 1.09 | 3.20% |
| **Total, 289 files** | **33,989,732** | **33.99** | **100%** |

The share extension executable is 72,200 bytes; do not add it again to the extension total.
App-local package resource bundles total 363,783 bytes and alternate-icon PNG files total 617,023
bytes; both are subsets of “everything else.” No embedded `Frameworks` directory exists: the relevant
third-party code is statically linked into the executable.

Summed filesystem allocation (`st_blocks * 512`) is 34,881,536 bytes on this Mac. Allocation is
filesystem-specific and may share storage through APFS; it is not an iPhone installed-size estimate.
No compressed download size was measured. App Store encryption, thinning, signing and distribution
can change delivered bytes. Obtain an exported **App Thinning Size Report.txt** and a representative
installed-device measurement before setting an installed-size target, following
[Apple's size measurement guidance](https://developer.apple.com/documentation/xcode/reducing-your-app-s-size).

## Reproducibility and provenance

- Source: `3572963941a8939aa863a0a5681df5651104f0df`; source/build configuration unchanged for the baseline.
  Concurrent changes were planning documents and lint policy only.
- Xcode 27.1, build 27A9275; iphoneos27.1 SDK; deployment target iOS 27.0; arm64 for app and extension.
- App version 3.0.0, build 158; configuration Release; `CODE_SIGNING_ALLOWED=NO`.
- Both executable Mach-O files have zero code-signature bytes. No provisioning/signature payload is
  present, so this baseline needs no signing-byte subtraction.
- Archive completed successfully with zero compiler/lint warnings. Dead stripping was present in the
  app link command and both app and extension had a strip step.
- Observed compiler commands use `-O` for **78 iOS Swift modules**, including package code and the
  extension. Six additional host macro modules also used `-O`; those are not shipping payload.
- Existing resolved packages were reused, with automatic dependency resolution disabled.
- Full file sizes, duplicate groups, dependency lock hash and module flags are in
  [SIZE-MEASUREMENTS.json](SIZE-MEASUREMENTS.json). Paths inside the JSON are app-bundle-relative.

Reproduction command from the repository root (the cache directory is machine-local):

```sh
xcodebuild archive \
  -project EhPanda.xcodeproj -scheme EhPanda -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/ehpanda-261028-size/EhPanda.xcarchive \
  -derivedDataPath /tmp/ehpanda-261028-size/DerivedData \
  -clonedSourcePackagesDirPath "$HOME/Library/Developer/Xcode/DerivedData/EhPanda-bjhqwuemjjedwrfnzlznzjvcttjq/SourcePackages" \
  -onlyUsePackageVersionsFromResolvedFile -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO LD_GENERATE_MAP_FILE=YES
```

Measurements sum regular non-symlink files under `Products/Applications/EhPanda.app`; each file's
logical length and allocated blocks are recorded separately. Duplicate detection hashes full bytes
with SHA-256 for files of at least 1 KB. `lipo -archs` verified arm64. `assetutil --info` inspected the
compiled catalog; archive link maps supplied object membership and live-symbol contribution. Symbol
names contain non-UTF-8 bytes, so the analysis parses ASCII object entries and numeric columns from
the original bytes rather than discarding malformed text.

## Ranked opportunities

| Priority | Candidate | Measured evidence / addressable contribution | Confidence and behavior risk | Validation before adoption |
|---|---|---|---|---|
| 1 | Compare build-wide Release `-Osize` with this `-O` baseline | Executable is 22.13 MB; all 78 observed shipping Swift modules use `-O`. This is the largest relevant optimization surface. **Savings not measured.** | High confidence this is a valid experiment; medium performance risk for image processing, parsing and download throughput. | A/B unsigned archives from identical source/toolchain, unit tests, reader/parser/download performance checks. Preserve Debug `-Onone`. Apply to app, extension and source-built SwiftPM dependencies; project-only settings do not establish package coverage. |
| 2 | Inspect thinned icon payload; optimize artwork only after measuring device variants | Assets.car is 9.49 MB. `assetutil` reports about 7.99 MB of icon renditions and about 1.45 MB for two JPEG layers. Phone/pad 1024-pixel default/dark/tinted renditions have matching contents across idioms. | High confidence icons dominate assets. Unknown installed saving because the unthinned archive includes both idioms and catalog storage is compiled. Changing artwork can change appearance. | Generate device-specific thinning reports first. If still large, compare visually equivalent source artwork/compression with light/dark/tinted icons, all app icon sizes and supported devices. Do not delete renditions or edit Assets.car. |
| 3 | Investigate preview fixture code retained in Release | `PreviewSupport.o` contributes 54,397 live symbol bytes, and its 1,000-entry UUID table is referenced by preview fixture factories in gallery/home/search cells. | High confidence the object contributes; low total benefit. Symbol bytes include virtual storage and are not guaranteed file savings. | Verify all references are preview-only before conditional compilation; preserve every frozen identifier and Debug previews. Re-archive and compare. No unilateral pruning. |
| 4 | Examine generated symbol-library contribution during the compiler experiment | `SFSafeSymbols.o` accounts for 2,364,736 live symbol bytes; the library is actively used throughout the app. | Measured contribution, unknown reducible fraction. Replacing typed symbols would conflict with project conventions and is not proposed. | Keep the dependency/API. Check its contribution under `-Osize` and any supported upstream optimization path. Do not hand-prune generated definitions. |
| 5 | Consider image-stack consolidation only as a future feature refactor | Kingfisher: 1,136,967 live symbol bytes. SDWebImage, SwiftUI bridge, WebP coder and libwebp together: 747,911 live symbol bytes. | Both stacks have real uses; high regression risk and unknown saving. Low priority for size alone. | Preserve still-image caching, animated reading, WebP and cache isolation. Requires a behavioral migration plan and format/performance coverage, not removal of an apparently duplicate package name. |

Object live-symbol totals are attribution clues, not additive installed-size accounting: they include
virtual storage and exclude other binary overhead. The exact payload table above remains the size baseline.

## Findings that do not justify removal

- **No heavy extension duplication.** The extension link map contains the handoff controller and
  system libraries; no analytics, image, parser or UI package object was linked there.
- **No shipping test fixtures.** Link-map and bundle inspection found no TestingSupport,
  VisualSnapshotSupport, SnapshotTesting, XCTest or Appshot payload. The large parser HTML fixtures
  in the source tree are not installed assets.
- **No broadly unused dependency demonstrated.** `LibraryClient` configures the SDWebImage WebP
  decoder; `ReadingFeature/ReadingViewComponents.swift` uses the animated-image bridge; app components
  use Kingfisher; `FileClient/TagTranslation+ChtConverted.swift` uses OpenCC; AnalyticsClient imports
  TelemetryDeck. Keep these capabilities.
- **OpenCC's 1.21 MB serves Chinese conversion.** Removing dictionaries requires a precise supported
  conversion/configuration audit; no removal is justified here.
- **Exact duplicate files are small and required.** The only duplicate group at least 1 KB is six
  identical 3,520-byte `SettingFeature/Constant.strings` files (17,600 excess logical bytes). Repository
  policy requires non-translated keys in every supported locale. Preserve them.
- **Alternate icons are a feature.** Their 617 KB is not unused bulk and should not be silently removed.
- **Release stripping already runs.** The deployment scripts additionally call the existing payload
  thinning script. This audit measures the normal archive before that post-processing, so it does not
  claim the currently published IPA's size. A future size budget must name its measurement stage.

## Recommended next experiment

Start with a reproducible `-O` / build-wide `-Osize` comparison and exported thinning report. This
preserves features and targets the two dominant measured components. Set a normalized archive budget
only after selecting the accepted optimization; keep installed-device and download budgets separate.
No expected percentage reduction is asserted without that comparison.
