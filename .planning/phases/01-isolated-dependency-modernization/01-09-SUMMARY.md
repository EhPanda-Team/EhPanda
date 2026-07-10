---
phase: 01-isolated-dependency-modernization
plan: 09
subsystem: networking
tags: [deprecatedapi, cfnetwork, cfreadstream, domain-fronting, swiftpm, de-vendor, warning-suppression, dep-06, gap-closure]

# Dependency graph
requires:
  - phase: 01-isolated-dependency-modernization (plan 01-06)
    provides: DEP-06 spike + D-12 document-skip decision (retain external DeprecatedAPI)
provides:
  - External EhPanda-Team/DeprecatedAPI package removed; deprecated CFReadStreamCreateForHTTPRequest isolated in a local internal LegacyCFReadStream module
  - Deprecation warning silenced only for that single-purpose target via -suppress-warnings in Package.swift
  - Domain-fronting behavior byte-identical; D-12 document-skip explicitly overridden by the user
affects: [NetworkingFeature, AppPackage build graph, DEP-06 record]

# Tech tracking
tech-stack:
  removed:
    - "DeprecatedAPI (EhPanda-Team/DeprecatedAPI, external package)"
  added:
    - "LegacyCFReadStream (local internal module, not a public product)"
  patterns: [isolate an unavoidable deprecated API in a single-purpose module + scope -suppress-warnings to only that target; keep implementation-detail modules out of the products list]

key-files:
  created:
    - AppPackage/Sources/LegacyCFReadStream/LegacyCFReadStream.swift
    - AppPackage/Sources/LegacyCFReadStream/.swiftlint.yml
    - .planning/phases/01-isolated-dependency-modernization/01-09-PLAN.md
    - .planning/phases/01-isolated-dependency-modernization/01-09-SUMMARY.md
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - AppPackage/Sources/NetworkingFeature/DFExtensions.swift
    - .planning/phases/01-isolated-dependency-modernization/01-DEP06-EVIDENCE.md

key-decisions:
  - "Inlined the external DeprecatedAPI package into a local internal LegacyCFReadStream module (DEP-06 'Candidate C'), overriding the D-12 document-skip decision at the user's explicit request."
  - "Silenced the unavoidable CFReadStreamCreateForHTTPRequest deprecation with -suppress-warnings scoped to only the LegacyCFReadStream target in Package.swift — SwiftLint still lints the module (plugin runs independently); nothing else is suppressed."
  - "Kept LegacyCFReadStream out of the package products list (internal implementation detail, like testingSupport); this also sidesteps any unsafeFlags-in-product concern. unsafeFlags is allowed because AppPackage is a local path package."
  - "Preserved the wrapper's exact CF ownership contract (Unmanaged +1 balanced by the caller's .autorelease().takeUnretainedValue()) — no behavior change to domain fronting."

patterns-established:
  - "To use a deliberately-required deprecated API warning-free without a blanket suppression: isolate it in a single-purpose internal module and apply -suppress-warnings to only that target; document the WHY in source + Package.swift + the decision record."

requirements-completed: [DEP-06]

coverage:
  - id: D1
    description: "External DeprecatedAPI removed; deprecated call isolated in a local internal module, build warning-free."
    requirement: "DEP-06"
    verification:
      - kind: integration
        ref: "xcodebuild AppPackage-Package build (id ADE09605-...) — BUILD SUCCEEDED [21.995s]; 0 warnings; LegacyCFReadStream compiled with -suppress-warnings; SwiftLint linted the module; no unsafeFlags/product-restriction error"
        status: pass
      - kind: other
        ref: "DeprecatedAPI absent from both Package.resolved files after resolve"
        status: pass
    human_judgment: false
  - id: D2
    description: "Domain-fronting behavior unchanged after the swap (S1–S7 semantics preserved)."
    requirement: "DEP-06"
    verification:
      - kind: integration
        ref: "xcodebuild AppPackage-Package test — TEST SUCCEEDED; NetworkingFeatureTests DF semantics (S1–S7) green; call site + CF ownership handling byte-identical"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-07-11
status: complete
---

# Phase 01 Plan 09: Inline DeprecatedAPI as LegacyCFReadStream Summary

**The external `EhPanda-Team/DeprecatedAPI` package is removed; its one deprecated call
(`CFReadStreamCreateForHTTPRequest`) now lives in a local, internal `LegacyCFReadStream` module
whose target is compiled with `-suppress-warnings`, so the build stays warning-free and domain
fronting is byte-identical. This is an explicit, user-authorized override of the DEP-06 `document-skip`
decision (D-12).**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-11
- **Tasks:** 2 (1 code commit + 1 docs commit, + the plan commit)
- **Files modified:** 5 modified, 4 created (module source + lint config + plan + summary)

## Accomplishments
- Created the internal `LegacyCFReadStream` module: `enum LegacyCFReadStream` with a single
  `static func create(_:_:) -> Unmanaged<CFReadStream>` wrapping `CFReadStreamCreateForHTTPRequest`,
  preserving the former shim's +1 ownership contract. Added a doc comment explaining the deliberate
  deprecated-API isolation (DEP-06 / D-12/D-14) and the scoped suppression.
- Wired it into `Package.swift`: new `Module.legacyCFReadStream`; a `.target(...)` with
  `swiftSettings: sharedSwiftSettings + [.unsafeFlags(["-suppress-warnings"])]`; excluded from the
  `products` map (internal implementation detail); removed the `DeprecatedAPI` package dependency +
  `deprecatedAPI` product helper; repointed `networkingFeature` to `.module(.legacyCFReadStream)` and
  dropped the vestigial `.deprecatedAPI` dependency from `appFeature`.
- Rewired the single call site in `DFExtensions.swift` (`import LegacyCFReadStream`,
  `LegacyCFReadStream.create(...)`) and updated the adjacent comment; DF semantics unchanged.
- Regenerated both `Package.resolved` files (DeprecatedAPI dropped).
- Verified in the build log that `LegacyCFReadStream` compiled **with** `-suppress-warnings` and that
  **SwiftLint still linted it** — so only compiler warnings are suppressed for this one target, and
  lint coverage (AGENTS.md `.swiftlint.yml`) is intact. No `CFReadStreamCreateForHTTPRequest`
  deprecation warning surfaces anywhere; the build is fully warning-free.
- Recorded the D-12 override in `01-DEP06-EVIDENCE.md` (historical evidence retained).

## Task Commits

1. **Plan doc** - `7f179c4c` (docs): 01-09-PLAN.md
2. **Task 1: inline DeprecatedAPI → LegacyCFReadStream** - `8f73cdca` (build): module + `.swiftlint.yml`
   + Package.swift rewire + DFExtensions + both Package.resolved.
3. **Task 2: DEP-06 override note + summary + STATE** - final docs commit (this summary).

## Files Created/Modified
- `AppPackage/Sources/LegacyCFReadStream/LegacyCFReadStream.swift` (+`.swiftlint.yml`) - new internal module.
- `AppPackage/Package.swift` - module added (suppressed target, excluded from products); DeprecatedAPI removed; NetworkingFeature repointed; vestigial AppFeature dep dropped.
- `AppPackage/Package.resolved` & xcodeproj mirror - DeprecatedAPI removed.
- `AppPackage/Sources/NetworkingFeature/DFExtensions.swift` - import + call site + comment updated.
- `01-DEP06-EVIDENCE.md` - dated D-12 override note.

## Decisions Made
- **Inline over external (override D-12):** at the user's explicit request, adopted DEP-06 "Candidate C". Rationale: an explicit, documented, single-boundary suppression is more transparent than leaning on SPM's implicit hiding of external-dependency warnings, and it sheds a dependency (milestone goal 6). DF behavior is untouched, so D-14 is preserved.
- **Scoped suppression, not blanket:** `-suppress-warnings` applies to only the single-purpose `LegacyCFReadStream` target (which does exactly one thing). SwiftLint still runs on it. This contains the suppression to one documented boundary rather than the codebase.
- **Internal module:** excluded from `products` because it is an implementation detail of NetworkingFeature; this also avoids any unsafeFlags-in-product edge case. `unsafeFlags` is permitted because AppPackage is a local path package (verified: build resolved with no restriction error).

## Deviations from Plan
- None of substance. The plan's Task 1 (module + full rewire) landed as one atomic commit to keep the build green (removing DeprecatedAPI breaks the import until the new module + rewire land together).

## Issues Encountered
- None. The primary risk — SwiftPM rejecting `.unsafeFlags` on a target whose code is linked into the app — did not materialize (local path package exemption); the build resolved and succeeded warning-free.

## Threat Flags
None new. T-01-09-01 (DF behavior) mitigated: byte-identical wrapper + call site, DF semantics tests (S1–S7) green. T-01-09-02 (suppression) mitigated: scoped to one documented target, WHY recorded in source + Package.swift + DEP-06 evidence.

## User Setup Required
None.

## Next Phase Readiness
- DEP-06 is now satisfied by removal-via-inlining rather than document-skip; the DeprecatedAPI external dependency is gone. Domain fronting still relies on the deprecated CFStream path, now isolated locally — the D-13/D-15 real-world (China/SNI) verification caveat for DF as a whole is unchanged and remains a manual concern, independent of this packaging change.

## Self-Check: PASSED

- Files verified on disk: `LegacyCFReadStream.swift`, `.swiftlint.yml`, `Package.swift`, both `Package.resolved`, `DFExtensions.swift`, `01-DEP06-EVIDENCE.md`, `01-09-PLAN.md`, `01-09-SUMMARY.md`.
- Commits verified in git log: `7f179c4c` (plan), `8f73cdca` (build).
- Gates: warning-free build (module compiled + linted + suppressed); full suite TEST SUCCEEDED.

---
*Phase: 01-isolated-dependency-modernization*
*Completed: 2026-07-11*
