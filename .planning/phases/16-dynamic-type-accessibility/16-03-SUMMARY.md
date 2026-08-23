---
phase: 16-dynamic-type-accessibility
plan: 03
subsystem: planning
tags: [dynamic-type, accessibility, sweep, simulator, pre-flight, infrastructure, D-09]

# Dependency graph
requires:
  - phase: 16-dynamic-type-accessibility
    plan: 02
    provides: "`16-SWEEP.md` with the unresolved § Infrastructure placeholders, the install-over rule, the forbidden-command list and the evidence root"
provides:
  - "`16-SWEEP.md § Infrastructure` resolved: IPHONE_UDID, IPAD_UDID, SPARE_UDID, BUNDLE_ID, IPHONE_LOGIN, IPAD_LOGIN, plus a shell block the sweep plans paste at session start"
  - "The reasoning for `BUNDLE_ID = app.ehpanda.personal` (the only id the project's build settings resolve on this machine, so the only one the install-over rule can target)"
  - "A `### Tooling` mapping from the § Protocol `agent-device` verbs to the owner's chosen `sim-use` driver"
  - "Per-simulator baselines recorded and proven restored; pre-flight A1 (live re-layout) and A6 (XXL token) confirmed on the real sweep simulator"
affects: [16-04, 16-05, 16-06, 16-07, 16-08, 16-09, 16-10, 16-11, 16-15, 16-26]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-flight proves an assumption once on the real target and records the outcome next to the values the later plans read, so no sweep plan re-derives it"
    - "Baseline read before the first change, restored to the recorded value, and read back after — the read-back is the proof, not the restore command"

key-files:
  created: []
  modified:
    - ".planning/phases/16-dynamic-type-accessibility/16-SWEEP.md"

key-decisions:
  - "BUNDLE_ID is `app.ehpanda.personal` because that is what `xcodebuild -showBuildSettings -scheme EhPanda` resolves on this machine (git-ignored `Config/LocalSigning.xcconfig` sets `BUNDLE_ID_SUFFIX`); `app.ehpanda` is never swept even though it also holds a session on the iPhone."
  - "IPAD_LOGIN is `none`: iPad rows of login-gated screens are recorded `blocked: no iPad session` and surfaced in plan 16-10's report; the row is written so a later owner login is a one-line amendment."
  - "sim-use is the primary sweep driver (owner's choice); the § Protocol listings stay in agent-device vocabulary and a `### Tooling` table maps each verb, so the protocol text is not rewritten."
  - "Pre-flight evidence is stored full-scale (sim-use writes the native-resolution PNG); no downscale step."

patterns-established:
  - "Sweep-plan session start is a paste of the § Infrastructure shell block followed by `xcrun simctl terminate $IPHONE_UDID app.ehpanda`, so only BUNDLE_ID is in the foreground"

requirements-completed: []  # A11Y-01 is phase-wide; it closes on the owner-signed sweep (16-12),
# not on any single plan. This plan opens the sweep environment; it verifies no screen.

coverage:
  - id: D1
    description: "Credential boundary honoured: the agent never read, typed, relayed or requested a credential; the rejected launch seam is not referenced (D-09)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "grep -ci 'IPB_MEMBER_ID\\|PASS_HASH\\|IGNEOUS' 16-SWEEP.md → 0; awk '/^## Infrastructure/,/^## Verdict rule/' | grep -ci cookie → 0; the only account-derived fact recorded is `login: present` / `none`"
        status: pass
    human_judgment: false
  - id: D2
    description: "Open Question 1 resolved: sweep simulators and bundle id named in the artifact; every later command addresses a UDID, never `booted` (D-08, D-09)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "grep -c 'IPHONE_UDID=' 16-SWEEP.md → 1; grep -c 'BUNDLE_ID=app.ehpanda' → 1; every simctl / sim-use call in this plan carried the explicit UDID"
        status: pass
    human_judgment: false
  - id: D3
    description: "A1 confirmed on the real sweep simulator: a running EhPanda re-lays out live on `content_size` without relaunch (D-05)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "same pid (51027) before and after the switch to accessibility-extra-extra-extra-large; Home heading 94×41 pt → accessibility size in `sim-use ui`; `$EVIDENCE_ROOT/preflight/ax5.png` shows the re-laid-out Home"
        status: pass
    human_judgment: false
  - id: D4
    description: "A6 confirmed: XXL = `extra-extra-extra-large` (iOS `xxxLarge`, slider 7), visibly between the baseline and AX5 (D-05)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "Home heading 94×41 (medium) → 105×46 (XXL) → larger still at AX5; 'Frontpage' 120×23 → 158×31; `$EVIDENCE_ROOT/preflight/xxl.png` vs `ax5.png`"
        status: pass
    human_judgment: false
  - id: D5
    description: "Idempotency: baselines recorded before the first change and restored exactly, proven by read-back on both simulators"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "iPhone read-back medium / dark / disabled / portrait (Home heading back to 94×41 pt); iPad read-back large / light / disabled / portrait (never changed)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Phase-infrastructure simulators untouched: no erase / uninstall / clear-app-state / install / xcodebuild test on either sweep UDID; no image in git (D-09, D-32)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "the only process-level action was `xcrun simctl terminate` of the non-target `app.ehpanda` and `xcrun simctl launch` of BUNDLE_ID; git status --porcelain image grep → 0; evidence lives only under $HOME/Library/Caches/ehpanda-phase16/preflight/"
        status: pass
    human_judgment: false

# Metrics
duration: 16min
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 03: Sweep Infrastructure and Pre-flight Summary

**The sweep environment is named, baselined, pre-flighted and restored: `16-SWEEP.md § Infrastructure` now carries the two sweep UDIDs, `BUNDLE_ID = app.ehpanda.personal` with the build-settings reasoning behind it, the login state per simulator, a `sim-use` tooling map, the recorded baselines with their read-back, and the two pre-flight confirmations (A1: live re-layout, A6: XXL token) — and the agent never touched a credential (D-09).**

## Performance

- **Duration:** 16 min (continuation agent; Task 1 was the owner's hand-login checkpoint, which consumed no agent time and produced no commit).
- **Simulator actions:** 2 `content_size` switches + 1 restore on the iPhone; 0 changes on the iPad (read only). One action at a time; no `xcodebuild` invocation in this plan.
- **Evidence:** 3 full-scale PNGs under `$HOME/Library/Caches/ehpanda-phase16/preflight/` (`baseline-medium.png`, `xxl.png`, `ax5.png`), none in the repo.

## Accomplishments

- Task 1 (checkpoint): the owner signed in by hand and named the environment; the orchestrator verified login state read-only via UI and passed six values (`IPHONE_UDID`, `IPAD_UDID`, `SPARE_UDID`, `BUNDLE_ID`, `IPHONE_LOGIN=present`, `IPAD_LOGIN=none`).
- Task 2: § Infrastructure filled — the values table, a paste-ready shell block, "Why `app.ehpanda.personal`", `### Tooling`, the baseline table with read-back, and `### Pre-flight`.
- Pre-flight on the iPhone only: `content_size` medium → AX5 → XXL → medium, with the app in the foreground on Home throughout; the process id never changed.
- Login confirmed on the iPhone by opening Favorites once (`present`); nothing from the page recorded. The iPad was only read (it sits on Favorites showing the login prompt under `app.ehpanda.personal`).

## Verification Results

| Check | Result |
|---|---|
| `grep -c "IPHONE_UDID = \|IPHONE_UDID="` | 1 |
| `grep -c "BUNDLE_ID = app.ehpanda\|BUNDLE_ID=app.ehpanda"` | 1 |
| `grep -c "### Pre-flight"` | 1 |
| `grep -ci "IPB_MEMBER_ID\|PASS_HASH\|IGNEOUS"` | 0 |
| `awk '/^## Infrastructure/,/^## Verdict rule/' \| grep -ci cookie` | 0 |
| grep for an expanded home-directory prefix | 0 |
| `xcrun simctl ui <IPHONE_UDID> content_size` / `appearance` after restore | `medium` / `dark` |
| `ls $HOME/Library/Caches/ehpanda-phase16/preflight/ax5.png` | present (1260×2736) |
| `git log -1 --format=%s` | `docs(16): record sweep infra and pre-flight` |
| `git status --porcelain \| grep -Ei '\.(png\|jpe?g\|heic\|gif)$' \| wc -l` | 0 |

## Pre-flight Outcomes

| Assumption | Outcome |
|---|---|
| A1 — running app re-lays out live on `content_size` | **Confirmed.** Same pid before/after; Home re-rendered at AX5 within 2 s. No sweep cell needs a relaunch after a size change. |
| A6 — XXL = `extra-extra-extra-large` (slider 7, `xxxLarge`) | **Confirmed.** Heading 94×41 → 105×46 pt at XXL; AX5 larger still. |

What the AX5 / XXL Home shots show is not judged here (the pre-flight is not a matrix walk); plan 16-04's Home rows own that verdict.

## Task Commits

1. **Task 1: Owner hand-login checkpoint** — no commit (checkpoint only; nothing modified).
2. **Task 2: Record the infrastructure, read the baselines, run the pre-flight, restore, commit** — `77e22cec` (docs)

**Plan metadata:** see the `docs(16-03)` commit that follows this summary.

## Files Created/Modified

- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` — § Infrastructure filled (+77 lines): values table with `IPHONE_LOGIN` / `IPAD_LOGIN` rows, shell block, "Why `app.ehpanda.personal`", `### Tooling`, baseline table with read-back note, `### Pre-flight`. No other section touched.

## Decisions Made

- `BUNDLE_ID = app.ehpanda.personal` is derived from the project's resolved build setting, not chosen; the reasoning is recorded so later plans do not second-guess it when they see `app.ehpanda` also logged in.
- `IPAD_LOGIN = none` is written as a single amendable row; login-gated iPad rows will be `blocked: no iPad session` and surfaced by 16-10 rather than silently skipped.
- `sim-use` is the primary driver; `agent-device` remains a documented fallback. The § Protocol text keeps its `agent-device` vocabulary with a mapping table, rather than being rewritten.
- Evidence stored full-scale; no `--scale 0.5` equivalent applied.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Non-target bundle in the foreground**
- **Found during:** Task 2 session start
- **Issue:** `app.ehpanda` (not `BUNDLE_ID`) was the running EhPanda process on the iPhone, so `sim-use ui` would have read the wrong app.
- **Fix:** `xcrun simctl terminate <IPHONE_UDID> app.ehpanda` (process only; touches no data container), then `xcrun simctl launch <IPHONE_UDID> app.ehpanda.personal`. Recorded in "Why `app.ehpanda.personal`" as the session-start rule.
- **Files modified:** `16-SWEEP.md`
- **Commit:** `77e22cec`

**2. [Rule 2 - Missing] Plan's verify grep expects a shell-form `IPHONE_UDID=`**
- **Found during:** Task 2 verification
- **Issue:** The values table alone does not match `grep "IPHONE_UDID = \|IPHONE_UDID="`.
- **Fix:** Added a paste-ready shell block under the table (the same values); it is also the form every sweep plan sources at session start.
- **Files modified:** `16-SWEEP.md`
- **Commit:** `77e22cec`

### Tooling substitution (not a deviation in outcome)

The plan's `agent-device open / snapshot / screenshot` steps were executed with `xcrun simctl launch` + `sim-use ui` / `sim-use screenshot`, per the owner's instruction to make `sim-use` the primary driver; the mapping is recorded in `### Tooling`.

## Issues Encountered

- `sim-use ui` printed "Screen orientation could not be confirmed (3 probes); assuming portrait" once on the iPhone right after launch; the header dimensions (420×912) confirmed portrait and the advisory did not recur.

## Authentication Gates

Task 1 was the planned D-09 gate: the owner logged in by hand on the iPhone Air; the agent received only UDIDs, a bundle id and `present` / `none`. No credential passed through any prompt, env var, shell history or artifact.

## Next Phase Readiness

- **16-04 … 16-09** can start: paste the § Infrastructure shell block, terminate `app.ehpanda` on the iPhone, launch `BUNDLE_ID`, and walk from the first `pending` row using the `### Tooling` map.
- **16-07 (wave 6)** inherits `IPAD_LOGIN=none`; if the owner logs in on the iPad before then, amend that one row in a separate docs commit.
- No relaunch fallback is needed anywhere (A1 confirmed), and XXL cells use `extra-extra-extra-large` (A6 confirmed).

## Self-Check: PASSED

- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` exists and contains `IPHONE_UDID=ADE09605-A44E-4F00-BE12-235970217355`, `BUNDLE_ID=app.ehpanda.personal`, `### Tooling`, `### Pre-flight`.
- Commit `77e22cec` exists on `feature/gsd-phase-16`; subject is exactly `docs(16): record sweep infra and pre-flight`; it touches only `16-SWEEP.md`.
- `$HOME/Library/Caches/ehpanda-phase16/preflight/ax5.png` exists; no image is tracked or staged in the repo.
- Grepping `16-SWEEP.md` and this summary for an expanded home-directory prefix → 0 hits; the evidence root is written only as `$HOME/…`.
- iPhone and iPad baselines read back identical to the recorded values.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-08-24*
