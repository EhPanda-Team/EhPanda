---
phase: 16-dynamic-type-accessibility
plan: 05
subsystem: planning
tags: [dynamic-type, accessibility, sweep, iphone, group-b, detail, reader, D-03, D-04, D-13, D-15]

# Dependency graph
requires:
  - phase: 16-dynamic-type-accessibility
    plan: 03
    provides: "`16-SWEEP.md § Infrastructure` — IPHONE_UDID, BUNDLE_ID, login state, recorded baselines, evidence root and the sim-use tooling map"
  - phase: 16-dynamic-type-accessibility
    plan: 04
    provides: "Findings #1–#12, the corrected rotation verb, the landscape-framebuffer and foreground-stealing mechanics, and the one download this phase created"
provides:
  - "All 84 `iPhone — Group B` matrix rows (#14–#27 × portrait/landscape × XXL/AX3/AX5) non-`pending`"
  - "Eleven new numbered § Findings entries (#13–#23) covering the Detail header, stats strip, tag cloud, comment cells, Comments view, Gallery Infos, Archives, Torrents, the reader page indicator and the Detail delete alert"
  - "All three remaining D-13 named edge cases observed — two of them contradicting their pre-registered prediction"
  - "Twenty D-04 checklist rows dispositioned, including four of the five `minimumScaleFactor` sites and both reader touch-target frames"
  - "The four D-15 `.large` baselines banked under `$HOME/Library/Caches/ehpanda-phase16/d15-baseline/` with a `### D-15 baseline` note recording file names, surfaces, capture conditions and the installed build version"
affects: [16-06, 16-07, 16-08, 16-09, 16-10, 16-11, 16-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The D-15 parity baseline is captured before any owner edit exists and is recorded by fixed file name plus the installed bundle's version, so the comparison in plan 16-11 does not depend on remembering which build produced it"
    - "A pre-registered edge case is recorded as observed-and-contradicted rather than quietly re-described when the real failure mode differs from the prediction"
    - "A surface that cannot be reached without changing the app's language or waiting for a server-issued event is recorded `blocked:` with the evidence for why, not silently skipped"

key-files:
  created:
    - ".planning/phases/16-dynamic-type-accessibility/16-05-SUMMARY.md"
  modified:
    - ".planning/phases/16-dynamic-type-accessibility/16-SWEEP.md"

key-decisions:
  - "The Detail header title's three-line cap is recorded as a finding even though tapping the title expands it in place — D-04 judges the default rendering, and the affordance is stated explicitly in the finding rather than used to excuse it."
  - "Findings #11 and #23 are kept separate. Both are download-delete confirmations, but #11 is the Downloads tab's fixed-width popover failing in portrait and #23 is the Detail screen's full alert failing in landscape; merging them would hide that two different containers fail for two different reasons."
  - "Gallery Infos (#19 → finding) was found by the walk, not inherited: its `lineLimit(3)` is not in the § D-04 checklist, which enumerates only `lineLimit(1)`. The checklist is a floor, not a ceiling."
  - "System menus that overflow are judged `pass` when they scroll to their last item (reader More menu, page context menu, Auto-Play menu in portrait) — dropped glyphs are decoration under D-03. The one case where scrolling could not be demonstrated is called out as unconfirmed rather than assumed either way."
  - "Screen #21 (Tag Detail) is `blocked` on evidence, not on effort: the sheet's only entry point is gated on a non-empty tag description, and the English translation database ships every entry with an empty description field."

patterns-established:
  - "Blocked rows carry the disproof, not just the symptom: #21 records which settings were enabled, that the app was relaunched, and what the downloaded cache file actually contains"

requirements-completed: []  # A11Y-01 is phase-wide; it closes on the owner-signed sweep (16-12).

coverage:
  - id: D1
    description: "All 84 iPhone Group B matrix rows are non-`pending`, each with a one-line reason"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "for n in 14..27: `grep -E '^\\| $n \\| .*iPhone' 16-SWEEP.md | grep -c '| pending |'` → 0 for every n; 84 Group-B rows present; status tally = 40 pass / 26 finding / 12 blocked / 6 n/a"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every `finding:#N` in the Group B rows resolves to a numbered § Findings entry with a written description"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "Group B rows reference #5, #6, #8, #9 (Group A, screen list extended to include #17) and #13–#23; § Findings defines #1–#23; no dangling reference"
        status: pass
    human_judgment: false
  - id: D3
    description: "The four D-15 `.large` baselines exist under the evidence root with the four fixed names, and § Infrastructure records what each shows"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "`ls $HOME/Library/Caches/ehpanda-phase16/d15-baseline/` lists exactly large-comments-view.png, large-detail-comment-cells.png, large-detail-header.png, large-gallery-detail-cell.png; `grep -c '### D-15 baseline' 16-SWEEP.md` → 1"
        status: pass
    human_judgment: false
  - id: D4
    description: "All three remaining D-13 rows carry an iPhone `Observed` note and remain undispositioned"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "D-13 section contains 0 `_pending` placeholders; stats-strip, long-tag and reader-counter rows all filled; Status column still `pending` for the owner to close in 16-11"
        status: pass
    human_judgment: false
  - id: D5
    description: "Twenty D-04 checklist rows dispositioned for Group B screens"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "HeaderSection:72/:73/:324, Subviews:99/:116, CommentCells:37/:42/:43/:51, CommentsView:165/:166, TorrentsView:110/:124, ArchivesView:143/:202, TagCloudView:122, CategoryView:31, ControlPanel:176/:166/:296 all non-pending"
        status: pass
    human_judgment: false
  - id: D6
    description: "Verdicts judged from rendered screenshots against D-03 / D-04, not from the accessibility outline"
    requirement: A11Y-01
    human_judgment: true
    rationale: "Whether a layout 'provides less information' is the owner's rule applied by eye. Several Group B cells are exactly why the image is the basis: the Torrents meta values and the reader page indicator are still reported in full by the accessibility tree while rendering nothing at all."
  - id: D7
    description: "No account mutation, no purchase, no post, no download, no deletion; the simulator is restored and read back"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "`content_size` → medium, `appearance` → dark, `increase_contrast` → disabled, `sim-use ui` header 420x912 with no orientation tag; the single Downloads/Default entry still present; Tags Extension and Translate Tags both read back 0"
        status: pass
    human_judgment: false
  - id: D8
    description: "No image entered the repository and no absolute home path entered the doc"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "`git status --porcelain | grep -Ei '\\.(png|jpe?g|heic|gif)$' | wc -l` → 0 before both commits; the absolute-home-prefix scan of `16-SWEEP.md` counts 0 matches"
        status: pass
    human_judgment: false

# Metrics
duration: 3h 5m
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 05: iPhone Group B Dynamic Type Sweep Summary

**All 84 iPhone Group B cells are judged, and the detail-and-reader third fails differently from the lists: instead of titles losing their tails, whole *values* stop being drawn — the Torrents card renders four glyphs with no numbers beside them, the reader's page indicator collapses to a two-point sliver, the Archives cards lose their size and price outright, and the Detail delete alert in landscape shows its red Delete button with no message and no Cancel.**

## Performance

- **Duration:** ~3 h 5 m for 84 cells across 14 surfaces, both orientations, three sizes, plus the D-15 baseline capture.
- **Evidence:** 136 full-scale PNGs for screens #14–#27 under `$HOME/Library/Caches/ehpanda-phase16/sweep/`, plus 4 under `d15-baseline/`. None in the repo.
- **Commits:** `3220992b` (rows 14–20, including the D-15 baselines), `5be5be6e` (rows 21–27).

## Task Commits

1. **Task 1: D-15 `.large` baselines, then iPhone × Group B #14–#20** — `3220992b` (docs)
2. **Task 2: iPhone × Group B #21–#27 and restore** — `5be5be6e` (docs)

## D-15 baselines

Captured first, before any owner edit to a `minimumScaleFactor` site exists, at `content_size large`, portrait, dark, Increase Contrast disabled, List Display Mode `Detail`, full-scale 1260×2736. Recorded in `16-SWEEP.md § Infrastructure → ### D-15 baseline`.

| File (under `$HOME/Library/Caches/ehpanda-phase16/d15-baseline/`) | Surface | Shrink site it hosts |
|---|---|---|
| `large-gallery-detail-cell.png` | Frontpage list, four rows, the first with a fifteen-character uploader and complete stats | `GalleryDetailCell.swift:155, :166` |
| `large-detail-header.png` | Gallery Detail header of a **Western** gallery — title, uploader, category badge, action row, stats strip | `DetailView+HeaderSection.swift:73` (0.72) |
| `large-detail-comment-cells.png` | The same gallery's Detail comment-cells strip | `DetailView+CommentCells.swift:42` |
| `large-comments-view.png` | The same gallery's full Comments view | `CommentsView.swift:165` |

**Build under test:** the installed `BUNDLE_ID` bundle reports `CFBundleShortVersionString` 3.0.0 / `CFBundleVersion` 158, installed 2026-08-11. The exact commit is not recorded, but it necessarily predates every phase-16 source change — phase 16 has not touched a source file yet (plans 16-01 … 16-04 changed only `.swiftlint.yml` and planning documents).

**Observed at `large`, for the owner's comparison:** nothing in the four frames is shrunk below its neighbours' type scale. In particular the Detail header's 0.72 shrink does **not** visibly engage at the default size for a seven-character category name, which is the D-15 collision the plan flagged as the likely blocker. The one value already incomplete at `large` is the Detail comment **card body**, capped by the card's fixed 300 × `cardHeight` frame at every size.

## Findings opened

Each is described in full in `16-SWEEP.md § Findings`; evidence paths are relative to `$HOME/Library/Caches/ehpanda-phase16/sweep/`.

| # | Screen | One-liner | Evidence (evidence-root relative) |
|---|---|---|---|
| 13 | #14 | Detail header title is three-line capped and loses its tail from XXL portrait; the uploader beneath it ellipsises from AX3. Tapping the title does expand it — stated in the finding, not used to excuse it. | `iphone-portrait-{XXL,AX3,AX5}-14-top.png` vs `../d15-baseline/large-detail-header.png` |
| 14 | #14 | **D-13 stats-strip case.** Fixed-fraction columns abbreviate the labels at XXL and the *values* from AX3 — 1133 → "11…" → "1…", 4.50 → "4.…" — and the star row is clipped at both ends. | `iphone-portrait-{XXL,AX3,AX5}-14-top.png`, `iphone-landscape-{AX3,AX5}-14-mid1.png` |
| 15 | #14 | **D-13 long-tag case.** Long tags run off the right screen edge cut mid-glyph with no ellipsis; at AX5 one tag's frame is 64 pt wider than the screen. | `iphone-portrait-{AX3,AX5}-14-mid.png` |
| 16 | #14 | Comment-cell author and timestamp ellipsise from XXL — **the only Group B row that fails in landscape at XXL**, because the card's width is fixed at 300 pt. | `iphone-landscape-XXL-14-bottom.png`, `iphone-portrait-{AX3,AX5}-14-bottom.png` |
| 17 | #14 | The same card's body loses characters at every larger size; height scales, width does not. | `iphone-portrait-{AX3,AX5}-14-bottom.png`, `iphone-landscape-AX5-14-bottom.png` |
| 18 | #16 | Comments view header row keeps author + score + timestamp on one line; timestamp goes at XXL, author from AX3, both down to "Pec…" / "20…" at AX5. The bodies wrap perfectly by contrast. | `iphone-portrait-{XXL,AX3,AX5}-16-bottom.png`, `iphone-landscape-AX5-16-bottom.png` |
| 19 | #18 | Gallery Infos caps values at three lines; Archive and Torrent URLs lose their token at AX3 portrait, the gallery title and Parent URL at AX5. Not in the D-04 checklist — found by the walk. | `iphone-portrait-AX3-18-mid3.png`, `iphone-portrait-AX5-18-{top,mid}.png` |
| 20 | #19 | Archives cards lose their **size** and **price** — the two values a purchase decision needs. In landscape both lines vanish at AX3; in portrait the names abbreviate into ambiguity at AX5 and the text is drawn outside the card. | `iphone-portrait-{AX3,AX5}-19-top.png`, `iphone-landscape-{AX3,AX5}-19-top.png` |
| 21 | #20 | Torrent meta values are destroyed by their fixed 44-pt slots: a "0" renders as a "C" at AX3, and at AX5 **all four numbers are absent** while the accessibility tree still reports them. | `iphone-portrait-{AX3,AX5}-20-top.png` vs `iphone-portrait-XXL-20-top.png` |
| 22 | #25 | **D-13 reader counter case.** The page indicator shows only an ellipsis at AX3 portrait and renders nothing at all at AX5 — a two-point sliver. It does not wrap. | `iphone-portrait-{AX3,AX5}-25-top.png` vs `iphone-portrait-XXL-25-top.png` |
| 23 | #23 | The Detail delete alert in landscape cuts its message at AX3 and at AX5 draws **neither the message nor the Cancel button** — the only visible affordance on a destructive confirmation is Delete. | `iphone-landscape-{AX3,AX5}-23-top.png`, `iphone-landscape-AX5-23-scrolled.png` vs `iphone-landscape-XXL-23-top.png` |

Group A findings #5, #6, #8 and #9 also reproduce on Detail Search (#17); their § Findings "Screen" column was extended to name it rather than opening duplicates.

## D-13 observations

All three remaining cases are now observed, and **two of them contradict their pre-registered description**:

- **Detail stats-strip abbreviation (#14)** — reproduces, and worse than "abbreviation". The column *labels* go first (XXL), then the *values* themselves (AX3 up): a four-digit favourite count reads "1…" at AX5 and a 4.50 rating is lost entirely. Recorded as finding #14.
- **Long-tag right-edge clip (#14)** — reproduces exactly as pre-registered, from AX3 up in portrait, and never in landscape. Recorded as finding #15.
- **Reader total-page counter wrap (#25)** — **does not wrap.** The capsule is squeezed rather than the row wrapping, so at AX3 the indicator is a bare ellipsis and at AX5 it renders nothing. The D-13 note that "under D-03 a wrap is not degradation, so this may close as `accepted` on the rule alone" no longer applies: there is no wrap to accept. Recorded as finding #22 and left undispositioned for the owner (16-11).

## Blocked and n/a rows

| Screen | Rows | Status | Why |
|---|---|---|---|
| #21 Tag Detail sheet | 6 | `blocked: unreachable in an English session` | The sheet's only entry point is the tag context menu, and that item is gated on the tag carrying a non-empty translated **description**. The sweep enabled Tags Extension **and** Translate Tags, relaunched the app to force the fetch, and then inspected the downloaded cache: **every entry in the English tag-translation database has an empty description field**, so the gate can never open while the app runs in English. Reaching it would need the app's language changed, which would put the whole surface in a different language from the other 78 rows. Both settings were switched back off and read back as `0`. |
| #22 NewDawn greeting | 6 | `blocked: greeting not presented this session` | Server-issued once per day and not summonable; not presented during this session, including across a full app relaunch. |
| #27 Live Text overlay | 6 | `n/a: no app-drawn text (system overlay)` | Enabled from the control panel and inspected. Everything the overlay draws is a transparent hit-target `UITextView` (clear text colour, zero-point font); the only visible affordance is the system's own selection and translate UI, so there is no app-drawn string for Dynamic Type to reflow. The panel controls that switch it on are judged under #25. |

## Unconfirmed observation for the owner

At **AX5 landscape** the reader's Auto-Play menu shows its header and first option inside the visible container, with the remaining five options laid out below it. Every synthetic drag inside the menu dismissed it rather than scrolling, so whether those options are reachable in landscape is **unconfirmed**. In portrait the equivalent menus (More, page context menu) demonstrably scroll to their last item, which is why those cells are `pass`. This is a one-tap check on a device and is worth doing before the owner dispositions #25's landscape rows.

## Files Created/Modified

- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` — 84 Group B iPhone rows filled; findings #13–#23 added; the three remaining D-13 rows observed; twenty D-04 rows dispositioned; a `### D-15 baseline` note added to § Infrastructure.

## Decisions Made

Recorded in the frontmatter `key-decisions`. The two that most affect later plans:

- **#11 and #23 are separate findings.** Two download-delete confirmations fail, but in different containers (Downloads-tab popover in portrait vs Detail alert in landscape) for different reasons. Merging them would let one fix look like it closed both.
- **The D-15 collision the plan predicted did not materialise.** The 0.72 shrink on the Detail header category label does not visibly engage at `.large` for a seven-character category, and the badge never truncates at any sampled size. The site is recorded `fine` with that evidence attached, so the owner can weigh removing it against parity with facts rather than the hypothesis.

## Deviations from Plan

**1. [Rule 3 - Blocker] Screen #21's route is gated on data the English build does not have**
- **Found during:** Task 2, first attempt at the tag context menu.
- **Issue:** The plan's route ("long-press a tag in the Detail tag cloud and open its detail sheet") produced only Vote Up / Vote Down. `DetailView+Subviews.swift:312–313` gates the Tag Detail item on a translation with a non-empty description.
- **Fix:** Enabled Tags Extension, then Translate Tags, relaunched the app to force the database fetch, retried on two different galleries, and finally inspected the downloaded `tagTranslations-en.json` directly: zero of its entries carry a description. Recorded the six rows `blocked:` with that evidence rather than switching the app's language, which would have made #21 the only surface judged in a different language.
- **Restore:** both settings switched back off and read back as `0`. The fetched cache file remains under the app's `Library/Caches/` — a cache artifact, unused with the extension off, and deleting it would be a container mutation the sweep is not licensed to make.
- **Commit:** `5be5be6e`.

**2. [Rule 2 - Coverage] Screen #23's retry-mode variant could not be exercised**
- **Issue:** The plan asks for "the delete / retry-mode dialog". The session's only download is complete, and the retry-mode variant needs a download in an error state.
- **Fix:** Judged the delete variant at all six cells (it produced finding #23) and stated the gap explicitly in the finding rather than implying both variants were covered.
- **Commit:** `5be5be6e`.

**3. [Rule 1 - Bug in this plan's own tooling] Findings rows were being concatenated onto one line**
- **Found during:** Task 2, verifying the D-04 dispositions.
- **Issue:** The helper that appends § Findings rows anchored on the `Status ∈ {…}` line and consumed the blank line before it, so each subsequent append landed on the tail of the previous row instead of a new line. Findings #17–#23 ended up on a single line.
- **Fix:** Split the run back into seven rows on the `| open |` → `| N | #` boundary, restored the blank line before the anchor, and repaired the three D-04 notes that had been joined to their predecessor without punctuation.
- **Verification:** `grep -cE '^\| 2[0-3] \| #'` → 4; the Group B status tally reads 40 pass / 26 finding / 12 blocked / 6 n/a across exactly 84 rows.
- **Commit:** `5be5be6e`.

**Total deviations:** 3 auto-fixed (1 blocker, 1 coverage gap, 1 tooling bug). **Impact:** every unreachable surface carries its disproof, and the findings table is machine-readable for plan 16-10's report.

## Simulator handling

- Addressed only by `IPHONE_UDID`; `IPAD_UDID` was never touched.
- No erase, no uninstall, no clear-app-state, no `xcodebuild` against the sweep simulator. The app was terminated and relaunched twice (process only, data container untouched).
- **Nothing was purchased, posted, voted, favourited, downloaded, moved or deleted.** The Archives sheet was opened and dismissed; the post-comment sheet was opened, judged and cancelled; every download-delete dialog raised was cancelled; no torrent download was started; no gallery was moved between folders. The phase's single download is still the only entry under `Downloads/Default/`.
- Two settings were changed and restored: `Enable Tags Extension` and `Translate Tags` (both back to `0`, read back through the UI). Reading Direction was read but never changed. List Display Mode was never touched.
- Restored and read back at session end: `content_size` `medium`, `appearance` `dark`, `increase_contrast` `disabled`, portrait (`420x912`, no orientation tag).

## Issues Encountered

- The `sim-use` batch that walked several sizes in one shell invocation exceeded the 120-second tool timeout twice; the affected captures were re-taken individually. Later batches were kept to two sizes at a time.
- Synthetic drags inside a landscape system menu dismiss it rather than scrolling it, which is why the Auto-Play menu's reachability in landscape is recorded as unconfirmed rather than judged.
- The Archives sheet in portrait opens scrolled past its own title; the first captures were re-taken after scrolling to the top so the header is in frame.

## Next Phase Readiness

Group B is verified on the iPhone. Ready for plan 16-06 (iPhone Group C, screens #28–#42). The iPad pass over these same screens is plan 16-08 and will need `IPAD_LOGIN` before #14–#20 and #23–#25 can be more than `blocked: no iPad session`. The D-15 baselines are banked and survive the owner checkpoints between here and plan 16-11.

## Self-Check: PASSED

- `16-SWEEP.md` carries 84 Group-B iPhone rows, 0 `pending` (40 pass / 26 finding / 12 blocked / 6 n/a).
- Commits `3220992b` and `5be5be6e` present in `git log`.
- `ls $HOME/Library/Caches/ehpanda-phase16/d15-baseline/` lists exactly the four required names; `grep -c "### D-15 baseline" 16-SWEEP.md` → 1.
- Matrix references findings #5, #6, #8, #9 and #13–#23; § Findings defines #1–#23; no dangling reference.
- `git status --porcelain | grep -Ei '\.(png|jpe?g|heic|gif)$' | wc -l` → 0; the absolute-home-prefix scan of `16-SWEEP.md` counts 0 matches.
- Simulator baseline read back identical to the recorded values; the phase's single download is intact.
