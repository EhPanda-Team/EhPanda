---
phase: 18
review: 18-REVIEW.md
titles: json
findings:
  - id: IN-01
    severity: info
    disposition: fixed
    title: "The member-ID parser accepts any host that ends in `e-hentai.org`"
  - id: IN-02
    severity: info
    disposition: skipped
    title: "Two new reducers use the `Reducer` suffix, not AGENTS.md's `Feature` suffix"
  - id: IN-03
    severity: info
    disposition: skipped
    title: "A link opened during the analytics choice routes at once, under the gate"
open: 0
total: 3
recorded: 2026-11-05T18:01:35.202Z
---

# Phase 18: Code Review Disposition

| Finding | Severity | Disposition | Source |
|---------|----------|-------------|--------|
| IN-01 | info | fixed | Fixed in `c3ef39ac9` (the lead's call): only the exact contact link host `forums.e-hentai.org` over `https`, path `/index.php`, digits only; look-alike host tests added |
| IN-02 | info | skipped | Accepted exception (the lead's decision, 2026-11-05): screens inside an existing `*Reducer` tree keep the `Reducer` suffix; not renamed |
| IN-03 | info | skipped | Accepted by the lead (2026-11-05): no user-visible difference, since nothing is shown and no analytics is sent before the choice; the content fetch after the age confirmation is allowed by D-04 and DD-07 |

Dispositions: `open` (recorded, not yet triaged), `fixed`, `skipped`, `deferred`.
Set `deferred` by hand and put the reason in the Source cell; both are preserved. A `|` in the reason is kept as prose and escaped on the next run.
Re-running the gate keeps every row it can. A row the current review no longer reports is kept and its Source cell flagged, so a finding does not leave this record silently. ONE exception: when a finding id is REUSED by a different finding, the earlier decision cannot keep a row — the id is taken — and it is dropped. A RECORDED decision (anything but `open`) is named on the console when that happens; a row still at `open` is replaced silently, because `open` records no decision to lose.
