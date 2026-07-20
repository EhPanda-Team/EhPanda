---
phase: 11-infra-refactor-lint-capstone
plan: 14
subsystem: ParserFeature
tags: [lint, swiftlint, parser, subscript, robustness, html]
requires:
  - "11-01/11-02 (Parser.degrading seam; module at zero optional-try)"
  - "11-12/11-13's finding that the draft rule's `excluded: \"\\\\[validatedIndex\\\\]\"` entry is inert"
provides:
  - "ParserFeature contributes zero matches to the draft `unchecked_subscript_index_access` rule"
  - "Parser.InfoPanel — the gallery detail info panel as named fields instead of an 8-slot positional array"
  - "Parser.GalleryTitleInfo — gid/token extracted where the URL shape is validated"
  - "Zero precondition-checked exception sites, so 11-17 has no directive to insert here"
affects:
  - "No other module — every changed type is internal to ParserFeature; no public signature, no test, no fixture changed"
tech-stack:
  added: []
  patterns:
    - "named-field struct replacing a positional `[String]` record addressed by literal indices"
    - "`zip(1..., array)` as the 1-based page enumeration for page-keyed dictionaries"
    - "`dropFirst(n).first` as the bounds-safe replacement for a literal path-component index"
key-files:
  created: []
  modified:
    - AppPackage/Sources/ParserFeature/Parser+Types.swift
    - AppPackage/Sources/ParserFeature/Parser+List.swift
    - AppPackage/Sources/ParserFeature/Parser+Detail.swift
    - AppPackage/Sources/ParserFeature/Parser+Preview.swift
    - AppPackage/Sources/ParserFeature/Parser+Image.swift
    - AppPackage/Sources/ParserFeature/Parser+Greeting.swift
    - AppPackage/Sources/ParserFeature/Parser+Profile.swift
decisions:
  - "The 20 Parser+Detail matches were symptoms of one design defect: `parseInfoPanel` returned a positional `[String]` of 8 slots, written at 11 sites by literal index and read at 8 by literal index, with nothing tying slot 4 to the file size. Replacing it with a named-field `InfoPanel` struct deleted all 20 in one change and is a readability win independent of the lint rule."
  - "The 8 `galleryURL.pathComponents[2]`/`[3]` reads across four list-mode parsers were resolved at the root: `parseGalleryTitle` already validated `pathComponents.count >= 4`, so it now extracts gid/token inside that same guard and returns them. The four call sites stop indexing a scraped URL on trust."
  - "Page-keyed `[Int: URL]`/`[Int: String]` dictionaries were renamed `index` → `page`, matching 11-13's precedent: a Dictionary subscript is Optional-returning and cannot trap, and the key genuinely is the 1-based page number `parseGTX00IndexFromTitle` reads out of a \"Page N: filename\" title."
  - "No precondition-checked exception was needed anywhere in the module — every site resolved to a safe idiom or an honest rename, so unlike 11-12 this plan leaves 11-17 nothing to insert."
metrics:
  duration: ~35 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 14: ParserFeature Subscript-Rule Cleanup Summary

ParserFeature's 43 `unchecked_subscript_index_access` matches are gone, resolved entirely with safe idioms and structural fixes — zero exception sites, zero test edits, zero `.swiftlint.yml` changes. Two of the clusters were genuine defects in the untrusted-HTML path, not lint ceremony.

## The count was right, the file list was not

Plan said 43. The standalone binary against a scratch config enabling only the draft rule reported **exactly 43** at HEAD before any edit — the second consecutive wave where the plan's number matched the tree.

The plan's task split named `Parser+List.swift`, `Parser+Shared.swift` and `Parser+Torrent.swift` for Task 1. **`Parser+Shared.swift` and `Parser+Torrent.swift` contain zero matches.** The real distribution:

| File | Matches | Kind |
|---|---|---|
| `Parser+Detail.swift` | 20 | positional `[String]` info panel |
| `Parser+List.swift` | 14 | scraped URL path components, split-string arrays, Array index |
| `Parser+Preview.swift` | 5 | 3 positional config array, 2 Dictionary |
| `Parser+Image.swift` | 2 | Dictionary |
| `Parser+Greeting.swift` | 1 | parallel-array indexing |
| `Parser+Profile.swift` | 1 | scraped node list |

Task 1 was therefore scoped to `Parser+List.swift`; Task 2 took the remaining five files plus the module audit.

## The two real defects

**1. `parseInfoPanel` returned an 8-slot positional array.** It built `Array(repeating: "", count: 8)`, wrote slots by literal index at 11 sites (`infoPanel[0] = gdt2Text`, `infoPanel[5] = "KiB"`, …), validated with `filter { !$0.isEmpty }.count == 8`, and returned it for the caller to read back by literal index at 8 more sites (`Float(infoPanel[4])`, `Int(infoPanel[6])`, `parseVisibility(value: infoPanel[2])`). Nothing but the reader's memory connected slot 4 to the file size or slot 6 to the page count, and a mis-numbered slot would have silently mapped the favourited count onto the page count.

It now returns a named-field `Parser.InfoPanel`. All 20 matches vanish, the magic numbers vanish with them, and the emptiness contract is preserved exactly:

```swift
guard ![postedDate, parentURL, visibility, language,
        fileSize, sizeType, pageCount, favoritedCount].contains(where: \.isEmpty)
else { throw AppError.parseFailed }
```

which is `filter { !$0.isEmpty }.count == 8` restated. The one nested read, `infoPanel[3] = words[0]` behind an `!words.isEmpty` check, became `if …, let firstWord = gdt2Text.split(separator: " ").first`.

**2. Four list-mode parsers indexed a scraped URL on trust.** Each built a `Gallery` with `gid: galleryURL.pathComponents[2], token: galleryURL.pathComponents[3]`. The bound *was* proven — `parseGalleryTitle`'s inner `findTitle` guards `url.pathComponents.count >= 4` — but that proof lived in a different function, and any future caller of `parseGalleryTitle` would have inherited a trap. Fixed at the root: the guard that validates the shape now extracts the identifiers.

```swift
let url = URL(string: urlString),
// Skips the leading "/" and "g" components to reach <gid>/<token>.
case let identifiers = url.pathComponents.dropFirst(2),
let gid = identifiers.first,
let token = identifiers.dropFirst().first
```

`count >= 4` ⟺ `dropFirst(2)` has at least two elements, so the accept/reject set is unchanged. `parseGalleryTitle` returns a `GalleryTitleInfo` instead of a `(String, URL)` tuple, and the four call sites read `titleInfo.gid` / `.token` / `.title` / `.url`.

## The rest

**`parseGalleryTags` tag merge** (`Parser+List.swift`) — a genuine `Array` subscript, `tags[index]` behind `tags.firstIndex(where:)`. Per the anti-dodge rule this could not be renamed out of, and `GalleryTag.contents` is `let` so it could not be mutated in place. The subscript was removed instead by grouping into a dictionary with an explicit first-appearance order list. This also deleted a duplicated 6-line `GalleryTag.Content` construction that appeared identically in both branches of the if/else, and turns an O(n) scan per tag into an O(1) lookup. Output order is unchanged: namespaces in first-appearance order, contents in encounter order.

**Split-string reads** — `components[1]`/`components[0]` behind `components.count == 2` (page count) and `titleComponents[0]`/`[1]` behind `titleComponents.count == 2` (tag namespace) became `.last` / `.first`. With the count check retained these are exactly equivalent.

**`parsePreviewConfigs`** built a `keys` array, `compactMap`ped values out of the query items, checked `configs.count == keys.count`, then read `configs[0]`, `configs[1]`, `configs[2]`. Replaced with a local `intValue(for:)` reading each key by name, so the three values are bound to named locals in the guard. The `components.queryItems = nil` mutation still happens before `components.url` is read, and `queryItems` is a separate binding captured before that mutation, so ordering is preserved.

**Page-keyed dictionaries** — `previewURLs[index]` (×2), `thumbnailURLs[index]` — renamed `index` → `page`. These are `[Int: URL]` Dictionary writes: Optional-returning, incapable of trapping, so the violation was purely nominal. The key is the number `parseGTX00IndexFromTitle` extracts from a `"Page N: filename"` title, i.e. a 1-based page. Same reasoning and same resolution as 11-13's 60 renames.

**`imgKeys[index + 1]`** inside `array.enumerated().forEach` became `for (page, dict) in zip(1..., array)`. The `+ 1` existed to convert a 0-based offset to the 1-based page key; `zip(1...)` produces that key directly and the arithmetic disappears.

**`Parser+Greeting.swift`** indexed `gainedIntValues[index]` while enumerating `gainedTypes`, behind an equal-count guard — the textbook `zip` case. Now `for (type, value) in zip(gainedTypes, gainedIntValues)`. The count guard is retained: it enforces that every value parsed as an `Int`, which `zip` alone would silently tolerate by truncating.

**`Parser+Profile.swift`** — `strongTexts.count > 1 ? strongTexts[1] : nil` became `strongTexts.dropFirst().first`. Same value, no subscript.

## No exception sites — nothing for 11-17 to insert

Every one of the 43 matches resolved to a safe idiom, a structural fix, or an honest rename. **Zero precondition-checked exceptions were created**, so there is no pending `// swiftlint:disable:next unchecked_subscript_index_access` directive in this module and 11-17 has no edit to make here. The module's one pre-existing unrelated disable pair (`cyclomatic_complexity` in `Parser+Shared.swift` and `Parser+Detail.swift`, `function_body_length` in `Parser+Detail.swift`) is untouched.

## Verification

- Draft rule via standalone binary over `AppPackage/Sources/ParserFeature`, scratch config, `--no-cache` — **0 violations** (43 before).
- Full project config `--strict` over the same tree — **0 violations, 0 serious in 17 files**.
- Comment-filtered optional-try count in the module — **0**, unchanged from 11-02.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings. Run after each task.
- `ParserFeatureTests` — **33 tests / 10 suites passed**, run after each task, **zero assertion edits and zero fixture edits**.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED** (59.9s). The 3 known issues in `SettingReducerTests` / `SettingPresentationTests` are pre-existing and unchanged.
- `bash Scripts/check-cookie-logging.sh` — **exit 0** after each task. No logging was added or changed in this plan.
- `git diff --name-only HEAD~2 -- .swiftlint.yml` — empty. Config untouched.
- `LINT-01` left open — it flips at 11-29.

## Deviations from Plan

**1. [Rule 1 — Plan inventory] Task 1's file list was wrong; `Parser+Shared.swift` and `Parser+Torrent.swift` have zero matches**

- **Found during:** Task 1 enumeration
- **Issue:** The plan scopes Task 1 to List/Shared/Torrent. Shared and Torrent contribute nothing to the 43; the actual second-largest cluster is `Parser+Detail.swift` at 20, which the plan assigns to Task 2.
- **Fix:** Task 1 took `Parser+List.swift` alone (14 matches), Task 2 took the other five files (29) plus the module audit. Total and end state unchanged.
- **Commits:** `277289d9`, `d9d8d63f`

**2. [Rule 2 — Missing critical functionality] Two clusters were fixed structurally rather than guarded**

- **Found during:** Tasks 1 and 2
- **Issue:** The plan's idiom ladder anticipates per-site `indices.contains` guards. For the info panel (20 matches) and the gallery-URL identifiers (8 matches), a per-site guard would have been 28 guards papering over two single root causes, and in the info panel's case would have left the slot-numbering fragility fully intact.
- **Fix:** Introduced `Parser.InfoPanel` and `Parser.GalleryTitleInfo`, both internal to the module. Shorter diff than 28 guards, and the defect class is removed rather than caught.
- **Commits:** `277289d9`, `d9d8d63f`

**3. [Scope] The `validatedIndex` idiom was not used, and no exception site was created**

- **Found during:** Both tasks
- **Issue:** The plan's `key_links` pattern names `validatedIndex`; the orchestrator's finding that this escape hatch is inert was confirmed to be irrelevant here, as in 11-13 — no site needed it.
- **Fix:** None needed. Recorded so 11-17 does not go looking for a directive site in this module.
- **Commit:** n/a

**4. [Rule 3 — Blocking] Test scheme substitution (same as 11-01/11-02)**

- **Issue:** `-scheme ParserFeature` has no test action.
- **Fix:** `xcodebuild test -scheme AppPackage-Package -destination '…iPhone Air' -only-testing:ParserFeatureTests`, invoked from `AppPackage/`.

## Robustness gains worth recording

Neither cluster below could trap on today's call graph — both bounds were proven, just remotely. They are recorded because the *proof* moved to the access, which is what stops a future caller from inheriting a trap on malformed remote HTML.

1. **`Parser+Detail.swift` info panel.** The positional array's slot numbering was unenforced at both ends. A write to the wrong slot or a read of the wrong slot would have compiled and silently mis-parsed. Now impossible: the fields are named and the compiler checks them.
2. **`Parser+List.swift` gallery identifiers.** `pathComponents[2]`/`[3]` on a URL parsed out of scraped markup, guarded only inside a different function. Any future caller of `parseGalleryTitle` that did its own identifier extraction would have had no such guard. The extraction now lives inside the validation.

No behaviour change was introduced by either: the accept/reject sets and the parsed values are identical, proven by the 33 unmodified fixture tests.

## Known Stubs

None.

## Threat Flags

None. No new network, auth, file-access or schema surface. T-11-17's mitigation is satisfied in the sense the register intended — the flagged out-of-bounds surface in this module is gone — though see the note above that these particular bounds were already proven remotely rather than genuinely reachable crashes.

## Flagged for owner review

**1. `parseGTX00IndexFromTitle` is misnamed.** It reads the number out of a `"Page N: filename"` title, so it returns a 1-based *page*, not an index. Four call sites now bind its result to a local named `page`, so the call reads `let page = parseGTX00IndexFromTitle(from: title)`. Renaming the function to `parsePageNumberFromTitle` would tidy this, but it is used across `Parser+Image.swift` and `Parser+Preview.swift` and was out of this plan's mandate. Cosmetic; same family as 11-13's flagged `PreviewConfig.pageNumber(index:)` misnaming.

**2. `parseInfoPanel`'s emptiness contract is load-bearing and undocumented.** A gallery whose "Favorited" row genuinely reads as empty would fail the whole detail parse, because the guard requires all eight fields non-empty. That behaviour is unchanged from before this plan, and the replacements `"Never" → "0"` / `"Once" → "1"` suggest the remote page never emits an empty value there. Worth confirming against a real page with zero favourites, since a regression here rejects the whole detail rather than degrading one field.

**3. `Parser+Preview.swift`'s `parsePreviewConfigs` returns `nil` on a partial config.** Unchanged semantics, but now visible in the guard: if a preview URL carries width and height but no offset, the whole config is discarded. Previously the same thing happened via `configs.count == keys.count`, just less legibly. No action needed unless partial configs are expected in the wild.

## Self-Check: PASSED

- `AppPackage/Sources/ParserFeature/Parser+Types.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+List.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Detail.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Preview.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Image.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Greeting.swift` — FOUND
- `AppPackage/Sources/ParserFeature/Parser+Profile.swift` — FOUND
- `.planning/phases/11-infra-refactor-lint-capstone/11-14-SUMMARY.md` — FOUND
- Commit `277289d9` — FOUND
- Commit `d9d8d63f` — FOUND
