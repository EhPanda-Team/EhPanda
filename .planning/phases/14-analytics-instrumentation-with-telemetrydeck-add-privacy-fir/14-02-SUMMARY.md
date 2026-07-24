---
phase: 14-analytics-instrumentation
plan: 02
subsystem: planning
tags: [decisions, checkpoint, privacy, analytics, taxonomy]

# Dependency graph
requires:
  - phase: 14-analytics-instrumentation
    provides: the locked D-01 … D-14 spine in 14-CONTEXT.md and the five Open Questions in 14-RESEARCH.md that this plan resolves
provides:
  - D-15 … D-19 recorded as locked inputs every downstream Phase 14 plan can cite
  - D-16 as a written amendment to D-08, giving the bucketing guarantee a second documented exception
  - D-19 as a written amendment to D-09, permitting one String parameter on AnalyticsClient's public API
  - The identifier salt decided once, with its write-once permanence stated
  - Plan 14-17's conditional SwiftLint task confirmed in scope
affects: [14-03, 14-04, 14-05, 14-17]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "An amendment to a locked decision is recorded as an amendment, never as a clarification, so a later auditor finding the mismatch finds the explanation with it"
    - "Consequences of a decision are flagged in the decision itself and assigned to their owning plan, rather than fixed outside the deciding plan's file boundary"

key-files:
  created:
    - .planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/14-DECISIONS.md
  modified: []

key-decisions:
  - "D-15: the full eleven-case `Category` enum ships, including `imageSet` and `private` — D-07's nine-name parenthetical was incomplete recitation, not deliberate narrowing"
  - "D-16: per-namespace tag counts ship as exact `Int` values, not through `CountBucket` — the owner declined the recommendation and read D-08's exception list as non-exhaustive, which amends D-08 to carry two documented exceptions"
  - "D-17: a random 64-character salt is generated now and stored beside the app ID in the gitignored `Config/Analytics.local.xcconfig`; the value is write-once, because changing it after release permanently resets retention and DAU/MAU"
  - "D-18: the SwiftLint `custom_rules` entry rejecting the TelemetryDeck SDK import outside `AnalyticsClient` is approved, putting plan 14-17's conditional lint task in scope"
  - "D-19: `TagNamespaceCounts(tags:)` and `SearchShape(keyword:)` live inside `AnalyticsClient` as the audited reduction boundary — an amendment to D-09 permitting exactly one `String` parameter on the module's public API"

patterns-established:
  - "A decision that widens what is collected still states its cost: D-16 records that exact counters against a stable per-install identifier are more distinguishing than buckets, so the widening is auditable rather than merely permitted"
  - "Scope discipline at a decision boundary: the three artifacts D-16 invalidates are named, assigned owners, and deliberately left uncorrected because this plan's file boundary is one file"

requirements-completed: []

coverage:
  - id: D1
    description: "All five research Open Questions carry a recorded owner disposition before any taxonomy code is written"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "grep -c '^### D-1[5-9]' 14-DECISIONS.md — 5"
        status: pass
    human_judgment: false
  - id: D2
    description: "The salt is decided exactly once, with its irreversibility stated (T-14-07)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "14-DECISIONS.md §D-17 — 'This value is write-once' plus the retention/DAU/MAU reset consequence"
        status: pass
    human_judgment: false
  - id: D3
    description: "The D-09 wall placement is a recorded decision rather than an implementer's judgement call, with the departure from D-09's wording stated in plain terms (T-14-01)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "14-DECISIONS.md §D-19 — 'This amends D-09, and the departure is literal', naming the one String parameter and scoping the amendment to a single initializer"
        status: pass
    human_judgment: false
  - id: D4
    description: "No decision narrows what D-01 … D-14 permit the app to collect"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "D-15 widens (eleven cases, not nine); D-16 widens (exact counts, not buckets); D-17, D-18 and D-19 do not touch the allow-list"
        status: pass
    human_judgment: false
  - id: D5
    description: "The generated doc leaks no absolute home path and names no other local project"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "an absolute-home-path scan of 14-DECISIONS.md returns 0 matches"
        status: pass
    human_judgment: false

# Metrics
duration: ~6 min
completed: 2026-07-24
status: complete
---

# Phase 14-02: Owner disposition of the five open questions Summary

**The five questions research left open are answered and locked as D-15 … D-19, with the two that depart from a locked decision — D-16 amending D-08's bucketing guarantee and D-19 amending D-09's no-bare-`String` wall — written as amendments rather than clarifications, so a future auditor finding the mismatch finds the explanation with it.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-07-24T03:31:31Z
- **Completed:** 2026-07-24
- **Tasks:** 1 (a `checkpoint:decision` gate, answered by the owner before execution)
- **Files modified:** 1 created, 0 modified

## Accomplishments

- `14-DECISIONS.md` exists with five sections matching `^### D-1[5-9]`, each recording an explicit disposition rather than a restatement of its question. Four accepted the recommendation; one (D-16) declined it.
- **D-16 is the consequential one and is written as an amendment to locked decision D-08.** It names the second documented exception, states that exact counters measured against D-10's stable per-install identifier are more distinguishing than buckets — the aggregate re-identification surface D-08's bucketing existed to reduce — and flags three downstream artifacts that now assert something untrue, each assigned to its owning plan.
- **D-19 is written as an amendment to locked decision D-09**, stating in plain terms that `SearchShape(keyword: String)` is a `public init` on a `public` type and therefore puts one `String` parameter on `AnalyticsClient`'s public API, that D-09 as written forbids exactly that, and that the owner amended D-09 to permit this single audited initializer. It scopes the amendment to one initializer, notes that `TagNamespaceCounts(tags: [GalleryTag])` is compliant as written because `GalleryTag` is a domain type, and lists what stays unchanged.
- **D-17 records the salt's write-once permanence** — changing it after release re-derives every anonymized identifier, permanently resetting retention and DAU/MAU with no migration — and assigns the xcconfig/`Info.plist` plumbing to plan 14-04.
- **D-18 puts plan 14-17's conditional SwiftLint task in scope**, and restates that the repository's no-suppression policy binds the new rule exactly as it binds the existing ones.
- Every decision names the plan that owns its implementation, so plans 14-03 through 14-18 can each cite a specific answer.

## Task Commits

1. **Task 1: Owner disposition of the five open questions** — `79a0ab29` (docs)

_The task is a `checkpoint:decision` gate. The owner's dispositions were supplied before execution; this plan performed the second half of the task's action — writing and committing the record._

## Files Created/Modified

- `.planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/14-DECISIONS.md` — five decision sections plus a preamble that names D-16 and D-19 as the two amendments up front, so a reader skimming for "what changed in the locked spine" finds them without reading all five

## Decisions Made

- **D-15 — the full eleven-case `Category` enum ships**, `imageSet` ("Image Set") and `private` ("Private") included. The recommendation was accepted: D-07's nine-name parenthetical was incomplete recitation of the named entity, not deliberate narrowing. `Category.private` is display-only in this codebase (decision 09-02) and may never occur in a payload; it is included anyway, because excluding it for being unlikely would narrow D-07 by a different route.
- **D-16 — per-namespace tag counts ship as exact `Int` values, not through `CountBucket`.** The one answer that went against its recommendation. The owner read D-08's exception list as non-exhaustive. D-08 now carries two documented exceptions: exact search-keyword length, and exact per-namespace tag counts. The change widens rather than narrows collection, so it does not violate the phase's no-narrowing rule, but it increases the aggregate re-identification surface, and the section says so.
- **D-17 — a random 64-character salt, generated now, stored in the same gitignored `Config/Analytics.local.xcconfig` as the app ID and surfaced through a second `Info.plist` key.** Write-once: changing it after release makes every existing install look new to the vendor.
- **D-18 — the `custom_rules` entry rejecting the TelemetryDeck SDK import outside `AnalyticsClient` is approved.** It makes D-12 structural rather than review-held, a second layer behind the D-09 type wall.
- **D-19 — the D-09 wall sits at the `AnalyticsClient` module boundary.** `TagNamespaceCounts(tags:)` and `SearchShape(keyword:)` are the audited reduction boundary; the `AppModels`-derivation fallback was declined because it spreads the reduction across five gallery-open sites and every search site, in a module whose tests do not prove it.

## Flagged Follow-ups (recorded in D-16, deliberately not fixed here)

This plan's `files_modified` is one file and its verification asserts that nothing outside `.planning/` is modified, so the three artifacts D-16 invalidates were flagged rather than corrected:

| Artifact | What is now wrong | Owning plan |
|----------|-------------------|-------------|
| `AppPackage/Sources/AnalyticsClient/Buckets.swift` | Header comment reads "The single documented exception — exact search-keyword length — is minted elsewhere and is deliberately not expressible here." There are now two exceptions. | **14-17** (close-out), or **14-03** if it touches the file first. Neither lists `Buckets.swift` in `files_modified` today, so whichever takes it must add it. |
| `ANALYTICS-01` in `.planning/REQUIREMENTS.md` | Reads "every counter and duration ships as a bucket, with exact search-keyword length as the single documented exception". | **14-17**, which already owns closing out the requirement. |
| Plan 14-03's `TagNamespaceCounts` | Must carry exact `Int` counts, not `CountBucket` values; plan 14-05's `AnalyticsSignal` cases carrying tag counts follow suit. | **14-03**, then **14-05**. |

`CountBucket` remains correct and required for every other counter, and `DurationBucket` is untouched by D-16.

## Deviations from Plan

None — the plan executed exactly as written. The task's first half (present the five questions and wait) was satisfied by the owner's dispositions arriving before execution; the second half (write, commit, record) is what this plan performed.

## Issues Encountered

None.

## Verification Run

```
grep -c '^### D-1[5-9]' 14-DECISIONS.md   # 5   (plan's <automated> gate)
absolute-home-path scan of 14-DECISIONS.md # 0   (CLAUDE.md no-absolute-home-paths rule)
git diff --name-only HEAD~1 HEAD | grep -v '^\.planning/'   # empty
```

- All five headings present and correctly numbered.
- No absolute home path; no other local project named anywhere in the file.
- No file outside `.planning/` modified by the task commit; no deletions in the commit.

## User Setup Required

None from this plan. The salt D-17 commits to must be generated and placed in `Config/Analytics.local.xcconfig` alongside the app ID — plan **14-04** owns that plumbing, and both values are owner-supplied at that point.

## Next Phase Readiness

- **Wave 1 is complete.** Plans 14-03 and 14-04 both declare `depends_on: [14-01, 14-02]` and are now unblocked.
- Plan **14-03** must build `TagNamespaceCounts` with exact `Int` counts (D-16), mark `SearchShape(keyword:)` in source as the single audited D-09 exception (D-19), test it with sentinel keywords, and mirror all eleven `Category` cases (D-15).
- Plan **14-04** owns the salt and app-ID plumbing (D-17).
- Plan **14-17**'s conditional SwiftLint task is confirmed in scope (D-18), and it inherits two wording corrections from D-16.
- Carry-forward from 14-01, still in force: every `xcodebuild` invocation in this phase needs `-skipMacroValidation -skipPackagePluginValidation`.

## Self-Check: PASSED

- `14-DECISIONS.md` — FOUND
- `14-02-SUMMARY.md` — FOUND
- Commit `79a0ab29` — FOUND

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*
