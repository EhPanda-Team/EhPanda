---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "07"
subsystem: infra
tags: [website, privacy-policy, support-url, pal-source, wording-guard, app-store-connect]

requires:
  - phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
    provides: "D-05 (amended 2026-11-11), D-10 and D-26 decisions on the website URLs and release order"
provides:
  - "A wording guard test: no Apple-approval phrasing in tracked files outside .planning/"
  - "20-07-WEBSITE.md: the six live privacy pages, the support URL and the PAL source redirect, with status lines"
affects: [20-08 App Store Connect listing, release checks]

actuals:
  tokens: 4500
  tasks: 2
  commits: 3
plan_head_before: 2dcb3a988d2769b0696a6b2298c134cea353db7f
plan_head_after: 102b6716921d8d260b2910a737179d538a153e3e

tech-stack:
  added: []
  patterns: ["a tracked-file wording guard with a self-check on a temporary file"]

key-files:
  created:
    - actions-tool/tests/test_no_apple_approved.py
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-07-WEBSITE.md
  modified: []

key-decisions:
  - "Support URL is the GitHub repository page and no contact link is published (2026-11-11 owner decision, already recorded)"
  - "Privacy link is each language's own page, https://ehpanda.app/<language>/privacy/ (owner decision, already recorded)"

patterns-established:
  - "Website dependencies are recorded as `- privacy|support: <url> 200` lines checked by the plan's verify command"

requirements-completed: [UGC-18-01]

duration: 3min (this session; Task 1 and the draft record were made in earlier sessions)
completed: 2026-11-25
status: complete
---

# Phase 20 Plan 07: Website URLs and wording guard Summary

**Live check of the six per-language privacy pages, the GitHub repository support URL and the AltStorePAL.json redirect, all passing, plus a test that keeps "Apple-approved" wording out of the tracked files.**

## Performance

- **Duration:** about 3 min in this session (Task 1 and the draft record came from earlier sessions)
- **Completed:** 2026-11-25
- **Tasks:** 2
- **Files modified:** 2 (both created)

## Accomplishments

- `actions-tool/tests/test_no_apple_approved.py` fails on any case-insensitive `apple[- ]approved` or `approved by apple` in `git ls-files` outside `.planning/`, and proves itself on a temporary file. It passes on the current tree (2 tests, re-run this session).
- The live check (2026-11-25T08:34Z, after the website went live with the 3.0 release, D-26) found the six privacy pages (`en`, `de`, `ja`, `ko`, `zh-Hans`, `zh-Hant`) and the support URL `https://github.com/EhPanda-Team/EhPanda` at 200 with the plan's exact `curl -sSfL` flags.
- `https://ehpanda.app/AltStorePAL.json` answers `HTTP/2 302` with `location: https://github.com/EhPanda-Team/EhPanda/raw/main/AltStorePAL.json`, which is `AltStorePAL.json` on `main`.
- The six fetched privacy pages hold no match for the wording (0 hits each).
- The task's verify command gives 7 URL lines with 200 (needs 2) and 3 `AltStorePAL.json` lines (needs 1).

## Task Commits

1. **Task 1: Wording guard** - `49dd2b8be` (test), made in an earlier session and re-verified, not rewritten
2. **Task 2: Website URLs with the webmaster** - `102b67169` (docs); the draft record before it is `8c05bf931` (docs)

**Plan metadata:** the commit holding this SUMMARY, STATE.md and ROADMAP.md.

`commits: 3` is measured with `git log --grep='(20-07)'` from `plan_head_before` to `plan_head_after`. A plain `rev-list --count` over that range counts every other plan's commits on `develop` as well, because other work was merged in between, so it would not measure this plan.

## Files Created/Modified

- `actions-tool/tests/test_no_apple_approved.py` - the wording guard for tracked files
- `.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-07-WEBSITE.md` - the live URL record, the webmaster's answers and the amendment history

## Decisions Made

None new. The 2026-11-11 amendment (no contact link, support URL is the GitHub repository page) and the per-language privacy pages were owner decisions already recorded.

## Deviations from Plan

None - plan executed exactly as written. The webmaster's step-1 answer was already recorded and the orchestrator marked the resume signal received, so steps 2 to 4 were done directly.

Note, not a deviation: the redirect's target is GitHub's `https://github.com/EhPanda-Team/EhPanda/raw/main/AltStorePAL.json` path, not the `raw.githubusercontent.com` form quoted in the plan's question. It still points at `AltStorePAL.json` on `main`, which is what the plan's verification requires.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None. T-20-20 (dead support URL) is mitigated by the live 200 on the support URL before 20-08. T-20-21 ("Apple-approved" claims) is mitigated by the guard test and the page grep.

## Next Phase Readiness

20-08 can enter the support URL (the GitHub repository page) and a privacy policy URL (proposal: `https://ehpanda.app/en/privacy/`, with a localized listing's own page where one exists) in App Store Connect. DIST-18-02 stays Pending because 20-08 shares it. The privacy page rewrite for the three analytics levels is not requested here (D-10).

## Self-Check: PASSED

- FOUND: `actions-tool/tests/test_no_apple_approved.py`
- FOUND: `.planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-07-WEBSITE.md`
- FOUND commits: `49dd2b8be`, `8c05bf931`, `102b67169` (all ancestors of HEAD)
