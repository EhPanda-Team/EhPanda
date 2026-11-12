---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "05"
subsystem: comment-moderation
tags: [moderation, ugc, tca, reducer, swift-testing]

requires: ["18-04"]
provides:
  - "`CommentModerationFeature` (DetailFeature/Moderation/CommentModeration.swift): the per-screen moderation child, scoped as `moderation` into `CommentsReducer` and `DetailReducer`"
  - "`postTapped` on both reducers: the filter decides before anything is sent; the reducer, not the view, closes the editor (D-12, P-8)"
  - "Moderation actions for the views: `.moderation(.reportTapped(comment))`, `.blockTapped(comment)`, `.unblock(author:)`, `.show(commentID:)`, `.hide(commentID:)`, and the alert actions `edit`, `postAnyway`, `confirmReport(URL)`, `confirmBlock(author:)`"
  - "State helpers for the views: `moderation.isCollapsed(_:)`, `moderation.isBlocked(_:)`, `moderation.alert` (an `AppAlertState`), `moderation.blockedAuthors`, `moderation.revealedCommentIDs`"
  - "`Destination.reportPage(URL)` on `CommentsReducer` and `DetailReducer`: the report sheet's route (A-5)"
  - "`DependencyValues.commentFilterTerms`: the filter list as a dependency (live and test value: the bundled list)"
affects: [18-11, comment-moderation]

actuals:
  tokens: 60000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "One moderation child reducer scoped into two hosts; the host owns the editor and sheets and reacts to the child's delegate actions"
    - "Reducer tests that reach a real request type use an unsupported-scheme gallery URL, so the request fails at once without the network"

key-files:
  created:
    - AppPackage/Sources/DetailFeature/Moderation/CommentModeration.swift
    - AppPackage/Tests/DetailFeatureTests/CommentModerationReducerTests.swift
  modified:
    - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
    - AppPackage/Sources/DetailFeature/DetailReducer.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Actions.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
    - AppPackage/Tests/DetailFeatureTests/CommentsReducerTests.swift

key-decisions:
  - "Alerts use the existing `AppAlertState`, not TCA `AlertState`. UI-SPEC allows either but wants one mechanism per screen, and Detail already presents `AppAlertState` through `.appAlert`. Button roles and texts are the same `ButtonState`/`TextState`"
  - "The reducer is named `CommentModerationFeature` (AGENTS.md `Feature` suffix) and lives in the plan's file `CommentModeration.swift`"
  - "A gallery with no report target gets no Report alert at all, not only no sheet: Open would have nowhere to go. In practice every parsed gallery URL is on e-hentai.org or exhentai.org. Owner to confirm (see Decisions)"
  - "The report URL travels in the alert's button action (`confirmReport(URL)`), so the sheet opens exactly the page the alert was built for"
  - "Blocking an author collapses every one of their comments on the screen, revealed ones included: the host drops their IDs from `revealedCommentIDs` on the child's `didBlock` delegate (C-4). Without this, a comment revealed, unblocked and blocked again would stay open"
  - "Own comments: an `editable` comment is own without reading anything else; otherwise `CommentOwnership.isOwn` gets `cookieClient.didLogin` and `@SharedReader(.user).displayName`"
  - "Post order: `.concatenate(.send(.postComment(…)), .send(.destination(.dismiss)))`, so the request action starts before the editor closes. Detail without a gallery URL only closes the editor, as the view did"

patterns-established:
  - "Moderation decisions live in `CommentModerationFeature`; hosts translate its delegates (`post`, `resumeEditing`, `openReportPage`, `didBlock`) into their own editor and sheet state"

requirements-completed: [UGC-18-01]

coverage:
  - id: D1
    description: "Posting warning on the comments screen (new comment and edit) and Detail: no request before the decision, Edit keeps text and sheet and refocuses, Post Anyway sends then closes, no match posts as before"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "DetailFeatureTests/CommentModerationReducerTests (posting cases) and CommentsReducerTests/postClosesTheEditorAfterSending"
        status: pass
    human_judgment: false
  - id: D2
    description: "Report: alert with site and author, then the report sheet destination with ?report=select; cancel and no-target present nothing"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "DetailFeatureTests/CommentModerationReducerTests (report cases, comments screen and Detail)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Block once, collapse every comment by the author, unblock without alert, show one comment once, hide, reveal never stored"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "DetailFeatureTests/CommentModerationReducerTests (block, unblock, show, hide cases)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Own comments (Edit link or signed-in name) get no Report or Block; no moderation action sends an analytics signal"
    requirement: UGC-18-01
    verification:
      - kind: unit
        ref: "DetailFeatureTests/CommentModerationReducerTests/ownCommentsGetNoReportOrBlock, moderationSendsNoAnalyticsSignal"
        status: pass
    human_judgment: false

duration: 28 min
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 05: Comment moderation reducers Summary

**The comments screen and Detail now make every moderation decision in a shared `CommentModerationFeature`. Posting
checks the filter before anything is sent, and Report, Block, Unblock, Show and Hide are reducer actions with tests.
The views switch to these actions in 18-11.**

## Performance

- **Duration:** 28 min (Step 0 included)
- **Started:** 2026-11-05T08:30Z
- **Completed:** 2026-11-05T08:58Z
- **Tasks:** 2
- **Files modified:** 7 (2 created, 5 modified)

## Accomplishments

- **Posting warning (D-12, P-8):**
  - `CommentsReducer.postTapped` and `DetailReducer.postTapped` replace the views' "send, then dismiss".
  - A match presents the warning (`comment.filter.*`): Edit has the cancel role and Post Anyway has no role. Nothing
    is sent, the editor stays open and the text is unchanged.
  - Edit closes the alert and gives the editor focus again. Post Anyway sends the request (`EditGalleryCommentRequest`
    for an edit) and then closes the editor.
  - Text that doesn't match posts and closes as before.
- **Report (D-10, A-5):** `reportTapped(comment)` presents "Report this comment?", whose message names the site
  (`E-Hentai`/`ExHentai`) and the author. Open presents `Destination.reportPage(https://<host>/g/<gid>/<token>/?report=select)`.
  Cancel does nothing. A gallery with no report target presents nothing.
- **Block, Unblock, Show, Hide (D-13, C-4, C-6, C-7):**
  - `blockTapped(comment)` presents "Block <author>?" with a destructive Block button. Confirming adds the author to
    `@Shared(.blockedCommentAuthors)` once. Every comment of theirs then reports `isCollapsed == true`.
  - `unblock(author:)` removes the author at once, with no alert.
  - `show(commentID:)` and `hide(commentID:)` toggle a per-screen `revealedCommentIDs` set that is never stored.
    Another comment by the same author stays collapsed.
- **Own comments (A-10):** `reportTapped` and `blockTapped` are ignored for an `editable` comment and for one whose
  author is the signed-in display name.
- **Analytics (D-02):** the child has no analytics dependency, and a spy test runs every moderation action and finds
  no signal. No new signal was added.

## Task Commits

1. **Task 1: Posting warning on both post paths:** `56678d9c1` (feat)
2. **Task 2: Report, block, unblock, show once:** `8259ef9e4` (feat)

TDD: Task 1's tests were written first and run red. With the implementation set aside, the build failed with
`type 'CommentsReducer.Action' has no member 'postTapped'` and `value of type 'CommentsReducer.State' has no member
'moderation'`. Each task was committed once, with tests and code together, as in 18-04.

## Files Created/Modified

- `DetailFeature/Moderation/CommentModeration.swift`: the moderation child (state, alerts, delegates, ownership check),
  `collapseComments(by:in:)`, and the `commentFilterTerms` dependency.
- `DetailFeature/Comments/CommentsReducer.swift`: `moderation` state and scope, `postTapped`, `Destination.reportPage`,
  and the delegate handling.
- `DetailFeature/DetailReducer.swift`: `moderation` state and scope, `postTapped`/`moderation` actions,
  `Destination.reportPage`, and the `commentFilterTerms` dependency.
- `DetailFeature/DetailReducer+Fetch.swift`: Detail's `postTapped`, the post delegates and `postAndDismiss`.
- `DetailFeature/DetailReducer+Actions.swift`: the report-sheet and block delegates.
- Tests: `CommentModerationReducerTests` (20 functions, 23 cases) and `CommentsReducerTests/postClosesTheEditorAfterSending`.

## Decisions Made

See `key-decisions` above. One needs the owner's confirmation:

- **@owner: no Report alert for a gallery with no report target.** The plan's must-have says "nothing is presented
  when the URL is nil". It is applied at the menu tap, so the alert doesn't appear either: its Open button would lead
  nowhere. Research §5.2 mentions a `{site}` fallback to `setting.galleryHost` for an unrecognised host. 18-04 made
  such a gallery have no target (T-18-09), so the fallback has no use. Every gallery the parser produces is on
  e-hentai.org or exhentai.org, so users should never see this. If the owner wants the Report item hidden instead,
  that is a view change in 18-11.

Technical decisions, no product impact:
- `AppAlertState` instead of TCA `AlertState` (one alert mechanism per screen; Detail already uses it).
- The reducer is named `CommentModerationFeature`, per AGENTS.md.
- The filter list is a dependency (`commentFilterTerms`), so tests inject a one-term list.
- A block re-collapses that author's revealed comments on the screen.
- `revealedCommentIDs` is per screen. Detail and the comments screen each have their own, so a comment shown in one
  stays collapsed in the other ("the reveal lasts until the comment leaves the screen", C-7).

## Deviations from Plan

1. **Alert type.** The plan's actions say TCA `AlertState`. UI-SPEC (Component library row) leaves `AppAlertState` or
   `AlertState` to the developer, one per screen. Detail's existing alerts are `AppAlertState` with `.appAlert`, so the
   moderation alerts use it too. The roles and texts match UI-SPEC C-4 and C-5 exactly. Commits `56678d9c1`, `8259ef9e4`.
2. **Type name.** The plan calls the child `CommentModeration`. It is `CommentModerationFeature`, per AGENTS.md's
   reducer naming rule, in the plan's file `CommentModeration.swift`.
3. **Task 2 RED was not run on its own.** Task 2's tests were drafted while Task 1's build ran and first built
   against the implementation. They use actions and state that did not exist before Task 2 (`reportTapped`,
   `Destination.reportPage`, `isCollapsed`), so they could not have compiled before it, but that red build was not run.
4. **`postTapped` is reachable from the UI only after 18-11.** The views still send `.postComment` and dismiss
   themselves, as the plan intends: "the view change itself is in 18-11".

**Total deviations:** 4 (2 naming/mechanism choices the specs allow, 1 process note, 1 planned hand-off). **Impact:**
none on behaviour or scope.

## Issues Encountered

- **Strict lint inside the build.** `child_reducer_shorthand_scope` failed the first test build on the two
  `Scope { CommentModerationFeature() }` closures. They became `Scope(state:action:child: CommentModerationFeature.init)`.
- **`EquatableVoid` identity.** Detail's `.postComment(EquatableVoid)` destination makes a fresh id per value, so the
  Detail test checks the case, not equality with `.postComment(.init())`.
- **One timing failure in an unchanged test.** `CommentsReducerTests/presentingPostCommentResetsStaleComposeState`
  failed once, in the run where Task 1's code was first compiled: its real 750 ms sleep missed the 2 s receive
  timeout. The test and the code it covers are unchanged by this plan. It then passed in every later run (phone
  twice, pad, and the full plan). It is recorded for 18-12's gate, like the 18-03 flake.
- **Step 0 (the 18-02 hosted-store flake).**
  `UITestStubTests/hostedStoreKeepsItsFixturesWhenTheCallingTestScopeChanges` passed 30 of 30 iterations of
  AppFeatureTests on the phone (`-test-iterations 30 -run-tests-until-failure`), so it did not reproduce.
  - **What 18-02 changed:** it added both the `#expect(store.isUnlocked)` assertion and the preset path. The preset
    is written synchronously (`AppStorageKey.save` → `UserDefaults.set`) into the held in-memory suite before
    `initialState` is evaluated, inside the same `withDependencies` that builds the store.
  - **Why it isn't a product race:** no reducer path resets `ageDeclarationVersion`. The only way the store can read
    "unconfirmed" is a nil read from that suite. On iOS 17+, `UserDefaults.inMemory` is file-backed under
    `NSTemporaryDirectory()`, and swift-sharing's KVO re-read then writes the default `Setting()` back.
  - **Verdict:** a test-infrastructure timing flake under parallel load, not a race in shipped code. The stubbed and
    capture launches write the app's own storage before the store exists.
  - **If it recurs at 18-12:** seed the visual host's suite directly, or assert on the stored setting.

## Verification

- Task 1: `-only-testing:DetailFeatureTests` on the phone (FFE7E686) gave TEST SUCCEEDED. Strict lint of
  `AppPackage/Sources/DetailFeature` and `AppPackage/Tests/DetailFeatureTests` found 0 violations in 60 files.
- Task 2 (plan `<verification>`): `-only-testing:DetailFeatureTests`:
  - Phone FFE7E686: TEST SUCCEEDED, 97 test functions, 178 case runs, 0 failed.
  - Pad B470DB46: TEST SUCCEEDED, 97 test functions, 178 case runs, 0 failed.
  - Strict lint found 0 violations in 60 files.
- The full FeatureTests plan on the phone gave TEST SUCCEEDED, with 2586 case runs passed and 0 failed (`DetailReducer.State`
  gained a property, and other modules build Detail states).

## User Setup Required

None.

## Next

18-11 wires the views:
- `PostCommentView`'s Post sends `.postTapped`.
- The comments list and the Detail strip render `isCollapsed`/`revealedCommentIDs` and send the moderation actions.
- `.appAlert` presents `moderation.alert` over the sheet.
- The `reportPage` destination presents the session web sheet, seeded from `CookieClient.sessionCookies(for:)`.

## Self-Check: PASSED

- Both created files exist on disk.
- Commits `56678d9c1` and `8259ef9e4` are on `feature/gsd-phase-18`.
- The acceptance criteria were re-run:
  - "No request before the decision" is proven for the new-comment, edit and Detail paths.
  - Edit keeps the exact text and the sheet.
  - The show-once, block-all-by-author, own-comment and no-analytics tests pass on both devices.
