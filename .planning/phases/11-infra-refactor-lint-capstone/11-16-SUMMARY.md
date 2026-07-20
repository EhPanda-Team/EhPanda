---
phase: 11-infra-refactor-lint-capstone
plan: 16
subsystem: ImageColors
tags: [lint, swiftlint, subscript, color-extraction, vendored-algorithm, parity]
requires:
  - "11-13/11-14/11-15's finding that the draft rule's `excluded: \"\\\\[validatedIndex\\\\]\"` entry is inert"
  - "11-15's finding that the draft rule polices `doc_comment`"
  - "D-16 (owner: ImageColors gets NO module-level exception) and D-08 (checked idiom)"
provides:
  - "ImageColors contributes zero matches to the draft `unchecked_subscript_index_access` rule"
  - "`ProposedColors` — the four color slots as named fields instead of a positional `[Double]`"
  - "Zero precondition-checked exception sites, so 11-17 has no directive to insert in this module"
  - "Second independent confirmation that the draft rule polices doc comments"
affects:
  - "No other module — ImageColors' only public surface is `ImageColors.colors(from:quality:)` and `Colors`, neither of which changed. Every edit is inside `private` code."
tech-stack:
  added: []
  patterns:
    - "`makeIterator()` + a four-way `while let` chain as the bounds-safe replacement for a strided pixel-buffer walk"
    - "Named-field struct replacing a fixed-length positional array used as a record (the 11-14 pattern, second application)"
key-files:
  created: []
  modified:
    - AppPackage/Sources/ImageColors/ImageColors.swift
decisions:
  - "22 of the 25 source matches were one design defect, not 22 sites: `proposed` was a four-element `[Double]` used as a record (`[0]` background, `[1]` primary, `[2]` secondary, `[3]` detail) with `-1` as an unset sentinel. Replaced with a `ProposedColors` struct carrying the same four packed `Double`s as named fields. This is 11-14's InfoPanel pattern applied a second time, and it removes the wrong-slot defect class rather than merely renaming around it."
  - "The histogram's `pixels[pixel + 1..3]` reads were removed structurally, not guarded: the buffer is now walked four bytes at a time through `makeIterator()` and a `while let blue/green/red/alpha` chain. No index arithmetic exists to check, so no precondition was needed."
  - "The pixel-walk reorder (column-major → memory order) is safe because the loop's only output is a `[Double: Int]` tally, which is order-independent. Argued explicitly below rather than assumed."
  - "`edgeColor`'s `for index in 1..<sortedColors.count` became `for next in sortedColors.dropFirst()`, and the now-redundant `!sortedColors.isEmpty` guard was dropped with it."
  - "The two doc-comment matches were resolved by rewriting the comment to describe the four-byte walk, which is what the code now does — the rewrite improved the comment rather than degrading it, so 11-15's 'clarity loss' tradeoff did not recur here."
  - "No precondition-checked exception was created anywhere in this module, despite D-16 explicitly sanctioning them. 11-17 has no directive to insert here."
metrics:
  duration: ~20 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 16: ImageColors Subscript-Rule Cleanup Summary

All 27 `unchecked_subscript_index_access` matches in ImageColors are gone, and the three parity fixtures pass byte-identically with zero test edits. No module-level exception, no path exclusion, no `.swiftlint.yml` change, and — despite this being the phase's designated best case for them — **no precondition-checked exception sites at all**. 22 of the 25 source matches turned out to be a single design defect.

## The count was right: 27, and the split was predictable

The standalone binary against a scratch config enabling only the draft rule reported **exactly 27** at HEAD before any edit — the fourth consecutive wave where the plan's number matched the tree.

| Location | Matches | Kind |
|---|---|---|
| `colors(from:)` / `accentColors(from:proposed:)` — `proposed[N]` | 22 | positional record |
| `colors(from:)` histogram — `pixels[pixel + 1…3]` | 3 | name ± literal, pixel buffer |
| `edgeColor(from:threshold:)` — `sortedColors[index]` | 1 | loop index |
| `sampledPixels` doc comment — `pixels[i]`, `pixels[i + 3]` | 2 | **doc comment (rule defect)** |

Note the ratio: 22 of 25 source matches sat on one variable.

## `proposed` was a four-slot positional record — the 11-14 defect, again

The algorithm carried its four output colors as:

```swift
var proposed: [Double] = [-1, -1, -1, -1]
```

`[0]` is the background, `[1]`/`[2]`/`[3]` are the primary/secondary/detail accents, and `-1` means "not yet filled". Every read and write of every slot — across two functions and the final `Colors` construction — was a literal-index subscript. That is 22 matches produced by one modeling choice, exactly the shape 11-14 found in `parseInfoPanel`'s 8-slot `[String]`.

The fix names the slots:

```swift
private struct ProposedColors {
    static let unset: Double = -1

    var background = Self.unset
    var primary = Self.unset
    var secondary = Self.unset
    var detail = Self.unset
}
```

Each field holds exactly the packed `Double` its array element held, and `unset` is the same `-1` the array was seeded with. `accentColors(from:proposed:)` takes and returns `ProposedColors` instead of `[Double]`. The candidate loop's three-branch cascade reads the same way it did, with `proposed.primary == ProposedColors.unset` where it had `proposed[1] == -1`.

**This is not a rename to dodge a regex.** The array invited a real defect the struct forecloses: writing the wrong slot — `proposed[2]` where `proposed[1]` was meant — is a silent bug that yields a plausible-looking color, and nothing in the type system or the tests would catch it. That failure mode no longer exists.

The one branch that genuinely iterated slots was the fallback fill:

```swift
for index in 1...3 where proposed[index] == -1 {
    proposed[index] = isDarkBackground ? 255_255_255 : 0
}
```

Three fields, three conditions, no loop:

```swift
let fallback: Double = proposed.background.isDarkColor ? 255_255_255 : 0
if proposed.primary == ProposedColors.unset { proposed.primary = fallback }
if proposed.secondary == ProposedColors.unset { proposed.secondary = fallback }
if proposed.detail == ProposedColors.unset { proposed.detail = fallback }
```

Same three slots, same predicate, same two constants.

## The histogram walk: removed the arithmetic rather than checking it

The pixel loop was the module's only genuine buffer indexing, and the one place D-16's sanctioned precondition form was most likely to be needed:

```swift
for column in 0..<width {
    for row in 0..<height {
        let pixel = ((width * row) + column) * 4
        guard pixels[pixel + 3] >= 127 else { continue }
        let color = (Double(pixels[pixel + 2]) * 1_000_000)
            + (Double(pixels[pixel + 1]) * 1_000)
            + Double(pixels[pixel])
        colorCounts[color, default: 0] += 1
    }
}
```

The bound *is* provable — `pixels` is allocated at exactly `width * height * 4`, and `((width * row) + column) * 4 + 3` maxes out at `count - 1` — so a `precondition` citing that invariant was the expected resolution. But a precondition that can never fire is ceremony around arithmetic that does not need to exist. The buffer is a flat BGRA stream; consuming it as one:

```swift
var channels = pixels.makeIterator()
while let blue = channels.next(), let green = channels.next(),
    let red = channels.next(), let alpha = channels.next() {
    guard alpha >= 127 else { continue }
    let color = (Double(red) * 1_000_000) + (Double(green) * 1_000) + Double(blue)
    colorCounts[color, default: 0] += 1
}
```

No index, no arithmetic, nothing to bound-check. It also reads the buffer in memory order rather than striding by `width * 4` down each column, which is strictly friendlier to the cache — a small win in the module's only hot loop, and certainly not a regression, which is the bar the plan set for idiom substitutions in tight pixel loops.

**Why the reorder is safe.** The nested loop's `width * row + column` ranges over `0..<width * height` exactly once as `(row, column)` covers its domain, so the old walk and the new one visit precisely the same set of pixels. The loop's sole output is `colorCounts`, a `[Double: Int]` tally, and addition is commutative — the resulting dictionary has the same keys with the same values regardless of visit order.

The one place order could theoretically leak through is tie-breaking: both `edgeColor` and `accentColors` call `sorted { $0.count > $1.count }`, Swift's sort is not stable, and the input derives from `colorCounts.keys`, whose iteration order depends on insertion sequence. But that tie-break was **already** nondeterministic before this change — Swift seeds hashing per process, so two runs of the *unmodified* algorithm on the same image can order equal-count colors differently. Nothing may depend on it, so nothing can be broken by it. The three fixtures use distinct, deliberately-separated counts and are unaffected either way.

## The doc-comment defect, confirmed a second time — with no clarity cost this time

Line 151's doc comment described the buffer layout as ``(`pixels[i]` = blue ... `pixels[i + 3]` = alpha)``. Under the draft config that is **two violations**, because `excluded_match_kinds` lists `comment` and `string` but SwiftLint treats `///` as the separate `doc_comment` kind. This independently reproduces 11-15's finding.

Here the fix was free: the code no longer indexes anything, so the comment describing it in subscript terms had become inaccurate. It now reads:

> returning bytes laid out blue, green, red, alpha per pixel — the order the four-byte walk in `colors(from:)` consumes them, and the layout the packing math in the `Double` extension expects.

More accurate than what it replaced. **11-15's clarity-loss tradeoff did not recur** — but only by luck, because the same edit that cleared the rule also made the subscript phrasing obsolete. Had the indexing stayed, the comment would have had to be degraded exactly as 11-15's was. The recommendation to add `doc_comment` to `excluded_match_kinds` stands undiminished.

## Algorithm parity: what was and was not touched

Every constant, comparator and threshold in the diff is byte-identical: the `127` alpha cutoff, the `1_000_000` / `1_000` packing multipliers, the `255_255_255` / `0` text fallbacks, the `0.3` count ratio in `edgeColor`, both `sorted { $0.count > $1.count }` comparators, the `0.15` minimum saturation, and the entire `Double` extension (luminance weights, `isDistinct` deltas, `isContrasting` ratio, the HSV round-trip). Untouched:

- `edgeColor`'s `filter`/`map`/`sorted` pipeline and its black-or-white skip logic
- `accentColors`' candidate pipeline and its three-branch cascade, including the `break` on the detail slot
- `scaledPixelSize`, `sampledPixels` (bitmap info, color space, `.high` interpolation)
- the public `Colors` struct and `ImageColors.colors(from:quality:)` signature

The jathu attribution and the DEP-02/D-01/D-04/D-16 provenance comment on `Colors` are preserved verbatim.

The single behavioral simplification is `edgeColor`'s dropped `!sortedColors.isEmpty` guard. It gated a `for index in 1..<sortedColors.count` loop, where an empty array would make the range `1..<0` and trap. `sortedColors.dropFirst()` on an empty array is simply empty, so the guard now protects nothing. Removing an always-true condition on a loop that can no longer misbehave — same accept/reject set.

## Verification

- Draft rule via standalone binary over `AppPackage/Sources/ImageColors`, scratch config, `--no-cache` — **0 violations** (27 before). Run after each task.
- Full project config `--strict` over the source and test trees — **0 violations**. Confirms live `lifecycle_modifiers` / `binding_initializer` still pass.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings. Run after each task.
- `ImageColorsTests` — **3 tests / 1 suite passed**, run after *each* of the two commits, not just at the end.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (61.0s). The 2 known issues in `SettingFeature` tests are pre-existing and unchanged from 11-15.
- `bash Scripts/check-cookie-logging.sh` — **exit 0**. No logging added or changed.
- `git diff --name-only -- .swiftlint.yml` — empty. Config untouched.
- `git diff --name-only HEAD~2 HEAD` — **one file**, `AppPackage/Sources/ImageColors/ImageColors.swift`. No test file, no `.swiftlint.yml`, no `Package.swift`.
- `LINT-01` left open — it flips at 11-29.

## D-16 gate: proven

The three parity fixtures — `lightSolidImageLocksBackgroundAndBlackTextFallback`, `darkSolidImageLocksBackgroundAndWhiteTextFallback`, `saturatedMultiRegionImageLocksAccentColors` — passed **unchanged after both commits**, with zero edits to `ImageColorsParityTests.swift`, no re-baselining, and no tolerance widening (`isClose` still uses its default `tolerance: 2`; the accent assertions still pin exact RGB triples). The striped fixture is the load-bearing one: it exercises `with(minSaturation:)`, `isDistinct`, `isContrasting` and the full three-slot accent cascade, which is precisely the code the `ProposedColors` conversion rewrote.

No module-level exception was added. No path exclusion was added. D-16 is satisfied on its own terms.

## No exception sites — nothing for 11-17 to insert

Every one of the 27 matches resolved to a structural fix or an accurate comment rewrite. **Zero precondition-checked exceptions were created**, so there is no pending `// swiftlint:disable:next unchecked_subscript_index_access` directive in this module and 11-17 has no edit to make here.

This is notable because the orchestrator identified ImageColors as the phase's *best* candidate for the precondition form — a vendored algorithm indexing with loop-derived variables. It turned out not to need one: the 22-match cluster was a modeling defect that a named struct dissolves, and the 3-match pixel loop had a shorter answer than a proof of its own bound. **Four consecutive waves, 172 matches (11-13 through 11-16), zero exception sites.** That the sanctioned exception has not been needed once is now worth flagging to the owner in its own right — see below.

## Deviations from Plan

**1. [Rule 3 — Blocking] Test scheme substitution (same as 11-01/11-02/11-14/11-15)**

- **Found during:** Task 2
- **Issue:** The plan's `-scheme ImageColors` does not exist.
- **Fix:** `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air' -only-testing:ImageColorsTests`, invoked from `AppPackage/`. The `ImageColorsTests` target does exist and was verified before use.
- **Commit:** n/a (invocation only)

**2. [Scope] The `validatedIndex` idiom was not used, and no exception site was created**

- **Found during:** Both tasks
- **Issue:** The plan's `key_links` pattern names `precondition|validatedIndex` and its action text directs arithmetic-derived indices toward a guard-validated `validatedIndex` local. Neither was needed: the arithmetic-derived indices were removed rather than validated.
- **Fix:** None needed. Recorded so 11-17 does not go looking for a directive site in this module.
- **Commit:** n/a

**3. [Rule 1 — Bug class] The `proposed` cluster was fixed structurally rather than annotated**

- **Found during:** Task 1
- **Issue:** The plan's action text anticipates per-site checked forms. Applying that to `proposed[0…3]` would have added 22 annotations to literal indices into a fixed-size local array — all provably in bounds, all pure ceremony — while leaving the wrong-slot defect class fully intact.
- **Fix:** `ProposedColors` struct. Shorter diff than 22 annotations, and it removes a silent-mis-index failure mode instead of documenting it.
- **Commit:** `c172519b`

**4. [Scope] One redundant guard removed**

- **Found during:** Task 1
- **Issue:** `edgeColor`'s `!sortedColors.isEmpty` existed only to keep `1..<sortedColors.count` from trapping.
- **Fix:** Dropped with the range loop it protected. `dropFirst()` handles the empty case natively.
- **Commit:** `4e9e684d`

## Flagged for owner review

**1. Recommendation for 11-17, seconding 11-15: the draft rule polices doc comments.** Independently reproduced here — the two matches on the `sampledPixels` doc comment were `doc_comment` kind, which `excluded_match_kinds` does not list alongside `comment` and `string`. **Recommend adding `doc_comment` when 11-17 enables the rule.** This wave escaped without a clarity loss only because the same change that cleared the rule also made the old wording obsolete; that will not generally be true, and it penalises exactly the explanatory comments D-08's exception form requires.

**2. Recommendation for 11-17, thirding 11-13/11-14/11-15: delete the inert `excluded` entry.** `"\\[validatedIndex\\]"` is a file-path regex that cannot match source text. Four plans have now resolved every site without it.

**3. The sanctioned precondition-exception form has not been used once in four waves.** 11-13, 11-14, 11-15 and 11-16 resolved 172 matches with zero exception sites — including this module, which the phase singled out as the most likely to need them. Two readings: either the escape hatch is genuinely unnecessary and the rule can ship without an established exception idiom, or the remaining waves (11-17 onward) hold all of the hard cases. Worth the owner's attention before the flip, because a rule whose documented exception form has never been exercised is a rule whose exception form is untested — the first real use will be discovering, in the flip commit, whether `precondition` + reason comment + `disable:next` actually composes cleanly with `swiftlint_disable_requires_reason`.

**4. `ImageColors.colors(from:quality:)` tie-breaks nondeterministically, and always has.** Both `sorted { $0.count > $1.count }` calls receive input derived from `colorCounts.keys`; Swift's sort is unstable and its `Dictionary` iteration order varies with the per-process hash seed. Two runs on the same image *can* return different accent colors when candidate counts tie. This predates the milestone and is not a regression — it is called out because it was load-bearing in reasoning about this refactor's safety, and because it means the module's output is not reproducible run-to-run in the tie case. If the owner wants determinism, the fix is a total-order comparator (e.g. tie-break on the packed color value), which is a two-token change to both `sorted` calls but *would* be an algorithm change and so is deliberately out of this plan's mandate.

**5. `ProposedColors` could carry the `Colors` conversion.** The final `Colors(background: proposed.background.color, …)` is now a straight field-for-field map and would read well as a computed property or an `init(_:)` on the struct. Not done: it adds a member for one call site, and the plan's mandate is bounds annotation, not API shaping.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface. T-11-19's mitigation is satisfied structurally rather than by precondition: the histogram's out-of-bounds trap surface was removed with the index arithmetic that created it, and the parity fixtures gate the output as the register required. Note that the trap was not reachable in practice — `sampledPixels` allocates `width * height * 4` bytes and returns `nil` on failure, and `colors(from:)` guards `width > 0, height > 0` before the walk — so this closes a latent hazard, not a live one.

## Self-Check: PASSED

- `AppPackage/Sources/ImageColors/ImageColors.swift` — FOUND
- `AppPackage/Tests/ImageColorsTests/ImageColorsParityTests.swift` — FOUND (unmodified)
- `.planning/phases/11-infra-refactor-lint-capstone/11-16-SUMMARY.md` — FOUND
- Commit `4e9e684d` — FOUND
- Commit `c172519b` — FOUND
