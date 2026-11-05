---
phase: 18
review: 18-REVIEW.md
titles: json
findings:
  - id: IN-01
    severity: info
    disposition: deferred
    title: "The member-ID parser accepts any host that ends in `e-hentai.org`"
  - id: IN-02
    severity: info
    disposition: deferred
    title: "Two new reducers use the `Reducer` suffix, not AGENTS.md's `Feature` suffix"
  - id: IN-03
    severity: info
    disposition: deferred
    title: "A link opened during the analytics choice routes at once, under the gate"
open: 0
total: 3
recorded: 2026-11-05T18:01:35.202Z
---

# Phase 18: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| IN-01 | info | deferred | Info, recorded for the owner; not fixed in the post-execution gate run (gate brief: fix Critical/Warning, record Info). A one-line host check plus a parser case if taken up |
| IN-02 | info | deferred | Info, naming only; the plans (18-02, 18-10) named these types. A rename touches tests and `SettingPath`; left for a later cleanup if the owner wants it |
| IN-03 | info | deferred | Info, matches DD-07 and D-04 as written; listed for the owner as a product question (hold links until both screens are answered?) |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
