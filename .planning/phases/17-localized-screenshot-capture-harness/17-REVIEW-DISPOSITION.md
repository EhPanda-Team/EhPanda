---
phase: 17
review: 17-REVIEW.md
titles: json
findings:
  - id: WR-01
    severity: warning
    disposition: fixed
    title: "The pager's turn gate is not reset when the pager is rebuilt"
  - id: WR-02
    severity: warning
    disposition: skipped
    title: "The capture overlay preference reaches only Filters and the reader, not the other sheets"
  - id: IN-01
    severity: info
    disposition: fixed
    title: "The correction count carries over between unrelated misses"
  - id: IN-02
    severity: info
    disposition: deferred
    title: "verify-release.py would not catch a Release leak of the capture overlay key"
  - id: IN-03
    severity: info
    disposition: deferred
    title: "RootView imports AppComponents unconditionally but uses it only in DEBUG"
open: 0
total: 5
recorded: 2026-11-04T13:55:00.000Z
---

# Phase 17: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| WR-01 | warning | fixed | fb1ea4b18 (17-REVIEW-FIX.md) |
| WR-02 | warning | skipped | accepted / won't-fix: owner msg 1627, "the required pages don't show a home indicator. Do nothing." No code change. (17-REVIEW-FIX.md) |
| IN-01 | info | fixed | 443e74541 (17-REVIEW-FIX.md) |
| IN-02 | info | deferred | deferred to Phase 18: owner msg 1627 |
| IN-03 | info | deferred | deferred to Phase 18: owner msg 1627 |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
