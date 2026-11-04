---
phase: 17
review: 17-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: open
    title: "The pager's turn gate is not reset when the pager is rebuilt"
  - id: WR-02
    severity: warning
    disposition: open
    title: "The capture overlay preference reaches only Filters and the reader, not the other sheets"
  - id: IN-01
    severity: info
    disposition: open
    title: "The correction count carries over between unrelated misses"
  - id: IN-02
    severity: info
    disposition: open
    title: "verify-release.py would not catch a Release leak of the capture overlay key"
  - id: IN-03
    severity: info
    disposition: open
    title: "RootView imports AppComponents unconditionally but uses it only in DEBUG"
open: 5
total: 5
recorded: 2026-11-04T13:34:36.091Z
---

# Phase 17: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | open | - |
| WR-02 | warning | open | - |
| IN-01 | info | open | - |
| IN-02 | info | open | - |
| IN-03 | info | open | - |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
