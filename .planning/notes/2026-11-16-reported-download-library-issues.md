---
date: "2026-11-16T16:53:00Z"
promoted: false
---

# Reported download and Library issues — recorded, deferred

Source: owner, msg5570, 2026-11-16 at 16:53 UTC.

Owner direction (msg5570): record these issues in GSD documentation; do not work on them for now.
This note captures requests and owner-reported observations only, not verified findings.

## 1. Download queue operations — feature request

**Status: recorded/deferred per owner msg5570. Investigation and implementation are not authorized now.**

For a selected queued item **other than the item currently downloading**, the owner requested:

- **Start now:** replace/preempt the currently downloading item and start the selected item now.
  What happens to the preempted item is undecided; this note assigns it no disposition.
- **Start next:** place the selected item next to start, regardless of galleries already waiting.
- **Other useful operations:** propose additional useful queue operations later, not now.

Follow-up msg5573 requests retaining these additional queue-operation **proposals only**, not
approved scope, in this same deferred entry:

- Move waiting items up or down.
- Move a waiting item to the end.
- Pause a queued item without losing its position.

These are recorded proposals for later consideration, not decisions or authorization to design or
implement them now. Unclear queue semantics remain future decisions. No queue design approval or
implementation is recorded by this note.

## 2. Library picker does not remember the last selection — reported bug

**Status: recorded/deferred per owner msg5570. Investigation and implementation are not authorized now.**

The owner reports that the Library picker does not remember the last selection and resets to
Favorites. This is owner-reported and unverified. Persistence and session boundaries are unspecified.

## 3. Incorrect data on a download card — reported bug

**Status: recorded/deferred per owner msg5570. Investigation and implementation are not authorized now.**

The owner reports incorrect data on a download card. The exact field and incorrect/expected values
are unknown; reproduction is not confirmed.

Last observed sequence reported by the owner:

1. Start multiple downloads.
2. Delete one.
3. Pause/resume repeatedly to adjust queue order.
4. Go to Home.
5. See wrong data on a download card.

This is an observation sequence, not a confirmed reproduction procedure. No root cause or data-loss
conclusion is established.

## Authorization boundary

All three items remain recorded/deferred per owner msg5570. Investigation and implementation are
explicitly **not authorized now**. This documentation-only capture creates no new phase, changes no
ROADMAP, STATE or verification status, and grants no authorization for source changes, tests, builds,
app runs, simulator, NAS or network operations. Further work requires separate owner authorization.
