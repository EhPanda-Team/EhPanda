# Phase 16 execution recovery — 2026-09-08

**Fresh inspection available:** `16-TARGETED-RECHECK.md` records the owner's subsequent sim-use review request. It reproduces #4/#7 on iPhone Toplists, #26 at the iPad Auto-Play site, and #31 in the iPhone toast; it also separates current non-reproductions and unavailable states. Use that report for the next review discussion instead of treating the historical list below as a current defect inventory.

The owner authorized reconciliation of existing work and resumption at the remaining review checkpoint. Plans 16-10 and 16-11 now have `status: halted` summaries so dependency discovery preserves the work without treating either plan as complete.

## Verified repository evidence

- `7afc084a`: round-1 report.
- `1f6408b3`: reflow catalogue and suggestions.
- `5614f486`: layout implementation, batch history and later cover revision records.
- No `minimumScaleFactor` matches remain under `AppPackage/Sources`.
- The historical matrix has 397 pass / 95 finding / 12 n/a cells. Later targeted checks do not replace that matrix, and its finding references are not a current unresolved-defect count.
- D-01 amendment 2 authorizes agent-written fixes. The original owner-only restriction in the plans and roadmap is superseded; owner dispositions and round-1 sign-off remain required.

## Remaining review

The Findings table still labels these rows open. They are historical observations needing disposition or reconciliation against later evidence, not newly reproduced defects:

| Finding | Review subject |
| --- | --- |
| #4 | Search/filter field loses its visible contents at some accessibility sizes |
| #7 | Remaining Toplists navigation-title treatment |
| #11 | Downloads delete confirmation clips at iPhone portrait AX5 |
| #23 | Detail delete confirmation loses message/Cancel in iPhone landscape |
| #26 | Selected checkmark disappears in Runs and Auto-Play menus |
| #28 | E-Hentai Settings picker rows overlap |
| #31 | Error-toast subtitle truncation |
| #35 | Default-size comment score/date layout parity |
| #37 | iPad AX3 native delete alert clips its button row; the status already records “owner decision: accept as a system defect” |

Preserve the recorded acceptance for #37; do not request it again. Its status label is inconsistent with that annotation and must be normalized in the eventual closure pass. The remaining eight items need owner disposition or fresh verification where later changes may resolve them.

The five D-13 cases still need explicit dispositions:

1. Detail stats strip — findings record both-device re-verification (#14).
2. Long-tag clipping — findings record both-device re-verification (#15).
3. Reader page counter — finding #22 is re-verified; the D-13 row still describes an earlier batch.
4. Favorites trailing glyph/page count — finding #6 is re-verified; the D-13 row retains obsolete iPad-login wording.
5. Hero-carousel title — finding #1 is re-verified; subsequent cover revisions have their own pending owner review.

Use `D13-<n>=fixed` or `D13-<n>=accepted: <reason>`. Existing evidence must support a fixed disposition before its row closes. For remaining findings, record acceptance with a reason or identify the next fix/re-verification batch. No disposition is inferred from the recovery approval.

## Resume boundary

Continue the review at plan 16-11 Task 2 while retaining plan 16-10's unresolved disposition requirements. Before declaring round 1 clear, reconcile old matrix references and D-13 descriptions against the recorded batch evidence and any necessary fresh checks. The latest cover evidence is described in `.planning/quick/20260908-slideshow-viewport-cap/REVISION.md`.

After all findings and D-13 items are resolved, obtain the owner's `ROUND1-CLEAR`, execute plan 16-11 Task 3, then replace the halted summaries with complete summaries and update the roadmap. Until then, leave plan checkboxes and requirements incomplete. No phase completion or production-code change is part of this recovery.

## Subsequent owner disposition

On 2026-09-08 the owner accepted #31 (error-toast truncation when content does not fit): 「第四個我覺得展示不下就展示不下直接接受」. Remove #31 from the pending review set. The acknowledgment of seeing the first two screenshots is not acceptance of those findings. Auto-Play comparison screenshots are now present in the external evidence page.

Owner update 2026-09-08: #4 accepted as Apple defect, no app fix; #7 accepted as-is. Together with #31 and #37 these need no repeat approval. Auto-Play (#26) remains under discussion. See `16-TARGETED-RECHECK.md`.
