---
phase: 11-infra-refactor-lint-capstone
plan: 18
subsystem: lint-config
tags: [lint, swiftlint, tuple, rule-flip, config, regex, tag-translation]
requires:
  - "11-11's atomic-flip procedure (fixes + rule in one lint-clean sequence)"
  - "11-17's finding that an invalid excluded_match_kinds entry silently discards a whole rule"
  - "11-17's standing requirement that a custom-rule flip must prove the rule fires"
provides:
  - "`labeled_tuple_elements` live at error — unlabeled multi-element tuple TYPES are build-gated repo-wide"
  - "`TagTranslationLookup` — the `(String, TagTranslation?)` pair, declared 13 times, replaced by one named struct"
  - "A regex shape that rejects function-type parameter lists, where Swift forbids labels outright"
affects:
  - "Every future build: enforced by the SwiftLint build-tool plugin on source AND test targets"
  - "`TagTranslator.lookup(word:returnOriginal:)` return type changed (public, 11 call sites)"
  - "`Parser.parseGalleryDetail`/`parseArcAndTor`/`parseMPVKeys`/`parseCurrentFunds` return labels (public)"
  - "Four `Request.response()` return types gained labels (public)"
tech-stack:
  added: []
  patterns:
    - "Anchoring a tuple-type regex on `->` / `:` / `<` and rejecting the group when `->`/`throws`/`async` follows"
    - "`[ \\t]` rather than `\\s` in a custom-rule regex, since the regex runs over the whole file and `\\s` crosses newlines"
    - "Placing the negative lookahead BEFORE the optional whitespace it guards, so backtracking cannot skip it"
key-files:
  created: []
  modified:
    - .swiftlint.yml
    - AppPackage/Sources/AppModels/Tags/TagTranslation.swift
    - AppPackage/Sources/TagTranslationFeature/TagTranslator+Lookup.swift
    - AppPackage/Sources/GalleryListComponents/GalleryList.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
    - AppPackage/Sources/ParserFeature/Parser+Detail.swift
    - AppPackage/Sources/ParserFeature/Parser+Image.swift
    - AppPackage/Sources/ParserFeature/Parser+User.swift
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/NetworkingFeature/Request+Gallery.swift
    - AppPackage/Sources/NetworkingFeature/Request+Image.swift
    - AppPackage/Sources/DownloadClient/DownloadClient.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/AppComponents/ViewModifiers.swift
    - AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift
    - AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestFactories.swift
    - AppPackage/Tests/NetworkingFeatureTests/GalleryRequestBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/DetailRequestBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/ImageRequestBaselineTests.swift
decisions:
  - "The draft regex's `[^(){}\\[\\]]*` element class was the wrong tuning knob: it excluded brackets, so it missed every tuple containing a `[Int: URL]` or `[Gallery]` element — 11 genuine sites, including a `([Int: URL], [Int: URL])` that no one had labeled. Widening to `[^(),\\n]` and rejecting function-parameter lists via a trailing lookahead is strictly better: it catches more real sites AND drops all 11 draft false positives."
  - "The 11 draft false positives were two distinct classes, both fixed in the regex rather than the code. Four were tuple ASSIGNMENT statements paired with a `case N:` on the previous line, because `\\s` crosses newlines in a whole-file regex; seven were function-type parameter lists like `(String, Int) -> Void`, where Swift forbids argument labels — flagging those would have demanded an impossible fix."
  - "`(String, TagTranslation?)` became a named struct `TagTranslationLookup`, not a labeled typealias. A labeled typealias would satisfy the rule while leaving `.0`/`.1` legal, and the codebase had three such positional reads. The struct removes them."
  - "`(Data, URLResponse)` is URLSession's own return type, but the two flagged sites are DownloadClient's own wrappers around it, so labeling their signatures is legal and the implicit tuple conversion at the `return` handles the rest. Foundation's signature is untouched."
  - "`parseMPVKeys` was labeled `key:`, not the more descriptive `mpvKey:`, because `ReadingReducer.Action` and `DownloadClient.PageSource.mpv` already declare `key:`. Labeled-to-labeled tuple conversion with differing labels does not compile — the label had to match, not merely read well."
  - "The anchor set includes `<`, so `Result<(A, B), E>` is policed. Two such sites existed in `DetailSearchReducer` while ten sibling declarations were already labeled."
metrics:
  duration: ~50 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 18: Labeled Tuple Elements Summary

`labeled_tuple_elements` is live at error with zero violations and zero false positives across `AppPackage/Sources`, `AppPackage/Tests`, `App` and `ShareExtension`. Two commits: the tuple refactor, then the rule.

**The headline finding is that the draft regex was mis-tuned in both directions at once** — it reported 11 false positives while missing 11 genuine sites. Details below.

## The count: 64 draft matches, 53 of them real, 11 more found only after tuning

The standalone binary against a scratch config carrying the RESEARCH Pattern 6 regex reported **64** at HEAD. The plan predicted "~35 sites". The gap is entirely Tests: the plan's inventory listed five Sources modules, but the same shapes recur across `DownloadsFeatureTests`, `ImageClientTests` and `NetworkingFeatureTests`, which the plan's acceptance criteria do put in scope ("0 unlabeled multi-element tuple types in Sources **and Tests**").

Of the 64: **53 were genuine**, **11 were false positives**. Tuning the regex then surfaced **11 further genuine sites the draft could not see**. Final real total: **64 sites in 31 files**.

| Cluster | Sites | Shape |
|---|---:|---|
| `translateAction` closure type | 13 | `((String) -> (String, TagTranslation?))?` |
| stub-handler type (2 test targets) | 10 | `(URLRequest) throws -> (HTTPURLResponse, Data)` |
| Downloads test factory returns | 8 | `(DownloadStore, URL)`, `(DownloadedGallery, URL)`, … |
| `NetworkingFeature` request returns | 7 | `(PageNumber, [Gallery])`, `([Int: URL], [Int: URL])`, … |
| `NetworkingFeature` baseline-test closures | 9 | the same types restated in `capture { … }` signatures |
| `ParserFeature` returns | 4 | `(GalleryDetail, GalleryState)`, `(URL?, Int)`, … |
| `DownloadClient` | 4 | `(Data, URLResponse)` ×2, `(DownloadedGallery, DownloadManifest)` ×2 |
| generic-nested (`Result<…>`, `UncheckedBox<…>`) | 5 | found only after adding `<` to the anchor |
| observer stream pairs | 2 | `(AsyncStream<…>, AsyncStream<…>.Continuation)` |
| singletons | 2 | `(URL?, ImageModifier)`, `([WrappedKeyword], [WrappedKeyword])` |

# The regex: mis-tuned in both directions

## Direction 1 — 11 false positives, in two classes

**Four were tuple assignments, not types.** `Color.init(hex:)` in `AppTools/Extensions.swift`:

```swift
case 3:
    (alpha, red, green, blue) = (255, (int >> 8) * 17, …)
```

The draft anchors on `:` then `\s*\(`. A custom-rule regex runs over the **whole file contents**, and `\s` crosses newlines, so the `:` of `case 3:` paired with the `(` opening the next line's destructuring. D-10 explicitly does not police construction literals, and this is not even a literal — it is an assignment target. Fixed by using `[ \t]` throughout instead of `\s`, which confines every match to one line.

**Seven were function-type parameter lists**, e.g.

```swift
let voteTagAction: (String, Int) -> Void
let performEhProfileAction: (EhProfileAction?, String?, Int) -> Void
public func removeDuplicates(by predicate: (Element, Element) -> Bool) -> Self
```

These are not tuples, and **Swift forbids argument labels in function types outright** — `(count: Int) -> Void` is a compile error. A rule that flags them demands a fix that cannot be written. Fixed by extending the match through the closing `)` and adding a trailing negative lookahead for `->`, `async`, `throws` and `rethrows`.

That trailing lookahead is why the regex must span the whole paren group, and spanning the group is what exposed the second defect:

## The backtracking trap

The first attempt placed the "is this element labeled?" negative lookahead *after* the optional leading whitespace:

```
[ \t]*(?![_a-zA-Z][a-zA-Z0-9_]*[ \t]*:)[^(),\n]+
```

`[ \t]*` is backtrackable. On `(response: HTTPURLResponse, data: Data)` the engine tries `[ \t]*` = one space, the lookahead correctly fails on `data:` — and then **backtracks to zero spaces**, at which point the lookahead is evaluated against ` data: Data`, sees a leading space instead of an identifier, and *passes*. A fully-labeled tuple was reported as unlabeled. Fifteen already-fixed sites re-appeared as violations.

The fix is to put the whitespace inside the lookahead and anchor it at a fixed position:

```
(?![ \t]*[_a-zA-Z][a-zA-Z0-9_]*[ \t]*:)[ \t]*[^(),\n]+
```

Worth recording because the symptom — a rule that fires on code it should accept — is the *loud* failure mode, and it was still only diagnosable by reading the regex, not the output.

## Direction 2 — 11 genuine sites the draft could never see

The draft's element class was `[^(){}\[\]]*`, excluding square brackets. RESEARCH called this a feature ("generic argument lists containing `:` — dictionaries have `[`/`]`, excluded by the char class"). In practice it means **any tuple with an array or dictionary element is invisible to the rule**:

```swift
public func response() async throws(AppError) -> ([Int: URL], [Int: URL])
public func response() async throws(AppError) -> ([Int: URL], HTTPURLResponse?)
var doubleKeywords: ([WrappedKeyword], [WrappedKeyword])
func makeObserverStream() -> (AsyncStream<[DownloadedGallery]>, AsyncStream<[DownloadedGallery]>.Continuation)
```

`([Int: URL], [Int: URL])` is the worst positional pair in the repo — two same-typed dictionaries whose only distinction is order, and swapping them would compile silently. The draft rule would have shipped and left it in place. Widening the class to `[^(),\n]` catches all of these; the exclusions the bracket class was doing by accident are now done deliberately by the trailing lookahead.

Adding `<` to the anchor set found five more inside generic arguments — `Result<(PageNumber, [Gallery]), AppError>` in `DetailSearchReducer` (while ten sibling `Result<(pageNumber:…)>` declarations were already labeled), and three `UncheckedBox<(String, String)?>` test boxes read as `.0`/`.1`.

## Final shape

```
(?:->|:|<)[ \t]*\(
  (?:  (?:[ \t]*LABEL[ \t]*:[^(),\n]*,)+  UNLABELED  (?:,ANY)*
    |  UNLABELED  (?:,ANY)+  )
\)(?![ \t]*(?:->|async\b|throws\b|rethrows\b))
```

The two-branch alternation exists so the rule fires on an unlabeled element in **any** position, not just the first, while still requiring at least two elements. `(count: Int, String)` is a violation; `(Int)` is not.

# Negative control

Mandatory per 11-17, and the only thing that separates "clean codebase" from "silently discarded config". Probe linted against the **live** `.swiftlint.yml`:

| Line | Content | Expected | Actual |
|---|---|---|---|
| 1 | `/// doc comment mentioning -> (Int, Int)` | not flagged | not flagged |
| 2 | `// line comment mentioning -> (Int, Int)` | not flagged | not flagged |
| 3 | string literal containing `-> (Int, Int)` | not flagged | not flagged |
| 4 | `-> (Int, String)` | **flagged** | **flagged** |
| 5 | `-> (count: Int, name: String)` | not flagged | not flagged |
| 6 | `-> (count: Int, String)` (partial) | **flagged** | **flagged** |
| 7 | `transform: (Int, String) -> Bool` | not flagged | not flagged |
| 8 | `Result<(Int, String), any Error>` | **flagged** | **flagged** |
| 9 | `-> (Int)` | not flagged | not flagged |

Exactly three violations, on exactly the three genuine unlabeled tuple types. This simultaneously proves the rule is registered (not discarded), that all three excluded match kinds work, that partial labeling is caught, and that the function-type and single-element exclusions hold. Probe deleted before the commit; `git status` immediately before showed only `.swiftlint.yml`.

`excluded_match_kinds` uses `comment`, `doccomment`, `string` — the spelling verified in 11-17 and re-verified here by stderr carrying **no** `Invalid configuration … Falling back to default` line.

# The refactor

## `TagTranslationLookup` — one struct for thirteen declarations

`(String, TagTranslation?)` was declared 13 times: once as `TagTranslator.lookup`'s return, and twelve times as a `translateAction` closure type across `GalleryList` (3 list styles × 2), `GalleryDetailCell` (×4), `GalleryThumbnailCell` (×2) and `DetailView+Subviews` (×2). Three sites read it positionally as `.1`.

A **struct**, not a labeled typealias:

```swift
/// The outcome of translating one tag word.
public struct TagTranslationLookup: Equatable, Hashable, Sendable {
    /// The text to display: the translated value when one was found, otherwise the original word.
    public let text: String
    /// The matched translation, absent when the word has none or translation is switched off.
    public let translation: TagTranslation?
}
```

A typealias would have satisfied the rule and left `.1` legal. The struct turns all three positional reads into `.translation`. It lives in `AppModels` beside `TagTranslation`, because `GalleryListComponents` and `DetailFeature` import `AppModels` but not `TagTranslationFeature`. The closure type is now `((String) -> TagTranslationLookup)?` — no tuple at all — and the eleven `store.tagTranslator.lookup(…)` call sites are unchanged, since they pass the result straight through.

## `parseMPVKeys` — the label had to match, not merely read well

`(String, [Int: String])` naturally labels as `(mpvKey:, imageKeys:)`. That produced a compile failure surfacing as `error: failed to produce diagnostic for expression` on `ReadingReducer+ImageFetch`'s 300-line `Reduce { }` body — the compiler could not localize a real type error inside the result builder.

The cause: `ReadingReducer.Action.fetchMPVKeysDone` already declares `Result<(key: String, imageKeys: [Int: String]), AppError>`, and `DownloadClient.PageSource.mpv` already declares `case mpv(key:imageKeys:)`. An **unlabeled** tuple converts implicitly to any labeled tuple type, which is why the mismatch never existed before; two **differently-labeled** tuples do not convert. So labeling the producer forced it to agree with a label chosen years earlier. `key:` it is.

This is worth recording as a general consequence: adding labels to a widely-consumed positional return is not a no-op refactor — it *creates* a constraint that the unlabeled version silently absorbed. It is also the argument for the rule, since that silent absorption is what lets a `(A, B)` and a `(B, A)` line up by accident.

## Everything else

- **`(Data, URLResponse)`** — the two flagged sites are `DownloadClient`'s own `dataResponse`/`rawDataResponse` wrappers, so `-> (data: Data, response: URLResponse)` is legal and `return try await urlSession.data(for:)` converts implicitly. Foundation's own signature is untouched, as the brief required.
- **`(DownloadedGallery, DownloadManifest)`** — four consumers (`DetailReducer`, `PreviewsReducer`, `DownloadsReducer`, and `DownloadClient+PublicAPI`'s `Result`) already wrote `(download:, manifest:)`. The producer now matches them rather than relying on conversion.
- **`arcAndTor.0` / `.1`** in `Parser+Detail` became `.archiveURL` / `.torrentCount`; **`parseGalleryDetail(…).0.archiveURL`** in `Request+Detail` became `.detail.archiveURL`.
- **`([Int: URL], [Int: URL])`** became `(imageURLs:, originalImageURLs:)`, matching `ReadingReducer.Action`'s existing labels.
- **Test stub handlers** kept an inline `(response: HTTPURLResponse, data: Data)` in both test targets rather than gaining a shared type: the two targets have no shared support module, and inventing one for a two-element pair is more machinery than the duplication costs.

No named struct was needed beyond `TagTranslationLookup`. No tuple in the sweep reached three elements, so `large_tuple` never fired and D-11's mandatory-struct clause never triggered.

# Verification

- **Draft rule, standalone binary, `--no-cache`**, over `AppPackage/Sources AppPackage/Tests App ShareExtension` — **64 before**.
- **Tuned rule, same roots** — **0 after**, and 0 for every intermediate tuning round once the site list was closed.
- **Live project config, `--strict --reporter json`**, same four roots — **0 violations, exit 0**. All previously-flipped rules (`lifecycle_modifiers`, `binding_initializer`, `unchecked_subscript_index_access`, `swiftlint_disable_requires_reason`, `superfluous_disable_command`) pass alongside it.
- **stderr inspected for `Invalid configuration` / `Falling back to default`** — none. The 11-17 silent-discard trap is absent.
- **Negative control** — 3 violations on 3 genuine sites, 0 on prose/string/function-type/single-element. Probe deleted before commit.
- **Five previously-cleaned modules** (`GalleryListComponents`, `DetailFeature`, `ParserFeature`, `NetworkingFeature`, `DownloadClient`) — all inside the zero-violation roots, re-verified under the live config after the flip.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings, run after the flip with the plugin active.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED**, run after Task 1 and again after the flip. Test targets carry the plugin; this is the gate the app-scheme build does not give.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (61–86 s), run after each commit. 1 `withKnownIssue` marker, pre-existing and unchanged. `DownloadSchedulingTests` green.
- `bash Scripts/check-cookie-logging.sh` — **exit 0**. No logging added or changed.
- No `try?` introduced; `optional_try` remains satisfiable.
- `LINT-01` left open — it flips at 11-29.

# Deviations from Plan

**1. [Rule 1 — Bug] The draft regex missed 11 genuine sites and flagged 11 non-sites**

- **Found during:** Task 2
- **Issue:** Detailed above. The bracket-excluding element class hid every tuple containing `[Int: URL]`-style elements, including a same-typed `([Int: URL], [Int: URL])` pair; `\s` crossed newlines onto `case N:` labels; function-type parameter lists were flagged despite Swift forbidding labels there.
- **Fix:** Widened the element class, restricted matching to one line, extended the match through the closing paren with a trailing `->`/`throws`/`async`/`rethrows` rejection, and added `<` to the anchor set.
- **Commit:** `d50966f8`

**2. [Rule 1 — Bug] A backtracking hole let a labeled tuple be reported as unlabeled**

- **Found during:** Task 2
- **Issue:** `[ \t]*` preceding the "is it labeled?" negative lookahead is backtrackable, so the engine could re-evaluate the lookahead one character early and pass it. Fifteen already-fixed sites reappeared as violations.
- **Fix:** Whitespace moved inside the lookahead so it is evaluated at a fixed position.
- **Commit:** `d50966f8`

**3. [Rule 3 — Blocking] Labeling `parseMPVKeys` broke `ReadingFeature`'s compile**

- **Found during:** Task 1
- **Issue:** The natural label `mpvKey:` disagrees with `ReadingReducer.Action.fetchMPVKeysDone`'s pre-existing `key:`. Differently-labeled tuples do not convert. The compiler reported `failed to produce diagnostic for expression` on the whole `Reduce { }` body rather than naming the mismatch.
- **Fix:** Used `key:` to match the two existing declarations.
- **Commit:** `1672003f`

**4. [Scope] Tests were 31 of the 64 sites; the plan's file list named only five Sources modules**

- **Found during:** Task 1
- **Issue:** The plan's `files_modified` lists five `Sources/` directories, but its own acceptance criteria say "Sources **and** Tests". The binary found the same tuple shapes across three test targets.
- **Fix:** Fixed them. `.swiftlint.yml` carries no `*Tests.swift` path exclusion for this rule, unlike `unchecked_subscript_index_access`.
- **Commit:** `1672003f`

**5. [Scope] `(String, TagTranslation?)` became a struct, changing a public signature and three read sites**

- **Found during:** Task 1
- **Issue:** The plan sanctioned "a named struct or a labeled typealias". A typealias is the smaller diff but leaves `.0`/`.1` legal, and three sites used `.1`.
- **Fix:** `TagTranslationLookup` in `AppModels`. `TagTranslator.lookup` is public; all 11 call sites pass the result through unchanged.
- **Commit:** `1672003f`

# Flagged for owner review

**1. `DownloadClient.dataResponse(for:retriesRequest:)` appears to have no callers.** It is `public`, it wraps `rawDataResponse` in the retry helper, and a repo-wide grep for `dataResponse(` finds only its own definition and `gdataResponse` (an unrelated name). If it is genuinely dead, it and its retry path are ~15 lines to delete. Not removed here — out of this plan's scope, and a public API deletion deserves a deliberate decision. Logged rather than acted on.

**2. `parseMPVKeys`'s label is `key`, not `mpvKey`, and that is a compromise.** `(key: String, imageKeys: [Int: String])` is asymmetric — one element names the thing, the other names a collection of the thing. `key:` was chosen because `ReadingReducer.Action` and `DownloadClient.PageSource.mpv` already use it, and disagreeing labels do not compile. If you would rather all three read `mpvKey:`, it is a three-file rename with no behavioural risk; it just could not be done unilaterally from the producer side.

**3. The rule does not police every tuple type, and the gaps are deliberate.** It misses a tuple whose element contains a top-level comma inside generics (`(Result<A, B>, Int)`), a tuple nested one paren deep (`((A, B))`), and a tuple in a position not preceded by `->`, `:` or `<`. Each could be closed only by making an already dense regex denser, and none occurs in the tree today. A structural (SwiftSyntax) rule would cover all of them properly; that is a different kind of investment than this phase is making.

**4. Labeling a public return type creates a constraint the unlabeled version absorbed.** The `parseMPVKeys` failure is the general case: any consumer that previously wrote its own labels was relying on implicit conversion from the producer's unlabeled tuple. Now they must agree. That is the point of the rule — the same conversion is what lets `(A, B)` and `(B, A)` line up by accident when the types match — but it means future edits to these signatures are less free than they were.

**5. The rule is now permanent.** Any future `-> (A, B)`, `let x: (A, B)` or `Result<(A, B), E>` fails the build in Sources and in Tests. The message names the two sanctioned fixes (label, or small named struct), which is more actionable than `unchecked_subscript_index_access`'s message, but the "use a struct" branch is the right answer more often than the message implies — especially for same-typed pairs like the `([Int: URL], [Int: URL])` this plan found.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface. T-11-21's mitigation is satisfied: the rule was tuned to zero on the clean tree and its detection was proven by a nine-case probe before the flip, so it cannot break a build on valid code. The changes themselves are type-level only — no control flow, no parsing behaviour, no I/O was altered.

## Self-Check: PASSED

- `.swiftlint.yml` — FOUND, `labeled_tuple_elements` present at `severity: error` with `comment`/`doccomment`/`string` excluded
- `AppPackage/Sources/AppModels/Tags/TagTranslation.swift` — FOUND, `TagTranslationLookup` present
- `AppPackage/Sources/TagTranslationFeature/TagTranslator+Lookup.swift` — FOUND, returns `TagTranslationLookup`
- `AppPackage/Sources/ParserFeature/Parser+Detail.swift` — FOUND
- `AppPackage/Sources/NetworkingFeature/Request+Image.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient.swift` — FOUND
- `AppPackage/Sources/AppTools/ZZProbe.swift` — ABSENT (probe deleted, as required)
- `.planning/phases/11-infra-refactor-lint-capstone/11-18-SUMMARY.md` — FOUND
- Commit `1672003f` — FOUND
- Commit `d50966f8` — FOUND
