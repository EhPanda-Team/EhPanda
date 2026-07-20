---
phase: 11-infra-refactor-lint-capstone
plan: 13
subsystem: reader
tags: [lint, swiftlint, reader, naming, subscript, tca]
requires:
  - "11-09's finding that a disable directive cannot precede its rule"
  - "11-12's finding that the draft rule's `excluded: \"\\\\[validatedIndex\\\\]\"` entry is inert"
provides:
  - "ReadingFeature contributes zero matches to the draft `unchecked_subscript_index_access` rule"
  - "Confirmation that the `validatedIndex` escape hatch is unnecessary — no site needed it"
  - "Zero precondition-checked exception sites in this module, so 11-17 has no directive to insert here"
affects:
  - "No other module — every rename is local to a scope inside ReadingFeature; no public API, action label or test changed"
tech-stack:
  added: []
  patterns:
    - "`page` as the honest name for a 1-based reader page key into a `[Int: …]` store"
    - "`ForEach(collection.enumerated(), id: \\.offset)` as the id-preserving replacement for `ForEach(collection.indices, id: \\.self)` + subscript"
key-files:
  created: []
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
    - AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift
decisions:
  - "60 of 61 matches were `[Int: …]` Dictionary subscripts — Optional-returning and incapable of trapping. The violation was purely nominal, so the honest rename `index` → `page` is the fix, not a dodge: every one of these keys is a 1-based reader page number (confirmed against `PreviewConfig.batchRange`, whose lower bound is 1, and against `containerDataSource`, which builds `Array(1...pageCount)`)."
  - "Renames were confined to local binding scopes — `case .foo(let page)` patterns, closure parameters, and private helper parameters. The `Action` enum's `index:` argument labels, the `ImageContainer(index:)` view label and `PreviewConfig.pageNumber(index:)` were all left alone: changing them would ripple into tests and other modules for no lint gain. Zero test files were touched."
  - "The one genuine Array site (`dataSource[position]` in the horizontal pager) was resolved by removing the subscript, not by renaming `position`. `ForEach(dataSource.enumerated(), id: \\.offset)` yields byte-identical scroll ids, so the Phase 5 sliding-window contract is preserved."
  - "No precondition-checked exception was needed anywhere in the module, so unlike 11-12 this plan leaves 11-17 nothing to insert."
metrics:
  duration: ~30 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 13: ReadingFeature Subscript-Rule Cleanup Summary

ReadingFeature's 61 `unchecked_subscript_index_access` matches are gone. 60 were Dictionary reads that could never trap and were renamed to the domain-honest `page`; the single genuine Array read was restructured so the subscript no longer exists. No test was modified, no `.swiftlint.yml` line was touched, and no exception site was created.

## The count was right

Plan said 61. The standalone binary, run against a scratch config that enables only the draft rule, reported **exactly 61** at HEAD before any edit. This is the first wave in the phase where the plan's number matched the tree.

| File | Matches | Kind |
|---|---|---|
| `ReadingReducer+ImageFetch.swift` | 40 | Dictionary |
| `ReadingReducer+Body.swift` | 7 | Dictionary |
| `ReadingViewComponents.swift` | 6 | Dictionary |
| `Support/LiveTextHandler.swift` | 3 | Dictionary |
| `ReadingView.swift` | 3 | 2 Dictionary, **1 Array** |
| `Support/ControlPanel.swift` | 2 | Dictionary |

`PageHandler.swift` — named in the plan as the Array-indexing risk — contains **no subscript at all**. It is 38 lines of pure page arithmetic (`mapFromPager` / `mapToPager`) with no collection access. Its suite is a gate for this work only in the sense that it must stay green, which it did, untouched.

## Why renaming was the fix, not a dodge

Every one of the 60 renamed sites reads a `[Int: …]` Dictionary declared on `ReadingReducer.State` or a handler: `imageURLs`, `originalImageURLs`, `thumbnailURLs`, `previewURLs`, `localPageURLs`, `imageURLLoadingStates`, `previewLoadingStates`, `mpvImageKeys`, `mpvSkipServerIdentifiers`, `liveTextGroups`, `analysisTasks`. A Dictionary subscript returns `Optional` and cannot trap on a missing key — there is no crash surface to guard. The rule flagged them because it polices *names*, and `index` is on its list.

So the question is only whether `page` is honest, and it is. These keys are 1-based reader page numbers, not 0-based offsets:

- `PreviewConfig.batchRange(index:)` returns `pageNumber(index:) * batchSize + 1 ... `, i.e. a range whose lowest possible value is **1**.
- `State.containerDataSource` builds `Array(1...gallery.pageCount)`.
- `fetchMPVKeysDone` seeds the first fetches with `Array(1...min(3, max(1, pageCount)))`.

The key space starts at 1 and runs to `pageCount`. `page` names exactly that. This is the anti-dodge condition the plan and RESEARCH set out: the rename is permitted precisely because the access is provably safe and the new name is more accurate than the old one, not less.

**What was deliberately not renamed.** The renames stop at local scope. `Action`'s `index:` argument labels (`fetchPreviewURLsDone(index:result:)` and eleven siblings), `ImageContainer(index:)`, `GalleryMPVImageURLRequest(index:)` and `PreviewConfig.pageNumber(index:)` all keep their labels — only the *values* passed to them changed name. Renaming those labels would touch test files and other modules to satisfy a rule that was already satisfied. The resulting `.fetchPreviewURLsDone(index: page, …)` call sites read slightly oddly, and that mismatch is recorded below as a cosmetic follow-up rather than smuggled into this diff.

## The one real Array site

`ReadingView.swift:203`, inside the horizontal paging ScrollView:

```swift
ForEach(dataSource.indices, id: \.self) { position in
    imageStack(index: dataSource[position])
```

`position` comes from `dataSource.indices`, so the read is safe — but it is a genuine `Array` subscript, and the anti-dodge rule forbids renaming out of it. The subscript was removed instead:

```swift
ForEach(dataSource.enumerated(), id: \.offset) { _, page in
    imageStack(index: page)
```

**Why this is parity-safe.** The file's own doc comment states the contract: the `.scrollPosition(id:)` ids are the **0-based positions in `containerDataSource`**, the same index space as `pageModel.index` and `PageHandler.mapToPager` — positions rather than element values, because dual-page mode makes the elements non-uniform. `EnumeratedSequence.Element.offset` over an `Array` is that same 0-based position, so the id set is unchanged element-for-element. `windowBase`, `scrollPositionID` write discipline, `.scrollTargetBehavior(.paging)`, `.scrollDisabled(scale != 1)` and the two `layoutDirection` environment flips are all untouched.

`enumerated()` is directly `ForEach`-able here — Swift 6.2's `Collection` conformance for `EnumeratedSequence` means no `Array(…)` wrapper and no extra allocation per body evaluation. The tools version is 6.3.1.

## No exception sites — nothing for 11-17 to insert

Unlike 11-12, this plan created **zero** precondition-checked exceptions and therefore zero pending `// swiftlint:disable:next unchecked_subscript_index_access` directives. 11-17 has no edit to make in ReadingFeature. The module's existing disables are unrelated and untouched: `line_length` in `LiveTextHandler.swift` (reference URLs) and the three D-02 `lifecycle_modifiers` exceptions 11-09 recorded, all still in place and unmodified.

## On the `validatedIndex` escape hatch

The orchestrator's finding — that `excluded:` on a SwiftLint custom rule is a **file-path** regex, so `"\\[validatedIndex\\]"` can never match and the hatch is inert — held up, and it turned out not to matter: no site in this module needed it. The plan's Task 2 text instructs producing `validatedIndex` locals "which the draft rule's excluded pattern sanctions"; that instruction is unusable as written and was not followed. See the recommendation below.

## Verification

- Draft rule via standalone binary over `AppPackage/Sources/ReadingFeature`, scratch config, `--no-cache` — **0 violations**, exit 0 (61 before).
- Full project config via standalone binary over the same tree — **0 violations**, exit 0. Confirms the live `lifecycle_modifiers` / `binding_initializer` rules and everything else still pass.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings. Run after each task.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED**, 0 failures (63s). `PageHandlerTests`, `ContainerDataSourceTests`, `GestureHandlerTests` and `ReadingReducerImageFetchTests` all pass; the two pre-existing known issues in `SettingReducerTests` / `SettingPresentationTests` are unchanged.
- `git diff --stat` for both commits: 6 source files, no test file, no `.swiftlint.yml`, no `Package.swift`.
- `LINT-01` left open — it flips at 11-29.

## Deviations from Plan

**1. [Scope] Task 2's `validatedIndex` idiom was not used**

- **Found during:** Task 2
- **Issue:** The plan directs producing `validatedIndex` locals on the premise that the draft rule's `excluded` list sanctions them. That entry is a file-path regex and is inert, as 11-12 flagged and the orchestrator re-verified.
- **Fix:** The single Array site was resolved by removing the subscript entirely (`enumerated()`), which needs no escape hatch. No behaviour change; ids preserved.
- **Commit:** `85127fa5`

**2. [Scope] No precondition-checked exception sites were created**

- **Found during:** Task 2
- **Issue:** The plan anticipated "zero or more" exception sites and told 11-17 to expect directives. The actual count is zero.
- **Fix:** None needed — recorded so 11-17 does not go looking for a site here.
- **Commit:** n/a

**3. [Scope] `PageHandler` had no subscripts to fix**

- **Found during:** Task 1
- **Issue:** The plan lists "PageHandler mapping math" among the Array-backed sites. `PageHandler.swift` contains no collection access whatsoever.
- **Fix:** None needed. Its suite was run as a parity gate and passes unmodified.
- **Commit:** n/a

## Flagged for owner review

**1. Recommendation for 11-17: fix or delete the rule's `excluded` list.** The entry `"\\[validatedIndex\\]"` is inert and actively misleading — three plans (11-13 through 11-17 by the orchestrator's account) were written around an escape hatch that does not exist. Two options: delete the entry, since no site in this module needed it and the two honest resolutions (rename a safe Optional access, restructure a real one) are sufficient; or, if a token-level escape is genuinely wanted, express it in the rule's own `regex` as a negative lookahead rather than in `excluded`. The sibling entry `".*/[^/]*Tests\\.swift$"` is correct and should stay. **11-17 owns this file; nothing was changed here.**

**2. Device UAT: reader paging.** The `ForEach` construct on the horizontal paging ScrollView changed shape, and this is inside the Phase 5 baseline-locked seeding pair that took four rounds of device UAT to settle. The ids are provably identical and the full suite is green, but the loop defect this construct originally fixed is not covered by any automated test. UAT: open a gallery previously read to page N and confirm it opens on page N in both LTR and RTL; swipe to the last page and back to the first, watching for the sliding-window rebase misbehaving; in landscape with dual-page mode on, confirm spreads pair the same pages as before, with and without "except cover". Zoom/pan/tap are untouched — no gesture code was modified.

**3. Cosmetic: `index:` labels now carry values named `page`.** Call sites read `.fetchPreviewURLsDone(index: page, result: …)`. Harmless, but the `Action` enum's twelve `index:` labels, `ImageContainer(index:)` and `PreviewConfig.pageNumber(index:)` are all really page numbers and could be relabelled for consistency. Deliberately out of scope: it touches tests and AppModels for zero lint benefit. Worth a small follow-up if the naming bothers the owner.

**4. `PreviewConfig.pageNumber(index:)` is misnamed.** It returns `max(index - 1, 0) / batchSize` — a **batch** number, not a page number, and its argument is the page. So the function's name and its label are both backwards. Pre-existing, in `AppModels`, untouched here; noted because it made verifying the key space slower than it should have been.

**5. `HorizontalImageStack.index` may be dead.** The struct stores an `index` property (line 47, assigned line 81) that nothing in the file's body reads — the two `imageContainer(page:)` calls use `config.firstIndex` / `config.secondIndex` instead. Not removed: it is outside this plan's mandate and deleting a stored property changes the initializer signature. Worth checking during a later pass.

## Self-Check: PASSED

- `AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift` — FOUND
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` — FOUND
- `AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-13-SUMMARY.md` — FOUND
- Commit `a887b038` — FOUND
- Commit `85127fa5` — FOUND
