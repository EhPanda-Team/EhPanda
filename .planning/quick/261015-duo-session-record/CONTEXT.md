---
type: retrospective-session-context
recorded: 2026-10-15
session_dates: [2026-10-14, 2026-10-15]
status: implemented-with-unselected-proposals
source_branch: claude/iphone-duo-support-c0b23d
implementation_head: 79a59892e0648457ae88710a552448ffa6a45aa8
---

# iPhone Duo and landscape support: complete session record

This record recovers the entire session, including the inherited handoff, owner choices,
implementation corrections, validation findings, and unselected proposals. It was written
retrospectively after the owner pointed out that these decisions belonged in GSD docs.
The original implementation commits updated only the scroll-edge inventory; most evidence
was left in ignored `.build`. This is a documentation failure, not evidence that a GSD plan
had been approved or executed. No retrospective PLAN is presented as a prior approval.

## Read this record

- [Decision log](DISCUSSION-LOG.md): all owner decisions and their supersession, with implementation references.
- [Summary](SUMMARY.md): commit ledger and current delivery boundary.
- [Verification](VERIFICATION.md): retained evidence, failures, corrections and remaining gaps.
- [Learnings](LEARNINGS.md): findings grounded in this session.
- [Wide-screen proposal](proposal/PROPOSAL.md): Favorites, Search and Downloads, nine native screenshots, still awaiting selection.
- [Migration](MIGRATION.md): integration state and rewritten commit mapping.

The final decisions in DISCUSSION-LOG take precedence over historical evidence reports.
In particular: Home splitting now includes fully open Duo and eligible iPad landscape;
iPad uses a plain 2 pt divider; the move button is opposite the slider; iPad retains its
lower Close; native Duo side tabs remain; and normal simulator launches must clear fixture flags.

## Scope and provenance

The user supplied a handoff with four existing commits, then approved and refined Home,
reader, presentation and toolbar behavior through this session. Direct owner messages and
option answers are the authority for product choices. Code and Git establish what was
implemented. Historical verification reports and retained logs establish what was tested;
static screenshots do not establish navigation, network or resize correctness.

Ordinary layout/presentation decisions use the current window's size classes and measured
geometry. Explicit device-capability requirements (automatic reader orientation and Duo/iPad
landscape panes) are separate product policies; they do not reinstate idiom-based width guesses.
Unrelated Phase 17 capture work remains in progress and is not marked complete by this record.

No push, PR, baseline promotion, or production implementation of the three wide-screen
proposals was requested. The preview must remain available during review and worktree migration.
