---
phase: 11-infra-refactor-lint-capstone
plan: 27
subsystem: lint-config
tags: [single-line-trailing-closure, lint, swiftlint, mechanical-sweep, tests-half, rule-flip]
requires:
  - "11-26's Sources half — 145 sites rewrapped, config deliberately left untouched"
  - "The commented `single_line_trailing_closure` draft in .swiftlint.yml"
provides:
  - "`single_line_trailing_closure` live at error, 0 violations across all four path roots"
  - "70 rewrapped closure sites across 26 test files, completing the 215-site phase sweep"
  - "The seventh live lint rule; `doccomment` added to its excluded kinds"
affects:
  - "11-28's `multiline_function_chains` sees no new multi-line chains from this half"
  - "11-29 flips LINT-01; this plan deliberately leaves it open"
tech-stack:
  added: []
  patterns:
    - "Negative-control probe: a throwaway file exercising the fires/does-not-fire cases proves the rule is live, not silently discarded by an invalid `excluded_match_kinds` entry"
    - "Scratch-config enumeration via `--config` with `only_rules: [custom_rules]` (inherited from 11-26), so the tracked config is never edited"
key-files:
  created: []
  modified:
    - .swiftlint.yml
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/CookieClientTests/CookieClientTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift
    - "23 further test files across AppPackage/Tests"
decisions:
  - "The Tests half was exactly 70 sites, matching 11-26's projection — the first wave in this phase whose inherited count did not drift."
  - "`doccomment` added to `excluded_match_kinds`, which the draft omitted. This rule contrasts two syntactic forms, so a doc comment showing the rejected form as a counter-example is precisely the prose it must not punish. Zero doc comments match today, so the addition is future-proofing, not masking a live violation."
  - "69 of 70 sites parenthesized, 1 hand-rewrapped for `line_length`. No site went multi-line: every match is an innermost closure and the Tests half is dominated by one-expression `withLock { $0 = x }` and `first { $0.name == n }` forms."
  - "No 11-26-style nested-closure trap exists in Tests. Four of the six nested sites sit inside accessor braces (a computed getter, a `get`/`set` pair), not closures; the other two sit inside a dependency-override closure that the rule does not police. Parenthesizing the inner closure is the only available fix at all six, not a silencing shortcut."
  - "Rewraps and the flip landed in ONE commit (Pitfall 10), though with zero exception directives the atomicity constraint was vacuous this time."
metrics:
  duration: ~20 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 27: single_line_trailing_closure — Tests Half + Flip Summary

`single_line_trailing_closure` is **live at error** and the standalone binary reports **0 violations
across all four path roots**. The 70 Tests-half sites are rewrapped, completing the phase's 215-site
sweep. One commit: `2da57704`, 27 files, +94/−78.

This is the **seventh** live rule this phase, joining `lifecycle_modifiers`, `binding_initializer`,
`unchecked_subscript_index_access`, `labeled_tuple_elements`, `optional_try` and `sorted_imports`.

## The count: 70, exactly as 11-26 projected

| | 11-26's projection | Actual at HEAD |
|---|---:|---:|
| Tests violations | 70 | **70** |
| Tests files | — | **26** |
| Phase total (Sources 145 + Tests 70) | 215 | **215** |

The plan's frontmatter says ~74 and its objective says 223; both are the stale pre-11-26 figures.
The measured inheritance was exact — the first wave this phase where the handed-off count did not
drift. Reported rather than adjusted, consistent with every prior wave.

Distribution: `DownloadsFeatureTests` 33, `SettingFeatureTests` 11, `NetworkingFeatureTests` 8,
`AppFeatureTests` 6, `CookieClientTests` 4, `ImageClientTests` 3, `ReadingFeatureTests` 2,
`ParserFeatureTests` 2, `HomeFeatureTests` 1.

## Nested closures: checked explicitly, no trap present

11-26 found four sites where parenthesizing only the *inner* closure silences the rule — the outer
stops matching once its body contains braces — while leaving a denser line. A clean lint result does
not distinguish that wrong answer from the right one, so the Tests half was checked for it directly
rather than inferred from the zero.

Six of the 70 matches sit inside an unclosed brace on their own line. **None is the 11-26 trap:**

| Site | Enclosing brace | Why parenthesizing is the only fix |
|---|---|---|
| `DownloadBackgroundAssertionTests.swift:200` | computed getter `var beginCount: Int { … }` | accessor, not a closure — nothing to expand |
| `DownloadBackgroundAssertionTests.swift:201` | computed getter `var endCount: Int { … }` | same |
| `DownloadFeatureTestSupportTypes.swift:15` | `get { … }` accessor | same |
| `DownloadFeatureTestSupportTypes.swift:16` | `set { … }` accessor | same |
| `FolderManagerReducerTests.swift:33` | `folders: { … }` dependency override | the outer closure is not a policed method, so it never matched |
| `FolderManagerReducerTests.swift:133` | same | same |

In the four accessor cases the enclosing `{ }` is a property accessor, so there is no outer closure
to open — and expanding the accessor across lines would leave the inner closure still matching. In
the two `folders:` cases the enclosing closure is a dependency-override argument, which the rule's
method list does not cover, so it was never a candidate match being silenced.

The structural reason the trap is bounded at all: the rule's body class is `[^{}\n]*`, so **every
match is by construction an innermost closure**. Parenthesizing one cannot create a new match either,
because the enclosing braces remain. No `$0` shadowing was introduced anywhere — unlike 11-26, no
closure parameter needed renaming, since no matched closure was expanded across lines.

## 69 parenthesized, 1 hand-rewrapped, 0 multi-line

| Form | Sites |
|---|---:|
| Parenthesized | **69** |
| Hand rewrap (`line_length`) | **1** |
| Multi-line | **0** |

The Sources half split 130/7; the Tests half is 69/1/0. Test code is more uniform — the bulk is
one-expression `withLock { $0.field }` state reads in test doubles and `first { $0.name == n }`
lookups, both of which read better parenthesized than tripled in line count. Nothing in Tests carried
a real multi-statement body on one line.

### The methods that needed a label

Nine distinct methods appeared: `withLock`, `map`, `first`, `flatMap`, `filter`, `forEach`,
`withValue`, `contains`, `allSatisfy`. Two take a label once the closure leaves trailing position:

| Method | Trailing | Parenthesized | Sites |
|---|---|---|---:|
| `first` | `.first { $0.name == n }` | `.first(where: { … })` | 9 |
| `contains` | `.contains { … }` | `.contains(where: { … })` | 1 |

`allSatisfy` is deliberately **not** in that set — its signature is `allSatisfy(_ predicate:)`,
unlabeled, so labelling it would not compile. No `sorted`/`sort`/`last`/`firstIndex` occurred in
Tests, so the `by:` mapping went unused. No site had a pre-existing argument list before its closure
(verified programmatically: 0 of 70), so no closure had to be folded into an existing parameter list.

### The one hand rewrap

`CookieClientTests.swift:106` was 113 characters and would have reached **123** after `(where: …)` —
past the `line_length` error threshold of 120. Rather than shrink the expression, the receiver was
lifted to a local, which also reads better:

```swift
let ehentaiCookies = client.cookies(for: ehentaiSkipServerURL)
#expect(ehentaiCookies.contains(where: { $0.name == CookieName.skipServer }) == false)
```

It was the only site projected over the limit; the check was run across all 70 before editing, not
discovered by build failure.

## Negative-control probe

Mandatory before the flip, because two of the flip hazards fail *silently*. A throwaway `Probe.swift`
at the repo root was linted against the **live** config, then deleted:

| Case | Source | Expected | Result |
|---|---|---|---|
| Trailing closure, unlabeled method | `xs.map { $0.count }` | fires | **fired** ✓ |
| Trailing closure, labeled method | `xs.first { $0.isEmpty }` | fires | **fired** ✓ |
| Parenthesized | `xs.map({ $0.count })` | silent | **silent** ✓ |
| Parenthesized + label | `xs.first(where: { $0.isEmpty })` | silent | **silent** ✓ |
| Multi-line | `xs.map {\n $0.count \n}` | silent | **silent** ✓ |
| Doc comment naming the form | `/// … xs.map { $0.count } …` | silent | **silent** ✓ |
| Ordinary comment | `// … xs.map { $0.count }` | silent | **silent** ✓ |
| String literal | `"… xs.map { $0.count }"` | silent | **silent** ✓ |

The first two rows are the load-bearing ones. **An invalid `excluded_match_kinds` value discards the
entire rule config**, and a custom rule has no default, so it vanishes behind a single stderr
`warning:` that `--quiet --reporter json` swallows — reporting zero forever, indistinguishable from a
clean tree. Because the probe *fires* on rows 1–2 under the live config, the rule is provably
registered and every one of its three excluded kinds is valid. A zero-violation run alone could not
have shown this.

## `doccomment` added to the draft

The drafted block carried `excluded_match_kinds: [comment, string]`. `doccomment` was added, making
this the fourth rule in the file to carry it, alongside `optional_try`,
`unchecked_subscript_index_access` and `labeled_tuple_elements`.

**No doc comment matches today** — the four-root enumeration with only `comment`/`string` excluded
returned 70, all of them real code lines in Tests, and 0 in the three source roots. So this is
future-proofing, and it is explicitly *not* masking a live violation.

The justification is specific to this rule rather than a blanket habit: `single_line_trailing_closure`
exists to contrast two syntactic forms, and its own `message:` string quotes one of them. A doc
comment that shows the rejected form as a counter-example — the natural way to document a style rule —
would fire. Waves 15 and 17 established that rewording prose to dodge a lint rule is a real clarity
loss, not a fix, so the exclusion is the correct pre-emptive shape. A comment in the config records
the reasoning and the `doccomment`/`doc_comment` spelling hazard, per the wave-17 model.

## Verification

- **Scratch-config enumeration, all four roots** — 70 in `AppPackage/Tests` at baseline (0 in
  `AppPackage/Sources`, `App`, `ShareExtension`, inherited from 11-26); **0/0/0/0** after the rewrap.
- **Negative-control probe** — table above, 8/8, run against the live post-flip config, probe deleted.
- **Live-config `--strict --no-cache`, all four roots, all rules** — **0 violations**. `line_length`,
  `optional_try`, `sorted_imports` and the other four live rules all clean; no stderr config warning.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (26.6 s), 0 errors,
  0 warnings, run **after** the flip. This is the load-bearing gate for this plan: the app-scheme
  build does not lint `Tests/`, and this plan's entire payload is in `Tests/` (Pitfall 6 / the
  `e8589355` incident class). Wave 23's `FeatureTests.xctestplan` repair means it covers all 18 test
  targets.
- The same command was also run **before** the flip, as the compile gate for the 10 added `where:`
  labels — a missed label is a compile error, not a lint finding.
- **Full `AppPackage-Package` suite** — **TEST SUCCEEDED** (69.3 s), **565 tests, 0 failed**.
- **Diff-shape replay** — 70 removed lines; 69 reproduced exactly by re-running the parenthesization
  transform and matching against the added lines. Residue: exactly 1 line, the named
  `CookieClientTests.swift:106` rewrap. No fourth category.
- `git diff --diff-filter=D HEAD~1 HEAD` — empty; no file deleted. No untracked files.
- `LINT-01` left open — it flips at 11-29.

### On the test count

`TEST SUCCEEDED` alone is not evidence on this project: the XCTest summary prints `Executed 0 tests`
because everything is on Swift Testing, so a suite that silently ran nothing prints the same banner
(11-25's catch). The `Test run with N tests` lines were summed: **565**, matching every prior wave in
this phase. Two known issues appear (`Category.swift:45`, `SettingReducerTests.swift:38`,
`SettingPresentationTests.swift:71`) — pre-existing `withKnownIssue` markers, unchanged by this wave.

## `multiline_function_chains` (11-28) was not worsened

Parenthesization is a within-line edit, so the 69 parenthesized sites create no multi-line chains and
change no chain's break points. The single hand rewrap splits a receiver into a `let` binding, which
shortens rather than breaks a chain. 11-26's one deliberately-untouched pre-existing site,
`AppModels/Gallery/GalleryComment.swift:40–41`, is still 11-28's to resolve.

## Deviations from Plan

**1. [Rule 3 — Blocking] Enumeration used a scratch config, not a temporary edit of the tracked file**

- **Found during:** Task 1
- **Issue:** The plan directs the enumerator to "temporarily uncomment the draft" in the tracked
  `.swiftlint.yml` and revert it. That leaves a window in which the repository holds an error-level
  rule against 70 live violations; an interrupted run commits a broken build.
- **Fix:** 11-26's scratch config with the draft regex copied verbatim, passed via `--config` with
  `only_rules: [custom_rules]`. The tracked config was written exactly once, in the flip itself.
- **Commit:** n/a (tooling only)

**2. [Rule 2 — Missing critical config] `doccomment` added to `excluded_match_kinds`**

- **Found during:** Task 2
- **Issue:** The draft omitted `doccomment`, which the three sibling code-shape rules all carry. This
  rule polices the contrast between two syntactic forms, so a doc comment quoting the rejected form
  would break the build and force a reword.
- **Fix:** `doccomment` added with an explanatory comment. Verified to change nothing today (0
  doc-comment matches across all four roots) and verified valid by the probe firing.
- **Commit:** `2da57704`

**3. [Scope] The plan's ~74 / 223 figures were the stale pre-11-26 numbers**

- **Found during:** Task 1 enumeration
- **Issue:** Plan frontmatter says ~74 Tests sites and a 223-site phase total; both predate 11-26's
  measurement.
- **Fix:** Reported, not adjusted. Actual: 70 Tests sites, 215 phase total. The condition actually
  verified is the binary's zero over all four roots.
- **Commit:** n/a

**4. [Rule 3 — Blocking] Test scheme substitution (as in every prior wave)**

- **Issue:** The plan's Task 2 verify block names `xcodebuild test -scheme EhPanda`; the full suite on
  this project runs under `AppPackage-Package`.
- **Fix:** `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air'` from `AppPackage/`
  for the 565-test suite, plus `build-for-testing -scheme EhPanda` for the Tests lint gate. Both run,
  both green, sequentially — never concurrently.
- **Commit:** n/a (invocation only)

**5. [Deviation from plan structure] Tasks 1 and 2 landed in one commit**

- **Issue:** The plan splits the rewrap (Task 1) and the flip (Task 2) into two tasks, which the
  per-task commit protocol would commit separately.
- **Fix:** One atomic commit, per Pitfall 10. With zero exception directives the constraint was
  vacuous here, but the single commit also guarantees no intermediate state where the tree holds
  either an unenforced rewrap or a rule ahead of its fixes.
- **Commit:** `2da57704`

## Exception sites

**None.** All 70 Tests violations were rewrapped at parity. No `swiftlint:disable` directive was
written anywhere in this phase's `single_line_trailing_closure` sweep — 215 sites over two waves, zero
exceptions. The flip commit's directive payload was empty, as 11-26 predicted.

## Known Stubs

None.

## Threat Flags

None. Syntactic rewrapping plus a lint-config flip — no logic, no control flow, and no new network,
auth, file-access or schema surface. **T-11-30's mitigation is satisfied**: the binary reports zero
over all four roots against the live config, and `build-for-testing` proves the `Tests/` lint gate
inside the same commit that enables the rule, so no residual Tests violation can reach the build
pipeline.

## Self-Check: PASSED

- `.swiftlint.yml` — FOUND; `single_line_trailing_closure` uncommented at `severity: error` with
  `comment`, `doccomment`, `string` excluded and an explanatory comment block
- `AppPackage/Tests/CookieClientTests/CookieClientTests.swift` — FOUND; line 106 rewrap to a `let`
  binding plus `contains(where:)`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` — FOUND; 12
  `withLock` sites parenthesized including the `get`/`set` accessor pair
- `AppPackage/Tests/DownloadsFeatureTests/FolderManagerReducerTests.swift` — FOUND; both
  `folders: { … .map({ [$0] }) ?? [] }` dependency overrides
- `AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift` — FOUND; 6 sites
- `.planning/phases/11-infra-refactor-lint-capstone/11-27-SUMMARY.md` — FOUND
- Commit `2da57704` — FOUND; 27 files, +94/−78, no deletions, no untracked files
</content>
</invoke>
