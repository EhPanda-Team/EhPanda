---
phase: 01-isolated-dependency-modernization
plan: 04
subsystem: dependencies
tags: [uiimagecolors, dominant-color, dep-02, dependency-removal, clean-room, parity, libraryclient]

# Dependency graph
requires:
  - UIImageColorsTests target locking deterministic getColors(quality:.lowest) RGBA output (01-01)
provides:
  - App-owned local UIImageColors module (UIImage.getColors color extraction)
  - LibraryClient retargeted to the local module as the async color-analysis boundary
  - Removal of the external jathu/UIImageColors package from the dependency graph
affects: [isolated-dependency-modernization]

# Tech tracking
tech-stack:
  added:
    - "Local UIImageColors Swift target (clean-room dominant-color algorithm)"
  removed:
    - "External package github.com/jathu/UIImageColors (2.2.0) and its UIImageColors product"
  patterns:
    - "Clean-room vendor of only the app-needed getColors surface (D-04), algorithm output preserved verbatim (D-16)"
    - "Explicit sRGB premultiplied-first/little-endian CGContext sampling replaces force-unwrapped CFData byte access"
    - "Synchronous completion wrapper: the app's own async boundary (LibraryClient) supplies the off-main hop"

key-files:
  created:
    - AppPackage/Sources/UIImageColors/.swiftlint.yml
    - AppPackage/Sources/UIImageColors/UIImageColors.swift
    - AppPackage/Sources/UIImageColors/UIImage+Colors.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift

key-decisions:
  - "Executed the plan's three tasks as ONE atomic commit: a local target named `UIImageColors` collides with the external package's `UIImageColors` target, so the local module cannot coexist with the external package for even one buildable commit — removal and the LibraryClient/test retarget must land together."
  - "Preserved the color-selection algorithm verbatim (packed-Double channel math, edge/black-white skip, HSV min-saturation accent lift, contrast/distinctness selection, light/dark text fallback) so the Wave 0 RGBA fixtures pass unchanged (D-16/D-18)."
  - "Modernized only the rasterization/sampling: UIGraphicsImageRenderer (device scale, non-opaque, standard range) plus an explicit sRGB BGRA CGContext, eliminating the upstream force unwraps of `dataProvider!`/`CFDataGetBytePtr` while keeping the B,G,R,A byte layout the packing math expects."
  - "Made the `getColors(quality:_:completion:)` overload call the synchronous core directly instead of hopping to a background DispatchQueue; the only caller (LibraryClient.analyzeImageColors) already runs inside an off-main TCA effect, and the historical background hop is not Swift-6-clean without capturing non-Sendable UIImage/UIColor."
  - "Removed the now-unused external `UIImageColors` target dependency from AppFeature and HomeFeature and the stray `import UIImageColors` from GalleryCardCell (the view renders passed-in colors and consumes no module symbol)."

requirements-completed: [DEP-02]

coverage:
  - id: DEP-02-parity
    description: "Local getColors(quality:.lowest) returns the Wave 0 background + light/dark text-fallback RGBA tuples for deterministic solid-gray fixtures"
    requirement: DEP-02
    verification:
      - kind: unit
        ref: "AppPackage/Tests/UIImageColorsTests/UIImageColorsParityTests.swift (2 tests, unchanged fixtures)"
        status: pass
    human_judgment: false
  - id: DEP-02-build
    description: "Full AppPackage builds against the local module with the external package removed and no UIImageColors warnings"
    requirement: DEP-02
    verification:
      - kind: other
        ref: "xcodebuild ... -scheme AppPackage-Package build (BUILD SUCCEEDED)"
        status: pass
    human_judgment: false
  - id: DEP-02-visual
    description: "Subjective gallery-card color parity before/after the swap"
    requirement: DEP-02
    verification:
      - kind: manual
        ref: "01-VALIDATION.md Manual-Only Verifications (D-19)"
        status: deferred
    human_judgment: true

# Metrics
duration: 5min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 04: Local UIImageColors Module Summary

**Replaced the external `jathu/UIImageColors` package with an app-owned local `UIImageColors` Swift module that reimplements the app-needed `UIImage.getColors` color extraction clean-room — the dominant-color algorithm is preserved verbatim (packed-Double channel math, edge selection, HSV min-saturation accent lift, contrast/distinctness picking, and light/dark text fallback), so the Wave 0 deterministic RGBA fixtures pass unchanged while the rasterization is modernized to force-unwrap-free `UIGraphicsImageRenderer` + explicit sRGB BGRA sampling.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-10T03:04:58Z
- **Tasks:** 3 (merged into 1 atomic commit — see Deviations)
- **Files:** 7 (3 created, 4 modified)

## Accomplishments
- Added a local `UIImageColors` target under `AppPackage/Sources` with a parent-linked `.swiftlint.yml` (D-01/D-05/D-06), exposing only the `UIImageColors` result shape, `UIImageColorsQuality`, and the two `UIImage.getColors` overloads the app consumes (D-02/D-04).
- Reproduced the dominant-color algorithm exactly: packed-`Double` channel accessors, `isDarkColor`/`isBlackOrWhite`/`isDistinct`/`isContrasting`, the `with(minSaturation:)` HSV round-trip, edge-color black/white skip, and the light-vs-dark text fallback — no algorithmic redesign (D-16).
- Modernized the rasterization/sampling: `UIGraphicsImageRenderer` at device scale (non-opaque, `.standard` range) and an explicit sRGB `premultipliedFirst | byteOrder32Little` `CGContext`, removing upstream force unwraps of `dataProvider!` / `CFDataGetBytePtr` and the `fatalError` paths while keeping the B,G,R,A byte layout the packing math relies on.
- Retargeted `LibraryClient` to the local module (target dependency `.module(.uiImageColors)`; its `import UIImageColors` now resolves to the local target with no source edit) and kept `analyzeImageColors` mapping primary/secondary/detail/background into `[Color]` in the same order.
- Removed the external package (`Package.swift` dependency + `uiImageColors` product helper) and both `Package.resolved` entries; dropped the unused external dependency from AppFeature/HomeFeature and the stray `import UIImageColors` from `GalleryCardCell`.
- Retargeted `UIImageColorsTests` to the local module without changing the fixture expectations; both parity tests pass and the whole package builds green on the confirmed iPhone Air iOS 26.5 simulator.

## Task Commits

The plan's three tasks were committed together as one atomic change (rationale in Deviations):

1. **Tasks 1–3 (local UIImageColors swap)** — `0de9e602` (feat)

**Plan metadata:** see final `docs(01-04)` commit.

## Decisions Made
- **Atomic swap over three separate commits.** The external `jathu/UIImageColors` package ships a target named `UIImageColors`. SwiftPM rejects two targets with the same name in one graph, so the local `UIImageColors` target cannot coexist with the external package for even one commit. Removing the external package then requires the LibraryClient/test retarget in the same change, making the three plan tasks inseparable at the build level (identical precedent to plan 01-03's `copencc` collision).
- **Algorithm preserved, rasterization modernized.** DEP-02/D-16 require unchanged output, so the selection math is byte-for-byte faithful. Only the image scaling and pixel read were modernized, and only in a way that keeps the sampled bytes equivalent (device scale, non-opaque, standard range, explicit sRGB BGRA buffer). The Wave 0 gray fixtures — neutral-axis and channel-order symmetric — pass with the same `±2` background / exact fallback expectations.
- **Synchronous completion wrapper.** The historical `getColors(quality:_:completion:)` hopped to `DispatchQueue.global()` and called back on main. Capturing the non-Sendable `UIImage`/`UIColor` across that hop is not Swift-6-clean. Because the sole caller (`LibraryClient.analyzeImageColors`) already runs inside an off-main TCA effect wrapped in `withCheckedContinuation`, the local overload runs the work synchronously and invokes the completion inline. App-observable behavior (async color analysis off the main thread, four-element color order) is unchanged.

## Deviations from Plan

### Structural

**1. [Rule 3 - Blocking] Merged Tasks 1–3 into one atomic commit (unavoidable target-name collision)**
- **Found during:** Task 1 build.
- **Issue:** A local target named `UIImageColors` collides with the external package's `UIImageColors` target (`multiple packages declare targets with a conflicting name`). The plan assumed the local target could be added while the external package remained (Task 1), with removal deferred to Task 3. It cannot.
- **Fix:** Performed the whole DEP-02 swap as one buildable change — add the local module/target, retarget LibraryClient + test dependencies, drop the unused AppFeature/HomeFeature dependency and the stray GalleryCardCell import, remove the external package and both resolved entries — verified tests + build green, then committed once.
- **Committed in:** `0de9e602`.

### Auto-fixed Issues

**2. [Rule 3 - Blocking] Renamed single-letter identifiers to satisfy SwiftLint `identifier_name`**
- **Found during:** Task 1 SwiftLint build phase (error-level violations).
- **Issue:** The faithful reproduction used the upstream single-letter names `r`/`g`/`b` (packed-channel accessors) and `x`/`y` (pixel loop), which the root config's `identifier_name` rule rejects as errors (min length 3).
- **Fix:** Renamed to `red`/`green`/`blue` (and normalized locals `redUnit`/`greenUnit`/`blueUnit` inside `with(minSaturation:)`) and the loop vars to `column`/`row`. No behavior change; no suppression added.
- **Committed in:** `0de9e602`.

**Total deviations:** 2 (1 structural task-merge, 1 auto-fixed). No scope creep — no runtime color behavior changed; the Wave 0 parity fixtures pass verbatim.

## Threat Register Outcomes
- **T-01-04-01 (Tampering — UIImageColors algorithm):** mitigated — the Wave 0 RGBA parity fixtures pass unchanged as blocking evidence that the local implementation reproduces the same background/primary/secondary/detail output.
- **T-01-04-02 (DoS — image renderer/color sampling):** mitigated — the two solid-fixture cases (light and dark) exercise the sampling path; the sampler guards non-positive dimensions and missing color space / context by returning `nil` rather than crashing (the upstream `fatalError` paths were removed).
- **T-01-04-SC (Supply chain — SwiftPM resolution):** mitigated — the external package was removed only after the local parity tests passed; no new image package was added; both `Package.resolved` files no longer reference `jathu/UIImageColors`.

## Deferred Issues
- `AppPackage/Tests/DownloadsFeatureTests/ReadingReducerLocalTests.swift:23` emits a pre-existing `variable 'state' was never mutated` warning, unrelated to this plan's files. Left untouched per the scope boundary.
- `SettingFeature/Components/AboutView.swift` still lists `UIImageColors` in acknowledgements; the phase docs do not require attribution updates, so this is left as a possible follow-up.

## User Setup Required
None.

## Next Phase Readiness
- DEP-02 is fully realized: the app depends on the local `UIImageColors`, not the external package. No `import UIImageColors` resolves to a third-party module.
- Full package build + targeted parity tests are green on the confirmed simulator, so the next package-touching plan can proceed.
- Subjective gallery-card color parity remains a deferred user visual verification (D-19), recorded in `01-VALIDATION.md`.

## Self-Check: PASSED
