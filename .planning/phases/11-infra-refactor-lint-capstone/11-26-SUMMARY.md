---
phase: 11-infra-refactor-lint-capstone
plan: 26
subsystem: lint-config
tags: [single-line-trailing-closure, lint, swiftlint, mechanical-sweep, sources-half]
requires:
  - "11-25's `sorted_imports` flip — the sixth live rule this sweep must coexist with"
  - "The commented `single_line_trailing_closure` draft in .swiftlint.yml — the enumerator's regex"
provides:
  - "AppPackage/Sources, App and ShareExtension at 0 violations for `single_line_trailing_closure`"
  - "137 rewrapped closure sites across 76 files (0 in App/, 0 in ShareExtension/)"
  - "A scratch-config enumeration technique that never touches the tracked .swiftlint.yml"
affects:
  - "11-27 inherits 70 Tests-half sites and carries the config flip"
  - "11-28's `multiline_function_chains` sees no new multi-line chains from this sweep"
tech-stack:
  added: []
  patterns:
    - "Scratch-config enumeration: `swiftlint --config <scratch>.yml` with `only_rules: [custom_rules]`, so the tracked config is never edited and only the target rule reports"
    - "Diff-shape assertion by replaying the transform: every removed line re-run through the parenthesization function must equal an added line; the residue is exactly the hand rewraps"
key-files:
  created: []
  modified:
    - AppPackage/Sources/CookieClient/CookieClient.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
    - "73 further Swift files across AppPackage/Sources"
decisions:
  - "The plan's ~149 inventory was stale; the true count at HEAD was 145 violations across 76 files. Reported, not adjusted — consistent with every prior wave in this phase."
  - "Parenthesization was the default form, not multi-line. 130 of the 137 sites are short pure transforms in a chain (`.filter { $0.x }`), where `.filter({ $0.x })` is the smaller and clearer edit; 7 sites with a real body or a nested closure were rewrapped multi-line."
  - "Six methods need an argument label once the closure leaves trailing position: `sorted`/`sort` take `by:`, `first`/`last`/`firstIndex`/`contains` take `where:`. The trailing-closure form hides this; a naive parenthesization would not compile."
  - "Enumeration used a scratch config passed via `--config`, never a temporary edit of the tracked `.swiftlint.yml`. The plan's stated technique (uncomment, run, `git checkout --`) leaves a window in which an interrupted run commits a live rule against 145 violations."
  - "`.swiftlint.yml` is byte-identical to HEAD~2. No `swiftlint:disable` directive was written; none is possible while the rule is commented out (it would trip `superfluous_disable_command`), and no site needed one."
  - "No exception sites. Every one of the 145 violations was rewrapped at parity; 11-27 inherits an empty directive payload."
metrics:
  duration: ~25 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 26: single_line_trailing_closure — Sources Half Summary

`AppPackage/Sources`, `App` and `ShareExtension` report **0 `single_line_trailing_closure`
violations** against the draft rule. **`.swiftlint.yml` is untouched** — the rule stays commented
out, and the flip lands in 11-27 with the last fix (Pitfall 10).

Two commits: `505f6b7a` (first half, 73 sites) and `47168d9d` (second half, 71 sites+adjustments),
76 files, +158/−144 lines.

## The count: 145, not ~149 — and 70 remain in Tests

| | Plan / RESEARCH | Actual at HEAD |
|---|---:|---:|
| Sources violations | ~149 | **145** |
| Sources files | — | **76** |
| `App/` violations | — | **0** |
| `ShareExtension/` violations | — | **0** |
| Tests violations (11-27's half) | — | **70** |
| Phase total | 223 | **215** |

The drift is downward this time, unlike 11-25's. Reported rather than adjusted; the condition that
actually holds is the binary's zero over the three source roots, which is what was checked.

Both source-tree targets outside the package are already clean, so despite the plan naming `App/`
and `ShareExtension/` in `files_modified`, neither was touched.

## Enumeration without editing the tracked config

The plan's stated technique is to uncomment the draft rule in the working-tree `.swiftlint.yml`,
lint, then `git checkout --` the config before committing. That works, but it leaves a window in
which the repository holds an error-level rule with 145 live violations — an interrupted or
mis-ordered run commits a broken build.

A scratch config passed with `--config` gets the same enumeration with no such window:

```yaml
only_rules:
  - custom_rules
custom_rules:
  single_line_trailing_closure:
    regex: '…'          # copied verbatim from the commented draft
    excluded_match_kinds: [comment, string]
    severity: error
```

`only_rules: [custom_rules]` means the run reports this rule and nothing else, so the output is
directly a work list. Confirmed by inspecting the JSON: every one of the 145 entries carries
`rule_id: single_line_trailing_closure`, so no module-level nested `.swiftlint.yml` leaked another
rule into the result. `git diff --name-only -- .swiftlint.yml` was empty before each commit, and
the config is byte-identical to `HEAD~2` across both.

## Parenthesization is the default; multi-line is the exception

The rule offers two remedies. The design intent is readability, so a mechanical choice of one form
everywhere would defeat it — but the site distribution is lopsided:

| Form | Sites | Shape |
|---|---:|---|
| Parenthesized | **130** | `.filter { $0.x }` → `.filter({ $0.x })` — short pure transform, usually inside a chain |
| Multi-line | **7** | real body, or a closure nested inside another closure |

130 of the sites are one-expression transforms in a `map`/`filter`/`compactMap` chain, or a
one-assignment `withLock { $0 = value }`. Breaking those across three lines would triple the line
count of every reducer effect in the tree for no gain in clarity. The 7 that went multi-line are
listed below.

### The six methods that need a label

This is the trap in a mass parenthesization, and it is invisible in the trailing form:

| Method | Trailing | Parenthesized |
|---|---|---|
| `sorted`, `sort` | `.sorted { $0 > $1 }` | `.sorted(by: { $0 > $1 })` |
| `first`, `last`, `firstIndex`, `contains` | `.first { $0.isX }` | `.first(where: { $0.isX })` |
| `map`, `compactMap`, `flatMap`, `filter`, `forEach`, `reduce`, `allSatisfy`, `withLock` | `.map { … }` | `.map({ … })` |

Trailing-closure syntax elides the label; parentheses restore the requirement. The compiler catches
a miss, which is why the build gate runs per task rather than once at the end — but the label map
was derived from the standard-library signatures up front rather than by build-failure iteration.

### The seven multi-line rewraps

| File:line (pre-edit) | Why not parenthesized |
|---|---|
| `AppFeature/View/TabBar/TabBarView.swift:101` | `.onChange(of:)` already has an argument list; the closure carries an `in` clause |
| `HomeFeature/GalleryCardCell.swift:142` | same — `.onChange(of:initial:)` with `_, newColors in` |
| `ReadingFeature/ReadingViewComponents.swift:341` | `.task(id: url) { await load() }` — argument list present |
| `CookieClient/CookieClient.swift:468` | `withLock { $0.values.forEach { $0.yield(()) } }` — nested; the inner `$0` shadowed the outer, so the outer parameter was named `subscribers` |
| `SettingFeature/AppActivityLogs/AppActivityLogsView.swift:184` | `.map { (day: …, runs: $0.value.sorted { … }) }` — nested `$0` again; outer parameter named `group` |
| `SettingFeature/AppearanceSetting/AppearanceSettingView.swift:115` | `withLock` nested inside `.onTapGesture` |
| `SettingFeature/Components/DownloadSettingView.swift:45` | `withLock` nested inside a binding `set:` |

The four nested cases are the interesting ones: parenthesizing only the *inner* closure silences the
rule (the outer no longer matches, because its body then contains braces) while leaving a denser
line than before. That is the rewrap-makes-it-worse failure the design intent warns about, so all
four were opened by hand. Two required renaming the outer closure parameter away from `$0` to
un-shadow the inner one — the only semantically load-bearing edits in the sweep, both verified by
the compiler and the suite.

## Reviewing 144 changed lines by replaying the transform

The parenthesization is a total function, so the review does not need to be a read-through. Each
removed line was re-run through the exact transform and matched against the added lines; anything
left over is, by construction, not a pure parenthesization:

| Commit | Removed lines | Explained by pure parenthesization | Residue |
|---|---:|---:|---|
| `505f6b7a` | 73 | 71 | the 2 hand rewraps in that half |
| `47168d9d` | 71 | 66 | the 5 hand rewraps in that half |

The residue in both cases is exactly the hand-edited set from the table above, named line for line —
no fourth category. This bounds the whole sweep to "closures parenthesized, plus seven named
rewraps" without reading 76 files, and it would catch a transposed character, a dropped `$0`, or a
mangled line that a skim would not.

## The other six live rules, and `line_length` in particular

Parenthesizing lengthens a line by 2 characters (6 for the labeled forms), and `line_length` is at
**error 120**. A full `--strict` run against the **live** `.swiftlint.yml` over the three source
roots reports **0 violations** after both halves — `line_length`, `lifecycle_modifiers`,
`binding_initializer`, `unchecked_subscript_index_access`, `labeled_tuple_elements`, `optional_try`
and `sorted_imports` all clean. No line crossed the limit; the longest touched line
(`DetailView+Subviews.swift:263`, at 118 characters after the edit) is the closest call.

Two rules deserved a specific look rather than reliance on the aggregate zero:

- **`optional_try`** — the repo is at 0 and this sweep introduces no `try` at all. Confirmed by the
  strict run.
- **`labeled_tuple_elements`** — `AppActivityLogsView.swift` was rewritten around a labeled tuple
  `(day:runs:)`. The rule polices tuple *types*, and the function's return type was not touched.

## `multiline_function_chains` (11-28) was not worsened

Parenthesization is a within-line edit, so the 130 parenthesized sites create no new multi-line
chains and change no chain's break points. Of the 7 multi-line rewraps, six are modifier or
closure-body expansions rather than chain breaks; the seventh (`AppActivityLogsView.swift:184`)
keeps one call per line, which is the shape 11-28 wants.

One **pre-existing** shape will still need 11-28's attention and was deliberately left alone:
`AppModels/Gallery/GalleryComment.swift:40–41`, where `.joined()` shares a line with `.compactMap`
inside a broken chain. It was that way before this plan and fixing it here would put a
`multiline_function_chains` edit in a `single_line_trailing_closure` commit.

## Verification

- **Scratch-config enumeration, all three source roots** — 145 violations across 76 files at
  baseline; **0** after both halves at `--strict --no-cache`.
- **Tests half, unchanged** — 70 violations, confirming the enumerator still sees real work and that
  this plan's zero is not an artefact of a silently-disabled rule.
- **Live-config `--strict`** over the three roots — **0 violations**, after each half.
- **Diff-shape replay** — table above; residue is exactly the 7 named hand rewraps.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** after each half (23.7 s, 20.3 s), 0 errors,
  0 warnings.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (27.6 s), 0 errors. The
  `Tests/` compile gate (Pitfall 6 / the `e8589355` incident class).
- **Full `AppPackage-Package` suite** — **TEST SUCCEEDED**, **565 tests across 18 runs, 0 failed**.
- `git diff --name-only -- .swiftlint.yml` — empty at both commits; config byte-identical to `HEAD~2`.
- `git diff --diff-filter=D HEAD~2 HEAD` — empty; no file deleted. No untracked files at either commit.
- `LINT-01` left open — it flips at 11-29.

### On the test count

`TEST SUCCEEDED` alone is not evidence on this project: the XCTest summary prints `Executed 0 tests`
because everything is on Swift Testing, so a suite that silently ran nothing prints the same banner
(11-25's catch). The run was repeated capturing the `Test run with N tests` lines and summed:
**565**, matching every prior wave in this phase. Two "known issues" appear — pre-existing
`withKnownIssue` markers, unchanged by this wave.

## Deviations from Plan

**1. [Scope] The ~149 inventory was stale; the real figure was 145 across 76 files**

- **Found during:** Task 1 enumeration
- **Issue:** 4 fewer violations than the plan recorded. `App/` and `ShareExtension/` contributed
  zero despite being named in `files_modified`.
- **Fix:** Reported, not adjusted. The verification condition checked is the binary's zero.
- **Commit:** n/a

**2. [Rule 3 — Blocking] Enumeration technique changed to a scratch config**

- **Found during:** Task 1
- **Issue:** The plan directs the enumerator to uncomment the rule in the tracked `.swiftlint.yml`
  and revert it before committing. That leaves a window where the repository holds an error-level
  rule against 145 live violations; an interrupted run commits a broken build, and the technique has
  to be repeated at every re-lint.
- **Fix:** A scratch config with the draft regex copied verbatim, passed via `--config`, with
  `only_rules: [custom_rules]` so nothing else reports. Same authoritative list, tracked config never
  written. The plan's acceptance criterion ("committed diff contains NO `.swiftlint.yml` change") is
  satisfied more strongly — the file was never modified at all.
- **Commit:** n/a (tooling only)

**3. [Rule 3 — Blocking] Test scheme substitution (as in every prior wave)**

- **Issue:** The plan's verify block names only `xcodebuild build -scheme EhPanda`; the task text
  asks for "one representative module test scheme", which is not a thing this project has.
- **Fix:** The full package suite, `xcodebuild test -scheme AppPackage-Package -destination
  '…iPhone Air'` from `AppPackage/`, plus `build-for-testing -scheme EhPanda`. Both run, both green.
  Running the whole 565-test suite costs 61 s, so picking a representative subset buys nothing.
- **Commit:** n/a (invocation only)

**4. [Deviation from plan wording] Two closure parameters renamed**

- **Found during:** Task 1 (`CookieClient.swift:468`) and Task 2 (`AppActivityLogsView.swift:184`)
- **Issue:** The plan says "never alter closure semantics, capture lists, or argument names". Both
  sites nest a `$0`-using closure inside another `$0`-using closure; expanding the outer one to
  multiple lines requires naming the outer parameter, or the inner `$0` silently rebinds.
- **Fix:** Outer parameters named `subscribers` and `group` respectively. This is the minimum edit
  that preserves behaviour — the alternative (parenthesizing only the inner closure) satisfies the
  rule but leaves a denser line, which the design intent explicitly rejects.
- **Commit:** `505f6b7a`, `47168d9d`

## Exception sites for 11-27

**None.** All 145 Sources violations were rewrapped at parity. No site needed a prose-reason comment,
and no `swiftlint:disable` directive was written — one cannot exist while the rule is commented out
(it trips `superfluous_disable_command`, which is error-level). 11-27's flip commit therefore carries
an empty directive payload from this half; the Tests half's 70 sites are its own to assess.

## Known Stubs

None.

## Threat Flags

None. Syntactic rewrapping only — no logic, no control flow, and no new network, auth, file-access or
schema surface. **T-11-29's mitigation is satisfied**: the compiler gated each half
(`BUILD SUCCEEDED` twice, `TEST BUILD SUCCEEDED`), the diff-shape replay bounds 137 of the 144 changed
lines to a provably behaviour-preserving transform, the remaining 7 were hand-reviewed and named, and
the full 565-test suite passed.

## Self-Check: PASSED

- `.swiftlint.yml` — FOUND; unchanged since `HEAD~2`, `single_line_trailing_closure` still commented
- `AppPackage/Sources/CookieClient/CookieClient.swift` — FOUND; `notify()` multi-line, outer parameter
  named `subscribers`
- `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift` — FOUND;
  `groupedRuns` multi-line, outer parameter named `group`
- `AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift` — FOUND; `.task(id:)` multi-line,
  its `swiftlint:disable:next lifecycle_modifiers` directive and reason comment intact
- `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` — FOUND; `.onChange(of:initial:)` multi-line
- `.planning/phases/11-infra-refactor-lint-capstone/11-26-SUMMARY.md` — FOUND
- Commit `505f6b7a` — FOUND; 43 files, no deletions
- Commit `47168d9d` — FOUND; 33 files, no deletions
