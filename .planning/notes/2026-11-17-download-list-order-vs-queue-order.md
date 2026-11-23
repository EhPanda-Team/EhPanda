---
date: "2026-11-17T13:00:00Z"
promoted: true
promoted_to: .planning/quick/261123-1dk-download-queue-order-and-queue-operation/
---

# Download list order vs queue order: recorded, deferred

Source: owner, 2026-11-17.

Owner direction: record this as a deferred task; do not work on it for now.

## Investigation task, not a bug

**Status: resolved by quick task 261123-1dk (owner authorized 2026-11-23; decision A-1).** Findings: the list sorts by display status, then newest folder first, and never reads the queue; the queue runs FIFO by last enqueue; no record ever specified that they match (the sort predates the persisted queue). Owner decision: the waiting group now follows queue order. See `.planning/quick/261123-1dk-download-queue-order-and-queue-operation/` (`261123-1dk-CONTEXT.md` holds the evidence).

The owner observes that the order of the downloads list does not match the queue order. The owner
notes this may be a misunderstanding of the intended behavior, so this item is an investigation,
not a confirmed defect.

When authorized, the investigation should establish:

- What order the downloads list is specified to use, and where that is decided.
- What order the queue actually runs in.
- Whether the two are meant to match. If they are, it is a bug; if not, whether the difference
  should be made clearer to the user.

Related, and also deferred: the queue-operation feature request in
`.planning/notes/2026-11-16-reported-download-library-issues.md` (item 1).

## Authorization boundary

This item remains recorded/deferred per owner decision. This documentation-only capture creates no
new phase, changes no ROADMAP, STATE or verification status, and grants no authorization for source
changes, tests, builds, app runs, simulator or network operations. Further work requires separate
owner authorization.
