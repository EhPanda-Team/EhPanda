---
phase: 261122-fv8-port-462-item-10-my-tags-page-and-watche
plan: 01
subsystem: my-tags
tags: [my-tags, tag-highlight, tag-editor, settings, detail, swift-composable-architecture]
requires: []
provides:
  - MyTags model, parser, requests and MyTagsClient, cached on User.myTags
  - My Tags symbol on every tag chip (Detail, list and grid cells)
  - MyTagEditor module (Add Tag / Edit Tag) and a tag's My Tags item on Detail
  - Native My Tags page behind the Account row
affects: [AppModels, ParserFeature, NetworkingFeature, MyTagsClient, MyTagEditor, SettingFeature, DetailFeature, AppComponents, GalleryListComponents, Resources]
key-files:
  created:
    - AppPackage/Sources/AppModels/Tags/MyTags.swift
    - AppPackage/Sources/ParserFeature/Parser+MyTags.swift
    - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift
    - AppPackage/Sources/MyTagsClient/MyTagsClient.swift
    - AppPackage/Sources/MyTagEditor/
    - AppPackage/Sources/DetailFeature/DetailReducer+MyTags.swift
    - AppPackage/Sources/SettingFeature/MyTags/
status: complete
commits: 3
plan_head_before: d3dd40af1fbd4d6a5d38f0c55376e10738739839
plan_head_after: 73135957c7b5b846c7e0d2f7e5b039f73b7968a1
actuals:
  tasks: 3
  commits: 3
---

# Phase 261122-fv8 Plan 01: Port PR 462 item (10), My Tags Summary

My Tags is read from every tag set into a cache on the user, every tag of an enabled set carries its state's symbol on Detail and in list and grid cells, a tag's menu adds it to or removes it from the set last chosen, and the Account row opens a native My Tags page with a shared Add Tag / Edit Tag sheet.

## Commits (signature line, author and committer dates)

| Task | Hash | Subject | `%G?` | Dates |
|------|------|---------|-------|-------|
| 1 | 695bef546 | tags: highlight My Tags from a cached copy | G | 2026-11-22T13:49:30+08:00 (both) |
| 2 | a16116403 | detail: add and remove a tag from My Tags | G | 2026-11-22T13:52:23+08:00 (both) |
| 3 | 73135957c | settings: add the My Tags page | G | 2026-11-22T13:56:10+08:00 (both) |

Each body is the subject, one blank line and `Co-authored-by: dyphire <qimoge@gmail.com>`. Task 1 has 34 files, Task 2 17, Task 3 16 (Task 3 includes the tracked SCROLL-EDGE-INVENTORY.md, as the plan lists it).

## Gates

- BASELINE: build succeeded, 0 warnings (`warnings-baseline.txt` empty), lint baseline empty.
- Task 1: BUILD succeeded, no new warnings; LINT empty; every value gate printed its EXPECT; PRIVACY `clean`; STAGED 34 paths, 0 excluded paths, no file over 1000 lines.
- Task 2: BUILD succeeded, no new warnings; LINT empty; every value gate printed its EXPECT (including numstat 18/82/705/55); PRIVACY `clean`; STAGED 17 paths.
- Task 3: BUILD succeeded, 0 warnings in the log; LINT empty (after the E-ASR8 fix below); every value gate printed its EXPECT (numstat 4 2 / 2 0 / 11 0 / 492 0); PRIVACY `clean`; STAGED 16 paths.
- Per-bundle test counts:
  - `task1` (first run): 5 failures, all `htmlDocumentNotFound` from a stale embedded bundle (see Deviations).
  - `task1-rerun`: Passed, 0 failed, 1783 passed, 7 expected failures. AppModelsTests 163; DetailFeatureTests 213; DownloadsFeatureTests 534 (+6 expected failures); GalleryListComponentsTests 13; HostedViewTests 15; NetworkingFeatureTests 128; ParserFeatureTests 118; SettingFeatureTests 90 (+1 expected failure).
  - `task2`: Passed, 0 failed, 259 passed. DetailFeatureTests 226; HostedViewTests 15; SearchFeatureTests 18.
  - `task3` (whole FeatureTests plan minus VisualSnapshotTests): Passed, 0 failed, 2072 passed, 9 expected failures (AnalyticsClientTests 116 +2; AppFeatureTests 220; AppModelsTests 163; AppToolsTests 18; CookieClientTests 20; DetailFeatureTests 226; DownloadsFeatureTests 534 +6; FavoritesFeatureTests 22; FileClientTests 8; GalleryListComponentsTests 13; HomeFeatureTests 81; HostedViewTests 15; ImageClientTests 9; ImageColorsTests 4; LiveCheckTests 11; LiveTextTranslationTests 77; MarkdownExtTests 11; NetworkingFeatureTests 128; ParserFeatureTests 118; ReadingFeatureTests 139; SearchFeatureTests 18; SettingFeatureTests 105 +1; SystemNotificationTests 4; TagTranslationFeatureTests 12). The FavoritesFeatureTests flake did not occur.
- Simulator: `EhPanda iPhone Air (261122-fv8)`, UDID `6FE29F11-92C4-48C3-A2D4-46875C8AFFD6`, left in place for the orchestrator to delete.

## Deviations from Plan

1. **[Environment, owner-approved] Stale embedded TestingSupport bundle (Task 1 TEST).** The first `task1` run failed 5 `MyTagsParserTests` with `htmlDocumentNotFound`. `ParserFeatureTests.xctest/AppPackage_TestingSupport.bundle` in derived data was an old copy without the new fixtures. With the orchestrator's approval (option 1) I deleted the 8 `*.xctest/AppPackage_TestingSupport.bundle` directories under `.capture/dd-port-462/Build/Products/Debug-iphonesimulator/` and re-ran as `task1-rerun`, which passed. Used once; not needed for Tasks 2 and 3. No source or plan change.
2. **[Tooling, no plan change] E-ASR8.** My applier script dropped the trailing blank line of E-ASR8's find block, leaving two blank lines before `// Echo-guard.` in `AccountSettingReducer.swift` (SwiftLint `vertical_whitespace` and a build warning). I removed the one extra blank line, which the plan's find text (it ends with a blank line, replaced by nothing) already specifies; lint and build are clean afterwards. A scan of every edit block found no other find ending in a blank line with a replacement of nothing.

Otherwise the plan was executed exactly as written. The plan's per-task commit ledger (protocol 0c) was not written; `commits: 3` is measured with `git rev-list --count d3dd40af1..HEAD`.

## Known Stubs

None found in the files this plan adds.

## Threat Flags

None beyond the plan's register: credentials stay in feature state, `MyTags` (cached) has no credential field, fixtures are synthetic and PRIVACY printed `clean` for every commit.

## Open for the owner

Planner's choices beyond CONTEXT (Design 1 to 11 of the plan, one line each):
1. Model: `SiteColor` keeps three 8-bit channels; `MyTag` keeps both flags, `kind` is the one choice (hidden wins); the first enabled set holding a tag wins for the highlight.
2. Cache: one optional `User.myTags`, no credentials, every read keeps the chosen set.
3. Requests: the read takes set 1 then every set the picker lists; add, remove and tag-set update post the page's forms and parse the answer; the tag set update sends `tagset_name` empty as the site's script does; the edit posts `setusertag` JSON; no new `AppError` case.
4. `MyTagsClient` is its own module in GalleryClient's shape.
5. Reads at signed-in launch, after login and when Account's Website picker changes the host.
6. Highlight: the symbol sits inside the label's one `Text`; list cells drop the site's fill; the list parser keeps the gradient's last stop as the stand-in; `GalleryTag.Content.textColor` is gone; the home slideshow's tags carry no symbol.
7. Editor: a new `MyTagEditor` module; its tests live in DetailFeatureTests; errors use `AppAlertState.failure(title:message:)`; Add from Detail uses the default weight 10 and no colour; submitting an empty hex field clears the colour.
8. Detail: the item reads `myTags?.selectedTagSet`; Add opens the editor with the name locked; Remove runs at once.
9. Page: stays in SettingFeature; Enabled is sent at once, a colour change waits one second after the last change; a failed change puts the set back and shows the alert; the browser sheet is bound through `browserChanged`; no analytics for the page.
10. Account row sends `.delegate(.pushMyTags)`; the web view destination and `presentWebView` are gone; the Bypass SNI Filtering gate stays.
11. Strings: S19's groups `resources1`, `resources2`, `resources3`, `detail`, `editor`, `setting`, six locales, every `%@` argument a string.

## Snapshots to re-record

`git grep -n -E 'showTagsInList|myTags|MyTags|pushMyTags|account\(' -- AppPackage/Tests/VisualSnapshotTests EhPandaUITests` hits only `AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift`, lines 30, 35, 38, 40, 152 to 157, 170, 191 to 195 and 346 (the `settings-account-*` scenarios, the Account page and the pages stacked on it, all through `Page.account(...)` / `.account(.init())`). No scenario turns on `showTagsInList`, the preview `MyTagsClient` answers no sets so Detail shows no symbol, and the Account row stays gated, so the planner expects no baseline to change. The only rendering-relevant change in those scenarios is the Account screen itself (Website picker now bound through `galleryHostChanged`, the My Tags row now pushes instead of presenting a web view); I did not run or re-record anything.

## Self-Check: PASSED

The three commits exist in `git log d3dd40af1..HEAD`, each `G` with +08:00 dates; the working tree is clean apart from the untracked plan directory; STATE.md and the PLAN are untouched.
