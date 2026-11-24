---
phase: 19-visual-regression-marketing-export
plan: "23"
subsystem: ui
tags: [investigation, reading-settings-picker, home-slideshow-stats, dynamic-type, owner-decisions]

requires:
  - phase: 19-22
    provides: "the local capture and hosted-test method on the phase simulators (iOS 27.2) used again here"
provides:
  - "C6: the cause of the cut first row of the Reading settings (the stock menu `Picker` row's height under-reports a value that wraps), its evidence, and the owner's decision to keep the system Picker (no change, no test)"
  - "C9: the cause of the single Front Page column (the scenario's 2-gallery fixture) and of the hyphenated stat labels (two views), the measurements, and the owner's decisions (`fixture-8`; one stat per line as 'label value' below the cover on the iPhone, the same fallback on the iPad)"
affects: [19-24]

actuals:
  tokens: 6300
  tasks: 3
  commits: 3

plan_head_before: 274d46a73927e75b4d0bec2b673f4b7d17484b42
plan_head_after: b628e2df511c25712e30daef033aeea16d2208a7

key-files:
  created:
    - .planning/phases/19-visual-regression-marketing-export/19-23-INVESTIGATION.md
  modified: []

key-decisions:
  - "C9 fixture: `fixture-8`, the 8 existing public fixtures (6 home galleries and the 2 carousel neighbours), 4 columns (owner decision 2026-11-24)."
  - "C9 iPhone layout: `layout-lines`, refined: the stats move below the cover, use the card's full width, one stat per line as 'label value', as the last `ViewThatFits` option of `HomeCompactSlideshowInformation` (owner decision 2026-11-24)."
  - "C9 iPad layout: the same fallback in `HomeSlideshowInformation`, used when its two columns do not fit; content-sized columns were not chosen (owner decision 2026-11-24)."
  - "C6: keep the stock `Picker` (`fix-other`, no app change, no test); recorded as a known limitation that the owner may report to Apple (owner decision 2026-11-24)."

requirements-completed: [VIS-18-01]
status: complete
---

# Phase 19 Plan 23: C6 and C9 investigation Summary

**Both causes are known with evidence and both decisions are recorded: C6 is the system menu Picker's own sizing and stays as it is; C9's single column is the scenario's fixture, and its hyphenated labels come from two views, both fixed by the same one-stat-per-line fallback.**

All local runs of this plan ran on the iOS 27.2 simulator runtime (owner decision 2026-11-24); baseline2 was captured on iOS 27.0. Every measured value is a 27.2 value. No source file changed: the only tracked file of the plan is `19-23-INVESTIGATION.md`, and `git status --porcelain -- AppPackage` was empty at each commit.

## Accomplishments

- **Task 1** (`1c2fae630`): `19-23-INVESTIGATION.md` with the C6 and C9 evidence, causes and the options of Task 2 with their tests.
- **Task 2** (`f19f97316`): "## C9 decision": the owner's answers quoted verbatim (`fixture-8`; one stat per line below the cover on the iPhone; the same fallback on the iPad), with the tests they need.
- **Task 3** (`b628e2df5`): "## C6 decision": 「保留系統 Picker」, option `fix-other`, no app change and no test (a known limitation).

## Findings

- **C6 is an app defect, and `de` is not cut.** The cut is one coordinate family: iPhone, `ko`, `accessibility5`, portrait, both states (`settings-pages-reading`, `reader-settings-sheet`), rows 1 (Direction) and 5 (Landscape Direction). `de` is not cut in baseline2 or locally on either device or orientation, contrary to the original C6 note; iPad `ko` and `de`, iPhone landscape and the other locales are whole. In the settled hierarchy the first row's content is 15.0 pt above and 15.0 pt below its 174.7 pt cell (three identical reads over 1.5 s); a healthy row has 15 pt inside. The stock `Picker(...).pickerStyle(.menu)` row reports its value as one line tall and lays it out on two when it wraps. The container comparison found no difference that produces the cut.
- **C9's single column is the fixture.** `TracerScenarios.home()` gives the shelf 2 galleries (1 pair, 1 column); the app gives up to 25 (12 columns).
- **A second view hyphenates.** The plan expected `HomeCompactSlideshowInformation` only (the squeezed last `ViewThatFits` option, 176 pt column on the iPhone in portrait at `accessibility5`: `en` "Rat-ing", "Pag-es", `de` "Be-wer-tung", "Sei-ten", and character splits in `ja`, `ko`, `zh-*`). `HomeSlideshowInformation` (the regular card on the iPad) also breaks words at `accessibility5`, portrait and landscape: `en` "Catego-ry" and "Doujin-shi", `de` "Kate-gorie" and "Dou-jinshi", because its two equal 166 pt columns sit under a 360 pt cap. "Bewertung" (200.3 pt) is wider than the 176 pt iPhone column by itself, which is why the owner's layout moves the stats below the cover to the card's full width.

## Probes beyond the plan's steps (working tree only, all reverted; copies kept in the ignored `$W/diagnostics/`)

Each was a diagnostic edit or a throw-away test, never committed.

- **Hosted C6 probe** (`NavigationStack { ReadingSettingView }` in a plain `UIHostingController` at several widths, locales and sizes): reproduced the cut outside the snapshot harness (15 / 15 at `ko` `accessibility5`, 420 pt), showed it at every width where the value wraps (300 to 420) and not where it does not (430 and above; `de`, `en`, `ko` `large`), so it is the app's layout and not a harness artefact.
- **`.fixedSize(horizontal: false, vertical: true)` on the Picker:** the Picker's ideal height is one line (144.7 pt of content in the 174.7 pt cell) and the wrapped value is squeezed and cut in the picture. Not a fix.
- **Explicit `VStack { Text(label); Picker.labelsHidden() }`:** the cell grew to 203 pt but still started its content 15 pt above itself; the label stayed cut. Not a fix.
- **`Menu` with a SwiftUI label for the first row:** the cell is 156 pt and its content fills it (0 / 0) at `ko` and `de`; the picture shows the row whole. It showed that SwiftUI measures its own label correctly, and it is the fix the record proposed. The owner chose not to build it.
- **C9 width-measuring hosted test:** ideal widths of the compact grids and labels in the six locales against the widths the cards give (176 pt on the iPhone in portrait, 166 pt columns on the iPad), the source of the numbers above.
- **A hierarchy-dumping `interact` step on the two Reading states:** the cell and element frames of the first rows, three snapshots per coordinate.
- **Contact sheets of the baseline2 `home-populated` and Reading pictures** (`$W/c9-*.png`, `$W/c6-baseline-*.png`) to find every hyphenated label.

## Deviations from Plan

None to the plan's tasks. Process notes:

1. **A build failure of my own diagnostic** (a `try?` in the hierarchy step, banned by the `optional_try` rule) stopped one capture run before it started; it was fixed and re-run, and the failed run is kept as `$W/compile-error-c6-hier-phone`. No other run was retried and no infrastructure error occurred (no first-boot AX error on the iPad).
2. **Task 1's verification command was not run as one line**; its three checks were run separately (2 section headings, 2 conclusion matches, 0 modified files under `AppPackage`), and the task's own `git status` check was repeated at each commit.
3. **Tasks 2 and 3 were answered by the orchestrator after asking the owner** (the plan's checkpoints), each in its own commit; the owner's answers are quoted verbatim in the record.

## Auth gates

None.

## Known Stubs

None.

## Threat Flags

None. T-19-51 (a design choice made without the owner) is mitigated: the C9 fixture and both stat layouts, and the C6 construction change, were each put to the owner and their answers are quoted in the record before 19-24 starts.

## Self-Check: PASSED

`19-23-INVESTIGATION.md` exists with "## C6", "## C9", "## C9 decision" and "## C6 decision" (one heading each); commits `1c2fae630`, `f19f97316` and `b628e2df5` are in the branch history (signed, +08:00 dates), and `git status --porcelain -- AppPackage` is empty.
