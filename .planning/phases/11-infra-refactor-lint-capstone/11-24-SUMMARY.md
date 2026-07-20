---
phase: 11-infra-refactor-lint-capstone
plan: 24
subsystem: lint-config
tags: [optional-try, d-15, d-01, rule-flip, lint, swiftlint, test-hygiene]
requires:
  - "11-23's DownloadsFeatureTests clearance (155 sites) — the bulk target"
  - "11-17's `doccomment` finding — the invalid-kind silent-kill trap"
  - "11-22.1's repaired FeatureTests.xctestplan — makes build-for-testing a trustworthy Tests/ gate"
provides:
  - "`optional_try` live at severity error, repo-wide, with NO Tests path exclusion (D-15)"
  - "Zero `try?` sites across AppPackage/Sources, AppPackage/Tests, App and ShareExtension"
  - "The finding that the drafted `excluded_match_kinds` pair was incomplete — it flagged a doc comment"
  - "Zero exception directives repo-wide: the D-01 ban landed with no escape hatch used anywhere"
affects:
  - "Every future build: `try?` now fails the build in Sources AND test targets"
  - "11 sites across 4 files; no production source touched"
tech-stack:
  added: []
  patterns:
    - "Probe a drafted rule against the real tree before flipping — the draft's own config was wrong"
key-files:
  created: []
  modified:
    - .swiftlint.yml
    - AppPackage/Tests/ImageClientTests/ImageClientTests.swift
    - AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift
    - AppPackage/Tests/CookieClientTests/CookieClientTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift
decisions:
  - "The plan's 316-site inventory and its four-target file list were both stale. The true remaining count at HEAD was 11 sites in 3 files; FileClientTests was already at zero. Reported, not adjusted."
  - "`doccomment` was added to `excluded_match_kinds`, which the draft did not carry. This is not a precaution: the drafted pair (`comment`, `string`) flagged a real `///` line in ParserFeature/Parser+Shared.swift:14. Verified empirically before and after."
  - "The ParserFeature doc comment was NOT reworded to dodge the rule. Wave 15 degraded a comment for exactly this reason and wave 17 recorded it as a clarity loss; fixing the config is the correct fix, and the sibling rules already carry `doccomment`."
  - "ImageClientTests' 9 identical `defer` cleanups route through one target-local `removeTemporaryItem(at:)`, mirroring 11-23's idiom. The two single-site files got inline `do`/`catch` — a helper for one call site would be worse than the block it replaces."
  - "No cross-target shared helper was created. `TestingSupport` exists and could host `removeTemporaryItem`, but only 4 targets depend on it and widening that graph for 10 sites is out of proportion. Flagged as an opportunity instead."
  - "Zero exception sites, so zero `swiftlint:disable` directives. The atomic-flip commit's directive payload was empty — the first flip in this phase where that is true."
metrics:
  duration: ~15 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 24: optional_try Rule Flip Summary

`optional_try` is **live at `severity: error`, repo-wide, with no path exclusions**. The standalone
binary reports **0 violations in 452 files** at `--strict` across `AppPackage/Sources`,
`AppPackage/Tests`, `App` and `ShareExtension`. D-01's exception-gated ban is now compiler-enforced,
and D-02's exception form went unused — there are **zero** exception sites in the entire repository.

One commit: `b72fab8e`, carrying the 11 remaining conversions, the config correction and the flip.

## Scope: 11 sites in 3 files, not the plan's 316 in 4

The plan's `must_haves` asserts "all 316 inventoried sites (127 Sources + 189 Tests)". That inventory
is a phase-opening figure; by the time 11-23 closed, waves 11-01…11-06 had taken `AppPackage/Sources`
to zero and 11-23 had taken `DownloadsFeatureTests` to zero. The true remaining tree:

| Plan's target | Actual sites |
|---|---|
| `ImageClientTests/ImageClientTests.swift` | **9** |
| `CookieClientTests/CookieClientTests.swift` | **1** |
| `NetworkingFeatureTests/AccountRequestBaselineTests.swift` | **1** |
| `FileClientTests/FileClientTests.swift` | **0** — already clean |
| repo-wide stragglers (Sources, App, ShareExtension) | **0** |

Consistent with every wave in this phase, the plan's count drifted. `FileClientTests` was cleared
incidentally by 11-19's `FileClient.live`-to-function conversion, which restructured the file's
temporary-root handling.

## The conversion split

| Site | Class | Conversion |
|---|---|---|
| 9 × `defer { try? FileManager.default.removeItem(at: rootURL) }` | `defer` teardown | `removeTemporaryItem(at:)` |
| 1 × `try? await Task.sleep(for: .milliseconds(10))` | cancellation absorption | `do`/`catch` → `return false` |
| 1 × `try? JSONSerialization.jsonObject(with: body)` | genuine probe | `do`/`catch` → `return [:]` |

**Plain `try`: 0 of 11 (0%).** 11-23's warning was correct and this wave is the sharper case — it
went from 1.3% to nothing at all. The design intent's ideal rung (propagate into a `throws` test
function) applies to none of these sites, and not because the conversion was lazy:

- 9 of 11 are `defer` bodies. A `defer` cannot throw. This is 82% of the wave, and it is the same
  UUID-scoped-temporary-root teardown that accounted for 83% of 11-23's sites.
- 1 is a `Task.sleep` inside a task-group task that the sibling task cancels on success. Cancellation
  is the designed exit; propagating would unwind past the loop the test is driving.
- 1 is a probe inside a **non-throwing** free function (`jsonFields(from:)`) whose whole contract is
  "return `[:]` if this request has no JSON body". Propagation would require changing the function's
  signature and every caller, to express a failure that is not one.

Every remaining silence is explicit and carries a written reason, which is what D-01 asks for. The
rule is satisfied with no `try?` and no directive.

### The three conversions

**`removeTemporaryItem(at:)`** (new, `ImageClientTestHelpers.swift`) — the same idiom 11-23 built for
`DownloadsFeatureTests`, rebuilt target-locally. The doc comment carries the rationale: the root is
UUID-scoped so a leftover cannot leak into another case, and no case asserts on the removal.

**`CookieClientTests`** — the poll loop's sleep. On cancellation the closure now `return false`s
rather than continuing to mutate cookies for a group that has already been cancelled, which is
slightly more correct than the `try?` was: the old form kept looping through up to 200 attempts
against a cancelled group, with each `Task.sleep` returning instantly.

**`AccountRequestBaselineTests.jsonFields(from:)`** — the probe. Restructured from a compound `guard`
into an explicit `do`/`catch` plus a separate cast guard. The accept/reject set is unchanged: absent
body, non-JSON body and non-dictionary JSON all still yield `[:]`.

# The config defect: the drafted rule was incomplete

The plan's action text instructs "uncomment `optional_try` … **exactly as drafted**". Doing so fails
the build. The draft's `excluded_match_kinds` carries only `comment` and `string`, and the repo holds
a doc comment that discusses the banned construct by name:

```
AppPackage/Sources/ParserFeature/Parser+Shared.swift:14
    /// field falls back to its default rather than failing the whole page parse. `try?` expressed
```

Probed against a scratch config carrying the drafted rule verbatim, over all four path roots:

```
error: try? Violation: try? should be avoided. (optional_try)   ← Parser+Shared.swift:14:84
```

Exactly one violation, on prose. Adding `doccomment` takes it to zero. This is 11-17's finding
arriving from the opposite direction — that wave found the *fix* was misspelled; this one found the
fix was *missing* — and it is the third construct in this phase that would have produced a broken or
inert flip if shipped as written.

**The doc comment was not reworded.** Wave 15 degraded a comment to dodge a rule and wave 17 recorded
that as a real clarity loss. The sibling custom rules already exclude doc comments; the draft simply
omitted it. Fixing the config is the correct fix, and the alternative — editing prose so a linter
stops reading it — is the anti-pattern this phase has already flagged once.

The config comment above the entry states both what the rule polices and the silent-fallback trap:

```yaml
  # Bans `try?`, which discards the error and the fact that one happened. Propagate with `try`, or
  # absorb it in an explicit `do`/`catch` whose body says why silence is correct there.
  optional_try:
    …
    excluded_match_kinds:
      - comment
      # `doccomment`, NOT `doc_comment`. An unrecognised kind makes SwiftLint discard the WHOLE
      # rule config and fall back to defaults; a custom rule has no default, so it silently
      # vanishes behind one stderr warning and reports zero violations forever.
      - doccomment
      - string
    severity: error
```

## The invalid-kind trap, re-demonstrated

Since this wave had to touch `excluded_match_kinds`, the trap was re-proven rather than taken on
trust from 11-17. A scratch config with `doc_comment`, run against a two-line file containing a
genuine `try? f()`:

```
warning: Invalid configuration for 'optional_try' rule. Falling back to default.
Done linting! Found 0 violations, 0 serious in 1 file.
```

Zero violations on a file that is nothing but a violation. Byte-identical to a clean run, and the
warning goes to stderr where `--quiet --reporter json` discards it. `doccomment` was used.

**All three kinds in the shipped config are valid**: `comment`, `doccomment`, `string`. Verified by
the rule firing correctly afterwards, not assumed.

# Negative control

Mandatory, and run against the **live** `.swiftlint.yml` after the edit — a zero-violation repo lint
is exactly what a silently-discarded rule also produces, so it proves nothing on its own.

| Line | Content | Expected | Actual |
|---|---|---|---|
| 1 | `/// A doc comment mentioning try? f()` | not flagged | **not flagged** |
| 2 | `// A line comment mentioning try? f()` | not flagged | **not flagged** |
| 4 | `func plain() throws -> Int { try f() }` | not flagged | **not flagged** |
| 5 | `func literal() -> String { "try? f()" }` | not flagged | **not flagged** |
| 6 | `func optionalTry() -> Int? { try? f() }` | **flagged** | **flagged**, exit 2 |

One violation, on the one real `try?`. The rule is registered, it fires on genuine code, it does not
fire on plain `try`, and all three exclusion kinds work. Probe file deleted before staging;
`git status --short` immediately before the commit showed exactly the five intended files.

# The atomic flip

One commit, `b72fab8e`:

1. the 11 conversions plus the new `removeTemporaryItem(at:)` helper
2. `doccomment` added to `excluded_match_kinds`, with the trap documented
3. `optional_try` uncommented at `severity: error`, with **no** `excluded:` path patterns (D-15)

**No `swiftlint:disable` directives** — the first flip in this phase whose directive payload is
empty. 11-11, 11-17 and 11-18 each had to carry directives into their flip commit because a directive
cannot exist while its rule is commented out. Here there is nothing to carry: 11-23 recorded zero
exception sites, waves 11-01…11-06 recorded none, and this wave created none. The atomicity
constraint still bound the conversions to the config change (a violating tree plus an active
error-level rule is a broken build in either order), so the split was never available regardless.

# Verification

- **Drafted rule via standalone binary**, scratch config, `--no-cache`, over all four path roots —
  **1 violation** (the ParserFeature doc comment). The defect that the "exactly as drafted"
  instruction would have shipped.
- **Corrected rule, same probe** — **0**.
- **Live project config `--strict`**, `--no-cache`, over `AppPackage/Sources AppPackage/Tests App
  ShareExtension` — **0 violations, 0 serious in 452 files**, with `optional_try` active. All five
  live custom rules pass together.
- **Negative control** against the live config — table above. Probe deleted.
- **Invalid-kind demonstration** — `doc_comment` reports 0 on a known violation. Scratch only.
- `grep -rn "try? " AppPackage/Sources AppPackage/Tests App ShareExtension | grep -v "//"` — **0**.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED** (27.0 s), 0 errors,
  0 warnings. This is the `Tests/` lint gate (Pitfall 6 / the `e8589355` incident class), and it is
  the repaired 18-target plan from 11-22.1 — the first flip that can rely on it covering every test
  target.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED** (20.6 s), 0 errors, 0 warnings.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED**, 0 failures. Run both immediately before the
  commit (63.7 s) and again after it (60.8 s).
- No production source touched. No assertion weakened, added or removed. No `.serialized` trait or
  `@MainActor` restored — 11-19/11-20/11-22.1's work is intact.
- `LINT-01` left open — it flips at 11-29.

## No hidden broken tests surfaced

The phase has repeatedly used this conversion to expose tests that a `try?` was masking (11-09 found
four, 11-20 found two). **This wave found none**, and the result is checked rather than assumed: all
11 sites' failure visibility is unchanged by construction — 9 are `defer` teardown that still cannot
fail the test, and the other 2 return the same fallback value on the same inputs. The suite passed on
the first run after the conversions with no assertion touched.

Stated explicitly so the absence reads as a checked result. Given the distribution, a hidden broken
test was never plausible here: no site's outcome feeds an assertion.

## Deviations from Plan

**1. [Rule 1 — Bug] `doccomment` added; the rule as drafted does not lint clean**

- **Found during:** Task 2, pre-flip probe
- **Issue:** The plan instructs uncommenting the draft "exactly as drafted". The drafted
  `excluded_match_kinds` omits `doccomment`, and `ParserFeature/Parser+Shared.swift:14` is a `///`
  line that names `try?`. Flipping as instructed puts an error-level violation on a doc comment and
  breaks the build.
- **Fix:** `doccomment` added, with a comment naming the invalid-kind silent-fallback trap. Both the
  defect and the fix were probed empirically before the flip.
- **Commit:** `b72fab8e`

**2. [Scope] The 316-site inventory and the four-file target list were both stale**

- **Found during:** Task 1 enumeration
- **Issue:** 11 sites in 3 files remained, not 316 in 4. `FileClientTests` was already clean.
- **Fix:** Reported rather than adjusted, matching every prior wave in this phase.
- **Commit:** n/a

**3. [Scope] Tasks 1 and 2 landed in one commit rather than two**

- **Found during:** Task 1
- **Issue:** The plan splits conversions (Task 1) from the flip (Task 2). With only 11 sites, an
  intermediate commit would be a two-line-per-file change of no independent value, and the atomic
  rule requires the flip to carry any residual anyway.
- **Fix:** One commit. Both tasks' acceptance criteria verified before it opened.
- **Commit:** `b72fab8e`

**4. [Rule 3 — Blocking] Test scheme substitution (same as every prior wave in this phase)**

- **Issue:** The plan's `-scheme CookieClient` does not exist.
- **Fix:** Full `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air'` from
  `AppPackage/`. `CookieClientTests`, `ImageClientTests` and `NetworkingFeatureTests` are all inside
  it.
- **Commit:** n/a (invocation only)

## Flagged for owner review

**1. `optional_try` is now permanent, and the escape hatch has never been used.** 316 inventoried
sites resolved across the phase with **zero** `swiftlint:disable:next optional_try` directives. That
is a strong result for D-01, but it also means the D-02 exception form is untested for *this* rule —
the first contributor who genuinely needs one will be exercising it for the first time. 11-17 probed
the equivalent form for the subscript rule and found it composes correctly with
`swiftlint_disable_requires_reason` and `superfluous_disable_command`; the mechanism is rule-agnostic,
so it should behave identically here, but it has not been demonstrated on this rule specifically.

**2. `removeTemporaryItem(at:)` now exists twice, in two test targets.** 11-23 built it in
`DownloadsFeatureTests`; this wave built the same six-line function in `ImageClientTests`. Both carry
the same rationale in their doc comments. `TestingSupport` already exists as a shared test-support
module and could host it, but only 4 of the ~18 test targets depend on it, so hosting a temp-directory
helper there means widening that dependency graph for what is currently 138 call sites concentrated in
two targets. **The larger lever is the one 11-23 identified:** a fixture type that removes its root in
`deinit` would delete all 138 `defer` lines outright and make the helper unnecessary in both places.
That is a test-architecture change well outside any flip plan's scope.

**3. Every remaining `try?`-shaped silence in the test suite is `defer` teardown.** Across 11-23 and
11-24, 138 of 166 converted sites (83%) are one line: removing a UUID-scoped temporary directory in a
`defer`. The rule flip has made that explicit and documented, which is the win it was after, but the
underlying duplication is untouched and will reappear in every new IO-touching test. See point 2.

**4. The plan's `must_haves.truths` cannot be verified as written.** It asserts "all 316 inventoried
sites … are root-fixed or carry the D-02 exception form". The end state is verifiable — zero `try?`
repo-wide, zero directives — but the 316 figure is a phase-opening inventory that no artifact tracks
cumulatively, and the per-wave counts have drifted in every wave. The success condition that actually
holds is the binary's zero over all four roots, which is what was checked.

## Known Stubs

None.

## Threat Flags

None. Test-only source change plus a lint-config change; no production file modified, and no new
network, auth, file-access or schema surface. T-11-27's mitigation is satisfied directly: the
standalone binary's zero-check ran before the commit, and `build-for-testing` — the gate that would
catch a residual Tests violation the app-scheme build cannot see — succeeded on the committed tree.

## Self-Check: PASSED

- `.swiftlint.yml` — FOUND, `optional_try` uncommented at `severity: error`, `doccomment` present, no
  `excluded:` path patterns
- `AppPackage/Tests/ImageClientTests/ImageClientTests.swift` — FOUND, 9 × `removeTemporaryItem(at:)`
- `AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift` — FOUND, helper present
- `AppPackage/Tests/CookieClientTests/CookieClientTests.swift` — FOUND
- `AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-24-SUMMARY.md` — FOUND
- Commit `b72fab8e` — FOUND
