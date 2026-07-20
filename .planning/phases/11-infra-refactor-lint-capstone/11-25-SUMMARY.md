---
phase: 11-infra-refactor-lint-capstone
plan: 25
subsystem: lint-config
tags: [sorted-imports, rule-flip, lint, swiftlint, autocorrect, mechanical-sweep]
requires:
  - "11-24's `optional_try` flip — the fifth live rule this one must coexist with"
  - "11-22.1's repaired FeatureTests.xctestplan — makes build-for-testing a trustworthy Tests/ gate"
  - "11-17's silent-rule-disable finding — the reason the negative control is mandatory"
provides:
  - "`sorted_imports` live at severity error, repo-wide, no path exclusions"
  - "Sorted import blocks across 325 Swift files (893 violations, 100% tool-resolved)"
  - "The stale top-level `excluded:` block removed — it named a path deleted by the modularization"
  - "Empirical proof that sorted_imports sorts each compile-condition block independently"
affects:
  - "Every future build: an unsorted import block now fails the build in Sources AND test targets"
  - "325 of 452 linted files touched; net-zero line delta in Swift (pure reorder)"
tech-stack:
  added: []
  patterns:
    - "Tool-first mechanical sweep: `--fix` over explicit path roots, then diff-shape assertion instead of file-by-file review"
key-files:
  created: []
  modified:
    - .swiftlint.yml
    - AppPackage/Sources/CookieClient/CookieClient.swift
    - AppPackage/Sources/OSLogExt/Logger+.swift
    - "323 further Swift files across AppPackage/Sources, AppPackage/Tests, App, ShareExtension"
decisions:
  - "The plan's 870/319 inventory was stale; the true count at HEAD was 893 violations across 325 files. Reported, not adjusted — consistent with every prior wave in this phase."
  - "`--fix` resolved 893 of 893. Zero hand-fixes were needed, including in the three conditional-import files the RESEARCH anti-pattern flagged."
  - "The whole top-level `excluded:` block was deleted rather than repointed. Its sole entry named `EhPanda/App/Generated`; no `EhPanda/` directory and no `Generated` directory exists anywhere in the repo, so there was nothing to repoint it at."
  - "Review of the 325-file diff was done by asserting the diff's SHAPE (every changed line is an import line; net line delta accounts for exactly the config edit) rather than reading 325 files. The three named risk files were still read individually."
  - "No `swiftlint:disable` directives. A mechanical rule with a complete autocorrect leaves no exception sites, so the atomic-flip commit's directive payload is empty — as in 11-24."
metrics:
  duration: ~12 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 25: sorted_imports Rule Flip Summary

`sorted_imports` is **live at `severity: error`, repo-wide, with no path exclusions**. The standalone
binary reports **0 violations, 0 serious in 452 files** at `--strict` across `AppPackage/Sources`,
`AppPackage/Tests`, `App` and `ShareExtension`. This is the phase's largest single rule by violation
count and the first resolved entirely by the tool.

One commit: `bd28644e`, carrying 325 reordered files, the config flip and the stale-exclusion cleanup.

## This rule is built-in, so the custom-rule hazards do not apply

The four prior flips in this phase were `custom_rules:` regex entries. `sorted_imports` is a
**built-in opt-in rule**, which changes the shape of the config entry and retires most of the
accumulated hazard list:

| Prior-wave hazard | Applies here? |
|---|---|
| `excluded_match_kinds` spelling (`doccomment` vs `doc_comment`) | **No** — built-in rules have no such key |
| Per-rule `excluded:` being a file-path regex, not a text filter | **No** — not used |
| Regex over-matching prose in comments/strings | **No** — the rule is AST-driven, not regex |
| **Silent disable via a name SwiftLint does not recognise** | **Yes, and it is the whole risk** |

The last one survives in a different form. A misspelled entry in `opt_in_rules` is not a
configuration error — SwiftLint emits one stderr line and enables nothing. The observable symptom is
identical to the custom-rule trap 11-17 and 11-24 documented: **zero violations forever, on any
input**, indistinguishable from a clean tree. Since this wave's headline result *is* a zero, that
zero proves nothing on its own. Hence the negative control below.

Rule availability was confirmed against the binary's own registry before writing the config:

```
| sorted_imports | yes (opt-in) | yes (correctable) | ... | style | severity: ... |
```

## Negative control

Mandatory, run against the **live** `.swiftlint.yml` after the edit, on four scratch files:

| Probe file | Content | Expected | Actual |
|---|---|---|---|
| `Bad.swift` | `import Foundation` / `import AppModels` | **flagged** | **flagged**, line 2 |
| `Good.swift` | `import AppModels` / `import Foundation` | not flagged | **not flagged** |
| `Testable.swift` | `AppModels`, `@testable Foundation`, `Zzz` | not flagged | **not flagged** |
| `Conditional.swift` | `Zebra`, then `#if DEBUG` / `Alpha` / `#endif` | not flagged | **not flagged** |

One violation, on the one genuinely unsorted file. The rule is registered, it fires on real code, and
two behaviours the sweep depends on are confirmed rather than assumed:

- **`@testable` is ignored for ordering.** `Testable.swift` places `@testable import Foundation`
  between `AppModels` and `Zzz` — correct by module name, and accepted. This matters because 305 of
  the inventoried violations are in test files.
- **Each compile-condition block is sorted independently.** `Conditional.swift` has `Zebra`
  unconditionally and `Alpha` inside `#if DEBUG` — globally out of order, and *not* flagged. This is
  the direct answer to the RESEARCH anti-pattern warning: the rule has no reason to move an import
  across an `#if` boundary because it never compares across one.

Probe files deleted before the sweep; `git status --short` immediately before staging showed exactly
326 modified files and **zero** untracked.

## The stale exclusion pointed at a directory that no longer exists

The config's only top-level `excluded:` entry:

```yaml
excluded:
  - EhPanda/App/Generated
```

Investigated before touching it. There is no `EhPanda/` directory in the working tree, **zero**
git-tracked files under that prefix, and no directory named `Generated` anywhere in the repository.
The path is a survivor of the modularization to `App/` + `AppPackage/` — it named the old monolithic
app target's generated-sources folder, and nothing replaced it.

**The whole block was deleted rather than repointed**, because there is no current generated-sources
directory to repoint it at. This is safe in both consumers: every standalone run in this phase passes
the four path roots explicitly (never a bare repo-root run, which would traverse `AppPackage/.build`),
and the build plugin lints per-target file lists where a top-level path exclusion for a nonexistent
directory is inert either way.

## The sweep: 893 of 893 resolved by the tool

| | Plan / RESEARCH | Actual at HEAD |
|---|---:|---:|
| Violations | 870 | **893** |
| Files | 319 | **325** |
| Hand-fixes required | "hand-fix any file `--fix` could not settle" | **0** |

The count drifted upward by 23 — the phase's own waves added imports to test files as they went. The
drift direction is the opposite of 11-24's (where the count collapsed from 316 to 11), and the
handling is the same: reported, not silently adjusted.

`--fix` was run over the four explicit path roots, never bare. The re-lint immediately after was
**zero at `--strict`**, so no file needed a hand-fix — including all three conditional-import files.

### Reviewing a 325-file diff without reading 325 files

The prompt requires reviewing the autocorrect output. Reading 325 files is not review, it is
theatre. Two whole-diff assertions constrain the change far more tightly than skimming would:

**1. Every changed line is an import line.** Inverting a match for `^[+-](@testable )?import <Module>$`
over the entire Swift diff left exactly one line pair:

```
-@_exported import OSLog
+@_exported import OSLog
```

`OSLogExt/Logger+.swift`, where `@_exported import OSLog` moved below `import AppTools`. Re-export
semantics are order-independent, so this is correct. No other line in 325 files was touched by
anything other than a plain reorder.

**2. The Swift diff is net-zero lines.** `992 insertions, 989 deletions` = **+3**, and the config edit
alone is +6/−3 = +3. So the Swift half is exactly net-zero: nothing was added, nothing removed, only
reordered. A `--fix` that dropped or duplicated an import could not produce this.

Together these bound the change to "imports reordered, nothing else" across the whole sweep. The
three named risk files were still opened and read individually, below.

## The three conditional-import files

RESEARCH flagged these as the `--fix` hazard. **Only one of the three changed at all:**

**`CookieClient/CookieClient.swift`** — the only one:

```diff
-import Foundation
 import AppModels
-import ComposableArchitecture
 import AppTools
+import ComposableArchitecture
+import Foundation
 #if DEBUG
 import Synchronization
 #endif
```

The four unconditional imports sorted; `import Synchronization` stayed inside `#if DEBUG`, untouched.
Exactly the correct outcome, and the one the anti-pattern warning was worried about.

**`AppTools/ColorCodable.swift`** — unchanged. `import SwiftUI` unconditional, then a three-way
`#if os(iOS)` / `#elseif os(watchOS)` / `#elseif os(macOS)` chain carrying one import each. Every
block is trivially sorted already.

**`AppTools/DeviceType.swift`** — unchanged. A single `import UIKit` inside `#if canImport(UIKit)`.

The negative control explains why nothing was disturbed: the rule never compares imports across a
compile-condition boundary, so there is no mechanism by which it could hoist one out. The risk the
plan identified is real for a naive sorter and absent from this one — established by probe, not by
inspection of a passing build.

## Verification

- **Baseline, live config, all four roots** — 893 `sorted_imports` violations across 325 files, and
  **no other rule firing**. The five rules from 11-11/11-17/11-18/11-24 were already at zero.
- **Negative control** against the live config — table above. Probes deleted.
- **Post-`--fix` `--strict`, `--no-cache`, all four roots** — **0 violations, 0 serious in 452 files**.
  Re-run on the committed tree after the commit: same.
- **Whole-diff shape assertions** — only import lines changed; Swift half net-zero.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** (26.2 s), 0 errors, 0 warnings.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (30.5 s), 0 errors. This
  is the `Tests/` lint gate (Pitfall 6 / the `e8589355` incident class) on 11-22.1's repaired
  18-target plan. It matters more here than in any prior wave: **305 of the fixed violations are in
  test files**, which the app-scheme build does not lint at all.
- **Full `AppPackage-Package` suite** — **TEST SUCCEEDED**, **565 tests, 0 failed runs**.
- No file deleted by the commit (`git diff --diff-filter=D HEAD~1 HEAD` — empty).
- `LINT-01` left open — it flips at 11-29.

### On the test count

The XCTest summary lines print `Executed 0 tests` because this project is on Swift Testing, whose
counts appear only in its own `Test run with N tests` lines. **`TEST SUCCEEDED` alone is not
sufficient evidence here** — a suite that silently ran zero tests prints exactly the same thing, and
a 325-file change is the wrong moment to accept that ambiguity. The run was repeated capturing the
Swift Testing lines and summed: **565**, matching the count every prior wave in this phase reported.
Two runs also carried "known issues" (2 and 1) — pre-existing `withKnownIssue` markers, not failures,
and unchanged by this wave.

## The atomic flip

One commit, `bd28644e` (Pitfall 10):

1. 325 files with sorted import blocks
2. `sorted_imports` added to `opt_in_rules` with a `severity: error` block
3. the dead top-level `excluded:` block removed

**No `swiftlint:disable` directives.** A directive cannot exist while its rule is commented out, so
prior flips had to carry theirs into the flip commit; a mechanical rule with a complete autocorrect
generates no exception sites at all, so the payload is empty — the second consecutive flip for which
this is true. The atomicity constraint still bound the sweep to the config change regardless: 893
violations plus an active error-level rule is a broken build in either order.

The config entry documents the two behaviours the sweep relied on, so a future reader does not have
to re-derive them:

```yaml
# Sorts by module name; the `@testable` attribute is ignored for ordering, and each
# compile-condition block (`#if`/`#else`) is sorted independently of the unconditional block.
sorted_imports:
  severity: error
```

## Deviations from Plan

**1. [Scope] The 870/319 inventory was stale; the real figures were 893/325**

- **Found during:** Task 1 baseline
- **Issue:** 23 more violations and 6 more files than RESEARCH recorded, from imports added by this
  phase's own earlier waves.
- **Fix:** Reported, not adjusted. Every wave in this phase has drifted; the verification condition
  that actually holds is the binary's zero, which is what was checked.
- **Commit:** n/a

**2. [Scope] Tasks 1 and 2 landed in one commit rather than two**

- **Found during:** Task 1
- **Issue:** The plan splits the sweep (Task 1) from the conditional-import review and test gate
  (Task 2). Task 2 required zero source edits — `--fix` disturbed nothing — so there was no second
  change to commit, and the atomic rule forbids splitting the flip from the fix regardless.
- **Fix:** One commit. Both tasks' acceptance criteria verified before it opened.
- **Commit:** `bd28644e`

**3. [Rule 3 — Blocking] Test scheme substitution (as in every prior wave)**

- **Issue:** The plan's Task 2 verify is `xcodebuild test -scheme EhPanda`, which is a build scheme,
  not the package test scheme.
- **Fix:** `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air'` from
  `AppPackage/`, plus `build-for-testing -scheme EhPanda` for the app-side Tests lint gate. Both run.
- **Commit:** n/a (invocation only)

**4. [Deviation from prompt guidance] No dead import was removed**

- **Issue:** The prompt notes that removing a genuinely unused import found during the sweep would be
  in the spirit of the phase (Wave 15 removed a dead `import Kanna`).
- **Fix:** None applied. `sorted_imports` reorders and does not report unused imports, and no unused
  import surfaced incidentally. Stated so the absence reads as checked rather than overlooked —
  finding dead imports across 325 files would require a different tool and is not this plan's scope.
- **Commit:** n/a

## Flagged for owner review

**1. The `excluded:` key is now gone entirely, not just emptied.** If a generated-sources directory
is ever reintroduced (a code-gen step, a resource-accessor folder), the exclusion will need to be
re-added rather than edited. Worth knowing that the slot no longer exists, because the failure mode
is loud rather than silent — generated files would simply start failing lint.

**2. This wave changed 325 of 452 linted files, which is a wide blast radius for a style rule.** The
diff-shape assertions bound it tightly and the full suite is green, but any in-flight branch or
unmerged work will conflict on import blocks across most of the repository. Rebasing such work is
mechanical — re-run `--fix` after resolving — but it is worth doing sooner rather than later.

**3. Two remaining rules are still commented out**, per plan: `single_line_trailing_closure` (flips at
11-27, after 11-26 does the Sources half) and `multiline_function_chains` (11-28). Neither is
auto-correctable, so neither gets this wave's leverage — the 223 and 85 sites are manual rewraps.

**4. `sorted_imports` is the first of the seven rules resolved with zero human judgement.** That is
the intended shape of a mechanical capstone sweep, but it also means it produced no findings about
the codebase — unlike `optional_try`, which surfaced hidden broken tests in 11-09 and 11-20. Its
value is entirely forward-looking: import order stops being a review topic.

## Known Stubs

None.

## Threat Flags

None. A style-only reorder plus a lint-config change; no logic, no control flow, and no new network,
auth, file-access or schema surface. **T-11-28's mitigation is satisfied directly**: the three
conditional-import files were manually reviewed (only one changed, and its `#if DEBUG` import stayed
inside the condition), the rule's block-independent behaviour was proven by probe rather than assumed,
`build-for-testing` compiled all 18 test targets, and the full 565-test suite passed.

## Self-Check: PASSED

- `.swiftlint.yml` — FOUND; `sorted_imports` in `opt_in_rules` at `severity: error`; no top-level
  `excluded:` block
- `AppPackage/Sources/CookieClient/CookieClient.swift` — FOUND; unconditional imports sorted,
  `#if DEBUG import Synchronization` intact
- `AppPackage/Sources/OSLogExt/Logger+.swift` — FOUND; `@_exported import OSLog` reordered
- `AppPackage/Sources/AppTools/ColorCodable.swift` — FOUND; unchanged by the sweep
- `AppPackage/Sources/AppTools/DeviceType.swift` — FOUND; unchanged by the sweep
- `.planning/phases/11-infra-refactor-lint-capstone/11-25-SUMMARY.md` — FOUND
- Commit `bd28644e` — FOUND; 326 files, no deletions
