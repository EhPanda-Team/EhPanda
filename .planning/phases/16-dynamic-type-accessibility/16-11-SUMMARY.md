---
phase: 16-dynamic-type-accessibility
plan: 11
subsystem: accessibility
tags: [dynamic-type, re-verification, d-15-parity, d-13, round-1-closure]

# Dependency graph
requires:
  - phase: 16-10
    provides: Round-1 findings report and owner dispositions
provides:
  - "`16-SWEEP.md § Round-1 report › ### Re-verification batches`: per-batch build HEAD, installed bundle id, re-walked cells, `.large` parity comparisons"
  - Closed round-1 findings loop: 0 `open` findings, 0 `pending`/`re-verify` matrix cells, 5/5 D-13 dispositions, `### Round-1 closure` counts, owner `ROUND1-CLEAR`
affects: [16-12, accessibility-round-2]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
# The two closure commits are shared with plan 16-10, whose checkpoint resolved on the same owner signal.
actuals:
  tokens: 10009
  tasks: 3
  commits: 2
  plan_head_before: db560275d3617363425dafe59918e2e26bad5e77

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - .planning/phases/16-dynamic-type-accessibility/16-SWEEP.md
    - .planning/phases/16-dynamic-type-accessibility/16-RECONCILIATION.md

key-decisions:
  - "Round 1 is closed on the owner's `ROUND1-CLEAR` (2026-09-11T08:04Z); the closure counts are measured from the table, and the persisted matrix is labelled historical stored results rather than a current-build verdict."
  - "The five § D-04 `minimumScaleFactor` sites read `removed-by 59fb2eb9`, the commit `git log -S'minimumScaleFactor' -- AppPackage/Sources` returns on this branch (five lines removed, none added)."
  - "A11Y-01 stays incomplete until plan 16-12's owner sign-off."

requirements-completed: []

coverage:
  - id: D1
    description: "Round-1 closure consistency check: no `pending`/`re-verify` matrix cell, no `open` finding, `### Round-1 closure` present, `minimumScaleFactor` live count 0"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "f=.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md; awk '/^## Matrix/,/^## Findings/' \"$f\" | grep -c '| pending\\|| re-verify'; awk '/^## Findings/,/^## D-13/' \"$f\" | grep -c '| open'; grep -c '### Round-1 closure' \"$f\"; grep -rn minimumScaleFactor AppPackage/Sources | wc -l  # prints 0 / 0 / 1 / 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every re-verified finding holds both halves of D-15 (no information loss at XXL/AX3/AX5; `.large` parity) as recorded per batch"
    requirement: A11Y-01
    verification: []
    human_judgment: true
    rationale: "Recorded from historical batch walks and owner-reviewed before/after images; not re-run in this continuation."

# Metrics
duration: historical batch execution unavailable; closure continuation 2026-09-11 about 6 min (shared with 16-10)
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 11: Round-1 re-verification and closure Summary

**Sixteen recorded re-verification batches, one D-15 parity finding (#35, owner-accepted), all 38 round-1 findings `re-verified` or `accepted`, five D-13 items dispositioned, and the findings loop closed on the owner's `ROUND1-CLEAR` at 2026-09-11T08:04Z.**

## Performance

- **Duration:** historical batch execution not independently recoverable; this closure continuation ran about 6 min on 2026-09-11 (shared with plan 16-10)
- **Started:** batch 1 re-verification 2026-09-03; continuation 2026-09-11T08:09Z
- **Completed:** 2026-09-11
- **Tasks:** 3 (Task 1 batches, historical; Task 2 owner loop, resolved; Task 3 closure check, run today)
- **Files modified:** 2 (`16-SWEEP.md`, `16-RECONCILIATION.md`)

## Accomplishments

- **Batches processed (Task 1).** `16-SWEEP.md § Round-1 report › ### Re-verification batches` holds sixteen entries: fix batches 1, 2, 2b, 3, 4 (2026-09-03); the iPad login-gated walk, batches 5b, 6, the iPad batch 7 walk, the unblock walk (8), the NewDawn mock walk (9) and NewDawn scroll fix (10) (2026-09-04); the owner-requested iPhone 17e AX5 rerun (2026-09-04); the targeted owner fixes, the iPhone 17e Large rerun and the E-Hentai Settings ValuePicker fix (2026-09-05). Each fix-batch entry records the commits covered, the build installed (HEAD and bundle id), the cells re-walked, the before-capture source and the `.large` parity result. Individual historical batch hashes are provenance inside those entries; the branch was rewritten after batch 1, so they are not asserted to be separately reachable commits.
- **Parity findings.** One raised: #35, the D-15 `.large` delta on the Detail comment cell carrying a vote score, recorded in fix batch 1 when the five `minimumScaleFactor` sites were removed. One resolved: the owner accepted #35 on 2026-09-09. Every other `.large` comparison in the batch log is a matched `parity` row, not a finding.
- **D-13 dispositions (final).** 1 Detail stats strip `fixed` (2026-09-09); 2 long-tag clip `fixed` (2026-09-09); 3 reader page counter `fixed` (2026-09-09); 4 Favorites trailing glyph / page count `fixed` (2026-09-11, basis: iPhone #6 re-verification plus the 2026-09-09 sampled iPad populated Favorites AX3/AX5 checks); 5 hero-carousel title `accepted` (2026-09-09: keep the card height limit; long titles may truncate with an ellipsis).
- **Task 2 resolved.** The owner's resume signal, delivered at 2026-09-11T08:04Z through the orchestrator's structured question: `D13-4=fixed`, `#28=fixed`, `ROUND1-CLEAR` (conditional on the two dispositions being recorded). Recorded verbatim in `### Owner review closure — 2026-09-11`. Earlier dispositions (#4, #7, #31; #11, #26; #23, #35; #37; D13-1/2/3/5) were preserved unchanged.
- **Task 3 closure check.** `### Round-1 closure` records: 504 persisted cells (397 `pass`, 95 historical finding references as 90 `finding:#N` plus 5 `accepted` on #31's cells, 12 system-overlay `n/a`; 0 `pending`, 0 `re-verify`); 38 findings (32 `re-verified`, 6 `accepted`, 0 `open`); D-13 5/5 (4 `fixed`, 1 `accepted`); parity findings 1 raised / 1 resolved; `minimumScaleFactor` live count 0 with the five § D-04 sites marked `removed-by 59fb2eb9`; `ROUND1-CLEAR` 2026-09-11T08:04Z.

## Task Commits

| Task | Commit | Result |
| --- | --- | --- |
| Task 1: fix-batch re-verification (historical) | recorded in `### Re-verification batches`; implementation on this branch at `59fb2eb9` (the pre-rewrite object `5614f486` cited on 2026-09-08 still resolves but is not an ancestor of HEAD) | Historical batches recorded; not re-run today |
| Task 2: owner review loop, final dispositions | `7d7b8d43` | docs(16): record D13-4 and #28 owner dispositions |
| Task 3: round-1 closure consistency check | `9f3f3035` | docs(16): close round-1 findings loop |

Task 3 automated check after `9f3f3035`: `0` / `0` / `1` / `0` (pending-or-re-verify cells, open findings, closure sections, live `minimumScaleFactor` sites).

## Files Created/Modified

- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md`: § Findings row 28; § D-13 named edge cases row 4; `### D-13 dispositions requested` (five cells, intro sentence); § D-04 checklist `minimumScaleFactor` rows (`removed-by 59fb2eb9`); `### Owner review closure — 2026-09-11`; `### Round-1 closure`.
- `.planning/phases/16-dynamic-type-accessibility/16-RECONCILIATION.md`: `## Round-1 closure — 2026-09-11` note; history retained.

## Decisions Made

- Closure counts were measured from the table by script, not copied from the halted summary; the 95 "finding references" figure is reported as its two components (90 `finding:#N` + 5 `accepted`) so the matrix vocabulary stays exact.
- The `removed-by` hash was taken from `git log -S` on the current branch and verified (five removals, zero additions, ancestor of HEAD) rather than from batch-log provenance.

## Deviations from Plan

- The plan's Task 2 loop expected `FIXED=<hashes>` batch signals; after D-01 amendment 2 the batches were agent fix commits, and the final signal came as three tokens through the orchestrator rather than a chat line. Recorded as delivered.
- Task 3's action says "reopen the checkpoint if `minimumScaleFactor` is nonzero"; it was 0, so no reopen occurred.

## Explicit limits

- The persisted matrix is stored historical results from the original sweep and the recorded batches, not a current-build verdict.
- `16-TARGETED-RECHECK.md` (2026-09-08) and `16-LOGIN-COVER-RECHECK.md` (2026-09-09/10) are sampled evidence for specific items; they do not replace the matrix.
- Findings #11, #26 and #28 are `re-verified` on owner provenance plus, for #28, the 2026-09-09 sampled agent check; none is a new agent device pass.
- Nothing was re-run on 2026-09-11: no simulator check, build, or test. No Swift, asset, lint-config or image change was made.

## Issues Encountered

None.

## User Setup Required

None.

## Next Phase Readiness

- Plan 16-12 (wave 11) is unblocked: add the `no_minimum_scale_factor` SwiftLint rule (precondition, live count 0, is met) and run the owner-signed UAT gate that completes A11Y-01.
- Round-2 plans (16-13 onward) remain gated on 16-12.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-11*

## Self-Check: PASSED

All referenced files exist; commits `7afc084a`, `1f6408b3`, `feb4260f`, `59fb2eb9`, `7d7b8d43`, `9f3f3035` resolve on `feature/gsd-phase-16`; `5614f486` resolves as an object but is not an ancestor of HEAD, exactly as stated above. `minimumScaleFactor` live count 0. No Swift, asset, lint-config or image file was changed; no absolute home path was written.
