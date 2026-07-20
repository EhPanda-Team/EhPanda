---
phase: 11-infra-refactor-lint-capstone
plan: 12
subsystem: previews
tags: [swiftui, previews, determinism, lint, swiftlint, spm]
requires:
  - "11-11's live lifecycle_modifiers / binding_initializer rules (new code satisfies both)"
  - "11-09's finding that a disable directive cannot precede its rule"
provides:
  - "`PreviewSupport` module — 1,000 frozen UUID literals behind a precondition-checked static subscript"
  - "The in-repo reference implementation of the D-08 checked-subscript idiom"
  - "Deterministic fixture identities in the 5 cell previews that minted random UUIDs"
affects:
  - "HomeFeature, SearchFeature and GalleryListComponents gain a Foundation-only target dependency"
  - "11-17 must add this file's `unchecked_subscript_index_access` directive in its flip commit"
tech-stack:
  added: []
  patterns:
    - "Preview-only support code lives in its own SPM target rather than in the feature module"
    - "`precondition` + `// reason:` line as the shape a checked subscript exception takes"
key-files:
  created:
    - AppPackage/Sources/PreviewSupport/PreviewIdentifiers.swift
    - AppPackage/Sources/PreviewSupport/.swiftlint.yml
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/HomeFeature/GalleryRankingCell.swift
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
    - AppPackage/Sources/SearchFeature/GalleryHistoryCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
decisions:
  - "The `swiftlint:disable:next unchecked_subscript_index_access` directive was NOT written. The rule is still commented out until 11-17, and a directive naming an unregistered rule is a `superfluous_disable_command` warning — verified empirically with a throwaway probe. The repo's own 11-09 finding (directives land in the same commit as the flip) is the precedent applied. The `// reason:` line is in place so 11-17 only has to insert one line."
  - "The module's one live disable is `file_length` (the file is 1,048 lines and is a table, not logic). Its reason had to be a single line: `swiftlint_disable_requires_reason` requires `// reason:` on the line immediately preceding the directive, so a two-line reason still fails."
  - "The random `UUID()` in all 5 files lived in a file-private `Gallery.previewFixture` helper, not inline in the `#Preview` bodies. The helper gained an `identity: Int` parameter and each call site passes a distinct literal index — the smallest change that makes the identity a caller decision."
  - "`Gallery.preview`, `Gallery.previews(count:)` and `Gallery.mockGalleries` in AppModels still mint random UUIDs and are the remaining source of preview non-determinism. Left alone: they are production model code outside this plan's file list, and giving AppModels a PreviewSupport dependency is an architectural call for the owner (Rule 4)."
metrics:
  duration: ~25 min
  completed: 2026-07-21
status: complete
---

# Phase 11 Plan 12: PreviewSupport Stable Identities Summary

`PreviewSupport` ships as a Foundation-only SPM target holding 1,000 frozen UUID literals, reachable only through a `precondition`-checked static subscript, and the five gallery-cell previews now draw fixture identities from it by index instead of minting a fresh `UUID()` per render. Both builds and the full suite are green; one piece of the D-09 design is deliberately deferred to 11-17 and is flagged below.

## The module

`AppPackage/Sources/PreviewSupport/PreviewIdentifiers.swift` — 1,048 lines, of which 1,000 are the table.

```
private static let uuidStrings: [String]   // frozen literals, generated once with uuidgen
private static let all: [UUID]             // compactMap(UUID.init(uuidString:)) + count assertion
public  static subscript(index: Int) -> UUID  // precondition, then the indexed read
```

Both stored arrays are `private`, so the subscript is the only way in — a caller cannot index `all` unguarded, and cannot append to it. The count assertion exists because `compactMap` drops a malformed literal *silently*, and a dropped entry shifts every later index: a call site that resolved index 400 yesterday would resolve a different identity today, which is precisely the failure mode the table exists to prevent. `assertionFailure` turns that into a debug-time failure at the table instead of an inexplicable preview diff much later.

The literals are lowercase, generated in one `uuidgen` run, and asserted unique at generation time (1,000 generated, 1,000 distinct). The doc comment states the contract that matters more than any of the code: appending is safe, editing or reordering an existing entry is not.

`.swiftlint.yml` carries the one-line `parent_config: ../../../.swiftlint.yml` stub, so the module is covered by the root rules rather than escaping them.

## The consumers

The plan said "replace every random `UUID()` in each `#Preview` block". In the tree, none of the five files had `UUID()` inside a `#Preview` body — each had it in a file-private `private extension Gallery { static func previewFixture(…) }` used by two previews. So the change is one parameter, not five inline edits:

| File | Fixture helper | Indices |
|---|---|---|
| `HomeFeature/GalleryRankingCell.swift` | `previewFixture(identity:title:uploader:)` | 0, 1 |
| `HomeFeature/GalleryCardCell.swift` | `previewFixture(identity:title:rating:)` | 0, 1 |
| `SearchFeature/GalleryHistoryCell.swift` | `previewFixture(identity:title:rating:uploader:)` | 0, 1 |
| `GalleryListComponents/Cells/GalleryThumbnailCell.swift` | `previewFixture(identity:title:rating:pageCount:)` | 0, 1 |
| `GalleryListComponents/Cells/GalleryDetailCell.swift` | `previewFixture(identity:title:rating:pageCount:)` | 2, 3 |

The two `GalleryListComponents` cells use disjoint indices from each other — same module, and it costs nothing. Indices repeat across modules, which is fine: determinism is the requirement, uniqueness only matters within one rendered preview.

`import PreviewSupport` sits at file top, because Swift imports are file-scoped and cannot be confined to a `#Preview` block. The dependency reaches production compilation units but nothing in a production code path references it — the only use in each file is inside the `private` preview-fixture extension. That is the practical form of T-11-15's mitigation; `git diff` for `172ef103` shows no changed line outside the import, the fixture helper and the `#Preview` bodies.

Preview content and state matrices are untouched, as Phase 10's D-09 constraint requires.

## The directive that was not written — 11-17 must add it

D-09 specifies the subscript body as `precondition(…)` + `// reason: …` + `// swiftlint:disable:next unchecked_subscript_index_access` + the indexed read. The directive is **absent**, deliberately.

`unchecked_subscript_index_access` is still commented out in `.swiftlint.yml`; 11-17 flips it. A directive naming a rule SwiftLint does not know is not a no-op — it is a `superfluous_disable_command` violation. Verified with a throwaway probe file before writing anything:

```
"reason" : "'unchecked_subscript_index_access' is not a valid SwiftLint rule; remove it from the disable command",
"rule_id" : "superfluous_disable_command",
"severity" : "Warning"
```

Warning, not error — so it would not have failed the build, but it would have put a warning into a repo that 11-11 verified at zero. This is the same constraint 11-09 discovered and 11-11 acted on by landing directives in the same commit as their flip; the same answer applies here.

**What 11-17 must do:** insert one line into `PreviewIdentifiers.swift` between the existing `// reason: bounds are precondition-checked immediately above.` and `return all[index]`, in the flip commit. The reason line is already in place, so the edit is purely the directive. `11-17`'s own instructions already say the standalone binary is authoritative for enumerating remaining sites, so the binary will surface this one — but it is recorded here so it is not read as a miss.

The module therefore currently carries exactly one disable: `file_length`, reason-annotated, for a genuinely 1,048-line file.

## Verification

- Standalone SwiftLint binary over `AppPackage/Sources/PreviewSupport` and all three consumer modules (30 files) — **0 violations**, exit 0, `--no-cache`.
- `xcodebuild build -scheme EhPanda` — **BUILD SUCCEEDED**, 0 errors, 0 warnings. Run after each task.
- `xcodebuild build-for-testing -scheme EhPanda` — **TEST BUILD SUCCEEDED**. Test targets carry the plugin; the app-scheme gate does not lint `Tests/`.
- Full `AppPackage-Package` suite — **TEST SUCCEEDED**, 0 failures (54s testing, 86s wall).
- `AppPackage/Package.resolved` unchanged — the new target is local and pulls no external package, so there was nothing to re-resolve.
- `LINT-01` left open; it flips at 11-29.

## Deviations from Plan

**1. [Rule 3 - Blocking] `unchecked_subscript_index_access` directive deferred to 11-17**

- **Found during:** Task 1
- **Issue:** The named rule is not registered until 11-17, and the directive would emit `superfluous_disable_command`.
- **Fix:** Directive omitted; `precondition` and `// reason:` line both in place. Detailed above.
- **Commit:** `5c7b56fc`

**2. [Rule 3 - Blocking] The `file_length` reason had to collapse to one line**

- **Found during:** Task 1
- **Issue:** A two-line `// reason:` explanation still tripped `swiftlint_disable_requires_reason` — its regex demands `// reason:` on the line *immediately* preceding the directive.
- **Fix:** Reason rewritten as a single 100-char line.
- **Commit:** `5c7b56fc`

**3. [Scope] The `UUID()` calls were not where the plan said**

- **Found during:** Task 2
- **Issue:** The plan described replacing `UUID()` inside `#Preview` bodies. All five sites were in file-private `Gallery.previewFixture` helpers instead.
- **Fix:** Each helper gained an `identity: Int` parameter; call sites pass literal indices. Same outcome, smaller diff.
- **Commit:** `172ef103`

## Plan counts that matched, and one that did not

The plan's "5 consumers" is correct — re-enumerated at HEAD, `grep -rn "UUID()"` over `AppPackage/Sources App ShareExtension` returns exactly those 5 preview-fixture sites plus request-ID and cache-path uses that are not preview identities.

What the count *misses* is `AppModels/Gallery/Gallery.swift` (below).

## Flagged for owner review

**1. `AppModels`' shared gallery fixtures still mint random UUIDs — and they feed these very previews.** `Gallery.preview` (line 34), `Gallery.previews(count:)` (line 57) and `Gallery.mockGalleries` (line 15) all use `UUID().uuidString`. Four of the five files' *first* preview renders `Gallery.preview`, so those previews are still non-deterministic across builds after this plan. They were left alone on purpose: `Gallery` is production model code outside this plan's file list, and giving `AppModels` a `PreviewSupport` dependency (or moving these fixtures out of the model module) is an architectural decision, not an auto-fix. If D-09's intent is "no preview fixture has a random identity", this is the remaining half of the job and wants its own plan.

**2. `mockGalleries`' comment is subtly wrong.** It says `.preview` "can't stand in because its `gid` is a fixed constant". `.preview` is a `static let` holding a *random* UUID — constant within one process, different every launch. The reasoning it gives for needing distinct ids is still valid; the stated reason is not. Worth correcting whenever item 1 is addressed.

**3. `AppPackage/Package.swift` is 1,060 lines and exceeds `file_length`.** Pre-existing — it was already over before this plan added 11 lines, and it is never linted in a build because the manifest is not a target source. Only visible if the standalone binary is pointed at it directly. Recorded so it is not mistaken for new.

**4. The custom rule's `excluded: "\\[validatedIndex\\]"` pattern is likely inert.** For a SwiftLint custom rule, `excluded` is a *file path* regex, not a match regex — so a pattern shaped like source text can never match a path, and the intended `[validatedIndex]` escape hatch would not work. Not touched here (the rule is still commented out and 11-17 owns it), but 11-17 should confirm before relying on it, since D-08 alternatives may have been planned around that escape.

**5. Previews are not covered by any automated gate.** `#Preview` bodies compile under the build, which is what the green build proves, but nothing renders them. Whether the fixtures still look right is a Preview-canvas check: open each of the five cells in Xcode and confirm the three previews per file render as they did in Phase 10.

## Self-Check: PASSED

- `AppPackage/Sources/PreviewSupport/PreviewIdentifiers.swift` — FOUND
- `AppPackage/Sources/PreviewSupport/.swiftlint.yml` — FOUND, contains `parent_config: ../../../.swiftlint.yml`
- Commit `5c7b56fc` — FOUND
- Commit `172ef103` — FOUND
