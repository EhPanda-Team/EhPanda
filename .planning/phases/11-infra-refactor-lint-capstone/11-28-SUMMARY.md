---
phase: 11-infra-refactor-lint-capstone
plan: 28
subsystem: lint-config
tags: [multiline-function-chains, lint, swiftlint, mechanical-sweep, rule-flip, built-in-rule]
requires:
  - "11-27's `single_line_trailing_closure` flip — the seventh live rule this one must coexist with"
  - "11-26's handover of the pre-existing `GalleryComment.swift:40–41` chain site"
provides:
  - "`multiline_function_chains` live at severity error, 0 violations across all four path roots"
  - "43 misplaced chained calls reformatted across 32 lines in 19 Sources files"
  - "The eighth live lint rule, and the last of the seven LINT-01 rule deliverables"
affects:
  - "11-29's capstone verification battery — all seven rules now enforced; LINT-01 still open"
  - "Every future build: a multi-line chain with two calls sharing a line now fails the build"
tech-stack:
  added: []
  patterns:
    - "Raw-vs-unique violation accounting: this rule reports once per chain-link pair, so the headline count double-counts; the work list is the deduplicated (file, line, character) set"
    - "Negative-control probe with a base-plus-one-call case, proving the rule's one-shared-call allowance rather than assuming it"
key-files:
  created: []
  modified:
    - .swiftlint.yml
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/AppModels/Gallery/GalleryComment.swift
    - "16 further Swift files across AppPackage/Sources"
decisions:
  - "The plan's ~85/20 figure is the RAW violation count; the true work list is 43 unique offending calls on 32 lines across 19 files. Both numbers reported rather than adjusted, consistent with every prior wave."
  - "Zero sites were created or reshaped by 11-26/11-27, verified by blaming all 32 offending lines against the three sweep commits: 31 last touched by older unrelated commits, and the one intersection (GalleryComment:41) had its chain break already present at 505f6b7a^."
  - "Receiver-alone was the default shape, not receiver-plus-one-call. The rule permits one call on the base expression's line, but a `Text(x).font(y)` head followed by one-per-line modifiers reads as an arbitrary wrap; splitting the head is 1 extra line for a uniform chain."
  - "Two sites were shortened rather than split: both had an argument list broken across lines purely so a following `.map`/`?.lowercased()` could ride the closing-paren line. Joining the argument list removed the chain break entirely."
  - "`.map({ … })` parenthesized at DownloadClient+PublicAPI, not left trailing — `map` is on 11-27's `single_line_trailing_closure` method list, so the trailing form would have traded one live rule's violation for another's."
metrics:
  duration: ~25 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 28: multiline_function_chains — Final Rule Flip Summary

`multiline_function_chains` is **live at `severity: error`** and the standalone binary reports
**0 violations, 0 serious in 452 files** at `--strict --no-cache` across all four path roots. This
is the **seventh and final rule flip** of the phase; the capstone battery runs at 11-29.

One commit: `5a86b4a0`, 20 files, +102/−49.

## The count: 84 raw, but 43 real sites

| | Plan / RESEARCH | Actual at HEAD |
|---|---:|---:|
| Violations reported | ~85 | **84** |
| **Unique offending calls** | — | **43** |
| Distinct lines touched | — | **32** |
| Files | 20 | **19** |
| `AppPackage/Tests` / `App` / `ShareExtension` | 0 | **0** |

The raw figure matches the plan almost exactly, but it is not the size of the job. This rule reports
**once per chain-link pair**, so a line carrying three misplaced calls surfaces as several identical
`(file, line, character)` entries — `NewDawnView.swift:104` alone appears four times at the same
offset. Deduplicating the JSON gives 43 genuine offenders on 32 lines. Both numbers are reported
rather than reconciled, consistent with every prior wave; the condition actually verified is the
binary's zero.

Distribution of the 43: `DetailView+Subviews` 7, `GalleryDetailCell` 5, `SettingTextField` 4,
`TagCloudView` 4, `CategoryView` 3, `TagDetailView` 3, `NewDawnView` 2, `HomeView+Sections` 2,
`GalleryCardCell` 2, `DetailView+HeaderSection` 2, and one each in `QuickSearchView`,
`GalleryComment`, `DetailView+CommentCells`, `Greeting`, `ControlPanel`, `CookieClient`,
`DownloadClient+PublicAPI`, `CommentsView`, `DownloadClient+ResponseValidationHelpers`.

## Nothing here was created by 11-26 or 11-27

This was the plan's stated interaction risk: two waves had just rewrapped 215 closure sites in the
same files, and could not verify the result against a disabled rule. **The risk did not
materialise — zero of the 43 sites was created or reshaped by either wave.**

Established rather than assumed: each of this wave's 32 offending lines was `git blame`d at the
pre-flip tree against the three sweep commits (`505f6b7a`, `47168d9d`, `2da57704`). **31 of 32 were
last touched by an unrelated, older commit.** The single intersection is `GalleryComment.swift:41`,
and it is not a counter-example — 11-26 edited that line *within* itself, parenthesizing
`.compactMap { … }` to `.compactMap({ … })`. Checked at `505f6b7a^`, the `.joined()` was already
riding that line before 11-26 ran, which is precisely what 11-26 recorded when it handed the site
over.

So the shape count is unchanged by both waves. Their own reasoning predicted this and is now
confirmed empirically: parenthesization is a within-line edit, so it cannot create a chain break or
move one, and the handful of multi-line rewraps 11-26 did perform were closure-body expansions, which
put one call per line by construction.

## The site 11-26 handed over

`AppModels/Gallery/GalleryComment.swift:41`, the one pre-existing shape 11-26 deliberately declined
to fix so a chain edit would not land in a closure commit:

```diff
         contents
             .filter({ [.plainText, .linkedText, .singleLink].contains($0.type) })
-            .compactMap({ $0.type == .singleLink ? $0.link?.absoluteString : $0.text }).joined()
+            .compactMap({ $0.type == .singleLink ? $0.link?.absoluteString : $0.text })
+            .joined()
```

`DetailView+CommentCells.swift:17` is the same shape — a `.joined()` riding the `.compactMap` line —
and was fixed identically.

## Shapes chosen

The rule permits exactly one chained call on the base expression's line (confirmed by probe, below).
Three shapes were available, and the site decided which:

| Shape | Sites | When |
|---|---:|---|
| Receiver alone, then one call per line | 30 | the common SwiftUI modifier chain |
| Base + one call, then one per line | 1 | `DownloadClient+PublicAPI` — the base call is long and self-contained |
| Chain break removed entirely | 2 | the argument list was broken only so the next call could ride the `)` line |

**Receiver-alone was preferred over the minimal edit.** Leaving `Text(text).font(font.bold())` as a
head and breaking the rest would have satisfied the rule with a smaller diff, but it re-creates in
miniature the shape the rule exists to reject: the break point stops tracking the call boundaries and
the reader has to count. One extra line per site buys a chain that scans uniformly.

The two shortened sites are the more interesting ones, because there the rule pointed at a real
formatting artefact rather than a style preference:

```diff
-            storage.existingCoverRelativePath(
-                folderURL: folderURL,
-                manifest: download.manifest
-            ).map {
-                folderURL.appendingPathComponent($0)
-            }
+            storage.existingCoverRelativePath(folderURL: folderURL, manifest: download.manifest)
+                .map({ folderURL.appendingPathComponent($0) })
```

The argument list was split across three lines purely so `.map` could sit on the closing-paren line.
Joined, the call is 96 characters — well inside the 120 limit — and the chain no longer breaks
awkwardly. `DownloadClient+ResponseValidationHelpers.swift:19–21` had the identical artefact around
`httpResponse.value(forHTTPHeaderField:)?.lowercased()` and was resolved the same way. These two are
the only sites where the diff is net-negative.

**`.map({ … })`, not `.map { … }`.** `map` is on 11-27's `single_line_trailing_closure` method list,
so the trailing form would have traded a violation of this rule for a violation of that one. Caught
before the build, from the method table in the 11-26 summary rather than by lint failure.

## Negative-control probe

Mandatory: a misspelled entry in `opt_in_rules` is not a config error — SwiftLint emits one stderr
line and enables nothing, reporting zero forever on any input, which is indistinguishable from this
wave's clean result. A throwaway `Probe.swift` at the repo root was linted against the **live**
post-flip config, then deleted:

| Case | Source shape | Expected | Result |
|---|---|---|---|
| Two calls share the base line, chain then breaks | `[…].filter({…}).map({…})` ⏎ `.reduce(0, +)` | **fires** | **fired** ✓ (L4, at `.map`) |
| One call per line | `[…]` ⏎ `.filter` ⏎ `.map` ⏎ `.reduce` | silent | **silent** ✓ |
| Single-line chain | `[…].filter({…}).map({…}).reduce(0, +)` | silent | **silent** ✓ |
| Base + exactly one call, then one per line | `[…].filter({…})` ⏎ `.map` ⏎ `.reduce` | silent | **silent** ✓ |

Exactly one violation, on the one genuinely offending construct, at the correct column. The rule is
provably registered and firing on real code — a zero-violation run alone could not have shown this.

The fourth row is load-bearing beyond registration: it **proves the one-shared-call allowance**
rather than inferring it from which offsets the baseline enumeration happened to report. Every
"receiver + first call" head left in the tree depends on that allowance being real.

Rule availability was also confirmed against the binary's own registry before writing the config:

```
| multiline_function_chains | yes | no | no | style | ... |
```

`no` in the correctable column — unlike `sorted_imports` (11-25), this rule has no autocorrect, so all
43 sites were hand edits. That was the plan's expectation and it held.

## Verification

- **Scratch-config enumeration, all four roots** — 84 raw / 43 unique at baseline across 19 files,
  0 in `AppPackage/Tests`, `App` and `ShareExtension`; **0** after the sweep. Enumeration used a
  scratch config via `--config`, never a temporary edit of the tracked file (11-26's technique).
- **Negative-control probe** — table above, 4/4, against the live post-flip config; probe deleted and
  `git status --short` confirmed zero untracked files before staging.
- **Live-config `--strict --no-cache`, all four roots, all rules** — **0 violations, 0 serious in 452
  files**. All seven previously-live rules clean, `line_length` included; no stderr config warning.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** (24.5 s), 0 errors, 0 warnings.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (29.9 s), 0 errors. The
  `Tests/` lint gate (Pitfall 6 / the `e8589355` incident class) on 11-22.1's repaired 18-target plan.
  Run after the flip. This wave's payload is entirely in `Sources/`, so the app-scheme build already
  covered it — the test build proves no test file regressed under the newly-live rule.
- **Full `AppPackage-Package` suite** — **TEST SUCCEEDED** (64.9 s), **565 tests across 18 runs,
  0 failed**.
- **Diff-shape review** — every changed line that is not a bare `.call(…)` was enumerated and
  accounted for: 10 receiver lines split from their trailing calls (receiver text byte-identical),
  one closure body re-indented by 4, and the two joined argument lists. No expression was altered.
- `git diff --diff-filter=D HEAD~1 HEAD` — empty; no file deleted. No untracked files.
- `LINT-01` left open — it flips at 11-29.

### On the test count

`TEST SUCCEEDED` alone is not evidence on this project: the XCTest summary prints `Executed 0 tests`
because everything is on Swift Testing, so a suite that silently ran nothing prints the same banner
(11-25's catch). The `Test run with N tests` lines were captured and summed: **565** across 18 runs,
matching every prior wave in this phase. Three known issues appear across two runs — pre-existing
`withKnownIssue` markers, unchanged by this wave.

### `line_length` specifically

The plan flagged this as the live interaction risk (T-11-31): splitting a chain lengthens no line,
but the two *joined* argument lists do. Both were measured before editing rather than discovered by
build failure — 96 and 83 characters against the 120 error threshold. The aggregate `--strict` zero
confirms nothing else crossed.

## The atomic flip

One commit, `5a86b4a0` (Pitfall 10): 19 reformatted source files plus the config entry. The
**directive payload is empty** — no `swiftlint:disable` anywhere, the fourth consecutive flip for
which this is true — but the atomicity constraint still bound the sweep, since 43 live violations
plus an error-level rule is a broken build in either order.

The config entry carries a comment explaining what the rule enforces and the one-shared-call
allowance, so a future reader does not have to re-derive it from a probe:

```yaml
# A chain that breaks across lines must put every chained call on its own line. Exactly one call may
# share the base expression's line; once a second call joins it, the break points stop tracking the
# call boundaries and the chain reads as an arbitrary wrap. Single-line chains are untouched.
multiline_function_chains:
  severity: error
```

SwiftLint defaults were used for everything else, per the CONTEXT Claude's-discretion note — this
built-in rule exposes no tuning knobs beyond severity, so there was nothing to decide. None of the
custom-rule machinery (`excluded_match_kinds`, per-rule `excluded:`, regex) applies or was carried
over.

## Deviations from Plan

**1. [Scope] The ~85/20 inventory is the raw count; the real work list is 43 sites in 19 files**

- **Found during:** Task 1 enumeration
- **Issue:** The rule double-reports each chain-link pair, so 84 raw entries deduplicate to 43 unique
  offending calls on 32 lines. The file count is 19, not 20.
- **Fix:** Reported, not adjusted. The verification condition checked is the binary's zero.
- **Commit:** n/a

**2. [Rule 3 — Blocking] Enumeration used a scratch config, not a temporary edit of the tracked file**

- **Found during:** Task 1
- **Issue:** The plan's Task 1 action names the "temporary-enable technique" — add the rule to the
  working-tree `.swiftlint.yml`, lint, revert. That leaves a window in which the repository holds an
  error-level rule against 43 live violations; an interrupted run commits a broken build.
- **Fix:** 11-26's scratch config passed via `--config`, with `only_rules: [multiline_function_chains]`
  so the output is directly a work list. The tracked config was written exactly once, in the flip.
- **Commit:** n/a (tooling only)

**3. [Rule 3 — Blocking] Test scheme substitution (as in every prior wave)**

- **Issue:** The plan's verify blocks name only `xcodebuild build` / `build-for-testing -scheme
  EhPanda`; the full suite on this project runs under `AppPackage-Package`.
- **Fix:** Both plan-named commands run and green, plus `xcodebuild test -scheme AppPackage-Package
  -destination '…iPhone Air'` from `AppPackage/` for the 565-test suite. All three sequential, never
  concurrent.
- **Commit:** n/a (invocation only)

**4. [Deviation from plan structure] Tasks 1 and 2 landed in one commit**

- **Issue:** The plan splits the reformat (Task 1) from the flip (Task 2), which the per-task commit
  protocol would commit separately.
- **Fix:** One atomic commit, per Pitfall 10 and the plan's own Task 2 wording. Both tasks'
  acceptance criteria were verified before it opened.
- **Commit:** `5a86b4a0`

**5. [Deviation from plan wording] Two sites were shortened rather than reformatted**

- **Found during:** Task 1
- **Issue:** The plan says "pure formatting — no expression changes". At the two `DownloadClient`
  sites the chain break existed only because an argument list had been split across lines; joining
  the argument list removes the break entirely and is the smaller, clearer result.
- **Fix:** Applied. The calls are semantically identical — same callee, same arguments, same order;
  only the whitespace between the parentheses changed. Both were length-checked (96 and 83 chars)
  before editing.
- **Commit:** `5a86b4a0`

## Exception sites

**None.** All 43 sites were reformatted at parity. No `swiftlint:disable` directive was written, and
no chain legitimately resisted the required shape — so no explanatory comment was owed under the
document-deliberate-designs rule.

## Known Stubs

None.

## Threat Flags

None. Whitespace-only reformatting plus a lint-config flip — no logic, no control flow, and no new
network, auth, file-access or schema surface. **T-11-31's mitigation is satisfied**: the two sites
that could lengthen a line were measured against the 120-char threshold before editing rather than
after, the aggregate `--strict` run reports zero for `line_length` and all seven other live rules,
and both build gates plus the 565-test suite passed inside the commit that enables the rule.

## Self-Check: PASSED

- `.swiftlint.yml` — FOUND; `multiline_function_chains` in `opt_in_rules` at `severity: error` with
  the explanatory comment block
- `AppPackage/Sources/AppModels/Gallery/GalleryComment.swift` — FOUND; `.joined()` on its own line
  (11-26's handover site)
- `AppPackage/Sources/DetailFeature/DetailView+Subviews.swift` — FOUND; all four chains one-per-line
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift` — FOUND; three chains split
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` — FOUND; argument list joined,
  `.map({ … })` parenthesized
- `.planning/phases/11-infra-refactor-lint-capstone/11-28-SUMMARY.md` — FOUND
- Commit `5a86b4a0` — FOUND; 20 files, +102/−49, no deletions, no untracked files
