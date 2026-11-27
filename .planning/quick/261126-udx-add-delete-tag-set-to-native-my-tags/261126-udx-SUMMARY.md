---
phase: 261126-udx-add-delete-tag-set-to-native-my-tags
plan: 01
subsystem: settings
tags: [my-tags, tag-set, delete, parser, networking, tca]
requirements: [U-1, U-2, U-3, U-4, U-5, U-6, U-7, U-8, U-9]
status: complete
commits: 3
plan_head_before: a747a420948182860a6b55ddaf49d42e5511c7aa
plan_head_after: 3e9c18732
key-files:
  created:
    - AppPackage/Sources/TestingSupport/Resources/Parser/Other/MyTagsTagSet3.html
  modified:
    - AppPackage/Sources/AppModels/Tags/MyTags.swift
    - AppPackage/Sources/ParserFeature/Parser+MyTags.swift
    - AppPackage/Sources/TestingSupport/HTMLFilename.swift
    - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift
    - AppPackage/Sources/MyTagsClient/MyTagsClient.swift
    - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift
    - AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift
    - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
    - AppPackage/Tests/AppModelsTests/MyTagsTests.swift
    - AppPackage/Tests/ParserFeatureTests/Other/MyTagsParserTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift
    - AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift
---

# Quick 261126-udx: Delete Tag Set on the native My Tags page Summary

Delete Tag Set is on the My Tags page for exactly the sets whose page offers it (read from the page's tag set form, kept in memory only), behind a confirmation, posted once, landing on the site's first set.

BASE: a747a4209. Nothing pushed. SUMMARY and STATE.md are left uncommitted for the orchestrator.

## Commits

All three are signed (`%G?` = G) with author and committer dates at +08:00, no body, no attribution.

| Task | Hash | Subject | `%aI` and `%cI` |
|------|------|---------|-----------------|
| 1 | 6b4efb6cf | tags: read whether a tag set can be deleted | 2026-11-27T14:28:49+08:00 |
| 2 | 15dc3d032 | tags: ask the site to delete a tag set | 2026-11-27T14:31:17+08:00 |
| 3 | 3e9c18732 | settings: add Delete Tag Set to My Tags | 2026-11-27T14:37:59+08:00 |

`commits: 3` is measured (`git rev-list --count` from BASE to HEAD).

## Test runs

Logs are in `.capture/261126-udx/` (gitignored). Device: EhPanda iPhone Air (phase19), plan FeatureTests.

| Run (log) | Targets | Result | Failed cases | Warnings |
|-----------|---------|--------|--------------|----------|
| task1-red | ParserFeatureTests, AppModelsTests | compile error: extra argument 'isDeletable' | n/a | n/a |
| task1-tests | ParserFeatureTests, AppModelsTests, NetworkingFeatureTests, SettingFeatureTests, DetailFeatureTests | TEST SUCCEEDED | 0 | 0 |
| task2-red | NetworkingFeatureTests | compile error: cannot find 'DeleteMyTagSetRequest' | n/a | n/a |
| task2-tests | NetworkingFeatureTests, SettingFeatureTests, DetailFeatureTests, DownloadsFeatureTests | TEST SUCCEEDED | 0 | 0 |
| task3-red | SettingFeatureTests | compile error: 'DeleteTagSetDialog' is not a member type of MyTagsFeature | n/a | n/a |
| task3-tests | SettingFeatureTests, AppToolsTests | TEST FAILED (one unrelated case, see below) | 1 | 0 |
| task3-rerun | SettingFeatureTests, AppToolsTests | TEST SUCCEEDED | 0 | 0 |
| full-plan | whole FeatureTests plan, `-skip-testing:VisualSnapshotTests` | TEST SUCCEEDED | 0 | 0 |

New tests seen as passed:
- Task 1: `aPageWithTheDeleteControlOffersDeletingItsSet`, `aPageWithoutTheDeleteControlOffersNoDelete(filename:)` (two arguments), `aPageWhoseDeleteControlIsDisabledOffersNoDelete`, `aPagesDeleteOfferReplacesItsSetsAndTheOtherSetsKeepTheirs`, `aSetsDeleteOfferIsNeverStoredAndAStoredSetDecodesWithoutIt`. Distinct names: MyTagsParserTests 10 (HEAD 7), MyTagsTests 14 (HEAD 12).
- Task 2: `theFetchKeepsEachSetsDeleteOffer`, `aTagSetDeletePostsTheSetsFormInOrder`, `aTagSetDeleteIsNotRetriedAfterATransportFailure`. MyTagsRequestTests distinct names: 15 (HEAD 12). The existing update and create body tests still pass.
- Task 3: `theDeleteRowShowsOnlyWhileTheShownSetsPageOffersIt`, `theDeleteRowOpensTheConfirmationAndCancelSendsNothing`, `aConfirmedDeleteChoosesTheFirstSetTheAnswerShows`, `aConfirmedDeleteReadsTheFirstSetWhenTheAnswerShowsAnother`, `aRefusedDeleteShowsTheSitesReasonOnTheRowAndKeepsTheSet`, `aRefusalThatWithdrawsTheOfferKeepsTheRowUntilItsAlertIsDismissed`, `aDeleteWhoseAnswerStillListsTheSetShowsTheUnknownError`, `aFailedDeleteShowsTheErrorOnTheRowAndKeepsTheSet`, `aDeleteWhileACreateOrADeleteIsOnItsWaySendsNothing`, `aDeleteOfASetNotShownOrNotOfferedSendsNothing(shownTagSetID:confirmedTagSetID:)`. MyTagsFeatureTests distinct names: 34 (HEAD 24). PointerHoverAuditTests unchanged and passing.

The full-plan run printed 3689 passed cases. The Favorites login-return flake did not occur.

## Gate outputs

- Lint, per task trees (Task 1, Task 2, Task 3): no output, exit 0.
- Lint over `App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension`: no output, exit 0.
- Invariant `git diff a747a4209 -- AppPackage | grep -cE '^\+.*(swiftlint:|\.serialized)'`: 0.
- Task 1 greps: `isDeletable = false` 1, `CodingKeys` 1, XPath 1, `isDeletable: offersDelete` 1, fixture control 1, `HTMLFilename` case 1.
- Task 2 greps: `DeleteMyTagSetRequest` 1, `attempts: 1)` 2, `URLQueryItem(name: "tagset_action"` 1, `tagSetFormFields(` 4, `deleteTagSet:` 5 in the client.
- Task 3 greps: `insert_copy.py check` ok, catalog diff 123 insertions and 0 deletions, `isCreatingTagSet` 0, and every view and feature pattern 1 (`AppError.unknown.alertText` 2, as expected).
- `git status --short` after the commits shows only AGENTS.md, ReleaseNotes/README.md and Scripts/visual/README.md, which are other sessions' edits and were never staged or touched.

## Deviations from Plan

None to the code or the plan's shapes: every Swift, HTML and Python block was copied from the plan by script. Three process notes:

1. **Task 3's first green run had one unrelated failure.** `WaveFormReduceMotionTests/underReduceMotionTwoRendersAtDifferentTimesAreIdentical()` (SettingFeatureTests, an ImageRenderer pixel comparison 250 ms apart) failed once in `task3-tests.log`. It passed in the Task 1 run, the Task 2 run, the `task3-rerun` run and the full-plan run. Task 3 touches nothing it uses. I stopped and asked the orchestrator, who approved one re-run, which passed. This looks like an intermittent failure under load. I did not read an xcresult assertion text for it, because no later run failed.
2. **Task 1's RED step.** I wrote the Task 1 source before running the RED build by mistake, so I saved it as a patch, reverted the three source files, ran the RED build (compile error as expected), then re-applied the patch unchanged. The committed content is exactly the plan's.
3. **An earlier handback was sent by mistake** with placeholder text. It carried no content and is superseded by the stop report and this SUMMARY.

Plan latitude used: none (no comment re-wrapping was needed).

## Known Stubs

None.

## Threat Flags

None. No new endpoint beyond the planned form post of the delete, no new storage, no dependency change (`AppPackage/Package.swift` untouched).

## Decisions Made (planner's choices P-1 to P-10 as carried out)

- P-1: `MyTagSet.isDeletable`, in memory, left out of `CodingKeys`, so the stored shape is unchanged and a set read back from storage offers nothing (tested by the encoded keys).
- P-2: the control is any element under `div#tagset_outer` whose `onclick` contains `do_tagset_delete(` and that has no `disabled` attribute.
- P-3: fixture `MyTagsTagSet3.html` (set 3, "Fixture Holds", empty), synthetic, because no page with the control has been read; `HTMLFilename` says so.
- P-4: `DeleteTagSetDialog.delete(tagSetID:)` names the set the confirmation was opened for; a delete is sent only if that set is still shown and still offered.
- P-5: `isCreatingTagSet` became `isChangingTagSets`, one flag for both rows and both requests.
- P-6: one fileprivate `tagSetFormFields(action:name:isEnabled:color:)` builds the update, create and delete bodies; the existing body tests pin update and create byte for byte.
- P-7: the site's first set is `page.tagSetIDs.first ?? page.tagSet.id`.
- P-8: a "still listed, no `#msg`" answer shows `AppError.unknown.alertText`.
- P-9: the three copy keys were inserted by `insert_copy.py` from CONTEXT's table; nobody retyped copy.
- P-10: three layered tasks with one green commit each, no tracer.
- U-1a (disabled control is not an offer): `[not(@disabled)]` in the XPath, with a parser test on an inline variant of `MyTagsTagSet3`.
- U-2a (row kept while its own failure alert is up): `showsDeleteTagSetRow` is `canDeleteTagSet || (alertSource == .deleteTagSet && alert != nil)`; the row is disabled when not offered; `aRefusalThatWithdrawsTheOfferKeepsTheRowUntilItsAlertIsDismissed` covers it.

## Owner's device check (U-9)

Not done by the executor, because it needs the owner's signed-in account and deletes a set on the site. On iPhone (Setting tab) and on iPad (Settings sheet), open Account, My Tags.

1. Note for which sets the tag set section shows Delete Tag Set after New Tag Set, and that it matches the sets whose site page shows an enabled Delete button (U-1a).
2. On an offered set, tap it. The confirmation shows "Delete this tag set?" with Delete and Cancel (on iPad a popover pointing at the row; a tap outside cancels). Cancel changes nothing.
3. Delete. The set leaves the picker and the site's first set is shown (after the loading view if the site answered with another page), and the set is gone from the site's own My Tags page.
4. Also note which page the site answered the delete with, and any refusal wording it shows.

## Self-Check: PASSED

- Created and modified files exist (`git show --stat` of the three commits lists exactly the planned files: 6, 3 and 4).
- Commits 6b4efb6cf, 15dc3d032 and 3e9c18732 are ancestors of HEAD.
