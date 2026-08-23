---
phase: 16-dynamic-type-accessibility
plan: 02
subsystem: planning
tags: [dynamic-type, accessibility, sweep, verdict-table, state-machine, resumability]

# Dependency graph
requires:
  - phase: 10-ui-polish
    provides: "The 10-10 per-screen checklist (diff base only) and the 10-11 B1–B10 verdict-table shape"
  - phase: 16-dynamic-type-accessibility
    plan: 01
    provides: "HEAD the inventory and the D-04 file:line sites were re-derived against"
provides:
  - "`16-SWEEP.md` — the round-1 state machine: 42-row inventory, 504-cell matrix, findings register, 5 D-13 rows, 48-row D-04 checklist, and the sweep protocol"
  - "The install-over rule (build by UDID → `plutil` bundle-id check → `simctl install`) written once, referenced by every later plan"
  - "`EVIDENCE_ROOT = $HOME/Library/Caches/ehpanda-phase16/` — the persistent out-of-repo screenshot root that spans owner checkpoints"
  - "Resumability: any session starts at the first `pending` / `re-verify` row in layout order"
affects: [16-03, 16-04, 16-05, 16-06, 16-07, 16-08, 16-09, 16-10, 16-11, 16-12, 16-15, 16-26]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A committed planning doc used as an append-only state machine, not a report — the sweep's resume point is a table row, not a session note"
    - "Evidence root outside the repository and outside `/tmp`, so capture and comparison can be separated by an owner checkpoint that spans sessions"

key-files:
  created:
    - ".planning/phases/16-dynamic-type-accessibility/16-SWEEP.md"
  modified: []

key-decisions:
  - "All 42 inventory surfaces are treated as in-scope matrix screens (504 cells), with partial exclusions (share sheets, WebView pages, the Cloudflare challenge) recorded in the D-11 column of the host row rather than by deleting the row — this is what makes plans 16-04…16-09 add up to 78 / 84 / 90 rows each."
  - "The status vocabulary is written as a brace-comma set, not a pipe-separated list, so the mechanical `grep -c \"| pass\"` = 0 check can distinguish a verdict cell from prose."
  - "Task 1 and Task 2 land in one commit, per the plan's own verification item 3 (\"One docs commit touching only 16-SWEEP.md\")."

patterns-established:
  - "Sub-surfaces found by a re-grep that the research table did not name individually are folded into their host row AND listed in an explicit diff table, so nothing is dropped silently (D-12)"
  - "Every mechanically checkable rule the sweep must obey (never `booted`, never `erase`/`uninstall`/`clear-app-state`, never an image in git, always the recorded baseline on restore) is written once in § Protocol and referenced, never restated"

requirements-completed: []  # A11Y-01 is phase-wide and carried by all 26 plans; it closes on the
# owner-signed sweep and the five minimumScaleFactor removals. This plan builds the table the
# owner eventually signs; it verifies nothing. See 16-01-SUMMARY Deviations #3.

coverage:
  - id: D1
    description: "`16-SWEEP.md` is the single committed round-1 artifact: text-only verdict rows, no image anywhere in the repo (D-32)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "git status --porcelain | grep -Ei '\\.(png|jpe?g|heic|gif)$' | wc -l → 0; git ls-files | grep -Ei image ext | grep -c 16-dynamic-type-accessibility → 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Inventory re-derived against HEAD, not inherited from Phase 10 (D-12)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "re-ran the 9 presentation-site greps over AppPackage/Sources; 42 research rows confirmed, 5 unnamed sub-surfaces surfaced and folded in with an explicit diff table; 0 rows dropped"
        status: pass
    human_judgment: false
  - id: D3
    description: "12 cells per in-scope screen, iPad first-class, AX5 the maximum, no small-end column (D-05, D-06, D-07, D-10)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "504 matrix rows = 42 × 12; grep -c '| xSmall |' → 0; grep -c 'accessibility-extra-extra-extra-large' → 169"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-13 rows and the D-04 re-judgement checklist registered, every site file:line verified at HEAD"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "5 D-13 rows; 48 D-04 rows (30 lineLimit(1) + 1 lineLimit(4) + 5 minimumScaleFactor + 12 fixed frames), each line number re-confirmed by grep/sed against HEAD"
        status: pass
    human_judgment: false
  - id: D5
    description: "Protocol names the three content_size tokens, scroll-to-bottom, the recorded-baseline restore, the evidence root, the install-over rule and the forbidden list"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "grep -c '^## Protocol' → 1; 'never `booted`' → 1; '### Install-over' → 1; 'plutil -extract CFBundleIdentifier' → 1; 'clear-app-state' → 2; 'Library/Caches/ehpanda-phase16' → 3"
        status: pass
    human_judgment: false

# Metrics
duration: 14min
completed: 2026-08-23
status: complete
---

# Phase 16 Plan 02: Round-1 Sweep Verdict Table Summary

**`16-SWEEP.md` is now the round-1 state machine: a 42-surface inventory re-derived against HEAD, a 504-cell matrix every cell of which reads `pending`, the five pre-registered D-13 edge cases, a 48-row D-04 re-judgement checklist with every `file:line` re-confirmed at HEAD, and a sweep protocol that says exactly once how a cell is walked, where its screenshot goes, and what must never be run on the owner's logged-in simulators.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-08-23T13:55:00Z
- **Completed:** 2026-08-23T14:09:00Z
- **Tasks:** 2 of 2
- **Files created:** 1 (`16-SWEEP.md`, 1047 lines)

## Accomplishments

- **Re-derived the inventory against HEAD (D-12), not inherited.** Re-ran nine presentation-site greps over `AppPackage/Sources` — `.sheet(`, `.fullScreenCover(`, `.popover(`, `.alert(`/`.appAlert(`, `.confirmationDialog(`, `Menu {`, `.contextMenu`, `.navigationDestination(`, `.searchable(`, `toast` — and diffed the result against the RESEARCH 42-row table. **All 42 rows confirmed; none dropped; no 43rd landing surface exists.** `.popover(` and `NavigationLink` have zero hits in the tree today (the app navigates by `NavigationStack` path), which is recorded implicitly by their absence from the route column.
- **Folded five sub-surfaces the research table did not name individually into their host rows**, each listed in an explicit `### D-12 diff` table so nothing is lost: the Toplists jump-page alert (an alert *with a text field*, `ToplistsView.swift:34` + `ToolbarItems.swift:84` — the only `JumpPageButton` site in the tree), the Reading page context menu (`ReadingViewComponents.swift:149`), the Downloads row context menu (`DownloadsView.swift:195`), the Detail tag context menu (`DetailView+Subviews.swift:301`, the route to #21), and the Activity-logs run picker sheet + run menu (`AppActivityLogsView.swift:53, 62`).
- **Laid out the 12-cell matrix as six sub-tables** keyed to the six sweep plans (iPhone/iPad × Group A/B/C → 16-04…16-09), 504 rows, every one `pending`, every size carrying its `content_size` token inline. iPad rows are written as first-class rows, never derived from iPhone rows.
- **Registered the five D-13 named edge cases** with their exact sites, each `pending`, each closing only as `fixed` or `accepted (owner reason: …)` — including the note that D-03 makes the reader counter's *wrap* non-degraded, so `accepted` on the rule alone is a legitimate close that still gets recorded.
- **Built the D-04 checklist with every `file:line` re-verified at HEAD** — not copied on trust. `grep -rnF '.lineLimit(1)'` returned exactly the 30 sites at exactly the research's line numbers; `.minimumScaleFactor(` returned the same 5 at 155 / 166 / 42 / 73 / 165; each of the 12 fixed-frame lines was printed with `sed -n` and matched its described construct. The Phase-10 verdict column is carried only to show what D-04 overturns.
- **Wrote the protocol in the owner's literal terms** and made every rule it carries mechanically checkable: the explicit `--udid` (never `booted`, because two simulators are booted), scroll-to-bottom with `--settle` on every cell, the screenshot as the verdict basis (a truncated `Text` still reports its full label to the AX tree), record-and-move-on (D-02), and the restore to the **recorded** per-simulator baseline rather than a fixed `large` — the iPhone Air sits at `medium` and the iPad at `large`, so a fixed restore would silently change one of them.
- **Wrote the install-over rule once**, as its own `### Install-over` block: build by UDID → `plutil -extract CFBundleIdentifier raw` must print exactly `BUNDLE_ID` → `simctl install`. The bundle-id gate is explained from the source: `PRODUCT_BUNDLE_IDENTIFIER = "app.ehpanda$(BUNDLE_ID_SUFFIX)"` with the suffix set by the gitignored `Config/LocalSigning.xcconfig`, and **both** variants installed on both sweep simulators — so a mismatched install lands *beside* the logged-in app and the sweep then walks a logged-out shell. Recovery is a command-line `BUNDLE_ID_SUFFIX=` argument override, never an xcconfig edit.

## Verification Results

| Check | Required | Actual |
|---|---|---|
| `grep -c "^## "` | 9 | **9** |
| Matrix rows (`# | Screen | Device | …`) | 12 × 42 = 504 | **504** |
| `grep -c "| pending"` | ≥ 549 | **557** (504 matrix + 5 D-13 + 48 D-04) |
| `grep -c "| pass"` | 0 | **0** |
| D-13 verbatim names | ≥ 5 | **8** |
| `grep -c "| xSmall |"` | 0 | **0** |
| `grep -c "xSmall\|Bold Text"` | ≥ 1 | **1** (the D-07 note) |
| expanded home-path grep (the `/Users` prefix) | 0 | **0** |
| Untracked/tracked image files | 0 | **0 / 0** |
| `grep -c "^## Protocol"` | 1 | **1** |
| ``grep -c "never `booted`"`` | ≥ 1 | **1** |
| `grep -c "### Install-over"` | 1 | **1** |
| `grep -c "plutil -extract CFBundleIdentifier"` | ≥ 1 | **1** |
| `grep -c "clear-app-state"` | ≥ 1 | **2** |
| `grep -c "Library/Caches/ehpanda-phase16"` | ≥ 2 | **3** |
| `grep -c "content_size extra-extra-extra-large"` | ≥ 1 | **1** |
| `grep -c "accessibility-extra-large"` | ≥ 2 | **170** |
| `grep -c "recorded"` | ≥ 1 | **11** |
| `git log -1 --format=%s` | `docs(16): add sweep verdict table skeleton` | **exact match** |
| `git show --stat HEAD` | only `16-SWEEP.md` | **1 file, +1047** |

## Inventory Result

- **42 surfaces**, unchanged in count from RESEARCH § Screen inventory.
- **Added relative to RESEARCH:** none as new rows. Five sub-surfaces were *named* that the research table left implicit (listed above), each folded into its host row.
- **Dropped relative to RESEARCH:** none.
- **Excluded (D-11), 8 entries with reasons:** EhSetting web pages, the Account Setting WebView sheet, the Login WebView sheet, the Cloudflare challenge surface, the ShareExtension, the iOS share sheet (3 call sites), the photo picker, and the `BGContinuedProcessingTask` card.
- **Group split, matching the sweep plans:** A = #1–#13 (13 surfaces → 78 rows/device), B = #14–#27 (14 → 84), C = #28–#42 (15 → 90). 13 + 14 + 15 = 42; 78 + 84 + 90 = 252 rows/device; × 2 devices = 504.

## Task Commits

1. **Task 1: Re-derive the inventory, write the matrix skeleton, D-13 rows and D-04 checklist** — folded into the Task 2 commit (see Deviations #1). Verified independently at its own acceptance point before Protocol was inserted: `grep -c "^## "` printed `8`, 504 matrix rows, 557 `pending`, 0 `| pass`, no expanded home path, 0 images.
2. **Task 2: Write the sweep protocol section and commit the skeleton** — `ca017d25` (docs)

**Plan metadata:** see the `docs(16-02)` commit that follows this summary.

## Files Created/Modified

- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` — created, 1047 lines. Nine `## ` sections in the plan's order with Protocol inserted third: Infrastructure, Verdict rule, Protocol, Inventory, Matrix, Findings, D-13 named edge cases, D-04 checklist, D-25 re-sweep.

## Decisions Made

- **All 42 inventory surfaces are matrix screens; partial exclusions live in the D-11 column, not in a deleted row.** Four rows are partly out of scope (#22 NewDawn in / share sheet out, #27 Live Text in / share sheet out, #29 native rows in / WebView sheet out, #30 native form in / WebView + Cloudflare out, #38 native sections in / web pages out). Deleting them would have made plans 16-04…16-09 unreachable — they expect exactly 78 / 84 / 90 rows per device — and would have lost the in-scope half of each screen. The D-11 column carries the boundary instead.
- **The status vocabulary is written as `{`pending`, `pass`, …}`, not as a pipe-separated list.** The plan's own acceptance criterion requires `grep -c "| pass"` to print `0`, which is how the checker distinguishes an unverified matrix from a prematurely-filled one. A pipe-separated vocabulary line in the prose would have broken that check for a purely cosmetic reason. All five tokens are present and defined; only the separator changed.
- **Matrix laid out as six sub-tables rather than one 504-row table.** The sub-table headings name the owning plan (`### iPhone — Group A (#1–#13) — plan 16-04`), so a sweep session can find its rows without counting, and the resume rule ("first `pending` in layout order") stays a single unambiguous scan.
- **Screen names in the matrix are shortened to their head phrase** (everything before the first parenthetical) so a 504-row table stays readable; the full surface description, including every sheet/menu/dialog it hosts, lives once in § Inventory where it is edited.
- **Evidence-root subfolders are enumerated as a table with what each holds**, so 16-05's `d15-baseline/` and 16-11's `d15-after/` cannot be conflated by a later session that did not read the plans.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Task 1 and Task 2 land in one commit**
- **Found during:** Task 2 (commit step)
- **Issue:** The executor protocol commits each task individually, but this plan's `<verification>` item 3 states "One docs commit touching only `16-SWEEP.md`", and Task 1 carries no commit instruction of its own. Two commits would satisfy every *task* acceptance criterion (HEAD would still be the Task 2 commit with the required subject and a single-file stat) but would violate the plan-level verification.
- **Fix:** Followed the plan: Task 1's output was written and verified against its own acceptance criteria in place (8 `## ` sections at that point), then Protocol was inserted and the file committed once as `ca017d25`. Same precedent as plan 16-01, whose two tasks also touched a single file.
- **Files modified:** none beyond the plan's own file
- **Verification:** `git log -1 --format=%s` → `docs(16): add sweep verdict table skeleton`; `git show --stat HEAD` → 1 file changed, 1047 insertions.

**2. [Rule 1 - Bug] The must-have's pipe-separated status vocabulary contradicts the plan's `grep -c "| pass"` = 0 criterion**
- **Found during:** Task 1
- **Issue:** The plan's must-have truth spells the vocabulary as `` `pending | pass | finding:#N | re-verify | accepted` ``, but its acceptance criterion requires `grep -c "| pass" 16-SWEEP.md` to print `0`. Writing the vocabulary literally would put the substring `| pass` in the file and fail the check that proves nothing has been verified yet.
- **Fix:** Wrote the vocabulary as a brace-comma set — Status ∈ {`pending`, `pass`, `finding:#N`, `re-verify`, `accepted`} — in § Verdict rule and § Matrix. All five tokens are defined, each with its meaning; only the separator differs. The mechanical check now measures exactly what it was written to measure: a `| pass` hit can only come from a filled verdict cell.
- **Files modified:** `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md`
- **Verification:** `grep -c "| pass"` → `0`; all five tokens present (`grep -c "re-verify"` → 5).
- **Committed in:** `ca017d25`

**3. [Rule 2 - Missing critical functionality] The D-04 checklist carries 48 rows, not the 40 the criterion floors at**
- **Found during:** Task 1
- **Issue:** The acceptance criterion budgets "40 (D-04 rows)". RESEARCH § D-04 lists 30 `lineLimit(1)` sites, 5 `minimumScaleFactor` sites and 12 fixed-frame sites — 47 — plus `GalleryCardCell.swift:73`'s `lineLimit(4)`, which RESEARCH names only in the D-13 mapping paragraph and which would otherwise have no checklist row despite being a truncation site.
- **Fix:** Wrote all 48. The criterion is a floor (`≥`), so this satisfies it; the extra row keeps the hero-carousel truncation traceable from both § D-13 and § D-04.
- **Files modified:** `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md`
- **Verification:** 31 + 5 + 12 rows across the three D-04 sub-tables; total `| pending` = 557 = 504 + 5 + 48.
- **Committed in:** `ca017d25`

---

**Total deviations:** 3 auto-fixed (1 × Rule 3 blocking, 1 × Rule 1 bug, 1 × Rule 2 completeness)
**Impact on plan:** None on scope. No decision was reinterpreted; no scope was added or removed. Deviation 2 changes one separator character to keep a mechanical check meaningful.

## Issues Encountered

- **`grep 'Menu \{'` fails under the local `grep`.** The machine's `grep` is a `ugrep` alias that treats `\{` as an invalid repeat quantifier. Re-ran as `grep -F 'Menu {'`; 20 hits, all accounted for in the inventory. Worth knowing for plans 16-04…16-09, which re-grep to confirm a route.
- **`.popover(` and `NavigationLink` have zero occurrences in `AppPackage/Sources` today.** The tree navigates entirely by `NavigationStack` path and `.navigationDestination(item:)` (2 sites, both in `QuickSearchFeature`). Menus therefore carry the whole popover-surface class, which is why § Inventory states the counting rule that a `Menu { … }` is a popover surface.
- **The five `.minimumScaleFactor` sites each sit one or two lines below a `.lineLimit(1)` on the same `Text`.** That pairing is recorded in the D-04 checklist's Note column (":155 pairs with :152", etc.) because removing the shrink without also re-judging the paired line limit would leave a clipped value behind — a fix that closes a D-14 row while opening a D-04 one.

## User Setup Required

**Blocking for plan 16-03, by design (D-09):** the owner must sign in by hand on the sweep simulator(s) and tell the agent which UDIDs and which bundle id hold the login — `app.ehpanda` and `app.ehpanda.personal` are both installed on both booted simulators, so it is not guessable. Until § Infrastructure is filled, **no matrix row may be walked**. The agent never handles a credential.

## Next Phase Readiness

- **16-03** fills § Infrastructure (UDIDs, bundle id, the three read-back baseline values per simulator and the starting orientation) and runs the pre-flight that confirms live re-layout on a `content_size` change and the XXL token. The table rows and the forbidden-command list it must respect are already in place.
- **16-04…16-09** each have their rows pre-laid-out under a heading that names them, and a protocol they follow verbatim rather than re-deriving.
- **16-05** captures the D-15 `.large` baselines into `$EVIDENCE_ROOT/d15-baseline/`; **16-11** compares against `$EVIDENCE_ROOT/d15-after/`. The root is outside the repo and outside `/tmp` specifically so those two survive the owner checkpoint between them.
- **16-12** signs the table and lands `no_minimum_scale_factor`; the five sites it depends on are already registered as D-04 rows with the D-15 collision flagged on `DetailView+HeaderSection.swift:73`.

## Self-Check: PASSED

- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` exists (1047 lines, 9 `## ` sections, 504 matrix rows).
- Commit `ca017d25` exists on `feature/gsd-phase-16`; subject is exactly `docs(16): add sweep verdict table skeleton`; `git show --stat` lists only `16-SWEEP.md`.
- `git status --porcelain | grep -Ei '\.(png|jpe?g|heic|gif)$' | wc -l` → `0`; `git ls-files | grep -Ei '\.(png|jpe?g|heic|gif)$' | grep -c 16-dynamic-type-accessibility` → `0`.
- Grepping `16-SWEEP.md` for an expanded home-directory prefix → `0` hits; the evidence root is written only as `$HOME/Library/Caches/ehpanda-phase16/`.
- `.planning/phases/16-dynamic-type-accessibility/16-02-SUMMARY.md` exists.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-08-23*
