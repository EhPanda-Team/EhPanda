---
phase: 261126-pfh-add-a-new-tag-set-action-to-the-native-m
plan: 01
subsystem: settings
tags: [my-tags, tag-set, app-alert, form-post, tca]
requires:
  - phase: 261122-fv8
    provides: native My Tags page, UpdateMyTagSetRequest, MyTagsClient
provides:
  - AppAlertTextFieldState.requiresText holds every non-cancel alert button until the field has text
  - CreateMyTagSetRequest and MyTagsClient.createTagSet, posted once
  - New Tag Set row, alert, create and choice of the new set on the My Tags page
affects: [my-tags, app-alert]
tech-stack:
  added: []
  patterns:
    - shared text-field alert option instead of a local workaround
    - a non-idempotent write is put on the wire once (attempts: 1)
key-files:
  created: []
  modified:
    - AppPackage/Sources/AppComponents/AppAlertState.swift
    - AppPackage/Sources/NetworkingFeature/Request+MyTags.swift
    - AppPackage/Sources/MyTagsClient/MyTagsClient.swift
    - AppPackage/Sources/AppModels/Tags/MyTags.swift
    - AppPackage/Sources/SettingFeature/MyTags/MyTagsFeature.swift
    - AppPackage/Sources/SettingFeature/MyTags/MyTagsView.swift
    - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
    - AppPackage/Tests/NetworkingFeatureTests/MyTagsRequestTests.swift
    - AppPackage/Tests/AppModelsTests/MyTagsTests.swift
    - AppPackage/Tests/SettingFeatureTests/MyTagsFeatureTests.swift
key-decisions:
  - "The create is posted with attempts: 1 (a replayed create could make a second set)."
  - "applying(_:) already keeps the page's own set, so reading the new set through fetchTagSet puts it in the picker with no code change."
requirements-completed: [N-1, N-2, N-3, N-4, N-5, N-6, N-7, N-8, N-9]
status: complete
commits: 3
plan_head_before: 4d9225271
plan_head_after: 25ec1d42e
actuals:
  tokens: 0
  tasks: 3
  commits: 3
---

# Quick 261126-pfh: New Tag Set on the native My Tags page Summary

The My Tags tag set section ends with a tint-coloured New Tag Set row that opens the app's native name alert; Create posts the site's create form once, then the page chooses the new set, reads it and shows the empty tags state.

`actuals.tokens` is 0 because the realized diff was not measured on the plan's chars/4 scale; the three commits are measured from the ledger base.

## Commits (all signed, author and committer dates +08:00)

| Task | Hash | `%G? %aI %cI` | Subject |
|------|------|---------------|---------|
| 1 | `5e04270d1` | `G 2026-11-26T17:54:26+08:00 2026-11-26T17:54:26+08:00` | alert: hold buttons until a field has text |
| 2 | `1f93c36ed` | `G 2026-11-26T18:01:46+08:00 2026-11-26T18:01:46+08:00` | tags: ask the site to create a tag set |
| 3 | `25ec1d42e` | `G 2026-11-26T18:12:00+08:00 2026-11-26T18:12:00+08:00` | settings: add New Tag Set to My Tags |

Nothing pushed. Start HEAD `4d9225271`.

## What changed

- **AppAlertState (N-3, P-1).** `AppAlertTextFieldState.requiresText` (default off) and the pure `enablesButton(role:text:)`; the modifier reads the bound text in its own body and disables each button the field holds. The page jump is unchanged.
- **CreateMyTagSetRequest (N-4, P-7).** Posts `tagset_action=create`, the trimmed name, `tagset_enable=on` only when the shown set is enabled, and `tagset_color`, in the browser's order, to the shown set's `/mytags` page, with `attempts: 1`. `postMyTagsForm` gained `attempts` (default 4). `MyTagsClient.createTagSet` exists in `live`, `noop`, `unimplemented` and `failing(_:)`.
- **MyTags model (N-6).** Doc comment and a test for `applying(_:)`; its code is unchanged.
- **MyTagsFeature and MyTagsView (N-1, N-2, N-5).** The New Tag Set row, the `newTagSetAlert` presentation, `newTagSetName`, `isCreatingTagSet`, `createTagSetDone(knownTagSetIDs:result:)`, `AlertSource.newTagSet`, and `fetchTagSet(_:host:)` taking an id. Both alerts attach to the row.
- **Copy.** Six keys in SettingFeature's `Localizable.xcstrings`, inserted by script from CONTEXT's table (246 insertions, 0 deletions; the script's `check` prints `ok`).

## Test runs

All on `EhPanda iPhone Air (phase19)`, one `xcodebuild test` at a time (waited for another project's runs; nothing killed). Logs are under `.capture/261126-pfh/` (gitignored).

| Log | Targets | Result | Failed cases | Warnings |
|-----|---------|--------|--------------|----------|
| `task1-tests.log` | HomeFeatureTests, SystemNotificationTests, AppToolsTests | TEST SUCCEEDED (335 cases passed) | 0 | none |
| `task2-red.log` | NetworkingFeatureTests | RED: `cannot find 'CreateMyTagSetRequest' in scope` (plus the `==` ambiguity below) | n/a | n/a |
| `task2-tests.log` | NetworkingFeatureTests, AppModelsTests, SettingFeatureTests, DetailFeatureTests | TEST SUCCEEDED | 0 | none |
| `task3-red.log` | SettingFeatureTests | RED: `MyTagsFeature.Action` has no member `newTagSetTapped`, and similar | n/a | n/a |
| `task3-tests.log` | SettingFeatureTests, AppToolsTests | TEST SUCCEEDED (after the three test fixes below; the first run had 3 failed cases) | 0 | none |
| `full-plan.log` | FeatureTests plan, `-skip-testing:VisualSnapshotTests` | TEST SUCCEEDED (3663 cases passed) | 0 | none |

The known flake (`cookieLoginTriggersReloadWithoutAViewCallback`) did not occur, so no re-run of `FavoritesFeatureTests` was needed.

New tests seen as passed: `MyTagsRequestTests/aTagSetCreatePostsTheShownSetsFormWithTheNameInOrder`, `MyTagsRequestTests/aTagSetCreateIsNotRetriedAfterATransportFailure`, `MyTagsTests/aPageOfASetTheCacheLacksTakesItsPlaceInThePickersOrder`, and in `MyTagsFeatureTests`: `theRowOpensTheAlertWithAnEmptyName`, `createWaitsForANameAndCancelNeverWaits`, `aNameIsPostedAndTheNewSetIsChosenAndRead`, `aRefusedCreateShowsTheSitesReasonOnTheRowAndChoosesNothing`, `aCreateWhoseAnswerListsNoNewSetShowsTheUnknownError`, `aFailedCreateShowsTheErrorOnTheRowAndChoosesNothing`, `aCreateWhoseAnswerListsTwoNewSetsReadsEverySetAgain`, `aBlankNameSendsNothing(name:)` (three arguments), `aSecondCreateWhileOneIsOnItsWaySendsNothing`. Distinct-name counts: `MyTagsRequestTests` 12, `MyTagsTests` 12, `MyTagsFeatureTests` 24. The `PointerHoverAuditTests` cases passed unchanged.

## Gates

- Lint: `swiftlint lint --strict --quiet` on each task's trees, and on `App AppPackage/Sources AppPackage/Tests EhPandaUITests ShareExtension` after Task 3: no output, exit 0.
- Invariant: `git diff 4d9225271 -- AppPackage | grep -cE '^\+.*(swiftlint:|\.serialized)'` prints `0` (the plan's base `12d91afcf` differs from `4d9225271` by planning documents only).
- Task 1 greps: `requiresText` 1, `enablesButton` 1, `.disabled(!Self.enables(...))` 1.
- Task 2 greps: `CreateMyTagSetRequest` 1, `attempts: 1` 1, `attempts: attempts` 1, `createTagSet:` in the client 5, doc phrase 1, `MyTags.swift` numstat `4 2`.
- Task 3 greps: `.appAlert(` 5, `Button(.myTagsNewTagSet)` 1, `fetchTagSet(state.selectedTagSetID, ...)` 2, old `fetchTagSet(_ state: State)` 0, `requiresText: true` 1, `AppError.unknown.alertText` 1, `case newTagSet` 1; `insert_copy.py check` prints `ok`; catalog numstat `246 0`.

## Deviations from Plan

All three are in plan-provided test code; no production code deviated. The first was within the orchestrator's narrow pre-authorisation for inference fixes; the second and third were explicit orchestrator decisions.

**1. [Test inference] S9a, `aTagSetCreatePostsTheShownSetsFormWithTheNameInOrder`**
- **Error:** `MyTagsRequestTests.swift:191:63: error: ambiguous use of operator '=='` (array literal on both sides; the compiler lists `IndexPath.==` and `IndexSet.==` among the candidates).
- **Before:** `#expect([first.tagSet.id, second.tagSet.id] == [2, 2])`
- **After:** `#expect(first.tagSet.id == 2)` and `#expect(second.tagSet.id == 2)`
- **Commit:** `1f93c36ed`

**2. [Test expectations] S8c, `aNameIsPostedAndTheNewSetIsChosenAndRead` and `aCreateWhoseAnswerListsTwoNewSetsReadsEverySetAgain`**
- **Failure:** `$user` is a shared reference, so each step's closure already saw the later read's answer ("A state change does not match expectation": the actual cache already held set 3, or sets 3 and 4, at the `createTagSetDone` step).
- **Fix (orchestrator decision), following `presentingSignedInReadsEveryTagSetAndKeepsTheChoice`:** in both tests added, right after the store is made, the comment "The cache is a shared reference, so a step's closure would already see the later read's answer; the cache is checked at the end, as the presenting test does." and `store.exhaustivity = .off`; deleted every `$0.$user.withLock(...)` line from the step closures (kept every other line); after the last receive added the end-state check.
  - First test, after: `#expect(store.state.user.myTags == MyTags(tagSets: [Self.set1, Self.set2, Self.set3], selectedTagSetID: 3))` (before the existing `#expect`s). Removed lines: `$0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2], selectedTagSetID: 3) })` in the `createTagSetDone` closure and `$0.$user.withLock({ $0.myTags = MyTags(tagSets: [Self.set1, Self.set2, Self.set3], selectedTagSetID: 3) })` in the `fetchTagSetDone.success` closure.
  - Second test, after: `#expect(store.state.user.myTags == everySet)`, the value of the plan's last `$user` assignment in that test (`$0.$user.withLock({ $0.myTags = everySet })`, removed from the `fetchMyTagsDone.success` closure). The test had no explicit selection assertion, so none was added; its no-selection result (`selectedTagSetID: nil`) is part of `everySet`'s equality.
- **Commit:** `25ec1d42e`

**3. [Test expectations] S8c, `aBlankNameSendsNothing(name:)`**
- **Failure (the `""` argument only):** "Expected state to change, but no change occurred" at `.newTagSetNameChanged("")`, because the name is already `""` after `newTagSetTapped`.
- **Before:** one `await store.send(.newTagSetNameChanged(name)) { $0.newTagSetName = name }` for every argument.
- **After (orchestrator decision):** all three arguments kept; under the comment "The empty name is already the alert's starting value, so that send changes nothing.", `if name.isEmpty { await store.send(.newTagSetNameChanged(name)) } else { await store.send(.newTagSetNameChanged(name)) { $0.newTagSetName = name } }`.
- **Commit:** `25ec1d42e`

No auth gates. No stubs: the New Tag Set row and alert are fully wired, and nothing was added to `.planning/WINDOWS.md`.

## Owner's device check (N-9)

Not done by the executor: it needs the owner's signed-in account and changes it on the site. On iPhone (Setting tab) and on iPad (Settings sheet), open Account, My Tags:

- The tag set section ends with New Tag Set.
- It opens the alert with the keyboard up and the Name field focused.
- Create stays disabled until a name is typed (spaces alone keep it disabled).
- Create shows the loading view, then the new set is selected in the picker under the name the site gives it, with Enabled and the colour as the site set them, and its tags section shows No Tags Yet with Add Tag.
- The set appears on the site's own My Tags page.
- Also worth noting there: which page the site answered the create with, and any limit it reports.

## Planner's choices (P-1 to P-11)

- **P-1** Option `requiresText` plus pure `enablesButton(role:text:)` on `AppAlertTextFieldState`; the modifier calls it per button.
- **P-2** The name binds through `$store.newTagSetName.sending(\.newTagSetNameChanged)`, not `BindableAction`.
- **P-3** The name alert is its own `@Presents newTagSetAlert`; its failure alert goes through the page's `alert` with `AlertSource.newTagSet`; both `.appAlert` modifiers sit on the row.
- **P-4** The cache's ids are captured when Create is handled and carried in `createTagSetDone(knownTagSetIDs:result:)`.
- **P-5** No new id and no `#msg` shows `AppError.unknown`'s text (the page was read, so not `.parseFailed`; it is not empty, so not `.notFound`).
- **P-6** More than one new id (CONTEXT N-5a, confirmed by the orchestrator): nothing is chosen, no failure alert, and every set is read again with `fetchMyTags`. Not covered by CONTEXT's original N-5.
- **P-7** `CreateMyTagSetRequest(host:name:shownTagSet:urlSession:)`; `postMyTagsForm` gained `attempts` (default 4), and the create passes 1.
- **P-8** The reducer refuses a blank trimmed name and a second create while one is on its way.
- **P-9** A `#msg` together with a new id fails the create; nothing is chosen.
- **P-10** The copy was inserted by script from CONTEXT's table, not retyped.
- **P-11** Three layered tasks with one green commit each, not a tracer.

## Note on component tests

`appAlert` has no component test of its kind (no AppComponents test target; settled fact 7), so the `requiresText` rule is pinned through the My Tags alert test `createWaitsForANameAndCancelNeverWaits`, its one user.

## Self-Check: PASSED

- Commits `5e04270d1`, `1f93c36ed` and `25ec1d42e` are ancestors of HEAD, each `G` with two `+08:00` instants.
- `git status --short` is clean; the six copy keys check `ok`.
