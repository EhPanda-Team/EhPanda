# Phase 19: Visual Regression & Marketing Export - Context

**Gathered:** 2026-11-05 (owner decisions recorded during the Phase 18 discussion)
**Status:** Discussion not yet run; owner decisions recorded. Run `/gsd-discuss-phase 19` before planning.

<domain>
## Phase Boundary

This phase does the visual-regression and marketing-export work moved from Phase 17 (owner msg 1305), against the
settled 3.0 UI:

- the snapshot scenario matrix, public real-app dispatch, strict never-record comparison and the review report
  (17-08 to 17-12);
- one owner-approved baseline (17-13; 17-20 folded in);
- the full-matrix CI gate on every PR and release (17-14 T1/T3), with the native visual policy tests (17-09-T2);
- preview review documentation (17-15);
- the 384-coordinate export tooling and handoff validator (17-07);
- the final gallery selection and 384 regeneration (17-21);
- the `Scripts/visual/README.md` rewrite.

Requirements: VIS-18-01, MKT-18-01 (export, selection, regeneration), CAP-17-02, CAP-17-03, and the moved parts of
CAP-17-01, CAP-17-04 and CAP-17-06.

**Not here:** the AltStore promotional images and store screenshots (17-22, CAP-17-05) and the final Release isolation
scan are Phase 20; the in-app UI is Phase 18.

</domain>

<decisions>
## Owner decisions that apply (recorded 2026-11-05)

- **D-01:** Three phases (owner msg 1753). This one runs after the in-app work, so the baseline is approved once,
  against final UI. The visual work must not start its baseline while Phase 18 UI is still changing.
- **D-02:** The coverage includes every new Phase 18 screen and state:
  - the age wall, with Continue dimmed and enabled;
  - the analytics choice, with nothing selected and with each level selected;
  - the Settings analytics picker and its Privacy Policy row;
  - the comment report confirmation and the posting warning;
  - the collapsed blocked-comment row, collapsed and shown;
  - the Blocked Users list, filled and empty.

  All six languages use the approved copy (Phase 18's 18-COPY-FIRST-LAUNCH.md and 18-COPY-COMMENTS.md).
- **D-03:** The coverage, comparison and approval rules from Phase 17 carry unchanged (prep L30 to L33; 17-CONTEXT
  D-07, D-12 to D-14):
  - every screen and state × six locales × all 12 Dynamic Type sizes × portrait and landscape × iPhone and iPad ×
    light and dark;
  - each coordinate is captured, failed or justified not applicable;
  - strict never-record comparison;
  - one owner baseline approval;
  - the full matrix on every PR and release;
  - a filterable report, and a controlled regression that proves detection.
- **D-04:** Toplists fixtures carry at least six galleries per period, so the regular-width two-by-three grid is full
  (Phase 17 scope 6; prep L34).
- **D-05:** Marketing content rules carry (prep L36, L37; 17-CONTEXT D-02, D-04, D-05): content is real, and no
  gallery appears twice on one screen. The final selection comes from owner identifiers, then everything is
  regenerated. The 384 tooling, validator and regeneration are in 3.0 scope.
- **D-06:** Rewrite `Scripts/visual/README.md` (prep L42). The index is now `website-capture-20261104.json`
  (11 fixture versions), and this phase, not 17-02, 17-05 or 17-07, owns the regression and marketing runners.
- **D-07:** For later use in Phase 20: an AltStore listing can use only non-adult pictures (Ampo msg 1751, guideline
  2.3.8). Store screenshots are the website screenshots plus the designer's decorations (owner msg 1753; Colo msg
  1757). This phase supplies captures; it does not design them.
- **D-08:** Tagging and release order are not this project's business (owner msg 1753).

## Open questions for this phase's discussion

- **GA-8 Q2, the final 384 selection:** reuse the approved website selections (msg 1581) for the iPhone half, and
  have the owner pick only the iPad half's extra galleries? The prep recommended this; the owner has not answered.
- **Pushing the fixture repository commits** (`8ee4fc2`, `f71d108`; R4-3): needed if the 384 regeneration runs
  anywhere but the capture machine. The owner decides.

## Developer defaults (changeable)

- **Snapshot CI:** shard the 576-coordinate matrix across simulators on the self-hosted `xcode-27` runner and report
  the runtime per PR. The gate is a new workflow, since the old manual "Visual capture" workflow was removed in quick
  task 261027-ci-cleanup (prep section 3).

</decisions>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md`, Phase 19, and the split map at the end of the Phase 18 section.
- `.planning/REQUIREMENTS.md`: VIS-18-01, MKT-18-01, CAP-17-01 to CAP-17-06.
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-DISCUSSION-PREP.md`: L30 to
  L37, L42, GA-8.
- `.planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-CONTEXT.md`: the Phase 18
  screens to cover.
- The Phase 18 copy files `18-COPY-FIRST-LAUNCH.md` and `18-COPY-COMMENTS.md` (same directory).
- `.planning/phases/17-localized-screenshot-capture-harness/17-CONTEXT.md` and the superseded plans 17-07 to 17-15,
  17-20 and 17-21.
- `Scripts/visual/README.md`, `Scripts/visual/selection-review.py`.

</canonical_refs>

<deferred>
## Deferred Ideas

None beyond the open questions above.

</deferred>

## Scope changes 2026-11-06

These supersede the matching parts above. ROADMAP.md Phase 19 is renamed "Visual Regression & Daily Live-Parsing
Check"; the directory name is unchanged.

- **Marketing export removed** (owner msg 1949; lead msg 1952; restated by the product lead in msg 1993): no
  regenerated iPhone marketing pictures and no iPad marketing pictures are planned. The 384-coordinate export
  tooling and handoff validator (17-07), the final gallery selection and the 384 regeneration (17-21) are dropped,
  with MKT-18-01's Phase 19 part and CAP-17-04's moved 384 export. D-05 and the GA-8 Q2 question no longer apply.
  D-04's six-galleries-per-Toplists-period rule existed only for the marketing grids and is dropped too.
- **Coverage:** D-02's comment report confirmation was removed in Phase 18.1; the native Report form takes its place.
- **Run limits** (owner msg 1949): one full check may take up to 2 days before options go back to the owner; weekly
  dependency updates also wait for the full check; per-simulator serial capture is allowed for screenshot runs only,
  with several simulators in parallel; the screenshot check goes first.
- **Matrix size and storage** (owner msg 1949): the owner questioned the image count and the 30–100 GB estimate ("I
  expected hundreds of reference pictures"; "swift-snapshot-testing snapshots won't take so much space"). Both are
  re-derived with swift-snapshot-testing in the discussion. A spike measured package-test snapshots at about 27, 80
  and 124 KB per light image at 1x, 2x and 3x, but package tests cannot render Liquid Glass, materials, alerts or
  sheets, so the capture path (app-hosted or package tests) is decided in the discussion.
- **Daily live-parsing check added** (owner msg 2006; product lead msg 2007; VIS-19-01): a scheduled GitHub Actions
  workflow runs the app's own parsers once a day on the live pages EhPanda reads, read-only, and keeps one GitHub
  issue open while a page fails, with no page content, images, gallery titles or account details in issues or logs.
  Sign-in pages use saved fixtures until the owner supplies a sign-in secret. Whether E-Hentai admits GitHub runner
  IPs is checked early; if not, options go back to the owner. Full wording: ROADMAP.md Phase 19, scope item 9.

---

*Phase: 19-visual-regression-marketing-export*
*Owner decisions recorded: 2026-11-05; discussion not yet run*
