---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "10"
subsystem: marketplace-listing
tags: [altstore-pal, screenshots, listing, assets, closed-by-decision]

requires: []
provides:
  - "The PAL template lists the owner's seven decorated iPhone screenshots (owner msg 2628), in the same order and as the same `{imageURL, width, height}` objects as `AltStore.json`, the SideStore template and the beta template"
  - "The source-template tests hold the PAL app to that set: `screenshots` is no longer a PAL-only field"
affects: [20-08, 20-13]

actuals:
  tokens: 40000
  tasks: 1
  commits: 3

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - actions-tool/altstore-pal.template.json
    - actions-tool/tests/test_source_templates.py
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - .planning/STATE.md

key-decisions:
  - "20-10 is closed with the owner's existing set, not with store renders from Phase 19: product lead msg 3168, after owner msg 3167 (\"Screenshots for PAL? Approved.\"). 20-10 no longer depends on Phase 19; 20-11 still does."
  - "The set is the seven decorated iPhone screenshots the owner approved in msg 2628 (01-home to 07-more, 1260 x 2736, RGB, no alpha), pushed to `EhPanda-Team/ehpanda-assets` under `app-marketplace/iphone/` (push reported in msg 2798; assets commit `41f9a13`). The PAL source uses the same raw URLs as the Classic, SideStore and beta sources, so there is no separate `pal/` folder."
  - "The PAL source lists iPhone screenshots only (`{\"iphone\": [...]}`). The owner's set has no iPad pictures, and none were made."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "The PAL app lists the seven screenshots, same order and objects as the other sources, and they are in the assets checkout"
    requirement: MKT-18-01
    verification:
      - kind: test
        ref: "test_source_templates.py: test_every_app_shows_the_seven_iphone_screenshots and test_the_screenshots_are_in_the_assets_repository now include PAL; RED at 134b6ff36 (2 failures, 1 error), GREEN at 176b9e170"
        status: pass
      - kind: manual
        ref: "curl -sSIL on the seven imageURLs: 200 each; ehpanda-assets origin/main is 41f9a13; sips: 7 x 1260 x 2736, RGB, hasAlpha no"
        status: pass
    human_judgment: false
  - id: D2
    description: "Owner approval of the set for the PAL listing, with a message number"
    requirement: DIST-18-02
    verification:
      - kind: manual
        ref: "owner msg 2628 (the set), owner msg 3167 (approved for PAL), product lead msg 3168 (close 20-10)"
        status: pass
    human_judgment: true

duration: n/a (closed by decision; one TDD pair and the docs)
completed: 2026-11-10
status: complete
---

# Phase 20 Plan 10: the PAL listing's store screenshots Summary

**20-10 is closed by product-lead decision (msg 3168) with the owner's seven approved decorated iPhone screenshots
(owner msg 2628). The owner approved them for PAL in msg 3167. The PAL template now lists them, exactly as
`AltStore.json`, the SideStore and the beta templates do. The plan no longer waits for Phase 19. The App Store
Connect upload, the PAL copy and the iPad question move to 20-08.**

## Performance

- **Duration:** not tracked; one TDD pair and the docs on 2026-11-10.
- **Completed:** 2026-11-10
- **Tasks:** the plan's three tasks are superseded (see Deviations); the work done is the PAL template step of
  Task 3.
- **Files modified:** 2 code files (`altstore-pal.template.json`, `test_source_templates.py`), plus ROADMAP,
  REQUIREMENTS and STATE

## Accomplishments

- **Tests first (RED).** `test_source_templates.py` now includes the PAL source in the seven-screenshot test and
  the assets-checkout test. `screenshots` left `PAL_APP_OWN`, so the Classic-metadata test also compares the PAL
  app's screenshots with `AltStore.json`. The field-order test now expects `screenshots` between `category` and
  `appPermissions`, as in the SideStore template. The test that said "20-10 adds them" dropped its
  no-screenshots assertion. The run failed as expected: 2 failures and 1 error, all from the missing field.
- **Template (GREEN).** `altstore-pal.template.json` gains the same `screenshots` block as
  `sidestore.template.json`: seven `{imageURL, width, height}` objects, `app-marketplace/iphone/01-home.png` to
  `07-more.png`, 1260 x 2736. Nothing else in the template changed. It keeps the Classic subtitle and description,
  `marketplaceID: ""`, `appPermissions` and no versions.
- **Checks.** `python3 -m unittest discover -s actions-tool/tests -v` (as `release-notes.yml` runs it): 173 tests,
  OK, none skipped. The assets test ran against the local `ehpanda-assets` checkout at `41f9a13`, which matches
  `origin/main`. All seven raw URLs return 200.

## Task Commits

1. **RED:** `134b6ff36` (test). Holds the PAL app to the owner's seven iPhone screenshots.
2. **GREEN:** `176b9e170` (feat). The PAL template lists them.
3. **Docs:** the commit that adds this summary and updates ROADMAP, REQUIREMENTS and STATE.

## Decisions Made

See `key-decisions`. The owner chose the set, its decoration and its order before this plan ran (owner msgs 2608,
2610, 2618, 2623 and 2628; CONTEXT D-17). His msg 3167 approved the same set for PAL. Product lead msg 3168 closed
the plan on that basis.

## Deviations from Plan

1. **Tasks 1 to 3 are superseded, not done as written.**
   - Task 1 (screens, decoration, wording): the screens and decoration are the owner's existing set. The wording
     approval moved to 20-08 (see below).
   - Task 2 (store renders from Phase 19's approved references, the same-run 1x match, the delivery check): not
     done. There are no store renders from Phase 19, no `Scripts/visual/store_screenshots.py` and no 1x match. So
     T-20-27's mitigation (the store picture equals the approved scenario) does not apply. The set was made by the
     outside designer from the website screenshots (D-17).
   - Task 3: the owner's approval (msg 3167) and the push (msg 2798, `41f9a13`) happened outside this plan. The PAL
     template step is done here. The collaborator's upload moved to 20-08.
2. **No `20-10-LISTING.md`.** This summary records the owner's choices, the pushed commit and the files.
3. **No `pal/iphone/` or `pal/ipad/` folders.** The set lives under `app-marketplace/iphone/`, shared with the
   other sources (the stale paths were already noted at 20-03).
4. **The plan's external dependency is dropped** ("Phase 19: approved reference set pinned (19-13)"). 20-11 still
   depends on Phase 19.

## Moved to 20-08

- **(a) The App Store Connect upload.** The collaborator uploads the same seven pictures for the first
  submission. 20-08-PLAN.md Task 3, step 2 now carries it (updated after this summary; the earlier text said the
  set was "already uploaded by the collaborator" in 20-10).
- **(b) The PAL subtitle and description** (copywriter msg 2785) **and the owner's approval of them** (D-25).
  20-10 Task 1 carried both. They now come before the PAL submission, in 20-08. The template still has the
  Classic copy, and `test_the_pal_template_has_the_classic_metadata` still holds it to `AltStore.json`. When the
  PAL copy lands, that test must exempt the subtitle and description fields.
- **(c) iPad 13-inch screenshots.** None exist. CONTEXT D-04 notes that App Store Connect may require at least one
  iPad 13-inch screenshot (2064 x 2752 or 2048 x 2732) at submission, because EhPanda runs on iPad. 20-08's truth
  lists "screenshots (iPhone and iPad 13-inch)" among the Required properties. Whether the 1260 x 2736 iPhone set
  alone satisfies the iPhone class through scaling is also first confirmed there. This is flagged for 20-08.

## Requirements

- **MKT-18-01** (AltStore promotional images and store screenshots): **partly met, stays Pending.** All four
  AltStore and SideStore sources (Classic, SideStore, beta, PAL) now carry the owner-approved decorated set. The App
  Store Connect upload of the same set, and any iPad set Apple requires, remain at 20-08.
- **DIST-18-02** (prepare the marketplace listing): **stays Pending.** The PAL source's screenshots are done. Still
  open: the PAL copy (20-08), `marketplaceID` and versions (20-08 and the publish job), and the listing's privacy
  and support URLs (20-07).
- **CAP-17-05** (assign AltStore promotional composition to a separate designer agent and validate its local
  consumer handoff): **not met as written, stays Pending.** The composition came from an outside human designer
  the owner dispatched (owner msg 2618), not from a designer agent. The set was published, not validated as a
  local handoff. The requirement needs the owner or the product lead to amend or close it; this plan does not.
- The traceability rows for MKT-18-01 and DIST-18-02 now note the progress. The CAP-17-05 row is unchanged.

## Open items

- **The first picture's caption.** `01-home.png` is headed "Over a million adult comics and doujinshi". The
  pictures are non-explicit (D-17), and owner msg 3167 approved the set for PAL as it is. D-25 put the caption
  check in the copy approval, which has moved to 20-08. Whether the notarization review accepts the caption under
  guideline 2.3.8 is first seen at 20-08.
- **20-08-PLAN.md wording** was updated after this summary: Task 3, step 1 now has the owner's copy-and-caption
  approval and the test change, and step 2 the upload.
- **`AltStorePAL.json`** does not exist yet. The first PAL publish creates it from this template, screenshots
  included.

## User Setup Required

None.

## Next Phase Readiness

20-13's dependency on 20-10 is met. It still waits for 20-11 (Phase 19's screenshot check). 20-08 gets the
screenshot set from here, plus items (a) to (c) above.
