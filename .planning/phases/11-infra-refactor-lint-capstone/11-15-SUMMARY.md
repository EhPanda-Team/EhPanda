---
phase: 11-infra-refactor-lint-capstone
plan: 15
subsystem: DownloadClient + NetworkingFeature
tags: [lint, swiftlint, download, networking, subscript, robustness]
requires:
  - "11-03/11-04 (DownloadClient at zero optional-try; probeManifest / closeReadHandle helper seams)"
  - "11-13/11-14's finding that the draft rule's `excluded: \"\\\\[validatedIndex\\\\]\"` entry is inert"
provides:
  - "DownloadClient and NetworkingFeature contribute zero matches to the draft `unchecked_subscript_index_access` rule"
  - "`URL.galleryIdentifiers` — gid/token extracted behind one guard instead of two unproven path-component indices"
  - "Zero precondition-checked exception sites, so 11-17 has no directive to insert in either module"
  - "Verified finding: the draft rule polices doc comments — `excluded_match_kinds` omits `doc_comment`"
affects:
  - "No other module — every rename is either a loop/closure binding or an internal parameter name behind an unchanged external label; no public signature and no test changed"
tech-stack:
  added: []
  patterns:
    - "`index page:` — external argument label preserved, honest internal name, for public API that cannot be relabelled"
    - "`zip(staticTable, remotelyParsedArray)` as the bounds-safe replacement for parallel-array indexing"
    - "`dropFirst(n).first` as the bounds-safe replacement for a literal path-component index"
key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift
    - AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift
    - AppPackage/Sources/NetworkingFeature/Request+Image.swift
decisions:
  - "28 of DownloadClient's 29 matches were `[Int: X]` Dictionary subscripts keyed by 1-based page number — Optional-returning and incapable of trapping. The key space is not inferred: `DownloadStore.validateDecodedManifest` rejects any manifest whose `pages.keys.sorted() != Array(1...pages.count)`, so 1-based is a hard, enforced invariant. `index` → `page` is therefore an honest rename, not an evasion."
  - "Where the value flowed from a public parameter that tests call by label (`resolvedImageSource(index:)`, `captureTarget(for:index:)`), the fix was `index page:` — external label kept, internal name honest. This clears the rule without touching any call site or test, and is more accurate than aliasing."
  - "`Request+Account.swift`'s three loops indexed a remotely-parsed EhSetting array against a static table (`categoryNames`, `languageValues`, a hardcoded `0...9`). The pairing was never checked, so a short settings parse would have trapped mid-request-assembly. `zip` / `prefix(10)` removes the assumption structurally."
  - "`Request+Detail.swift` read `pathComponents[2]`/`[3]` on a URL that `GalleryReverseRequest` accepts from its caller and, when `isGalleryImageURL` is set, scrapes out of remote markup. Unlike 11-14's analogous cluster the bound was not proven anywhere. Extracted into a guarded `URL.galleryIdentifiers`; a malformed URL now throws `.parseFailed` instead of trapping."
  - "`URL.galleryToken` in `Request.swift` was dead code — declared in a file-private extension and never referenced. Deleted rather than guarded; the laziest correct fix for a violation in unreachable code."
  - "No precondition-checked exception was needed anywhere, so like 11-13 and 11-14 this plan leaves 11-17 nothing to insert."
metrics:
  duration: ~40 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 15: DownloadClient + NetworkingFeature Subscript-Rule Cleanup Summary

All 41 `unchecked_subscript_index_access` matches across DownloadClient (29) and NetworkingFeature (12) are gone, resolved with honest renames, safe idioms, and one dead-code deletion. Zero exception sites, zero test edits, zero `.swiftlint.yml` changes. Three of the NetworkingFeature clusters were genuine trap surfaces on remotely-influenced data, not lint ceremony.

## The count was right, and so was the split

Plan said 29 + 12. The standalone binary against a scratch config enabling only the draft rule reported **exactly 29 and 12** at HEAD before any edit — the third consecutive wave where the plan's number matched the tree, and the first where the module split also matched.

| File | Matches | Kind |
|---|---|---|
| `DownloadStore+Operations.swift` | 10 | page-keyed Dictionary |
| `DownloadClient+PageDownload.swift` | 5 | page-keyed Dictionary |
| `DownloadClient+ExecutionSupport.swift` | 5 | page-keyed Dictionary |
| `DownloadStore.swift` | 3 | 2 Dictionary, **1 Array** |
| `DownloadClient+PublicAPIHelpers.swift` | 2 | page-keyed Dictionary |
| `DownloadClient+ExecutionPerform.swift` | 2 | page-keyed Dictionary |
| `DownloadClient+PublicAPI.swift` | 1 | page-keyed Dictionary |
| `DownloadClient+PersistenceHelpers.swift` | 1 | page-keyed Dictionary |
| `Request+GalleriesMetadata.swift` | 4 | 2 split-string, **2 Array** |
| `Request+Detail.swift` | 3 | **URL path components** |
| `Request+Account.swift` | 3 | **parallel arrays** |
| `Request.swift` | 1 | dead code |
| `Request+Image.swift` | 1 | page-keyed Dictionary |

## DownloadClient: one pattern, 28 times

Every DownloadClient match but one is a `[Int: String]` / `[Int: URL]` Dictionary read or write — `manifest.pages`, `existingPageRelativePaths`, `failedPages`, `thumbnailURLs`, `imageKeys`. A Dictionary subscript returns `Optional` and cannot trap, so the violation was purely nominal; the only question is whether `page` is more honest than `index`, and it is provably so.

The key space is not inferred from usage — it is **enforced at the decode boundary**. `DownloadStore.validateDecodedManifest` throws `manifestCorruptedError()` unless:

```swift
guard manifest.pages.keys.sorted() == Array(1...manifest.pages.count) else {
    throw manifestCorruptedError()
}
```

Every manifest that reaches any of these call sites therefore has keys exactly `1...pageCount`. `page` names that. Same reasoning and same resolution as 11-13's 60 renames and 11-14's page-keyed dictionaries.

**Where the value came from a public parameter**, the label was preserved and only the internal name changed:

```swift
public func resolvedImageSource(
    index page: Int,
    ...
```

`resolvedImageSource(index:)` is called by `DownloadImageParsingTests`, and `captureTarget(for:index:)` and `performCacheCapture(gid:index:)` sit on the same path. Swift's external/internal parameter names are exactly the right tool: the call sites and the three test invocations are byte-identical, while the body reads honestly. This is a cleaner answer than 11-13 had available, and it avoids that plan's residual "`.fetchPreviewURLsDone(index: page, …)`" awkwardness.

**The one genuine Array site** is `DownloadStore.parentFolderName`, splitting a relative path and reading `components[0]` behind `components.count >= 2`. Became `components.first` with the count guard retained — same accept/reject set, no subscript.

## NetworkingFeature: three real trap surfaces

**1. `Request+Account.swift` indexed remotely-parsed arrays against static tables.** Three loops in `EhSettingRequest`'s form assembly:

```swift
EhSetting.categoryNames.enumerated().forEach { index, name in
    params["ct_\(name)"] = ehSetting.disabledCategories[index] ? "1" : "0"
}
Array(0...9).forEach { index in
    params["favorite_\(index)"] = ehSetting.favoriteCategories[index]
}
ehSetting.excludedLanguages.enumerated().forEach { index, value in
    if value { params["xl_\(EhSetting.languageValues[index])"] = "on" }
}
```

`categoryNames` and `languageValues` are static tables; `disabledCategories`, `favoriteCategories` and `excludedLanguages` come off the parsed remote settings page. `EhSetting.empty` builds them at 10/10/50, but nothing enforces those counts on a *parsed* setting — the pairing was an unchecked assumption spanning two different objects, and the third loop's `0...9` is a bare literal range against an array whose length is never checked. A settings page that yielded fewer entries would have trapped in the middle of assembling an outbound request.

Now `zip` and `prefix(10)`:

```swift
for (name, isDisabled) in zip(EhSetting.categoryNames, ehSetting.disabledCategories) {
    params["ct_\(name)"] = isDisabled ? "1" : "0"
}
for (slot, favoriteName) in ehSetting.favoriteCategories.prefix(10).enumerated() {
    params["favorite_\(slot)"] = favoriteName
}
for (languageValue, isExcluded) in zip(EhSetting.languageValues, ehSetting.excludedLanguages)
where isExcluded {
    params["xl_\(languageValue)"] = "on"
}
```

When the counts match — every case that did not previously crash — the emitted parameter set is identical, key for key and value for value. When they do not, the request now submits the parameters it has instead of trapping. `where isExcluded` on the third loop is the same filter the old `if value` performed.

**2. `Request+Detail.swift` indexed URL path components with no proof anywhere.** `GalleryReverseRequest` read `url.pathComponents[2]` / `[3]` in `getGallery`, and `resolvedGalleryURL.pathComponents[2]` in `response()`. This is 11-14's cluster shape, but strictly worse: there, `parseGalleryTitle` had validated `count >= 4` in a different function. Here **nothing validated it at all** — the URL is whatever the caller passed, and when `isGalleryImageURL` is set it is a URL parsed by `Parser.parseGalleryURL` out of remote markup.

Both sites now go through one guarded extractor:

```swift
var galleryIdentifiers: (gid: String, token: String)? {
    // Skips the leading "/" and "g" components to reach <gid>/<token>.
    let identifiers = pathComponents.dropFirst(2)
    guard let gid = identifiers.first, let token = identifiers.dropFirst().first else {
        return nil
    }
    return (gid: gid, token: token)
}
```

Same `dropFirst(2)` shape 11-14 established. `getGallery` folds the check into its existing `if let detail` (it already returned `Gallery?`), and `response()` throws `AppError.parseFailed` — the error it already throws when `getGallery` returns nil. This is T-11-18's mitigation: a malformed response now routes into the existing error path.

**3. `Request+GalleriesMetadata.parseTags` was the same defect 11-14 fixed in `Parser.parseGalleryTags`.** Identical shape — `tags[index] = .init(rawNamespace:, contents: tags[index].contents + [content])` behind a `firstIndex(where:)`, a genuine `Array` subscript that the anti-dodge rule forbids renaming out of. Resolved the same way: group into a dictionary with an explicit first-appearance order list.

```swift
if contentsByNamespace[namespace] == nil { namespaceOrder.append(namespace) }
contentsByNamespace[namespace, default: []].append(...)
...
return namespaceOrder.map { .init(rawNamespace: $0, contents: contentsByNamespace[$0] ?? []) }
```

Output order is unchanged — namespaces in first-appearance order, contents in encounter order — and the O(n) scan per tag becomes an O(1) lookup. The two `parts[0]`/`parts[1]` reads in the same function, behind `parts.count == 2`, became `parts.first` / `parts.dropFirst().first`; with `maxSplits: 1` the array has at most two elements, so the nil-fallback branch fires on exactly the inputs `count == 2` previously rejected.

**4. `Request.swift`'s `URL.galleryToken` was dead.** Declared in a `private extension` — file-scoped — and referenced nowhere in that file or anywhere else. Swift does not warn on unused private extension members, so it rotted silently. Deleted; its `filteredComponents[2]` went with it.

**5. `Request+Image.swift`** read `thumbnails[index]` inside `refetchAttempt()`, where `index` is a public stored property on `GalleryNormalImageURLRefetchRequest` used by three test call sites. Rather than relabel public API, the private helper now takes the value as a parameter: `refetchAttempt(page:)`, called `refetchAttempt(page: index)`. This is 11-13's "renames confined to private helper parameters" precedent. `Parser.parseThumbnailURLs` returns `[Int: URL]` in the same 1-based page key space verified in 11-13.

## Phase 4 invariants — explicitly confirmed intact

All four live in `GalleriesMetadataRequest`, whose `response()` and `fetchChunks(_:)` were **not modified by this plan** (only the private `parseTags` helper in the same file changed):

1. **25-pair gdata chunking** — `gidList.chunked(into: 25)` untouched, and the `chunked(into:)` helper itself untouched.
2. **Two-in-flight flood control** — `for chunk in chunks.prefix(2)` untouched; the `nextIndex < chunks.count` refill on each `group.next()` untouched.
3. **Input-order reconstruction** — `let order = gidList.map(\.gid)` … `return order.compactMap { byGID[$0] }` untouched. The reassembly is keyed by gid through a Dictionary, not by array index, so it never depended on completion order and no index-based reassembly was replaced. The ordering guarantee is structurally the same code it was before this plan.
4. **Page-URL ordering** — every DownloadClient loop over page keys still iterates `manifest.pages.keys.sorted()` / `pageRelativePaths.keys.sorted()`; only the loop *variable name* changed. `existingPageRelativePaths` still returns its map from the same `sorted(by: lastPathComponent)` file scan.
5. **`DownloadSchedulingTests` deterministic** — green on every run, no retries, no flake investigation needed.

## Verification

- Draft rule via standalone binary over both module trees, scratch config, `--no-cache` — **0 violations** (41 before). Run after each task.
- Full project config `--strict` over both trees — **0 violations**. Confirms the live `lifecycle_modifiers` / `binding_initializer` rules still pass.
- Comment-filtered optional-try count — **0 in DownloadClient** (unchanged from 11-03/11-04) and **0 in NetworkingFeature**.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings. Run after each task.
- `DownloadsFeatureTests` — **253 tests / 53 suites passed**, including `DownloadSchedulingTests`, `DownloadProcessTests`, `DownloadImageParsingTests`.
- `NetworkingFeatureTests` — **77 tests / 9 suites passed**, including `ImageRequestBaselineTests`.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (60.2s). The 2 known issues in `SettingReducerTests` / `SettingPresentationTests` are pre-existing and unchanged.
- `bash Scripts/check-cookie-logging.sh` — **exit 0** after each task. No logging added or changed.
- `git diff --name-only -- .swiftlint.yml` — empty. Config untouched.
- `git diff --name-only HEAD~2 HEAD` — 13 source files, **no test file**, no `.swiftlint.yml`, no `Package.swift`.
- `LINT-01` left open — it flips at 11-29.

## No exception sites — nothing for 11-17 to insert

Every one of the 41 matches resolved to a safe idiom, a structural fix, an honest rename, or a deletion. **Zero precondition-checked exceptions were created**, so there is no pending `// swiftlint:disable:next unchecked_subscript_index_access` directive in either module and 11-17 has no edit to make here. This is the third consecutive wave to land at zero exceptions; 145 matches across 11-13, 11-14 and 11-15 have now been resolved without a single one.

## Deviations from Plan

**1. [Rule 3 — Blocking] Test scheme substitution (same as 11-01/11-02/11-14)**

- **Issue:** The plan's `-scheme DownloadClient` and `-scheme NetworkingFeature` do not exist, and there is no `DownloadClientTests` target.
- **Fix:** `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air' -only-testing:DownloadsFeatureTests -only-testing:NetworkingFeatureTests`, invoked from `AppPackage/`.

**2. [Scope] The `validatedIndex` idiom was not used, and no exception site was created**

- **Found during:** Both tasks
- **Issue:** The plan's `key_links` pattern names `validatedIndex`; the orchestrator's finding that this escape hatch is inert was confirmed to be irrelevant here, as in 11-13 and 11-14 — no site needed it.
- **Fix:** None needed. Recorded so 11-17 does not go looking for a directive site in these modules.
- **Commit:** n/a

**3. [Rule 2 — Missing critical functionality] Three NetworkingFeature clusters were fixed structurally rather than guarded**

- **Found during:** Task 2
- **Issue:** The plan's idiom ladder anticipates per-site guards. For the EhSetting parallel arrays, the gallery-URL identifiers, and the tag merge, a per-site guard would have papered over three unchecked cross-object assumptions while leaving each one intact.
- **Fix:** `zip`/`prefix`, a guarded `URL.galleryIdentifiers`, and dictionary grouping. Shorter diff than the equivalent guards, and the defect class is removed rather than caught.
- **Commit:** `3c7f71bc`

**4. [Scope] One violation was resolved by deleting dead code**

- **Found during:** Task 2
- **Issue:** `Request.swift`'s `URL.galleryToken` contributed a match but is unreachable.
- **Fix:** Deleted the extension. Confirmed unreferenced across `AppPackage` before removal.
- **Commit:** `3c7f71bc`

## Flagged for owner review

**1. Recommendation for 11-17: the draft rule polices doc comments.** `excluded_match_kinds` lists `comment` and `string`, but SwiftLint treats `///` doc comments as the separate `doc_comment` kind. A doc comment that merely *describes* an indexed access trips the rule. This is reproducible — a four-line file whose only content is `/// doc mentions foo[2] here` produces a violation under the draft config. It bit this plan directly: the doc comment explaining why `URL.galleryIdentifiers` exists had to be reworded from ``` `pathComponents[2]` / `[3]` ``` to "path components 2 and 3", which made the explanation worse. **Recommend adding `doc_comment` to the rule's `excluded_match_kinds` when 11-17 enables it**, otherwise the rule will penalise exactly the documentation that D-08's precondition-checked exceptions are required to carry. Worth re-scanning the modules already cleared in 11-12 through 11-14 for the same false positive once the kind is added, since a doc-comment match there would have been resolved by rewording rather than flagged.

**2. Recommendation for 11-17, seconding 11-13 and 11-14: delete the inert `excluded` entry.** `"\\[validatedIndex\\]"` is a file-path regex that can never match source text. Three plans now (11-13, 11-14, 11-15) have resolved every site without it. Delete the entry; keep the correct sibling `".*/[^/]*Tests\\.swift$"`. **11-17 owns this file; nothing was changed here.**

**3. `EhSetting`'s three arrays have no count invariant.** The `zip`/`prefix` fix makes the request assembly safe, but it also means a settings page that parses short now *silently* submits a partial form rather than crashing — arguably worse than a loud failure, though strictly better than a trap. `EhSetting.empty` builds them at 10/10/50, and `EhSetting.categoryNames` is derived from `Category.allFiltersCases`, so the intended counts are knowable. If the owner wants the mismatch to be loud, the right place is a validation in the `EhSetting` parser (out of this plan's mandate), not a re-added trap here.

**4. `GalleriesMetadataRequest.parseTags` duplicates `Parser.parseGalleryTags`.** Both group `"namespace:content"` strings into `[GalleryTag]`, and 11-14 fixed the identical Array-subscript defect in the ParserFeature copy four hours earlier. Two independent implementations of one grouping rule will drift. NetworkingFeature already imports `ParserFeature` (`Request+Detail.swift` line 5), so consolidating is mechanically easy — but the two differ in input shape (flat `[String]` from the `gdata` JSON vs. HTML nodes) and vote flags, so it needs a shared helper rather than a straight call. Deliberately out of scope; worth a small follow-up.

**5. No network seam, as 11-12 flagged.** `GalleriesMetadataRequest` and every sibling take `urlSession: URLSession = .shared` as an init default and reducers never pass one, so a `TestStore` still cannot stub a fetch. Nothing in this plan's diff made a clean seam fall out — the changes were all inside request assembly and response slicing, never at the transport boundary. Recorded as still-open, not taken on.

**6. `getGallery(from:and:)` is public but has exactly one caller, itself.** It is called only at `Request+Detail.swift:206`, inside the same type. It could be `private`. Not changed: the plan forbids public API changes and this is cosmetic.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface was introduced. T-11-18's mitigation is satisfied and, unlike 11-14, genuinely so: the `Request+Detail.swift` path-component reads and the `Request+Account.swift` parallel-array reads were reachable traps on remotely-influenced data with no proof anywhere in the call graph, not bounds proven remotely. Both now route into existing error paths.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/NetworkingFeature/Request+Detail.swift` — FOUND
- `AppPackage/Sources/NetworkingFeature/Request+Account.swift` — FOUND
- `AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift` — FOUND
- `AppPackage/Sources/NetworkingFeature/Request+Image.swift` — FOUND
- `AppPackage/Sources/NetworkingFeature/Request.swift` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-15-SUMMARY.md` — FOUND
- Commit `903ad90e` — FOUND
- Commit `3c7f71bc` — FOUND
