---
phase: 261126-wzg-my-tags-editor-suggestions-color-weight
plan: 01
status: complete
requirements: [G-1, G-2, G-3, G-4]
base: 2df40b2f8
commits: 5
plan_head_before: 2df40b2f8
plan_head_after: 4b8fdf6ba
actuals:
  tasks: 5
  commits: 5
---

# Quick 261126-wzg: My Tags editor suggestions, colour feedback and weight field Summary

Add Tag now lists the site's own tag suggestions (debounced 200 ms, cancelled by a change, merged with the Translate Tags matches, alias line and canonical insert), an invalid hex code turns the Color footer red and holds confirm back, and the weight is a number field beside the Stepper.

BASE: `2df40b2f8`. The plan was executed as written; no deviation, no stop.

## Commits

| Task | Hash | Subject | `%G? %aI %cI` |
|---|---|---|---|
| 1 | becf8d685 | tags: read the site's tag suggestions | G 2026-11-27T14:44:27+08:00 2026-11-27T14:44:27+08:00 |
| 2 | 6789a481a | tags: ask the site for tag suggestions | G 2026-11-27T14:47:06+08:00 2026-11-27T14:47:06+08:00 |
| 3 | 6d0e2eca8 | tags: suggest the site's tags in Add Tag | G 2026-11-27T14:52:13+08:00 2026-11-27T14:52:13+08:00 |
| 4 | 6871e7359 | tags: flag an invalid color code in the editor | G 2026-11-27T14:54:33+08:00 2026-11-27T14:54:33+08:00 |
| 5 | 4b8fdf6ba | tags: type a tag's weight in the editor | G 2026-11-27T14:56:31+08:00 2026-11-27T14:56:31+08:00 |

## Test runs (logs under `.capture/261126-wzg/`)

| Log | Targets | Result | Failed cases | New tests seen as passed |
|---|---|---|---|---|
| task1-red | AppModelsTests | TEST FAILED, `cannot find 'SiteTagSuggestion' / 'SiteTag' / 'TagSuggestQuery' in scope` (14 matching errors) | n/a | n/a |
| task1-tests | AppModelsTests, ParserFeatureTests | TEST SUCCEEDED | 0 | SiteTagSuggestionTests 7 names / 45 cases; TagSuggestParserTests 4 names / 10 cases |
| task2-red | NetworkingFeatureTests | TEST FAILED, `TagSuggestRequest` not found | n/a | n/a |
| task2-tests | NetworkingFeatureTests, DetailFeatureTests, SettingFeatureTests, DownloadsFeatureTests | TEST SUCCEEDED | 0 | TagSuggestRequestTests 3 names / 4 cases |
| task3-red | DetailFeatureTests | TEST FAILED, 9 errors naming the missing editor members | n/a | n/a |
| task3-tests | DetailFeatureTests, AppFeatureTests, AppToolsTests, SettingFeatureTests | TEST SUCCEEDED | 0 | MyTagEditorTests 14 names; TagNameSuggestionTests 2 names; pointer-hover audit unchanged |
| task4-red | DetailFeatureTests | TEST FAILED, 14 errors naming `colorText` / `colorFooter` / `isInvalidCode` | n/a | n/a |
| task4-tests | DetailFeatureTests, SettingFeatureTests | TEST SUCCEEDED | 0 | MyTagEditorTests 18 names |
| task5-red | DetailFeatureTests | TEST FAILED, 18 errors naming `weightText` / `weightFieldCommitted` | n/a | n/a |
| task5-tests | DetailFeatureTests, SettingFeatureTests | TEST SUCCEEDED | 0 | MyTagEditorTests 21 names (weight tests: 6 cases) |
| full-plan | FeatureTests plan, `-skip-testing:VisualSnapshotTests` | TEST SUCCEEDED | 0 | 3781 `passed` lines; the known flake did not occur |

All runs: no `: warning: ` line.

## Gates

Every gate printed its EXPECT value: model/parser/request/client greps (1, 1, 1, 5), copy `check` (`ok` for both keys; each catalog diff 41 insertions, 0 deletions), Task 3 greps (`tagName` 0 and 0, `showTagsSearchSuggestion` 0, `translateTags ? ... : [:]` 1, `myTagsAlias` 1, `clock.sleep` 1, `cancellable` 1), Task 4 greps (1, 1, 1, 1; nothing under SettingFeature changed), Task 5 greps (`numbersAndPunctuation` 1, `labelsHidden` 2, `accessibilityValue` 1, clamp 1, `weightFieldCommitted` 1). Lint `--strict` clean on every task's trees and on `App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension`. `app_storage_isolation.py check`: `0 break(s) of the app-storage isolation rule.` (before and after). `git diff 2df40b2f8 -- AppPackage | grep -cE '^\+.*(swiftlint:|\.serialized)'` prints 0; nothing changed under `AppPackage/Sources/SettingFeature` or `AppPackage/Package.swift`.

## Notes

- Precondition: `git status --short` showed three modified files from another session (`AGENTS.md`, `ReleaseNotes/README.md`, `Scripts/visual/README.md`), which the orchestrator told the executor to leave alone; they were never staged. Everything else in the precondition held (udx's three commits found, `deleteTagSet:` 5, no scratch test, no earlier symbols or keys, isolation gate clean).
- Each task's RED run was done once before the code, as the plan says.
- `.capture/261126-wzg/insert_copy.py` (S8) is gitignored and was not committed.

## Planner's choices P-1 to P-14 (as implemented)

P-1 five layered tasks; P-2 model, parser and request in their own files, call on `MyTagsClient`; P-3 `TagSuggestQuery` follows the site's rewrite; P-4 entries in id order, unknown entries left out, `login` and `error` throw; P-5 rows are the last answer narrowed to word-start matches; P-6 same text asks again; P-7 site rows first, then translation matches the site did not list, at most ten under one count header; P-8 Show Tag Suggestions no longer gates anything in this field (owner to note); P-9 a tap fills the field with the canonical tag and clears the rows; P-10 200 ms `continuousClock` debounce with `cancelInFlight`; P-11 reducer keeps `colorText`, spaces around a code are ignored while typing (also on the My Tags default colour field); P-12 a typed weight moves the Stepper at once, submit or leaving rewrites the text (owner to note); P-13 `canonical` and `RowID` names; P-14 copy inserted by script from CONTEXT.

## Owner's device checks (the live site needs the owner's signed-in account; not done by the executor)

On iPhone and on iPad (the sheet stacked over Settings), in Account, My Tags, a tag set, Add Tag:

1. Type `f:gl`: nothing shows until typing pauses, then the site's rows appear under the field (with Show Tag Suggestions off as well); typing on narrows them; with one character after the namespace (`f:g`) the site's rows go.
2. Type a tag known to be an alias: its row shows the canonical tag with the third line "Also known as ..." (in each language checked); a tap puts the canonical tag in the field.
3. Translate Tags on: the rows show translated names and local matches the site did not list follow the site's rows, without a tag listed twice; Translate Tags off: only the site's rows, by their own names.
4. With the device offline, typing shows no site rows and no alert.
5. Color: type `#1F3A9`: the footer turns red with the new sentence, the well keeps the old colour, the checkmark is disabled; finish the code: the footer and the checkmark return; type `#1F3A9` and press Done: the field returns to the last valid code. Same in Edit Tag.
6. Weight: type `150`: the Stepper's value jumps to 99, and Done or tapping elsewhere shows 99 in the field; clear the field and leave it: the last weight comes back; the Stepper's plus is disabled at 99 and its minus at -99; the keyboard offers the minus sign; VoiceOver reads the field and the Stepper as Weight.
7. Text size Accessibility 3 and 5: nothing in the Weight and Color rows clips or overlaps.
8. Confirm an added tag chosen from a suggestion: the tag lands in the set on the site's own My Tags page.

## Self-Check: PASSED

All five commits exist and are ancestors of HEAD; all created files exist; gates above match.
