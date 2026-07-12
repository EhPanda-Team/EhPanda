---
gsd_state_version: 1.0
milestone: v3.0.0
milestone_name: milestone
current_phase: 04
current_phase_name: concurrency-framework-migration
status: executing
stopped_at: "04-14 D-11 checkpoint: 66 TCA deprecations require owner scope decision"
last_updated: "2026-07-12T23:00:52.335Z"
last_activity: 2026-07-13
last_activity_desc: Completed Phase 04 Plan 13
progress:
  total_phases: 11
  completed_phases: 3
  total_plans: 32
  completed_plans: 31
  percent: 27
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-09)

**Core value:** The load-bearing paths — fetch, parse, read, download galleries — keep working; every task is a foundation change held to behavior/appearance parity.
**Current focus:** Phase 04 — concurrency-framework-migration

## Current Position

Phase: 04 (concurrency-framework-migration) — EXECUTING
Plan: 14 of 14
Status: D-11 checkpoint — owner scope decision required
Last activity: 2026-07-13 — TCA trait reconnaissance found 66 unique deprecations
Next: decide whether Plan 04-14 expands to all 66 warning sites

Progress: [█████████░] 94% (30/32 plans across Phases 01–04)

## Performance Metrics

**Velocity:**

- Total plans completed: 30
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 9 | - | - |
| 02 | 4 | - | - |
| 03 | 5 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 8min | 2 tasks | 8 files |
| Phase 01 P02 | 8min | 2 tasks | 8 files |
| Phase 01 P03 | 14min | 3 tasks | 150 files |
| Phase 01 P04 | 5min | 3 tasks | 7 files |
| Phase 01 P05 | 7min | 3 tasks | 10 files |
| Phase 01 P06 | 12min | 3 tasks | 2 files |
| Phase 01 P07 | 20min | 3 tasks | 5 files |
| Phase 02 P01 | 8 | 2 tasks | 5 files |
| Phase 02 P02 | iterative | spike + auto-load | 3 files |
| Phase 02 P03 | 6min | 2 tasks | 2 files |
| Phase 02 P04 | 12min | 2 tasks | 4 files |
| Phase 03 P01 | 13min | 2 tasks | 4 files |
| Phase 03 P02 | 12min | 2 tasks | 1 files |
| Phase 03 P03 | 14min | 2 tasks | 4 files |
| Phase 03 P04 | 10min | 2 tasks | 2 files |
| Phase 04 P01 | 11min | 2 tasks | 29 files |
| Phase 04 P02 | 9min | 2 tasks | 3 files |
| Phase 04 P03 | 25min | 2 tasks | 2 files |
| Phase 04 P04 | 18min | 2 tasks | 2 files |
| Phase 04 P05 | 22min | 2 tasks | 2 files |
| Phase 04 P06 | 7min | 2 tasks | 2 files |
| Phase 04 P07 | 8min | 2 tasks | 2 files |
| Phase 04 P08 | 10min | 2 tasks | 5 files |
| Phase 04 P09 | 9min | 2 tasks | 4 files |
| Phase 04 P10 | 7min | 2 tasks | 9 files |
| Phase 04 P11 | 7min | 2 tasks | 8 files |
| Phase 04 P12 | 7min | 2 tasks | 6 files |
| Phase 04 P13 | 8min | 2 tasks | 12 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Combine→async/await (Phase 4) stays in this milestone, sequenced after the isolated dep removals.
- Roadmap: WaterfallGrid→Layout (Phase 2) and SwiftUIPager→native paging ScrollView (Phase 3, construct per D-04 not a TabView) are spike-first — validate feasibility before committing.
- Roadmap: Fold cookies→Keychain + networking/cookie/image tests + `.private.filterValue` fix into their open seams (Phases 8–9); defer Parser/Download refactors.
- Roadmap: LINT-01 split — mechanical rules sweep last (Phase 11); refactor-gated rules land with their refactors (`optional_try`→Phase 9; binding/lifecycle/unchecked-subscript→Phases 5–7).
- [Phase 04]: 04-01: Renamed the Result facade to legacyResponse() so response() is available for incremental typed-throws migration.
- [Phase 04]: 04-01: Every Request conformer stores an injected URLSession, including DataRequest, with .shared as the behavior-preserving default.
- [Phase 04]: 04-02: Unknown URLs and invalid harness tokens fail inside CountingStubProtocol, preventing live-network fallthrough.
- [Phase 04]: 04-02: Parity capture accepts a closure formed on each concrete request type to avoid protocol-extension static dispatch.
- [Phase 04]: Fetch errors map inside fetch; parse errors map after fetch returns, so parse failures never retry. — Preserves Combine retry placement and one AppError mapping per thrown boundary.
- [Phase 04]: TagTranslator retries metadata but performs its payload download once. — Preserves the frozen two-step Combine chain asymmetry.
- [Phase 04]: Native URLSession structured cancellation remains attached to the caller task. — Stops cancelled HTTP work while TCA preserves identical user-visible behavior.
- [Phase 04]: Login preserves an optional HTTP response while Igneous requires an HTTP response and maps a failed cast to unknown. — Matches the distinct frozen map and compactMap semantics.
- [Phase 04]: Account form and JSON assembly remains duplicated beside temporary publishers until publisher deletion. — Keeps each intermediate commit compiling while frozen structural assertions prove parity.
- [Phase 04]: Async gallery metadata preserves 25-pair chunks, two in-flight requests, and input-order reconstruction. — These are existing flood-control and presentation-order guarantees around the shared gdata transport.
- [Phase 04]: Metadata task-group children return typed Result values. — Preserves AppError typing and structured cancellation across the task-group boundary.
- [Phase 04]: Detail chains retry their first fetch and leave their second fetch un-retried. — Preserves the frozen publisher retry placement for reverse lookup and archive funds.
- [Phase 04]: Image refetch retries its complete three-step chain four times. — Matches the publisher-level genericRetry placement and frozen per-URL attempt counts.
- [Phase 04]: Image fan-out uses a Sendable result record in its throwing task group. — The compiler crashes on the equivalent labeled-tuple expression; the record preserves identical semantics.
- [Phase 04]: Reducer Done actions and handlers remain Result-based during the async consumer switch. — Limits the migration to request acquisition and preserves literal state-machine parity.
- [Phase 04]: TCA request effects use explicit do throws AppError with no casts or unknown fallback. — Keeps typed catch binding load-bearing and makes every failure send explicit.
- [Phase 04]: Reader image effects preserve cancellation identifiers and send ordering during acquisition conversion. — Protects the highest-frequency request path from reducer behavior drift.
- [Phase 04]: DownloadClient and file-operation run/catch effects remain outside the request consumer sweep. — They do not call the request facade and changing them would exceed the plan boundary.
- [Phase 04]: TagTranslator noUpdates remains an explicit failure action during the typed consumer switch. — Exactly preserves the previous inline Result switch outcome.
- [Phase 04]: Throwing DownloadClient functions await typed responses directly while Result-returning APIs rebuild Result explicitly. — Preserves public signatures and minimizes orchestration changes.
- [Phase 04]: Request now requires typed throws and the package source tree is Combine-free. — Makes the compiler enforce async conformance completeness and removes all publisher bridges.

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- Phase 8 (QUAL-02): NetworkingFeature tests couple to Phase 4's async migration but land in the hygiene phase (where CookieClient/ImageClient are reworked) — verify NetworkingFeature parity tests are written against the migrated async layer, not deferred silently.
- Phases 2 & 3 carry genuine parity risk (spike-gated); a failed spike must surface before committing implementation.
- Phase 4 Plan 14 hit its D-11 stop condition: the clean TCA trait recon found 66 unique sites across three patterns and 29 files, including 10 reducer-composition warnings outside the planned view-only surface.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-07-12T23:00:52.329Z
Stopped at: 04-14 D-11 checkpoint: 66 TCA deprecations require owner scope decision
Resume file: .planning/phases/04-concurrency-framework-migration/04-14-SUMMARY.md
