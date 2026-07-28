# Deferred Items — Phase 15

Out-of-scope discoveries found while executing this phase. Logged, not fixed.

## ROADMAP.md progress table is missing a Phase 16 row

The `| Phase | Plans Complete | Status | Completed |` table in `.planning/ROADMAP.md` ends at
row 15. Phase 16 (Dynamic Type Accessibility) has a phase entry and a checklist bullet but no
progress row. Row 15 also carried Phase 16's name until plan 15-07 corrected it to
"Continued Background Downloads" — the row the plan's own tooling had to update.

## ROADMAP.md execution-order line stops at 15

`**Execution Order:** Phases execute in numeric order: 1 → … → 15` predates the Phase 16 entry
and should end at 16.

Both are documentation staleness in a file outside this phase's edit scope (the plan scopes
Task 2 to the Phase 15 detail section). Neither affects any code or gate.
