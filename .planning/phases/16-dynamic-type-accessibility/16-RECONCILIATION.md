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

Owner update 2026-09-09: #35 accepted after the review question explicitly described score/date appearing beneath the author at normal text size. The owner replied “yes.” This closes the recorded comment-card parity disposition only; no other finding, D-13 disposition, or ROUND1-CLEAR is inferred.

Owner update 2026-09-09: D13-1 (detail statistics) and D13-2 (long tags) approved as fixed based on the recorded passing checks on both devices. The owner replied “yes” to the question naming those two cases. Their disposition cells are now filled; D13-3 through D13-5 and ROUND1-CLEAR remain pending.

Owner update 2026-09-09: D13-3 (reader page counter) approved as fixed based on the recent native-toolbar checks showing complete sampled page numbers at AX5 on iPhone and iPad, including the final leading iPad title. The owner replied “yes” to the question naming this case. Its stale batch-1 description is reconciled with `16-TARGETED-RECHECK.md`; D13-4, D13-5 and ROUND1-CLEAR remain pending.

Owner update 2026-09-09: D13-4 (Favorites trailing glyph and page count) remains pending. The owner requested leaving it open for now and continuing with other review questions; no fresh Favorites check or acceptance is inferred.

Owner update 2026-09-09: D13-5 (hero-carousel long-title truncation) accepted. The owner accepts ellipsis within the bounded-height carousel card. This is a disposition of title truncation, not blanket approval of all cover layouts. D13-4 remains pending at the owner’s request; ROUND1-CLEAR has not been given.

Owner update 2026-09-09: finding #11 (Downloads delete confirmation) confirmed checked and fixed by the owner. Its Findings status is now re-verified with owner provenance; no current-agent device check is claimed. Finding #23 remains pending while the Detail delete confirmation entry and Cancel action are clarified.

Owner update 2026-09-09: finding #23 (Detail delete confirmation at iPhone landscape AX5) remains pending at the owner’s request. Continue reviewing other items; no acceptance, fix confirmation, or fresh device check is inferred.

Owner update 2026-09-09: finding #28 (E-Hentai Settings Multi-Page Viewer row overlap) remains pending. The owner does not recall whether it was fixed and requested leaving it open while continuing other review questions. No verification or acceptance is inferred.

Owner update 2026-09-09: finding #26 (Runs and Auto-Play selected checkmarks) confirmed fixed by the owner. Its status is re-verified with owner provenance, not a claim of a new agent device pass.

## Current review boundary — 2026-09-09

This review closes #11 and #26 as owner-confirmed fixed, #35 as owner-accepted, D13-1/2/3 as owner-approved fixed, and D13-5 as owner-accepted truncation. The previously accepted #37 status has been normalized. Prior #4/#7/#31 acceptances remain preserved.

The remaining owner dispositions are D13-4 (populated Favorites page count/glyph) and #28 (E-Hentai Settings Multi-Page Viewer row overlap). Finding #23 is now owner-accepted as recorded below. Do not request ROUND1-CLEAR or mark plans 16-10/11 complete while these remain unresolved. No full matrix re-verification or final closure consistency pass was performed in this review.

Fresh checks on 2026-09-09 are recorded in `16-LOGIN-COVER-RECHECK.md`: D13-4 and #28 did not reproduce in the sampled conditions; #23 still reproduces during live rotation/text-size changes. These observations do not infer owner acceptance. The same report records the subsequent login and cover changes, their passing targeted tests, and the remaining live-verification limits.

Owner update 2026-09-09 after viewing the fresh snapshot: #23 accepted. The owner explicitly quoted the iPhone landscape AX5 loss of the message and Cancel and replied 「就沒有那麼多空間可以用來顯示，通過」. Record this as acceptance of the space-constrained presentation, not a fixed rendering defect. Preserve the reproduction evidence; no app change is required for #23. D13-4, #28, and ROUND1-CLEAR are not inferred from this acceptance.

## Round-1 closure — 2026-09-11

The owner review is closed. At 2026-09-11T08:04Z the owner gave the final two dispositions through the
orchestrator's structured question: `D13-4=fixed` (basis: the recorded iPhone #6 re-verification plus
the 2026-09-09 sampled populated-iPad Favorites AX3/AX5 checks in `16-LOGIN-COVER-RECHECK.md`) and
`#28=fixed` (basis: the 2026-09-09 sampled iPhone portrait AX5 check in the same record; recorded as
`re-verified (owner 2026-09-11: …)`), then `ROUND1-CLEAR` conditional on both being recorded. Both are
recorded in `16-SWEEP.md` (§ Findings, § D-13 named edge cases, `### D-13 dispositions requested`,
`### Owner review closure — 2026-09-11`), and plan 16-11 Task 3's consistency check is recorded in
`16-SWEEP.md § Round-1 report › ### Round-1 closure`. No simulator check, build or test was run today.

Plans 16-10 and 16-11 are complete. Next: plan 16-12 (wave 11) — the `no_minimum_scale_factor` rule and
the owner-signed UAT gate; A11Y-01 completes there, not here. The history above is retained as written.
