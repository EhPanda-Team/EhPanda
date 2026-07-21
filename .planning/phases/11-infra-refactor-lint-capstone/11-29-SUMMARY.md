---
phase: 11-infra-refactor-lint-capstone
plan: 29
subsystem: lint-capstone
tags: [lint, swiftlint, verification, capstone, owner-review, requirements]
requires:
  - "11-28's final rule flip — all eight LINT-01 rules live at error"
  - "11-22.1's repaired FeatureTests.xctestplan — the 18-target gate this battery runs on"
provides:
  - "11-EXCEPTIONS.md — the owner's batch-review inventory (D-01/D-02 exception-review flow)"
  - "The full capstone verification battery, each command with its verbatim result"
  - "Concrete identification of the phase's three 'known issues' — and the finding that no withKnownIssue has ever existed in this repo"
  - "LINT-01 marked complete; ROADMAP/REQUIREMENTS amended honestly, including what fell short"
affects:
  - "No source file — this plan is verification and documentation only"
tech-stack:
  added: []
  patterns:
    - "Negative-control probe as the only thing separating a clean tree from a silently-discarded rule config"
    - "git blame every disable to separate phase artifacts from inherited ones"
key-files:
  created:
    - .planning/phases/11-infra-refactor-lint-capstone/11-EXCEPTIONS.md
  modified:
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
decisions:
  - "The `.task(id:)` regex narrowing is surfaced as an owner DECISION, not implemented. Three of the six lifecycle exceptions collapse if it is taken, but it changes what the rule means, and this plan is explicitly not authorized to retune a rule."
  - "The phase is eight rules, not seven. `single_line_trailing_closure` is a full LINT-01 deliverable (ROADMAP criterion 1 names it; 11-26/11-27 swept 215 sites) but is routinely dropped from the phase's own shorthand. All eight verified."
  - "Task 1 produced no file changes, so it carries no commit. One commit for Task 2 plus the metadata commit."
  - "The '2 pre-existing known issues' phrase repeated across eight summaries is unsupported: `withKnownIssue` has never existed in this repository's git history. The real count is 3, from TCA's skipInFlightEffects (x2) and one production reportIssue."
  - "ROADMAP criterion 3 already carried the D-02 amendment from the phase's planning; the amendment work here was extending all four criteria with delivered-vs-shortfall status rather than inserting the 'unapproved' wording."
metrics:
  duration: ~50m
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 29: Capstone Verification & Exception Inventory Summary

The full battery is green — **0 lint violations in 452 files with all eight rules live and
negative-control-proven, both builds clean, 565 tests passing in parallel across 18 targets, cookie
scan clean** — and the owner's batch-review artifact exists. `LINT-01` is marked complete after 29
plans deliberately left it open.

One commit: `de754a4f`. No source file was touched.

## The verification battery

Every command run, with its verbatim result. `xcodebuild` invocations were strictly sequential.

| # | Command | Result |
|---|---|---|
| 1 | `swiftlint lint --strict --no-cache --reporter json --config .swiftlint.yml AppPackage/Sources AppPackage/Tests App ShareExtension` | **`Found 0 violations, 0 serious in 452 files`**, exit 0 |
| 2 | negative-control probe against the **live** config | all **8** rules fired |
| 3 | `xcodebuild build -scheme EhPanda -destination '…iPhone Air'` | **`** BUILD SUCCEEDED ** [23.580 sec]`**, 0 errors, 0 warnings |
| 4 | `xcodebuild build-for-testing -scheme EhPanda -destination '…iPhone Air'` | **`** TEST BUILD SUCCEEDED ** [29.240 sec]`** |
| 5 | `cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air'` | **`** TEST SUCCEEDED ** [67.992 sec]`**, exit 0, **565 tests / 18 runs**, 0 failures |
| 6 | `bash Scripts/check-cookie-logging.sh` | **`Cookie logging audit passed.`**, exit 0 |
| 7 | test-plan coverage audit (18 dirs vs 18 `testTargets`) | set difference **empty both ways** |

The binary is the DerivedData artifactbundle `swiftlint`, version **0.65.0**; it is not on `PATH`.

**Nothing failed, so nothing was weakened.** No rule was retuned, no exclusion added, no run repeated
until green.

### Why the zero is not self-evidencing

A zero-violation lint is exactly what a **silently-discarded** rule config also produces. This phase
found two config constructs that are inert in a way that reads as success — an invalid
`excluded_match_kinds` value discards a whole custom rule behind one stderr line, and a misspelled
`opt_in_rules` entry enables nothing. So a probe file was linted against the live config and deleted:

| Rule | Probe construct | Fired |
|---|---|---|
| `lifecycle_modifiers` | `.onAppear { … }` | ✓ |
| `binding_initializer` | `Binding(get:set:)` | ✓ |
| `unchecked_subscript_index_access` | `a[i]` | ✓ |
| `labeled_tuple_elements` | `-> (Int, String)` | ✓ |
| `optional_try` | `try? f()` | ✓ |
| `single_line_trailing_closure` | `[1].map { $0 * 2 }` | ✓ |
| `sorted_imports` | `import SwiftUI` before `import Foundation` | ✓ |
| `multiline_function_chains` | two calls sharing the base line | ✓ |

stderr carried no `Invalid configuration … Falling back to default` line.

### The test count, summed rather than assumed

`TEST SUCCEEDED` alone is not evidence on this project: the XCTest summary lines print
`Executed 0 tests` (18 of them) because everything is Swift Testing. The `Test run with N tests`
lines were summed: **565 across 18 runs**, one per target. Zero `✘`, zero `failed after`.

## The 2 "pre-existing known issues" do not exist as described

Eight summaries (11-11, 11-13…11-21, 11-25…11-28) refer to "2 pre-existing `withKnownIssue`
markers", or "3", or "1" — the count drifts between waves.

**`grep -rn "withKnownIssue"` over `AppPackage/`, `App/`, `ShareExtension/` returns nothing, and
`git log -S"withKnownIssue" --all` returns no commit.** The token has never existed in this
repository's history. There are also zero `.disabled` traits and zero `XCTSkip` calls.

The phrase was imprecise reporting, repeated by inheritance. 11-22.1 is the only summary that got it
right.

**What actually happens — three of them, from this plan's own run:**

| # | Test | Recorded at | Cause |
|---|---|---|---|
| 1 | `SettingReducerTests.defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges()` | `SettingReducerTests.swift:38:40` | TCA's `store.skipInFlightEffects()` records an `Issue` when it discards in-flight effects |
| 2 | `SettingPresentationTests.pushingAccountLoadsCookies()` | `SettingPresentationTests.swift:71:40` | same — the long-living jar subscription is deliberately skipped, with an in-file comment saying so |
| 3 | `AppModelsTests.privateFilterValueReportsIssueAndReturnsZero()` | `Category.swift:45:24` | a **production** `reportIssue(…)` in `Category.filterValue` for the display-only `.private` case — exactly what the test's name asserts |

All three are by design; none is a suppressed failure. Swift Testing labels them "known issues"
because `Issue.record` was called and the run still passed — a different mechanism from
`withKnownIssue`, and the source of the confusion.

## The exception inventory

`.planning/phases/11-infra-refactor-lint-capstone/11-EXCEPTIONS.md`. Built by enumerating every
`swiftlint:disable` in `AppPackage/`, `App/` and `ShareExtension/` with grep, then `git blame`ing
each one to date it — not by carrying plan text forward.

**28 directives in the tree. 8 created by this phase; 20 pre-date it.**

| Rule | Phase exceptions | Origin |
|---|---:|---|
| `lifecycle_modifiers` | **6** | 3 from 11-09 (reader teardown, per-page fetch/prefetch, image `.task(id:)`), 3 from 11-11 (toast timer, alert focus hop, thumbnail decode) — all landed in `df693e44` |
| `unchecked_subscript_index_access` | **2** | `GalleryHistory+Operations.swift:43` and `PreviewIdentifiers.swift:1046`, both landed in `3bf28440` |
| the other six rules | **0** | four consecutive flips shipped with an empty directive payload |

Each entry records file:line, the full reason text, and its argument. The 20 pre-existing ones
(`cyclomatic_complexity` / `function_body_length` in ParserFeature, `line_length` in several models,
`identifier_name`, `nesting`, and `file_length` in PreviewSupport) are listed separately, with blame
attribution, so none is reviewed as a phase artifact.

### Two corrections to the pre-digested picture

**The prompt's "1 subscript exception in PreviewSupport" is incomplete — there are 2.** The second,
`AppModels/Persistent/GalleryHistory+Operations.swift:43`, is 11-17's only *new* exception and the
phase's first and only organic use of the D-08 form across 240 matches. `PreviewSupport`'s was
prepared by 11-12 and only needed its directive.

**`swiftlint_disable_requires_reason` has a real gap.** 14 of the 20 pre-existing disables carry no
`// reason:` line at all, and the repo lints clean. The rule declares `match_kinds: [comment]`, so
the whole match — including the preceding line — must be comment-kind; a disable whose preceding
line is code (`extension Parser {`, `case yes`, a blank line) is **never matched**. The reason
requirement is enforced only where a comment already precedes the directive. Pre-existing, not a
phase regression, but the phase's exception mechanism rests on it.

### Retained serialization: none at all

Zero `.serialized` traits survive. `grep -rn '\.serialized' AppPackage/Tests` returns exactly one
hit and it is **prose** — `DidLoginKeyTests.swift:20`, a comment explaining why a trait would be
pointless. All 41 inventoried traits were removed by injection (11-19: 1, 11-20: 3, 11-21: 38).

The D-14 keeper is precise about itself: **there is no trait**, and adding one would be theatre —
`.serialized` orders cases within a suite and that suite has exactly one case. The isolation
mechanism is the suite's shape.

### Retained `@MainActor`: 185 across 45 files

Every survivor sits on a **member**, never a suite type (verified: zero suite-type-level
annotations). Three requirements phase-wide: TCA `TestStore.init` / `.state` (dominant),
`PageHandler`, `GestureHandler`.

Annotation count rose 142 → 185 while isolation narrowed 174 → 157 isolated cases. That is the
honest arithmetic of "narrowest scope": one suite-level attribute covering N cases becomes attributes
on the M members that need it, and M can exceed 1.

## The decision surfaced, not taken

**Narrowing `lifecycle_modifiers` to exempt `.task(id:)` would halve the exception list.** Three of
the six — the reader's image loader, the toast's auto-dismiss timer, and the thumbnail decode — are
one argument in three places: `.task(id:)` used for its **cancellation**, not to start work. In each,
the consuming code branches on `Task.isCancelled`, and every non-banned alternative
(`.onChange(of:initial:)` + an unstructured `Task`) drops the cancellation and leaks work.

**Not implemented.** It is a rule-tuning decision, this plan is explicitly not authorized to retune a
rule, and it is not free: `.task(id:)` can also be used simply to start work, so exempting it opens a
hole D-06 deliberately closed. It changes what the rule means, not just how many exceptions it needs.
Presented as a question with its counter-argument, per 11-11's own framing.

## Accumulated findings, verified against the tree

Each was checked at HEAD rather than trusted from its summary. All confirmed still present, all
attributed.

**Production concerns:**

| Finding | Verified at | From |
|---|---|---|
| The `DidLoginKey` subscription race **still exists in the live `CookieClient`** — a real production race | `CookieClient.swift:37–39`, observer built inside an inner `Task` | 11-20 |
| `AnimatedImageFeature` has **no test target**, and 11-17 rewrote its byte parser | no `AppPackage/Tests/AnimatedImageFeatureTests` directory | 11-17 |
| The gallery-URL grammar has **four** independent implementations | `Parser+Types.swift:32`, `Request+Detail.swift:358`, `URLClient.swift:29`, `AppError+Context.swift` | 11-14/15/17 |
| `parseTags` duplicated and will drift | `Request+GalleriesMetadata.swift:61` vs `Parser+List.swift:282` | 11-15 |
| EhSetting's remote-parsed arrays have **no count invariant** — a short parse silently submits a partial form | `Request+Account.swift` `zip`/`prefix(10)` | 11-15 |
| `ImageColors.colors` **tie-breaks nondeterministically** (pre-existing; load-bearing in 11-16's parity reasoning) | `ImageColors.swift:88`, `:116` | 11-16 |
| `parseInfoPanel` rejects the **whole** detail parse rather than degrading one field | `Parser+Detail.swift:275–276` | 11-14 |
| `saveTorrent` still writes a fixed real Caches path, outside 11-19's seam | `FileClient.swift:181` | 11-19 |
| `GestureHandler` / `PageHandler` are `@MainActor` **production** types pinning 15 test cases; isolation looks inherited | both at line 6 | 11-22/22.1 |
| **No network seam** — 50 `urlSession: URLSession = .shared` init defaults, reducers never pass one | `AppPackage/Sources/NetworkingFeature` | 11-07…11-10, 11-15 |

**Process findings** are recorded in the inventory in full: the `doccomment`-not-`doc_comment`
silent-kill trap (which nearly shipped an inert rule in wave 17 and is why every flip carries a
probe); `excluded:` being a file-path regex, which three plans were written around; plan-count drift
in nearly every wave and the discipline of treating the binary as the enumerator; the
positional-array → named-struct refactor that erased ~40 matches in two changes; and the
`FeatureTests.xctestplan` gap that left the standing `Tests/` lint gate incomplete until wave 23.

One new process finding: **`11-27-SUMMARY.md` ends with stray `</content></invoke>` tool-call markup**
instead of clean Markdown — a write-truncation artifact. Content above it is intact.

## Must-haves recorded as not achieved

Not quietly dropped. Detail in the inventory §7, and now reflected in ROADMAP and REQUIREMENTS.

1. **11-02's headline must-have is inert.** "An unparseable gallery-list page throws instead of
   rendering as an empty list" cannot hold: 11-01's `Parser.degrading` helper (D-04 Group A) makes
   every row-level failure non-throwing, so `(try? f()) ?? []` → `try f()` changed nothing
   observable. The executor correctly declined to invent an "empty means malformed" heuristic, which
   would throw on legitimately-empty search results. **A direct consequence of D-04 Group A's design
   — needs an owner decision.**
2. **D-13's yield is 17 cases and no measurable wall-clock change.** 157 of 186 cases (84%) remain
   main-actor-isolated, a floor set by TCA's `TestStore`, not by hygiene. There is nothing left to
   sweep.
3. **D-09 is half-done.** `AppModels`' shared fixtures still mint `UUID()` at `Gallery.swift:15`,
   `:34`, `:57`, and four of the five files 11-12 fixed render `Gallery.preview` first. Giving
   `AppModels` a `PreviewSupport` dependency is an architectural call.
4. **There is no network seam.** Structural, flagged by four plans, taken on by none.

## The doc amendments

**ROADMAP** — Phase 11 checkbox ticked, plan count corrected to 30/30, and all four success criteria
extended with delivered-vs-shortfall status. Criterion 3 already carried the D-02 "unapproved"
wording from the phase's planning, so the work here was honesty rather than insertion: criterion 2
now records that the premise "resolved at root during Phases 5–7/9" was **not true at HEAD**, and
criterion 4 records that the parallelism yield fell short of its framing. A new **"Not achieved as
originally written"** block names the three shortfalls.

**REQUIREMENTS** — LINT-01 checkbox ticked, traceability row set to Complete, and the acceptance
wording amended to "no unapproved suppressions" with the D-01/D-02 review flow named. Two new bullets
split **Delivered** from **Fell short**, so a future reader can tell what landed from what was
descoped.

Marked complete via `gsd-tools query requirements.mark-complete LINT-01` (traceability row applied;
the checkbox was already edited in the same commit).

Scope was kept tight: no other criterion text or requirement was touched.

## Deviations from Plan

**1. [Scope] The plan's Task 1 lists eight rule ids; the phase's shorthand says seven**

- **Found during:** Task 1
- **Issue:** The prompt and most summaries frame the phase around seven rules, omitting
  `single_line_trailing_closure`. It is a full LINT-01 deliverable — ROADMAP criterion 1 names it and
  waves 11-26/11-27 swept 215 sites for it. The plan's own Task 1 action text lists all eight.
- **Fix:** Verified all eight, and recorded the discrepancy in the inventory so the "seven" framing
  is not read as a complete list.

**2. [Scope] Task 1 produced no commit**

- **Issue:** The battery is verification only and every check passed, so no file changed. The
  per-task commit protocol had nothing to stage.
- **Fix:** One commit for Task 2, plus the metadata commit. Recorded so the missing Task 1 commit is
  not read as a skipped task.

**3. [Rule 1 — Inventory] The prompt's exception counts were incomplete in one place**

- **Found during:** Task 2 enumeration
- **Issue:** The prompt states "1 subscript exception in `PreviewSupport`". There are **2** — the
  second is `GalleryHistory+Operations.swift:43`, which is 11-17's only new exception.
- **Fix:** Both inventoried. Consistent with every prior wave: the tree is the enumerator.

**4. [Rule 1 — Evidence] The "2 pre-existing known issues" phrase was refuted, not repeated**

- **Found during:** Task 1
- **Issue:** The plan's context and eight prior summaries assert `withKnownIssue` markers exist.
  They do not, and never have.
- **Fix:** Refuted with `grep` + `git log -S`, and the three real `Issue.record`-sourced known issues
  identified concretely with file:line and cause.

**5. [Scope] ROADMAP criterion 3 already carried the D-02 wording**

- **Issue:** The plan's Task 2 directs rewriting criterion 3 to add the "unapproved" amendment. It
  was already there, added during the phase's planning.
- **Fix:** Left its substance intact and rewrote it to state the delivered result (8 exceptions, six
  rules at zero) plus a pointer to the inventory. The other three criteria gained the same
  delivered-vs-shortfall treatment, which the plan's honesty requirement asks for.

## Flagged for owner review

**1. The `.task(id:)` narrowing (§ above).** The single highest-value decision in the inventory.

**2. Both subscript-exception preconditions are unfirable.** Site 1's index comes from `firstIndex`;
site 2's is checked on the line above. That is the correct reading of a rule asking for *guarded*
access — but if you want the exception form to mean "a check that can actually fail", these two have
no principled annotation available, since neither subscript can be removed.

**3. Make "prove the rule fires" permanent.** Two config constructs in this phase were inert in a way
that reads as success, and both would have passed a zero-violation check. A `Scripts/` probe fixture
with known-violating lines and an expected-count assertion, run alongside `check-cookie-logging.sh`,
would close it. Infrastructure, not this plan's mandate.

**4. Nothing re-audits `FeatureTests.xctestplan`.** It is clean today (checked here, 18/18 both ways),
but the drift wave 22.1 repaired went unnoticed across at least three target additions because
nothing compares the directories against the plan. A one-line check would close it permanently.

**5. `unchecked_subscript_index_access`'s message under-hints its best fix.** It reads "Subscript
index access should be guarded by an index check", but five waves found the right answer is usually a
**rename** (`index` → `page` / `catIndex` / `favoritesIndex`, for Dictionary subscripts that cannot
trap) or a **structural fix**. The next contributor pays that discovery cost without context.

**6. Device UAT is outstanding across the phase and was not run here.** Waves 11-07 through 11-13
flagged UAT items — reader seeding and paging, the slider preview tray, the toast, detail-style list
pagination, the page-jump alert keyboard, the Filters sheet, Setting screens, the Previews grid, the
comment deep-link scroll, and animated GIF/WebP detection (§6.3, which has no test target at all).
None is covered by any automated gate.

## Known Stubs

None.

## Threat Flags

None. This plan touched no source file and introduced no network, auth, file-access or schema
surface. T-11-32's mitigation is satisfied: the inventory was built by grep + `git blame` over the
tree rather than from plan text, so it is exhaustive by construction, and the discrepancies it found
against the pre-digested picture (2 subscript exceptions not 1; no `withKnownIssue` anywhere) are the
evidence that it was not carried forward. T-11-SC: no packages installed.

## Self-Check: PASSED

- `.planning/phases/11-infra-refactor-lint-capstone/11-EXCEPTIONS.md` — FOUND, contains `optional_try`
- `.planning/ROADMAP.md` — FOUND, contains `unapproved`; Phase 11 ticked, 30/30
- `.planning/REQUIREMENTS.md` — FOUND, LINT-01 `[x]`, traceability row `Complete`, contains `no unapproved suppressions`
- Commit `de754a4f` — FOUND
- No absolute home path in any document written or edited — verified by grep
