---
phase: 01-isolated-dependency-modernization
plan: 06
subsystem: networking
tags: [domain-fronting, cfnetwork, deprecatedapi, urlsession, network-framework, tls, sni]

# Dependency graph
requires:
  - phase: 01-02
    provides: NetworkingFeature module extraction and DFRequestSemanticsTests baseline
provides:
  - DEP-06 evidence document with a recorded document-skip branch decision
  - Deliberate retention of the DeprecatedAPI package under D-12/D-13
  - Expanded DFRequestSemanticsTests (7 to 10) locking observable D-14 semantics
  - WHY doc comment at the DeprecatedAPI CFReadStream call site
affects: [dependency-modernization, networking, domain-fronting, milestone-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Evidence-backed conditional dependency removal gated by a blocking-human checkpoint"
    - "Deterministic semantics tests as an executable contract for a live network behavior"

key-files:
  created:
    - .planning/phases/01-isolated-dependency-modernization/01-DEP06-EVIDENCE.md
  modified:
    - AppPackage/Sources/NetworkingFeature/DFExtensions.swift
    - AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift

key-decisions:
  - "document-skip selected: DeprecatedAPI is deliberately retained; no domain-fronting behavior changed"
  - "No warning-free replacement (URLSession, Network.framework) preserves the S1+S2+S5 triad, so removal would weaken D-14"

patterns-established:
  - "Conditional dependency removal: prove a warning-free replacement preserves security semantics before removing, else document the skip"

requirements-completed: [DEP-06]

coverage:
  - id: D1
    description: "DEP-06 resolved via document-skip: DeprecatedAPI retained, evidence records Selected Branch with D-12–D-15 citations"
    requirement: DEP-06
    verification:
      - kind: other
        ref: ".planning/phases/01-isolated-dependency-modernization/01-DEP06-EVIDENCE.md (Selected Branch: document-skip, Decision section cites D-12–D-15)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Domain-fronting request semantics (S1–S7) preserved; NetworkingFeatureTests green and package builds clean"
    requirement: DEP-06
    verification:
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift (14 tests pass)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Real-world China/SNI domain-fronting behavior under filtering conditions (D-15 caveat)"
    requirement: DEP-06
    verification: []
    human_judgment: true
    rationale: "Live SNI-filtering behavior cannot be reproduced in a deterministic unit test; requires user-arranged testers physically in China. Retained-path risk is low (behavior unchanged), but end-to-end proof remains user-owned per D-13/D-15."

# Metrics
duration: 12min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 06: DEP-06 Domain-Fronting Spike Summary

**DEP-06 resolved as document-skip: DeprecatedAPI is deliberately retained because no warning-free replacement preserves the host-control + arbitrary-Host + original-domain-trust triad that domain fronting requires.**

## Performance

- **Duration:** ~12 min (continuation session; Task 1 spike ran in a prior session)
- **Completed:** 2026-07-10
- **Tasks:** 3 (Task 1 spike + Task 2 checkpoint resolved in prior session; Task 3 this session)
- **Files modified:** 2 (this session)

## Accomplishments
- Recorded the Task 2 human decision (`document-skip`) as the Selected Branch in `01-DEP06-EVIDENCE.md`, with the Decision section citing D-12, D-13, D-14, and D-15.
- Retained the `DeprecatedAPI` package and `.deprecatedAPI` target dependency unchanged; no domain-fronting source behavior (DFExtensions / DFRequest / DFStreamHandler / DFURLProtocol) removed or weakened.
- Added a WHY doc comment at the single `DeprecatedAPI.getCFReadStream` call site so the intentional deprecated-API dependency no longer reads as tech debt.
- Verified 14 NetworkingFeatureTests pass and the AppPackage builds clean with no deprecation warnings surfacing on the app target.

## Task Commits

1. **Task 1: Run the DEP-06 evidence spike** - `966b7d71` (test) — prior session
2. **Checkpoint pause record** - `231a3311` (docs) — prior session
3. **Task 3: Implement the document-skip branch** - `ed3cb291` (docs) — this session

_Task 2 was a blocking-human decision checkpoint resolved out-of-band; the user selected `document-skip`._

## Files Created/Modified
- `.planning/phases/01-isolated-dependency-modernization/01-DEP06-EVIDENCE.md` - Recorded Selected Branch: document-skip; marked the options table outcome; kept the full D-12–D-15 justification.
- `AppPackage/Sources/NetworkingFeature/DFExtensions.swift` - Added a WHY doc comment at the `DeprecatedAPI.getCFReadStream` call site explaining the deliberate retention (D-12) and the S1/S2/S5 constraint.

## Decisions Made
- **document-skip (retain DeprecatedAPI):** the deprecated `CFReadStreamCreateForHTTPRequest` path is the only proven way to keep domain fronting working. URLSession cannot reliably override the reserved `Host` header while suppressing SNI (breaks S1+S2); Network.framework could in principle preserve all semantics but only as a bespoke hand-rolled HTTP/1.1 + TLS client — a net increase in security risk that is unverifiable locally. Removal would weaken D-14, so it is deliberately skipped per D-12.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Documentation] Added a WHY comment at the DeprecatedAPI call site**
- **Found during:** Task 3 (document-skip implementation)
- **Issue:** The lone `DeprecatedAPI.getCFReadStream` call carried no explanation; a deliberate deprecated-API dependency reads as a bug/tech-debt without a documented rationale, which is exactly the risk the document-skip branch must guard against.
- **Fix:** Added a concise doc comment (within the 120-char line limit) citing DEP-06 / D-12 and the S1+S2+S5 constraint, pointing to the evidence doc.
- **Files modified:** AppPackage/Sources/NetworkingFeature/DFExtensions.swift
- **Verification:** NetworkingFeatureTests pass (14); package build clean, no new deprecation warnings.
- **Committed in:** `ed3cb291`

---

**Total deviations:** 1 auto-fixed (1 missing critical documentation)
**Impact on plan:** The comment is the plan's explicitly-welcomed optional doc note; it makes the retained dependency self-documenting. No behavior change, no scope creep.

## Issues Encountered
None. The corrected verify command (dropping `-testPlan FeatureTests`, per 01-VALIDATION.md's command correction) ran green on the first attempt.

## User Setup Required
None for this plan. **D-15 caveat (outstanding, milestone-level):** if the project ever adopts the `remove-deprecatedapi` path, real-world China/SNI tester confirmation under filtering conditions is mandatory before trusting the change. Under the selected document-skip branch nothing changed, so no new UAT is owed beyond the pre-existing manual domain-fronting verification tracked in 01-VALIDATION.md.

## Next Phase Readiness
- DEP-06 is resolved without weakening domain fronting; `DeprecatedAPI` remains a documented, intentional dependency.
- No blockers for subsequent Phase 01 plans.

## Self-Check: PASSED

- FOUND: `01-06-SUMMARY.md`
- FOUND: `01-DEP06-EVIDENCE.md`
- FOUND commits: `966b7d71`, `231a3311`, `ed3cb291`

---
*Phase: 01-isolated-dependency-modernization*
*Completed: 2026-07-10*
