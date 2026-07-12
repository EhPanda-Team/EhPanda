---
phase: 04-concurrency-framework-migration
plan: 13
subsystem: networking-transport
tags: [async-await, combine, typed-throws, networking, tca]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Typed async request implementations and fully migrated consumers
provides:
  - Typed-throws Request protocol with 44 async conformers
  - Combine-free AppPackage source tree
  - Removal of the Result facade, publisher retry bridge, continuation shim, and gdata publisher plumbing
affects: [04-14, networking, application-clients]

tech-stack:
  added: []
  patterns:
    - Typed-throws protocol requirement as the conformance completeness gate
    - Native URLSession structured cancellation without a Combine continuation bridge

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-13-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/NetworkingFeature/Request+GData.swift
    - AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift
    - AppPackage/Sources/NetworkingFeature/Request+Gallery.swift
    - AppPackage/Sources/NetworkingFeature/Request+Image.swift
    - AppPackage/Tests/ParserFeatureTests/Other/DownloadPageErrorParserTests.swift
    - AppPackage/Sources/ApplicationClient/ApplicationClient.swift
    - AppPackage/Sources/AuthorizationClient/AuthorizationClient.swift
    - AppPackage/Sources/ImageClient/ImageClient.swift
    - AppPackage/Sources/LibraryClient/LibraryClient.swift

key-decisions:
  - "The Request protocol now requires the typed-throws response method, making the compiler the completeness check for all 44 conformers."
  - "Native URLSession cancellation remains the only intentional behavior delta: cancellation stops transport work immediately while TCA still discards cancelled effect sends."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "The request layer has no publisher requirement, Result facade, retry publisher, continuation shim, or Combine gdata path"
    requirement: CONC-01
    verification:
      - kind: build
        ref: "AppFeature generic iOS Simulator build"
        status: pass
      - kind: other
        ref: "Zero AnyPublisher and legacyResponse grep gates"
        status: pass
    human_judgment: false
  - id: D2
    description: "AppPackage source is Combine-free and the frozen networking semantics remain green"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "Full AppPackage iOS Simulator suite, including 76 NetworkingFeature tests"
        status: pass
      - kind: other
        ref: "Zero import Combine and publisher-type grep gates under AppPackage/Sources"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 13: Combine Teardown Summary

**The request protocol and all 44 conformers now run exclusively through typed throws, leaving the entire AppPackage source tree Combine-free.**

## Performance

- **Duration:** 8 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 12

## Accomplishments

- Flipped `Request` to require `response() async throws(AppError)` and removed all 44 publisher implementations.
- Deleted the legacy Result facade, main-queue hop, publisher retry helper, continuation shim, and Combine gdata helpers.
- Migrated the parser error test double to typed throws while preserving the parsed `ipBanned` error assertion.
- Removed the final four dead client imports and proved that no Combine import or publisher type remains under `AppPackage/Sources`.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `72032d33` | Remove the Combine request layer and migrate the parser test double |
| 2 | `97d1701c` | Remove the final dead client Combine imports |

## Deviations from Plan

None. The planned deletion map and protocol flip were applied directly.

## Validation Results

- SwiftLint over all 12 modified Swift files — **passed**, 0 violations.
- AppFeature generic iOS Simulator build — **passed**.
- Package-wide Combine and publisher-type grep gates — **passed**, zero matches.
- Legacy facade grep gate across Sources and Tests — **passed**, zero matches.
- Full AppPackage iOS Simulator suite — **passed** (`TEST SUCCEEDED`), including 76 NetworkingFeature tests.

## Issues Encountered

None.

## Intentional Behavior Delta

Native URLSession structured cancellation stops the active HTTP request immediately. The removed continuation bridge could leave that work running, but TCA discarded the cancelled effect's send in either implementation, so user-visible behavior remains unchanged while cancelled transport work now ends promptly.

## Next Phase Readiness

- CONC-01 is complete and the package no longer depends on Combine.
- Plan 04-14 can pin TCA 1.23.1, enable deprecation traits, and migrate the remaining deprecated APIs against the final async request layer.

## Self-Check: PASSED

- All scoped publisher and bridge symbols are gone.
- The package source tree is Combine-free.
- Full tests and build gates pass.
