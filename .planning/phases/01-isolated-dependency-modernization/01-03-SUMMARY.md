---
phase: 01-isolated-dependency-modernization
plan: 03
subsystem: dependencies
tags: [swiftyopencc, opencc, copencc, cxx, dependency-removal, dep-01, mutex, parity]

# Dependency graph
requires:
  - SwiftyOpenCCTests target locking default/HK/TW ChineseConverter output (01-01)
  - FileClient parity fixtures proving OpenCC conversion applies only for .traditionalChinese (01-01)
provides:
  - App-owned local SwiftyOpenCC module (ChineseConverter) backed by internal copencc C++14 target
  - Bundled default/HK/TW .ocd2 dictionaries loaded via Bundle.module
  - FileClient-local TagTranslation.chtConverted seam (moved off OpenCCExt)
  - Removal of the external ddddxxx/SwiftyOpenCC package from the dependency graph
affects: [isolated-dependency-modernization]

# Tech tracking
tech-stack:
  added:
    - "Local copencc C++14 target vendoring the OpenCC/marisa/darts engine (internal, non-product)"
    - "Local SwiftyOpenCC Swift target with .copy(Dictionary) .ocd2 resources"
  removed:
    - "External package github.com/ddddxxx/SwiftyOpenCC (exact 2.0.0-beta) and its OpenCC product"
    - "OpenCCExt module"
  patterns:
    - "Vendor only the app-needed engine graph + required license notices (clean-room, D-04)"
    - "Mutex-guarded process-lifetime dictionary cache instead of an NSLock weak cache"
    - "Expose a C accessor (CCLastErrorCode) so Swift reads bridge error state without a shared-mutable global"
    - "App-specific tag-table conversion lives at the FileClient boundary, not in the converter module (D-05)"

key-files:
  created:
    - AppPackage/Sources/SwiftyOpenCC/ChineseConverter.swift
    - AppPackage/Sources/SwiftyOpenCC/ConversionDictionary.swift
    - AppPackage/Sources/SwiftyOpenCC/ConversionError.swift
    - AppPackage/Sources/SwiftyOpenCC/DictionaryLoader.swift
    - AppPackage/Sources/SwiftyOpenCC/DictionaryName.swift
    - AppPackage/Sources/SwiftyOpenCC/DictionaryStore.swift
    - AppPackage/Sources/SwiftyOpenCC/.swiftlint.yml
    - AppPackage/Sources/SwiftyOpenCC/LICENSE
    - AppPackage/Sources/SwiftyOpenCC/Dictionary/*.ocd2 (STPhrases, STCharacters, TWPhrases, TWVariants, HKVariants)
    - AppPackage/Sources/copencc/source.cpp
    - AppPackage/Sources/copencc/include/header.h
    - AppPackage/Sources/copencc/include/module.modulemap
    - AppPackage/Sources/copencc/src/** (OpenCC engine; tests/tools excluded from build)
    - AppPackage/Sources/copencc/deps/marisa-0.2.6/** and deps/darts-clone/darts.h
    - AppPackage/Sources/copencc/.swiftlint.yml
    - AppPackage/Sources/copencc/LICENSE (OpenCC Apache-2.0)
    - AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - AppPackage/Sources/FileClient/FileClient.swift
    - AppPackage/Tests/SwiftyOpenCCTests/ChineseConverterParityTests.swift
  deleted:
    - AppPackage/Sources/OpenCCExt/TagTranslation+ChtConverted.swift
    - AppPackage/Sources/OpenCCExt/.swiftlint.yml

key-decisions:
  - "Executed the plan's three tasks as ONE atomic commit: the external SwiftyOpenCC package declares its own `copencc` target, which collides with the local `copencc` target, so the local module cannot build until the external package is removed — and that removal forces the FileClient/test retargeting in the same change."
  - "Trimmed the local ChineseConverter API to EhPanda's traditionalize-only paths (traditionalize/hkStandard/twStandard/twIdiom) and bundled only the 5 .ocd2 files those chains use (D-02/D-04)."
  - "Replaced the upstream WeakValueCache/NSLock with a Synchronization.Mutex-backed strong process-lifetime DictionaryStore; converter/group/string handles are destroyed on deinit."
  - "Added a C accessor CCLastErrorCode() and made ccErrorno file-scoped in source.cpp so Swift 6 strict concurrency does not reject reading a shared-mutable C global."
  - "Moved TagTranslation.chtConverted (locale + `full color` custom mapping) into the FileClient module as an internal helper, keeping SwiftyOpenCC focused on string conversion (D-05)."

requirements-completed: [DEP-01]

coverage:
  - id: DEP-01-conv
    description: "Local ChineseConverter reproduces default (s2t), HK (s2hk), and TW-idiom (s2twp) outputs with distinct regional results via the copencc bridge"
    requirement: DEP-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SwiftyOpenCCTests/ChineseConverterParityTests.swift (5 tests, incl. regionalStandardsProduceDistinctOutput + missingDictionaryBundleThrowsFileNotFound)"
        status: pass
    human_judgment: false
  - id: DEP-01-fileclient
    description: "FileClient applies OpenCC + custom `full color` conversion only for .traditionalChinese, raw otherwise, and cache/rebuild behavior is unchanged"
    requirement: DEP-01
    verification:
      - kind: integration
        ref: "AppPackage/Tests/FileClientTests/FileClientTests.swift (8 tests)"
        status: pass
    human_judgment: false

# Metrics
duration: 14min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 03: Local SwiftyOpenCC Module Summary

**Replaced the external `ddddxxx/SwiftyOpenCC` package with an app-owned local `SwiftyOpenCC` Swift module backed by an internal `copencc` C++14 target that compiles the vendored OpenCC/marisa/darts engine and opens the bundled default/HK/TW `.ocd2` dictionaries — ChineseConverter and FileClient behavior are byte-for-byte identical to the Wave 0 parity fixtures.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-07-10T02:41:02Z
- **Completed:** 2026-07-10T02:55:09Z
- **Tasks:** 3 (merged into 1 atomic commit — see Deviations)
- **Files:** 150 staged (local engine + module + dicts created; 5 modified; 2 deleted)

## Accomplishments
- Vendored an internal, non-product `copencc` C++14 target (`source.cpp` bridge + OpenCC `src/**`, marisa `include`/`lib`, darts `darts.h`) exporting only its C module-map API, with OpenCC Apache-2.0 / marisa BSD-LGPL notices retained.
- Implemented a clean-room local `SwiftyOpenCC` Swift module (`ChineseConverter`, `ConversionDictionary`, `ConversionError`, `DictionaryLoader`, `DictionaryName`, `DictionaryStore`) that opens the bundled `.ocd2` dictionaries from `Bundle.module` and applies them through the copencc bridge.
- Bundled only the 5 dictionaries the app's traditionalize/HK/TW chains use (`STPhrases`, `STCharacters`, `TWPhrases`, `TWVariants`, `HKVariants`) via typed `.copy(.dictionary)`.
- Replaced the upstream `NSLock` weak cache with a `Synchronization.Mutex`-backed `DictionaryStore`; converter/group/string handles are destroyed on deinit; no force unwraps, force tries, `@preconcurrency`, or `@unchecked Sendable`.
- Removed the external SwiftyOpenCC package and the `OpenCCExt` module; moved `TagTranslation.chtConverted` into the FileClient boundary; retargeted `FileClient` and `SwiftyOpenCCTests` to the local module.
- Package build + full test suite green (13 targeted parity tests plus the entire package suite) on the confirmed iPhone Air iOS 26.5 simulator.

## Task Commits

The plan's three tasks were committed together as one atomic change (rationale in Deviations):

1. **Tasks 1–3 (local SwiftyOpenCC swap)** — `35136b7f` (feat)

**Plan metadata:** see final `docs(01-03)` commit.

## Decisions Made
- **Atomic swap over three separate commits.** The external `ddddxxx/SwiftyOpenCC` package ships its own target named `copencc`. SwiftPM rejects two targets named `copencc` in one graph, so the local `copencc` cannot coexist with the external package for even one commit. Removing the external package then breaks `import OpenCC`/`import OpenCCExt`, forcing the FileClient + test retarget in the same change. The three plan tasks are therefore inseparable at the build level; splitting them would produce non-building intermediate commits, violating the project's clean-build-per-commit gate.
- **App-fit API (D-02/D-04).** EhPanda only ever traditionalizes, so the local `ChineseConverter.Options` exposes `traditionalize`/`hkStandard`/`twStandard`/`twIdiom` (dropping the unused `simplify` matrix) and only 5 `.ocd2` files are bundled. Option raw values are compacted since they are runtime-only (never persisted).
- **Error state without a shared-mutable global.** Reading the imported C `ccErrorno` global from Swift is rejected by strict concurrency. `ccErrorno` is now file-scoped in `source.cpp` and read through a new `CCLastErrorCode()` accessor. In practice the only read happens inside the `DictionaryStore` mutex, so it is serialized regardless.

## Deviations from Plan

### Structural

**1. [Rule 3 - Blocking] Merged Tasks 1–3 into one atomic commit (unavoidable target-name collision)**
- **Found during:** Task 1 `build-for-testing`.
- **Issue:** `multiple packages ('apppackage', 'swiftyopencc') declare targets with a conflicting name: 'copencc'`. The plan assumed the local `copencc`/`SwiftyOpenCC` targets could be added while the external package remained (Task 1), with removal deferred to Task 3. They cannot: the external package's own `copencc` target collides, and its removal cascades into the FileClient/test retargeting (Task 2/3).
- **Fix:** Performed the whole DEP-01 swap as one buildable change — vendor local targets, remove the external package + `OpenCCExt`, retarget `FileClient`/`SwiftyOpenCCTests` — verified green, then committed once.
- **Files modified:** Package.swift, both Package.resolved files, FileClient.swift (+ new helper), SwiftyOpenCCTests, OpenCCExt removed.
- **Committed in:** `35136b7f`.

### Auto-fixed Issues

**2. [Rule 3 - Blocking] Removed 5 non-existent `deps/*` excludes from the copencc target**
- **Found during:** Task 1 build (`Invalid Exclude ... File not found`).
- **Issue:** The plan's exact exclude set lists `deps/google-benchmark`, `deps/gtest-1.11.0`, `deps/pybind11-2.5.0`, `deps/rapidjson-1.1.0`, `deps/tclap-1.2.2`. Clean-room vendoring (D-04) imports only marisa + darts, so those dirs do not exist and the excludes were invalid.
- **Fix:** Dropped those 5 exclude entries; kept every exclude that references a vendored file (marisa AUTHORS/CMakeLists/COPYING.md/README + the `src` test/tool set).
- **Committed in:** `35136b7f`.

**3. [Rule 1 - Bug] `no_nslock` SwiftLint violation on a doc comment**
- **Found during:** Task 1 SwiftLint build phase.
- **Issue:** The `no_nslock` custom rule excludes `comment` kinds but not `doc-comment`, so the literal word "NSLock" in a `///` line failed the build.
- **Fix:** Reworded the `DictionaryStore` doc comment to "upstream lock-based weak cache".
- **Committed in:** `35136b7f`.

**4. [Rule 3 - Blocking] Added `LICENSE` to both new targets' excludes**
- **Found during:** Task 1 (avoiding unhandled-file warnings).
- **Issue:** The plan requires a `LICENSE` at each new module root, but an extension-less `LICENSE` in a build target is an unhandled resource.
- **Fix:** Excluded `LICENSE` from the `copencc` and `SwiftyOpenCC` targets while keeping the files in the repo for license compliance.
- **Committed in:** `35136b7f`.

**Total deviations:** 4 (1 structural task-merge, 3 auto-fixed). No scope creep — no runtime behavior changed; the Wave 0 parity fixtures pass verbatim.

## Deferred Issues
- The vendored OpenCC/marisa C++ sources emit upstream compiler warnings (e.g. `-Wshorten-64-to-32`, an `-Wexceptions` catch-ordering warning in `source.cpp`). These are pre-existing in the third-party engine, do not affect conversion output or the build result, and are out of scope for this task per the scope boundary. Not fixed to avoid altering vendored engine behavior and risking parity.

## Threat Register Outcomes
- **T-01-03-01 (Tampering — vendored engine/dicts):** mitigated — only the verified engine graph + notices vendored; Wave 0 fixtures pass as blocking parity evidence.
- **T-01-03-02 (DoS — .ocd2 loading):** mitigated — each default/HK/TW chain is opened through copencc in tests; a missing-dictionary bundle surfaces `.fileNotFound`; FileClient keeps its `try?` fallback.
- **T-01-03-03 (Memory safety — Swift/copencc ownership):** mitigated — dictionaries retained for converter lifetime; dictionary/converter/string handles destroyed exactly once.
- **T-01-03-04 (Tampering — shared cache):** mitigated — `Synchronization.Mutex` store; no `NSLock`/`@preconcurrency`/`@unchecked Sendable`.
- **T-01-03-SC (Supply chain):** mitigated — external package removed from `Package.swift` and both `Package.resolved` files; `copencc` kept internal (filtered from products); `SwiftyOpenCC` remains the only new public product.

## User Setup Required
None.

## Next Phase Readiness
- DEP-01 is fully realized: the app depends on the local `SwiftyOpenCC`, not the external package. No `import OpenCC`/`OpenCCExt` remains.
- Full package build + test suite are green on the confirmed simulator, so the next package-touching plan can proceed.

## Self-Check: PASSED
