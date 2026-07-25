---
phase: 14-analytics-instrumentation
plan: 17
completed: 2026-07-25
tasks_completed: 3
tasks_total: 3
requirements-completed: [ANALYTICS-01]
---

# 14-17 Summary: Phase close-out

**The README disclosure D-03 requires, the D-18 lint rule proven to fire, the D-20/D-21 vocabulary completion across every entry point, the stale opt-in wording corrected everywhere, both deferred items resolved, and ANALYTICS-01 verified against the shipped surface and closed.**

## Task 1 — The README Analytics section

A `## Analytics` section after Content & Copyright, in the file's prose conventions (no bullets, one bolded sentence, inline links). It was reconciled against the shipped code — `AnalyticsSignal`'s thirteen cases and `AnalyticsDefaultParameters`' six settings — not against the plans. It states: on by default with no opt-out (the single bolded sentence); the collected categories including searches-as-shape; the explicit never-collected list (gallery identifiers/tokens/titles, gallery and page URLs, keyword text, tag values, usernames, cookies and credentials, file paths); the hashed per-install identifier with no IP retention, without over-claiming stability (it resets when iOS regenerates the vendor identifier); the vendor privacy-policy link; and that a build without `Config/Analytics.local.xcconfig` sends nothing.

## Task 2 — Wording sweep and requirement close-out

- `ROADMAP.md` line 37 still read "privacy-first, **opt-in** analytics" — corrected to on-by-default-no-opt-out phrasing. The Phase Details goal line was already correct, exactly as the plan predicted. Zero `opt-in` occurrences remain in the file.
- Repo-wide sweep: `14-CONTEXT.md` and `14-RESEARCH.md` mention the stale wording as *history* and were left intact per the plan. `STATE.md`'s roadmap-evolution log described the phase as "privacy-first opt-in analytics" — annotated with the D-01 supersession rather than rewritten, so the historical record stays truthful. `14-17-PLAN.md`'s own instructions mention the words and are not descriptions.
- **ANALYTICS-01 closed.** Every instrumentation plan (14-10 … 14-16) reports green and the full suite passes. The acceptance line was corrected in two places where the shipped surface lawfully differs from wave 1's anticipation: it now names D-19's single audited `String`-accepting initializer (`SearchShape(keyword:)`, sentinel-proven content-free) instead of claiming "no bare `String`", and names D-16's **two** bucketing exceptions instead of one. Mapping row → Complete; trailing last-updated line refreshed.

## Task 3 — The D-18 lint rule, proven both ways

`analytics_sdk_import_boundary` in `.swiftlint.yml` `custom_rules`: rejects `import TelemetryDeck` outside `AppPackage/Sources/AnalyticsClient/` at error severity, excluding comment/doccomment/string match kinds (spellings copied from an existing rule — Phase 11 recorded that an invalid spelling silently discards the whole rule configuration).

- **Fires:** a temporary `LintProbe.swift` in `AppTools` containing the import produced the violation at error severity, then was removed.
- **Clean:** with the probe reverted, the full-package sweep reports zero occurrences of the rule, and `import TelemetryDeck` exists at exactly one path repo-wide.
- No suppression directive anywhere; the type wall in the signal API remains the primary control, this is the second layer.

## Beyond the plan's declared scope (owner-directed)

The owner chose "everything, including deferred items", and two mid-plan discoveries required decisions that were made interactively and recorded in `14-DECISIONS.md` before implementation:

1. **D-20 second correction — three pause sites, per-reducer.** Implementation found a third `toggleDownloadPause` owner (`DownloadInspectorReducer`) beyond the two D-20 named. Emission is per-reducer at all three sites — matching the family convention that management actions (`deleted`, `moved`) count from any screen while the snapshot diff owns transfer endings — with the direction read at request time from state each reducer already holds, so no action signatures changed and nothing double-counts (the diff ignores active↔inactive).
2. **D-21 naming correction — one name from both sites.** The detail screen's update path (`retryDownloadButtonTapped(.update)`) already emitted `.retried` from 14-13, which would have put one intent under two names. `.updated` now emits at queue time from the list's `updateDownloadDone` **and** from detail's retry completion when the pre-mutation badge was `.updateAvailable`; genuine error-retries keep `.retried`. The 14-13 test was replaced accordingly — a correction, not a regression.
3. **`DownloadOutcome` grew three cases in one pass** (`paused`, `resumed`, `updated`), completing the download-outcome family once rather than amending it repeatedly. `Buckets.swift`'s header — the other artifact D-16 flagged — now names both documented exceptions.
4. **The deferred search success-bucket gap is closed:** `searchFeatureTests` gained the `.module(.networkingFeature)` edge (the wave-6 manifest freeze lifted with wave 6), and the success-arm test pins three fixture galleries in the 2-5 bucket. `SearchFeatureTests` runs 10 tests.

## Verification

- Full default test plan: **TEST SUCCEEDED**, zero warnings, zero failures.
- The plan's automated verify passes: ANALYTICS-01 present in both files, zero Phase-14 `opt-in` lines in the roadmap.
- README acceptance greps all pass (never-collected words present, opt-out words confined to the one sentence, privacy-policy link, sends-nothing sentence, no home paths, no third-level heading).
- Lint rule verified firing and clean; build succeeds with zero warnings.

## For 14-18 (manual verification)

The owner setup step from 14-04 (`14-USER-SETUP.md` — create `Config/Analytics.local.xcconfig` with the app ID and a generated salt) is still pending and is a precondition for 14-18's signals-actually-arrive check.
