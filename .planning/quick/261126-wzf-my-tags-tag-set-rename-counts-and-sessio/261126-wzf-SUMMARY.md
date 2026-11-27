---
phase: 261126-wzf-my-tags-tag-set-rename-counts-and-sessio
plan: 01
subsystem: my-tags
tags: [my-tags, rename-tag-set, expired-session, tca]
status: complete
requirements: [W-1, W-2, W-3, W-5, W-6]
actuals:
  tokens: 20000
  tasks: 4
  commits: 4
plan_head_before: 3a6558858009eb57cfc77ca6bb541a607e11468c
plan_head_after: 7f053cc2ceeed85829b7196872231a73692907bb
---

# Quick 261126-wzf Plan 01: My Tags tag set rename and the expired session Summary

Rename Tag Set row and alert (name filled in, not selected), a once-only rename request with an optimistic name and rollback, and an ended session shown as the page's existing Log In state, with a re-read after sign-in.

BASE: 3a6558858

## Commits

| Task | Hash | Subject | %G? %aI %cI |
|---|---|---|---|
| 1 | 152a876d2 | tags: ask the site to rename a tag set | G 2026-11-27T17:02:02+08:00 2026-11-27T17:02:02+08:00 |
| 2 | 398202d5a | settings: add Rename Tag Set to My Tags | G 2026-11-27T17:05:48+08:00 2026-11-27T17:05:48+08:00 |
| 3 | 3733d6247 | tags: report an expired session from the editor | G 2026-11-27T17:08:23+08:00 2026-11-27T17:08:23+08:00 |
| 4 | 7f053cc2c | settings: show Log In when My Tags is signed out | G 2026-11-27T17:10:38+08:00 2026-11-27T17:10:38+08:00 |

## Test runs (iPhone Air phase19 simulator, FeatureTests plan)

| Log | Targets | Result | Failed cases | New tests passed |
|---|---|---|---|---|
| task1-red | NetworkingFeatureTests | TEST FAILED, compile error `value of type 'MyTags' has no member 'renaming'` | n/a | n/a |
| task1-tests | AppModels, NetworkingFeature, SettingFeature, DetailFeature | SUCCEEDED | 0 | MyTagsRequestTests 17 names / 20 cases; MyTagsTests 15 / 23 |
| task2-red | SettingFeatureTests | TEST FAILED, 34 errors naming the rename symbols | n/a | n/a |
| task2-tests | SettingFeature, HomeFeature, AppTools | SUCCEEDED | 0 | MyTagsRenameTests 9 names / 13 cases |
| task3-red | DetailFeatureTests | TEST FAILED, errors at the two `\.delegate.signedOut` uses | n/a | n/a |
| task3-tests | NetworkingFeature, DetailFeature, SettingFeature | SUCCEEDED | 0 | MyTagsRequestTests 19 / 23; MyTagEditorTests 22 / 40 |
| task4-red | SettingFeatureTests | TEST FAILED, 5 errors naming `isSessionExpired` | n/a | n/a |
| task4-tests | SettingFeature, AppFeature | SUCCEEDED | 0 | MyTagsSessionTests 5 / 5 |
| full-plan | whole FeatureTests plan, `-skip-testing:VisualSnapshotTests` | SUCCEEDED | 0 | 3805 passed case lines; no warnings |

No intermittent failure (WaveFormReduceMotion, FavoritesFeature) occurred in any run.

## Gate notes (orchestrator-approved readings)

- Task 1 RED: the gate `grep -c RenameMyTagSetRequest` printed 0 instead of >=1. The run printed TEST FAILED and the only errors were at `MyTags.renaming(_:to:)` (a Task 1 symbol); AppModelsTests compiles before NetworkingFeatureTests, so the build stopped there. Accepted by the orchestrator (option 1).
- Task 3 RED: the gate `grep -c signedOut` printed 0 instead of >=1. The run printed TEST FAILED and the only errors were the key-path errors at the two `\.delegate.signedOut` uses in MyTagEditorTests (lines 313 and 325), which fail because `Delegate.signedOut` did not exist; the compiler words key-path failures without naming the case. Accepted by the orchestrator (option 1).
- Task 2 and Task 4 RED gates printed 34 and 5 (EXPECT >=1).
- Task 2 `insert_copy.py check` at HEAD raised `KeyError: 'my_tags.rename_tag_set'` as the plan's HEAD note says; after insert it printed `ok`; catalog diff `205 0`.

## Final gates

- Lint `--strict --quiet` on `App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension`: no output, exit 0.
- `app_storage_isolation.py check`: `0 break(s) of the app-storage isolation rule.`
- `git diff BASE -- AppPackage | grep -cE '^\+.*(swiftlint:|\.serialized)'`: 0.
- Picker invariant (`Picker|pickerStyle` lines changed in MyTagsView): 0.
- Scroll-edge: removed lines 0; `scrollEdgeEffectStyle(.soft, for: .top)` count in MyTagsView: 2.
- `git diff --stat BASE -- AppPackage/Package.swift EhPanda.xcodeproj App ShareExtension`: no output.
- Per-task grep gates all printed their EXPECT values (Task 1: 1, 3, 5, 1, 1; Task 2: 1 each of seven; Task 3: 1, 1, 3; Task 4: 5, 1, 1, 1, 1).

## Deviations from Plan

None in the code. The precondition's note that `git status --short` may show other-session files did not apply: the tree was clean at start. Two RED gates missed their named symbol for the reasons above, accepted by the orchestrator.

## Known Stubs

None.

## Owner's device checks (live site needs the owner's account)

On iPhone and iPad, in Account, My Tags:

1. Tap Rename Tag Set...: the alert shows the set's name, focused, not selected, with the cursor at its end (P-7); Rename is disabled while the field is empty, spaces only or the same name. Rename: the picker shows the new name at once, and the site's own My Tags page shows it too.
2. Rename with the device offline: the old name returns and "Couldn't Rename Tag Set" shows with the error. Rename to a name the site rejects or changes (for example a very long one): note what the site answers and what the app shows (P-9).
3. While a rename is on its way, New Tag Set, Rename Tag Set and Delete Tag Set are disabled.
4. Text size Accessibility 3 and 5: the Rename row does not clip or overlap.
5. If the site can be made to end the session while the app keeps its cookies (for example by signing out of the site in a browser with the same session): switch tag sets or toggle Enabled; the page shows Log In, with no alert; Log In, sign in, and the page reads every set again. In Edit Tag, Save: the sheet keeps its alert; close it: Log In is beneath (P-15).
6. In the same state, a form write (Enabled, New Tag Set, Rename): note whether the page shows Log In or the error; the error means the site's signed-out answer to a form post is a page the existing detection does not know (P-17).

## Planner readings (as executed)

- P-1 four layered tasks, one green commit each.
- P-2, P-3 withdrawn (no tag count, parser unchanged).
- P-4 rename put on the wire once (`attempts: 1`), documented on the request and in the file header.
- P-5 `MyTagsClient.renameTagSet(host, name, tagSet)` mirrors create.
- P-6 `AppAlertTextFieldState.editedValue` holds Rename while the trimmed text is the set's name.
- P-7 not selected: no selection machinery; the owner checks the cursor lands at the end.
- P-8 names compared trimmed; the trimmed name is sent and shown.
- P-9 the answer page is taken first; success needs the same set id, no `#msg`, and the new name; otherwise the alert, with the old name restored when the page shows another set or the request failed. Owner should note what the site actually answers.
- P-10 row disabled by the shared `isChangingTagSets` flag; both alerts attach to the Rename row; the reducer refuses blank, unchanged, in-flight and not-shown-set renames.
- P-11, P-12 withdrawn (picker untouched, no count copy).
- P-13 only the edit API's `login` answer (any value but null) fails as `loginRequired`; no new AppError case.
- P-14 `isSessionExpired` is `loadingState == .failed(.loginRequired)`; a write failing as `loginRequired` sets it instead of an alert.
- P-15 Edit Tag keeps its alert and sends `Delegate.signedOut`; Log In shows beneath once the sheet closes.
- P-16 Settings' `loginDone` also sends `fetchMyTags` to every My Tags page on the stack.
- P-17 form pages keep the existing signed-out detection; no new marker; the owner's account settles whether it is enough.
- P-18 new test files `MyTagsRenameTests` and `MyTagsSessionTests`.
- P-19 copy inserted by script from CONTEXT's table, no retyping.

## Self-Check: PASSED

All four commits exist (`git log` verified, signed, +08:00); the new files `MyTagsRenameTests.swift` and `MyTagsSessionTests.swift` exist; the five copy keys check `ok`.
