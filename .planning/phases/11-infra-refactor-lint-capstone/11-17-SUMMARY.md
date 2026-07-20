---
phase: 11-infra-refactor-lint-capstone
plan: 17
subsystem: lint-config
tags: [lint, swiftlint, subscript, rule-flip, config, bytes, url-parsing]
requires:
  - "11-11's atomic-flip procedure (directives + config + last fixes in one commit)"
  - "11-13/11-14/11-15/11-16's finding that the draft `excluded: \"\\\\[validatedIndex\\\\]\"` entry is inert"
  - "11-15/11-16's finding that the draft rule polices doc comments"
  - "11-16's warning that the sanctioned exception idiom was untested after four waves"
provides:
  - "`unchecked_subscript_index_access` live at error — subscript index access is now build-gated repo-wide"
  - "The corrected `excluded_match_kinds` spelling: `doccomment`, NOT `doc_comment`"
  - "Two reason-annotated exception directives, the complete repo-wide set for the owner's 11-29 review"
  - "`Data.byte(_:at:)` — a bounds-checked single-byte read for the GIF/WebP header walkers"
  - "`GalleryRoute` — the `/<kind>/<gid>/<token>` URL shape extracted behind one guard"
affects:
  - "Every future build: the rule is enforced by the SwiftLint build-tool plugin on source AND test targets"
  - "FavoritesReducer.State.index renamed to favoritesIndex (public property, consumed only inside FavoritesFeature)"
tech-stack:
  added: []
  patterns:
    - "`UInt32(littleEndian:)` / `UInt32(bigEndian:)` + `loadUnaligned` replacing hand-rolled byte shifting"
    - "`popFirst()` on a shrinking slice as the bounds-safe replacement for positional record indexing"
    - "`enumerated().min { $0.element < $1.element }?.offset` as the leftmost-minimum scan"
key-files:
  created: []
  modified:
    - .swiftlint.yml
    - AppPackage/Sources/AnimatedImageFeature/AnimatedImage+.swift
    - AppPackage/Sources/AppModels/Support/RunLogFile.swift
    - AppPackage/Sources/AppModels/Support/AppError+Context.swift
    - AppPackage/Sources/AppModels/Persistent/GalleryHistory+Operations.swift
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
    - AppPackage/Sources/URLClient/URLClient.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
    - AppPackage/Sources/AppComponents/TagCloudView.swift
    - AppPackage/Sources/AppComponents/TagSuggestionView.swift
    - AppPackage/Sources/AppTools/Extensions/String+Helpers.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
    - AppPackage/Sources/GalleryListComponents/MasonryLayout.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections2.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
decisions:
  - "The doc-comment fix is `doccomment`, not the `doc_comment` that waves 15 and 16 recommended and that this plan's own brief specified. `doc_comment` is not a valid SwiftLint syntax kind, and ONE invalid entry makes SwiftLint discard the entire rule configuration and fall back to defaults — silently, behind a single `warning:` line that a `--quiet` JSON run swallows. Shipping the recommended spelling would have disabled the rule while looking exactly like a clean flip."
  - "The inert `\"\\\\[validatedIndex\\\\]\"` entry was deleted outright, per the recommendation from all four prior waves. No negative lookahead was added to the regex in its place: 240 sites across five waves resolved without any token-level escape, so adding one now would be building a hatch nothing has ever needed."
  - "The surviving `\".*/[^/]*Tests\\\\.swift$\"` entry was verified functional rather than assumed — a probe pair of identical files named `FooTests.swift` and `FooHelper.swift` flagged only the latter."
  - "AnimatedImageFeature's 14 matches were one defect: unchecked reads into untrusted image bytes. A bounds-checked `byte(_:at:)` accessor plus `UInt32(littleEndian:)`/`UInt32(bigEndian:)` removed all of them with no exception site, and deleted the hand-rolled shift arithmetic."
  - "URLClient's 8 matches were the gallery-URL path-component cluster for the third time in the phase (after 11-14 and 11-15). Extracted a private `GalleryRoute`; the sibling `AppError+Context` cluster kept its own `dropFirst`/`popFirst` walk to preserve its deliberately laxer acceptance of a token-less `/g/<gid>`."
  - "FavoritesReducer's 7 matches all read `[Int: X]` dictionaries keyed by the State's `index` property, which is the favorites-category slot. Renamed the property to `favoritesIndex` — the name the reducer's own `setFavoritesIndex` action and the requests' `favIndex:` label already use."
  - "Exactly two exception sites exist repo-wide, both genuine in-place mutations through an index the surrounding code establishes. Both carry a precondition, a prose invariant and a reason-annotated directive."
metrics:
  duration: ~60 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 17: Subscript Rule Flip Summary

`unchecked_subscript_index_access` is live at error with zero violations across `AppPackage/Sources`, `AppPackage/Tests`, `App` and `ShareExtension`. The 239-site inventory is closed. Three commits: two module sweeps, then one atomic commit carrying the config corrections, the rule flip and both exception directives.

**The most important finding in this plan is that the doc-comment fix everyone recommended is spelled wrong, and that spelling it wrong disables the rule silently.** Details below.

## The count was right: 68, and the module list was wrong again

The standalone binary against a scratch config enabling only the corrected rule reported **68** at HEAD before any edit. The plan predicted "~67 (AnimatedImageFeature 14, AppModels 13, HomeFeature 10, URLClient 8, FavoritesFeature 7, ~6 smaller modules ~15)" — the total and the five named modules were all exact. The "~6 smaller modules" turned out to be 9 files across 7 modules.

| File | Matches | Kind |
|---|---|---|
| `AnimatedImageFeature/AnimatedImage+.swift` | 14 | untrusted image bytes |
| `URLClient/URLClient.swift` | 8 | URL path components |
| `AppModels/Support/RunLogFile.swift` | 8 | positional split record |
| `FavoritesFeature/FavoritesReducer.swift` | 7 | page-keyed Dictionary |
| `HomeFeature/HomeReducer+Body.swift` | 6 | category-keyed Dictionary |
| `HomeFeature/HomeView+Sections.swift` | 4 | Array, pair chunking + ranking rows |
| `AppModels/Support/AppError+Context.swift` | 4 | URL path components |
| `SettingFeature/EhSettingView+Sections3.swift` | 3 | flat bindings chopped into rows |
| `AppComponents/TagCloudView.swift` | 3 | parallel arrays |
| `AppTools/Extensions/String+Helpers.swift` | 3 | split-string pair |
| `DetailFeature/Previews/PreviewsView.swift` | 2 | page-keyed Dictionary |
| `SettingFeature/EhSettingView+Sections2.swift` | 1 | parallel arrays |
| `GalleryListComponents/MasonryLayout.swift` | 1 | Array, column scan |
| `AppComponents/TagSuggestionView.swift` | 1 | `firstIndex` + read |
| `DownloadsFeature/DownloadsView+Subviews.swift` | 1 | page-keyed Dictionary |
| `AppModels/Persistent/GalleryHistory+Operations.swift` | 1 | **exception** |
| `PreviewSupport/PreviewIdentifiers.swift` | 1 | **exception** |

# Obligation 1 — the inert `excluded` entry: deleted

`excluded:` on a SwiftLint custom rule is a **file-path** regex. `"\\[validatedIndex\\]"` is source-shaped and can never match a path, so it was dead configuration masquerading as an escape hatch — and three plans (11-13, 11-14, 11-15) were written around it before 11-12 caught it.

**Deleted, not replaced.** All four prior waves recommended deletion, and the case has only strengthened: **240 matches across five waves (11-13 through 11-17) resolved with exactly two exception sites, neither of which wanted a token-level escape.** The alternative the earlier waves offered — a negative lookahead in the rule's own `regex` — would be adding a mechanism nothing has ever asked for, and it would make an already dense regex worse.

The sibling entry `".*/[^/]*Tests\\.swift$"` was kept, per D-15 (Tests are handled in 11-23/11-24). It was also **verified rather than assumed**: two byte-identical probe files, `FooTests.swift` and `FooHelper.swift`, each containing `a[0]`. Only `FooHelper.swift` was flagged. The path exclusion works.

A comment now sits above the entry stating that `excluded` matches file paths, so the next reader does not have to rediscover it.

# Obligation 2 — the doc-comment defect, and a trap inside the recommended fix

## The recommended spelling is invalid, and invalid spellings fail silently

Waves 15 and 16 both independently recommended adding **`doc_comment`** to `excluded_match_kinds`, and this plan's own brief carried that spelling forward. It is wrong. The valid SwiftLint syntax kind is **`doccomment`** (`docComment` also parses).

That would be a trivial typo if SwiftLint rejected it loudly. It does not. An unrecognised entry in `excluded_match_kinds` makes SwiftLint discard the **entire** rule configuration:

```
warning: Invalid configuration for 'unchecked_subscript_index_access' rule. Falling back to default.
```

There is no default for a custom rule, so the rule is simply gone. It reports zero violations, on any input, forever. That is byte-identical to what a clean repo produces — and the warning goes to stderr, which a `--reporter json --quiet` verification run discards.

Concretely: had this plan shipped `doc_comment` as instructed, the flip commit would have "passed" every check in its own success criteria — zero violations repo-wide, clean build, clean `build-for-testing`, green suite — while enabling nothing at all. This was caught only because the first repo-wide enumeration returned `TOTAL 0` against a tree known to hold ~67 matches, which was implausible enough to investigate. **A rule that reports zero because it was silently discarded is indistinguishable from a rule that reports zero because the code is clean, and the negative-control probe is the only thing that separates them.** This is the second time in this phase that a config key was inert in a way that reads as success; it is worth treating "prove the rule fires" as a standing requirement for every custom-rule flip, not a nicety.

`doccomment` was verified against a four-line probe before use: a `///` mentioning `foo[2]`, a `//` mentioning `bar[3]`, a string containing `baz[4]`, and a real `a[0]`. Only the real access was flagged.

## Re-scan of the previously-cleaned modules

All six were re-enumerated under the **corrected** config, since their prior clearance was obtained under a config that policed doc comments and therefore proves nothing about this one:

| Module | Matches under corrected config |
|---|---|
| ReadingFeature (11-13) | 0 |
| ParserFeature (11-14) | 0 |
| DownloadClient (11-15) | 0 |
| NetworkingFeature (11-15) | 0 |
| ImageColors (11-16) | 0 |
| PreviewSupport (11-12) | **1** — the prepared exception site, see below |

The re-scan surfaced nothing new. The single PreviewSupport hit is not a regression: 11-12 left a fully-formed exception site there — `precondition`, prose, and a `// reason:` line — with the `disable:next` directive deliberately omitted, because a directive cannot exist while its rule is commented out. It was waiting for this commit. It is the only inheritance the phase left for the flip, and both prior waves that predicted "nothing for 11-17 to insert" were speaking only for their own modules.

Correcting the kind list did not reduce any module's count, which means no site cleared in waves 13–16 was a doc-comment false positive that got resolved by degrading prose. Only one such degradation is known, and it is addressed next.

## Wave 15's degraded comment: restored

11-15 had to reword `URL.galleryIdentifiers`' doc comment from ``` `pathComponents[2]` / `[3]` ``` to the vaguer "path components 2 and 3", and correctly recorded that as a clarity loss. Under the corrected config the precise wording is legal again.

**It was not restored, deliberately.** The comment as it stands today reads:

> Skips the leading "/" and "g" components to reach `<gid>/<token>`.

That is 11-15's *final* wording, and it does not describe the access in index terms at all — it describes the `dropFirst(2)` the code actually performs, which is more accurate than either the original or the intermediate rewording. Reverting to `pathComponents[2]` / `[3]` phrasing would re-introduce a reference to a subscript the function no longer contains. The clarity loss 11-15 flagged was real at the time it was made, but the code moved past it; there is nothing left to restore. Recorded explicitly so this is not read as the obligation being skipped.

# Obligation 3 — the exception idiom, probed before the flip

11-16 flagged that four waves and 172 matches had never once exercised the sanctioned `precondition` + reason-annotated-disable form, leaving its interaction with `swiftlint_disable_requires_reason` untested. The flip commit is the worst possible place to discover a broken escape hatch.

A throwaway probe exercised the full form end-to-end, under a config carrying the corrected rule, `swiftlint_disable_requires_reason` **and** `superfluous_disable_command`:

```swift
func head(_ values: [Int]) -> Int {
    // The caller guarantees a non-empty buffer; the precondition makes it explicit.
    precondition(!values.isEmpty, "values must not be empty")
    // reason: bound proven by the precondition on the line above
    // swiftlint:disable:next unchecked_subscript_index_access
    return values[0]
}
```

**Result: clean, exit 0.** All three rules were satisfied simultaneously — the directive suppressed the subscript rule, the `// reason:` line satisfied `swiftlint_disable_requires_reason`, and `superfluous_disable_command` stayed quiet because the directive was doing real work.

Deleting the `disable:next` line made the rule fire on that exact line, exit 2. So the suppression is load-bearing, not decorative.

The form composes. The probe file was deleted before any commit; `git status` immediately before the flip showed exactly the three intended files.

# The atomic flip

One commit, `3bf28440`, carrying:

1. `doccomment` added to `excluded_match_kinds`, with a comment naming the silent-fallback trap
2. the `validatedIndex` entry deleted, with a comment stating that `excluded` matches file paths
3. `unchecked_subscript_index_access` uncommented at `severity: error`
4. both `// swiftlint:disable:next` directives

Splitting these fails lint in either order, as five waves have now confirmed: directives-first trips `superfluous_disable_command` ("not a valid SwiftLint rule"), rule-first trips the rule itself. Lint is error-level, so either split breaks the build.

The last module fixes landed in the two preceding commits rather than in the flip, which is safe because neither of them introduced an exception site — the tree was at exactly two violations, both pre-existing prepared sites, when the flip commit opened.

## Negative control

A zero-violation lint is also what a silently-discarded config produces — the failure mode described above — so the rule was proven to fire before the flip was accepted. Probe, linted against the **live** `.swiftlint.yml`:

| Line | Content | Expected | Actual |
|---|---|---|---|
| 1 | `/// A doc comment mentioning values[0]` | not flagged | not flagged |
| 2 | `// A regular comment mentioning values[1]` | not flagged | not flagged |
| 4 | `let literal = values[2]` | flagged | flagged |
| 5 | `let named = values[index]` | flagged | flagged |
| 6 | `let arithmetic = values[index + 1]` | flagged | flagged |

Exactly three violations, all on real code, none on prose. This simultaneously proves the rule is registered, that all three policed forms (literal, policed name, name ± literal) match, and that the `doccomment` exclusion works.

The two `disable:next` directives are themselves a second proof of registration: an unknown rule id there would trip `superfluous_disable_command`, which reports zero.

# The module sweep

## AnimatedImageFeature (14) — one defect, not fourteen

Every match was an unchecked read into `UnsafeRawBufferPointer` over **untrusted image data**: GIF header bytes, block labels, sub-block sizes, WebP chunk sizes. Each read had a bounds check somewhere nearby, but the check and the read were separate statements, which is precisely the arrangement that rots.

Three changes cleared all fourteen with no exception site:

**A bounds-checked accessor** replaced five scattered single-byte reads:

```swift
/// The byte at `offset`, or `nil` when it lies outside the buffer.
///
/// Every read below comes from a length field or a walk cursor in untrusted image data, so the
/// bounds check belongs at the read rather than at each caller, where it is easy to omit.
private static func byte(_ bytes: UnsafeRawBufferPointer, at offset: Int) -> UInt8? {
    guard bytes.indices.contains(offset) else { return nil }
    return bytes.load(fromByteOffset: offset, as: UInt8.self)
}
```

The GIF walker's `while offset < bytes.count { switch bytes[offset] {` became `while let blockLabel = Self.byte(bytes, at: offset) { switch blockLabel {`, which is the same loop with the bound expressed once instead of twice.

**`UInt32(littleEndian:)` / `UInt32(bigEndian:)` + `loadUnaligned`** replaced eight matches' worth of hand-rolled shifting:

```swift
return UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
```

replacing `UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | …`. On a little-endian host `loadUnaligned` yields `b0 | b1<<8 | b2<<16 | b3<<24`, and `UInt32(littleEndian:)` is identity there — byte-for-byte the old expression. `UInt32(bigEndian:)` byte-swaps it to `b0<<24 | b1<<16 | b2<<8 | b3`, byte-for-byte the old big-endian expression. Both guards gained an `offset >= 0` term the originals lacked; a negative offset previously passed `offset + 4 <= count` and then read out of bounds.

**`elementsEqual` on a slice** replaced the signature comparison loop:

```swift
return bytes[offset..<offset + expected.count].elementsEqual(expected)
```

The dual image-stack routing (Kingfisher primary, SDWebImage for animated) was not touched; nor were the format signatures, the `0x2C`/`0x21`/`0x3B` GIF block labels, the color-table size formula, the `0x80`/`0x02` mask bits, or the WebP chunk-walk arithmetic. Frame timing and ordering are decided downstream by `SDAnimatedImage`, which this file only routes to.

## AppModels (13)

**`RunLogFile.init?(fileURL:)` (8)** parsed `ehpanda-<yyyyMMdd>-<HHmmss>-<runCount>.jsonl` by splitting twice and reading eight literal indices behind `count == 2` / `count == 4`. This is the positional-record shape 11-14 and 11-16 both found, at smaller scale. Each slot now binds to a named local (`baseName`, `fileExtension`, `prefix`, `day`, `time`, `runCountText`) via `first` / `dropFirst(n).first` / `last`, with both count guards retained so the accept/reject set is unchanged.

**`Dictionary.galleryFailure(url:action:reason:)` (4)** read `pathComponents[1]`/`[2]`/`[3]` to pull a gallery id out of a failing URL for diagnostics. Now a `switch` over a shrinking slice:

```swift
var route = url.pathComponents.dropFirst()
let candidate: String? = switch route.popFirst() {
case "g"?: route.first
case "s"?: route.dropFirst().first?.split(separator: "-", maxSplits: 1).first.map(String.init)
default: nil
}
```

Note this function accepts a **token-less** `/g/<gid>` (its original guard was `count >= 3`, not `>= 4`), which is why it keeps its own walk instead of adopting URLClient's `GalleryRoute`. The numeric-only validation and the no-raw-URL-in-context contract below it are untouched.

**`Array<GalleryHistoryEntry>.updateReadingProgress` (1)** is one of the two exception sites — see below.

## HomeFeature (10)

**`HomeReducer+Body` (6)** — `toplistsLoadingState[index]` / `toplistsGalleries[index]` are `[Int: …]` Dictionary accesses, Optional-returning and incapable of trapping, keyed by the toplist category. The action's payload binding was renamed `index` → `catIndex`, which is the name the request in the same block already uses (`ToplistsGalleriesRequest(catIndex:)`). The `index:` action labels were left alone, per 11-13's precedent: renaming them would ripple into `HomeFeatureTests` for no lint gain.

**`HomeView+Sections` pair chunking (2)** — `stride(from:0, to:count, by:2).map { [galleries[index], galleries[index + 1]] }`, preceded by an `if count % 2 != 0 { dropLast() }` that existed solely to keep `[index + 1]` in range. Both became one loop:

```swift
var remaining = galleries[...]
var pairs: [[Gallery]] = []
while let upper = remaining.popFirst(), let lower = remaining.popFirst() {
    pairs.append([upper, lower])
}
```

The odd trailing gallery is dropped by the loop's own structure, so the parity guard went with it — the failure mode and the workaround for it were deleted together.

**`GalleryRankingCell` rows (2)** — `ForEach(0..<galleries.count, id: \.self) { index in … galleries[index] … }` became `ForEach(galleries.enumerated(), id: \.offset)`. Identical ids (`offset` over an `Array` is the same 0-based position), and it also retires a `ForEach(0..<count)` over a runtime-varying count, which SwiftUI treats as a constant range.

## URLClient (8) — the gallery-URL cluster, third occurrence

`pathComponents[1]`/`[2]`/`[3]` across `checkIfHandleable`, `parseGalleryID`, `isMPVURL` and `analyzeURL`. This is the same shape 11-14 fixed in ParserFeature and 11-15 fixed in NetworkingFeature.

```swift
/// The `/<kind>/<gid>/<token>` route an E-Hentai gallery (`g`) or single-page (`s`) URL carries.
private struct GalleryRoute {
    let kind: String
    let gid: String
    /// Absent for a bare `/<kind>/<gid>` path that stops before the token.
    let token: String?
}
```

A struct rather than a tuple because a three-member tuple trips `large_tuple` — caught by the build, not by inspection.

`checkIfHandleable`'s `count >= 4` is now expressed as "the route has a token", which is the same condition. `isMPVURL` collapsed to `url?.pathComponents.dropFirst().first == "mpv"`. `analyzeURL` takes its token from the route instead of re-indexing, and returns the empty result when the route is absent — previously unreachable, since `checkIfHandleable` gates it, but no longer resting on that.

## FavoritesFeature (7)

Five parallel `[Int: X]` dictionaries (`rawGalleries`, `rawPageNumber`, `rawDateSeekNavigation`, `rawLoadingState`, `rawFooterLoadingState`) read through five computed properties, all keyed by `State.index`. Dictionary subscripts, so nothing could trap; the violation was nominal.

Unlike 11-13's local-binding renames, the key here is a **stored property**, so the rename had to reach the declaration: `index` → `favoritesIndex`. That name is not invented for the occasion — the reducer's action is already `setFavoritesIndex`, the requests already take `favIndex:`, and the value is genuinely the favorites-category slot (`-1` for "all favorites", `0...9` for the user's ten named categories). Blast radius was 20 sites, all inside `FavoritesFeature`; `FavoritesReducer.State` is constructed but never index-read from `AppFeature`, and no test referenced it.

The `index:` action labels on `fetchGalleriesDone` and its siblings were left alone, matching 11-13.

## The remaining nine files

**`TagCloudView` (3)** — `for (index, subview) in subviews.enumerated()` reading `frames[index]` from a parallel array built from those same subviews. Textbook `zip`: `for (subview, frame) in zip(subviews, frames)`.

**`EhSettingView+Sections2` (1)** — the same parallel-array shape, `Category.allFavoritesCases.enumerated()` indexing `$ehSetting.favoriteCategories`. Became `Array(zip(AppModels.Category.allFavoritesCases, $ehSetting.favoriteCategories))`, relying on `Binding`'s `Collection` conformance to yield `Binding<String>` elements. Both are 10 today, and `zip` truncates instead of trapping if a parsed setting ever comes up short — the same robustness gain 11-15 made in `Request+Account.swift`.

**`EhSettingView+Sections3` (3)** was the file's real defect. Fifty language toggles were chopped into three-wide rows by `index * 3 + num` over `[-1, 0, 1]`, with `if index != -1` as the only bounds consideration — a check that catches the first row's leading `-1` and nothing else. The row count was `languageBindings.count / 3 + 1` and the row title came from a parallel `languages[index]`. It happens to work out (17 languages × 3 cells − 1 leading placeholder = 50 bindings, exactly), but nothing in the code says so and nothing checks it.

Replaced by a single `rows` property that consumes a shrinking slice:

```swift
var remaining = languageBindings[...]
return languages.enumerated().map { offset, title in
    let leading: [Binding<Bool>] = offset == 0 ? [.constant(false)] : []
    let cells = remaining.prefix(3 - leading.count)
    remaining = remaining.dropFirst(cells.count)
    return (title, leading + cells)
}
```

Rows are driven by the language list, cells by what remains. Identical output on today's 17/50, and a short `excludedLanguages` now yields empty trailing cells instead of trapping. The placeholder offset is documented in a doc comment rather than encoded as a `-1` sentinel. `ExcludeRow`'s own `ForEach(0..<bindings.count, id: \.self)` became `bindings.enumerated()`.

**`AppTools/String+Helpers` (3)** — `strings[0]`/`strings[1]` behind `count == 2` → `first`/`last` bound in the same `if`. This one is worth noting as the widest-reach change in the plan: `stringsBesideColon` is a public `String` extension.

**`PreviewsView` (2)** — `[Int: URL]` merged dictionary keyed by a 1-based page (`ForEach(1..<pageCount + 1)`). Renamed `index` → `page` and the visibility-callback parameter `indices` → `visiblePages`, matching 11-13/11-14. The every-tenth-page fetch arithmetic `(page - 1) % 10 == 0` is unchanged.

**`DownloadsView+Subviews` (1)** — a preview-fixture builder whose tuple field was named `indices` while holding page numbers, shadowing `Collection.indices` in the bargain. Renamed to `pages`; the compiler found the second call site.

**`MasonryLayout` (1)** — the leftmost-shortest-column scan, `for index in 1..<columns where columnHeights[index] < columnHeights[column]`. This is D-26/D-27 baseline-locked and its doc comment explicitly warns against "improving" the strict `<` to `<=` or a tolerance compare. Became:

```swift
let column = columnHeights.enumerated().min { $0.element < $1.element }?.offset ?? 0
```

`min(by:)` replaces its running minimum only when the comparator returns true, i.e. only on a **strict** `<` — so it keeps the first (leftmost) element attaining the minimum, exactly as the manual scan starting at column 0 did. The doc comment was extended to say so, so the next reader does not have to re-derive it.

**`TagSuggestionView` (1)** — `firstIndex(where:)` then `[index].key` on a Dictionary. `first(where:)?.key` gets the same value in one step.

# The two exception sites

The complete repo-wide set, for the owner's 11-29 review. Both are genuine index-mediated access where the index is established by the surrounding code, and both carry a `precondition`, a prose invariant, and a `// reason:` line.

| # | Site | Invariant | Why not restructured |
|---|---|---|---|
| 1 | `AppModels/Persistent/GalleryHistory+Operations.swift:43` | `firstIndex(where:)` only ever returns a subscriptable index | The mutation must happen **in place** — the sibling `recordGalleryOpen`'s `removeAll` + `insert` idiom would move the entry to the front, and this function's contract is explicitly "leaving its recency and position untouched" |
| 2 | `PreviewSupport/PreviewIdentifiers.swift:1046` | `precondition(all.indices.contains(index))` on the line above | Prepared by 11-12; the type exists to trap loudly rather than substitute a wrapped-around identifier, so the trap is the feature |

Site 2 was inherited fully formed and needed only its directive. Site 1 is this plan's only new exception, and it is the phase's **first and only** organic use of the D-08 form across 240 matches.

Both preconditions are, by construction, unfirable — which is the honest reading of what the rule wants. It asks that an index access be *guarded*; where the guard is a `firstIndex` call or an explicit `precondition`, restating it at the access is documentation, not defence. 11-16 declined to add such a precondition for exactly this reason. The difference here is that these two sites cannot have the subscript removed at all, so the choice is between an annotated exception and no annotation.

# Verification

- **Draft rule via standalone binary**, corrected scratch config, `--no-cache`, over `AppPackage/Sources AppPackage/Tests App ShareExtension` — **68 before, 0 after**. Re-run after each of the three commits.
- **Live project config `--strict`**, same four path roots, JSON reporter — **0 violations**, exit 0, with the rule active. Confirms `lifecycle_modifiers`, `binding_initializer`, `swiftlint_disable_requires_reason` and `superfluous_disable_command` all still pass alongside it.
- **Negative control** against the live config — 3 violations on 3 real accesses, 0 on the doc comment and the line comment. Probe deleted before the commit.
- **Exception-form probe** (Obligation 3) — clean with the directive, fires without it. Probe deleted.
- **Path-exclusion probe** — `FooTests.swift` excluded, identical `FooHelper.swift` flagged.
- **`doccomment` spelling probe** — `doc_comment` produces `Invalid configuration … Falling back to default`; `doccomment` and `docComment` both work.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings. Run after each task and again after the flip.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED**. Test targets carry the plugin, so this is the gate the app-scheme build does not give (commit `e8589355`'s lesson).
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (60–74s), run after each of the three commits. 3 `withKnownIssue` markers (`SettingReducerTests`, `SettingPresentationTests`, `AppModelsTests.privateFilterValueReportsIssueAndReturnsZero`), all pre-existing and unchanged. `DownloadSchedulingTests` green on every run.
- `bash Scripts/check-cookie-logging.sh` — **exit 0**. No logging added or changed.
- `git status --short` immediately before the flip commit — exactly three files.
- **Zero test files modified** across all three commits.
- `LINT-01` left open — it flips at 11-29.

# Deviations from Plan

**1. [Rule 1 — Bug] The doc-comment fix was spelled `doccomment`, not the specified `doc_comment`**

- **Found during:** Initial enumeration
- **Issue:** The plan brief, and waves 15 and 16 before it, specified `doc_comment`. That is not a valid SwiftLint syntax kind, and it silently discards the entire rule configuration.
- **Fix:** `doccomment`, verified against a purpose-built probe before use. A comment in `.swiftlint.yml` now warns about the silent-fallback behaviour.
- **Commit:** `3bf28440`

**2. [Rule 3 — Blocking] Test scheme substitution (same as 11-01/11-02/11-14/11-15/11-16)**

- **Issue:** The plan's `-scheme HomeFeature` does not exist.
- **Fix:** Full `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air'` from `AppPackage/`, run after every commit rather than per-module. `HomeFeatureTests` is inside it.
- **Commit:** n/a (invocation only)

**3. [Rule 2 — Missing critical functionality] AnimatedImageFeature was fixed structurally rather than annotated**

- **Found during:** Task 1
- **Issue:** The plan's action text anticipates precondition-checked exceptions with cited invariants for buffer indexing. Applying that to 14 reads into untrusted image data would have added 14 directives while leaving 14 separate guard/read pairs to keep in sync.
- **Fix:** One bounds-checked accessor, two `UInt32(_:endian)` initializers, one `elementsEqual`. Shorter than the annotations, and it removed the defect class. Also added the missing `offset >= 0` term to both chunk-size guards.
- **Commit:** `07cd022b`

**4. [Rule 2 — Missing critical functionality] `EhSettingView+Sections3`'s row arithmetic was replaced, not guarded**

- **Found during:** Task 2
- **Issue:** Three matches sat on `index * 3 + num` arithmetic whose safety depended on an unstated and unchecked 17 × 3 − 1 = 50 relationship between two separate arrays.
- **Fix:** A slice-consuming `rows` property. Same output today, no unchecked cross-array assumption.
- **Commit:** `7261ea99`

**5. [Scope] `FavoritesReducer.State.index` is a public property and was renamed**

- **Found during:** Task 2
- **Issue:** Prior waves confined renames to local bindings. Here the policed name was a stored property read by five computed properties in the same type, so no local-scope rename could reach it.
- **Fix:** Renamed to `favoritesIndex`, matching `setFavoritesIndex` and `favIndex:`. Verified no cross-module or test reader before changing it; the blast radius was 20 sites inside `FavoritesFeature`.
- **Commit:** `7261ea99`

**6. [Rule 3 — Blocking] `GalleryRoute` is a struct because a 3-member tuple trips `large_tuple`**

- **Found during:** Task 2
- **Issue:** The natural shape `(kind:gid:token:)` violates the `large_tuple` rule at warning level, and this repo builds at zero warnings.
- **Fix:** A private struct with a doc comment on the optional `token`. Better than the tuple regardless.
- **Commit:** `7261ea99`

**7. [Scope] Wave 15's degraded comment was not restored**

- **Found during:** Obligation 2 re-scan
- **Issue:** The obligation asks whether the `Request+Detail.swift` comment can now be restored to its clearer wording.
- **Fix:** None needed. Its current wording describes the `dropFirst(2)` the code performs; restoring subscript phrasing would describe a subscript that no longer exists there. Reasoned through above rather than skipped.
- **Commit:** n/a

# Flagged for owner review

**1. `AnimatedImageFeature` has no test target, and this plan rewrote its byte parser.** The GIF/WebP animation-detection walkers were restructured with no automated coverage anywhere in the repo — no `AnimatedImageFeatureTests` target exists. Correctness was established by argument (byte-for-byte equivalence of the endian conversions on a little-endian host; identical loop bounds; `elementsEqual` over the same range) and by the full suite staying green, but nothing *tests* that an animated GIF is still detected as animated. This module is the strongest candidate in the repo for the D-15 test work in 11-23/11-24. **UAT in the meantime:** open a gallery containing an animated GIF and one containing an animated WebP, and confirm both still animate rather than showing a first frame; open a static JPEG/PNG gallery and confirm nothing regressed there.

**2. Treat "prove the rule fires" as a standing requirement, not a nicety.** This phase has now produced two config constructs that are inert in a way that reads as success — the `validatedIndex` path regex, and the `doc_comment` kind that discards the whole rule. Both would pass a zero-violation check. 11-11 introduced the negative-control probe as good practice; on this evidence it should be mandatory for every custom-rule flip, and it would be cheap to make permanent — a `Scripts/` probe fixture with known-violating lines and an expected-count assertion, run alongside `check-cookie-logging.sh`. Not built here: it is infrastructure, not this plan's mandate.

**3. The gallery-URL path-component shape now has four independent implementations.** `Parser.GalleryTitleInfo` (11-14), `URL.galleryIdentifiers` in NetworkingFeature (11-15), `GalleryRoute` in URLClient and the inline walk in `AppError+Context` (both this plan). All four decode `/<kind>/<gid>/<token>`. They differ in genuinely meaningful ways — whether the `kind` is validated, whether a token is required, what happens on a mismatch — so consolidating is not mechanical, and forcing them together would have meant changing at least two of them behaviourally. But four copies of one URL grammar will drift. Worth a small follow-up that puts the grammar in one place with the strictness as a parameter.

**4. `String.stringsBesideColon` is public and changed shape.** `strings[0]`/`strings[1]` → `first`/`last`. Same accept/reject set behind the retained `count == 2` guard, and the full suite covers its callers, but it is the widest-reach signature-adjacent edit in the plan and worth a glance.

**5. Both exception preconditions are unfirable.** Site 1's index comes from `firstIndex`; site 2's is checked on the line above. Neither can ever trap, so both preconditions are documentation. That is the correct reading of a rule that asks for *guarded* access, but if the owner would rather the exception form mean "a check that can actually fail", the two sites should be re-argued at 11-29 — they would then have no principled annotation available, since neither subscript can be removed.

**6. The rule is now permanent.** Any future `foo[0]`, `foo[index]`, or `foo[index + 1]` fails the build, in Sources and in test targets that are not `*Tests.swift`. That is the intent, but it also means that a Dictionary access keyed by something honestly named `index` will be flagged despite being incapable of trapping — five waves resolved that by renaming to the domain term (`page`, `catIndex`, `favoritesIndex`), which has been an improvement every time, but it is a cost the next contributor will pay without context. The `message:` text ("Subscript index access should be guarded by an index check") does not hint that a rename is often the right answer.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface. T-11-20's mitigation is satisfied and, unlike some earlier waves, partly on genuinely reachable surface: `AnimatedImage+.swift` walks untrusted image bytes with cursors derived from the data's own length fields, and both `UInt32` readers accepted a negative offset before this plan. `URLClient` and `AppError+Context` indexed URLs that arrive from deep links and scraped markup. All now route to a nil/false/empty result instead of trapping. The `PreviewIdentifiers` trap is deliberate and preview-only.

## Self-Check: PASSED

- `.swiftlint.yml` — FOUND, `unchecked_subscript_index_access` uncommented at `severity: error` with `doccomment` excluded and no `validatedIndex` entry
- `AppPackage/Sources/AnimatedImageFeature/AnimatedImage+.swift` — FOUND
- `AppPackage/Sources/URLClient/URLClient.swift` — FOUND
- `AppPackage/Sources/AppModels/Support/RunLogFile.swift` — FOUND
- `AppPackage/Sources/AppModels/Support/AppError+Context.swift` — FOUND
- `AppPackage/Sources/AppModels/Persistent/GalleryHistory+Operations.swift` — FOUND, directive present
- `AppPackage/Sources/PreviewSupport/PreviewIdentifiers.swift` — FOUND, directive present
- `AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-17-SUMMARY.md` — FOUND
- Commit `07cd022b` — FOUND
- Commit `7261ea99` — FOUND
- Commit `3bf28440` — FOUND
