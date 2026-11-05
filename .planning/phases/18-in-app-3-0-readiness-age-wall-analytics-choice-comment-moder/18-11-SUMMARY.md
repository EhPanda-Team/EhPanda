---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "11"
subsystem: comments-ui
tags: [swiftui, comments, moderation, report, wkwebview, accessibility, xcuitest]

requires: ["18-04", "18-05", "18-06", "18-08"]
provides:
  - "`SessionWebView(url:cookies:)` in AppComponents: a web view on `WKWebsiteDataStore.nonPersistent()` that awaits every given cookie before `load`, never touches `HTTPCookieStorage`, and skips `load` in stubbed UI-test launches"
  - "`ReportPageSheet`: the gallery's `?report=select` page in that web view, seeded with `sessionCookies(for:)` for the report host only, at the large detent with `SheetCloseToolbar` and `.privacyMask()`, presented from the comments list and Detail"
  - "`CommentModerationMenu`: one item table (Report, Block / Unblock, Hide on a revealed card) that feeds the list's `…` menu, the cell's and card's context menus and their accessibility actions"
  - "`BlockedCommentRow` (C-6, with the C-7 revealed header) and `BlockedCommentCard` (C-8), neither of which receives the author"
  - "Post in `PostCommentView` sends `postTapped`; the posting warning shows over the open editor, and the views no longer dismiss the editor themselves (P-8)"
  - "`CommentModerationUITests` (7 cases), passing on phone and pad"
affects: [18-12]

actuals:
  tasks: 4
  commits: 7

tech-stack:
  added: []
  patterns:
    - "A child view that shows changing child state takes a scoped store (`store.scope(state:action:)`), not a copy of the state: a copy goes stale when the parent view does not observe the change"
    - "`accessibilityActions` hands its actions to VoiceOver last first, so a block that must read in menu order declares them reversed"
    - "Strip UI tests reach a card within the Detail scroll view's frame, not the window's, because on the iPad the Detail screen is a sheet"

key-files:
  created:
    - AppPackage/Sources/AppComponents/SessionWebView.swift
    - AppPackage/Sources/DetailFeature/Moderation/ReportPageSheet.swift
    - AppPackage/Sources/DetailFeature/Moderation/CommentModerationMenu.swift
    - AppPackage/Sources/DetailFeature/Moderation/BlockedCommentRow.swift
    - AppPackage/Sources/DetailFeature/Moderation/BlockedCommentCard.swift
    - AppPackage/Tests/DetailFeatureTests/BlockedCommentPresentationTests.swift
    - EhPandaUITests/CommentModerationUITests.swift
  modified:
    - AppPackage/Sources/DetailFeature/Components/PostCommentView.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Tests/DetailFeatureTests/CommentCardLayoutTests.swift
    - AppPackage/Sources/ParserFeature/Parser+Comment.swift
    - AppPackage/Tests/ParserFeatureTests/Gallery/GalleryCommentParserTests.swift

key-decisions:
  - "The parser now trims the whitespace after a comment's author. The site follows the name with `&nbsp; &nbsp;` and a contact link, so every parsed author carried trailing spaces. As a result, the block list, the `Block %@` labels and the own-comment name check did not match the name as shown. Fixed under Rule 1, outside the plan's file list"
  - "`CommentsSection` (the Detail strip) takes `StoreOf<CommentModerationFeature>`, scoped from DetailReducer, instead of a copy of `CommentModerationFeature.State` plus an action closure. With the copy, Show and Hide on a strip card changed the state but not the card"
  - "The cell's and the card's `accessibilityActions` are declared in reverse because SwiftUI hands them over last first. VoiceOver now reads links, then Report, then Block or Unblock (and Hide on a revealed card), the same order as the menu. For a comment with several links, the links are declared in reverse too, so they still read in text order"
  - "The list sets `comment_cell_<id>` on the comment cell, not on the row. On the row it replaced the collapsed row's own `blocked_comment_row` identifier"

patterns-established:
  - "Moderation UI tests preset the block list with `EHPANDA_UITEST_BLOCKED_AUTHORS` and the signed-in name with `EHPANDA_UITEST_DISPLAY_NAME` on every launch, and read sent requests from `EHPANDA_UITEST_REQUEST_LOG`; no case depends on another"

requirements-completed: []

coverage:
  - id: T1
    description: "Session web view, report sheet and the post intent"
    verification:
      - kind: unit
        ref: "BlockedCommentPresentationTests: the sheet asks sessionCookies(for:) with the report URL and passes only that; every cookie is set before load; no cookies still loads; a stubbed launch seeds but never loads; the store is non-persistent"
        status: pass
      - kind: automated_ui
        ref: "CommentModerationUITests.testTheMenuOffersReportThenBlockAndReportOpensTheSignedInSheet and testAMatchingCommentWaitsForTheSecondTap on phone and pad"
        status: pass
    human_judgment: false
  - id: T2
    description: "Comments list: menu, accessibility actions, collapsed and revealed rows"
    verification:
      - kind: unit
        ref: "BlockedCommentPresentationTests: item table per surface and state, collapsed row holds no author or text, its label is the catalog string, named accessibility actions in menu order"
        status: pass
      - kind: automated_ui
        ref: "testBlockCollapsesTheAuthorsCommentsAndShowHideAndUnblockWork, testTheCellOffersReportAndBlockInItsContextMenu, testTheUsersOwnCommentOffersNoModeration on phone and pad"
        status: pass
    human_judgment: false
  - id: T3
    description: "Detail strip: drawing group removal, context menu, collapsed card"
    verification:
      - kind: unit
        ref: "CommentCardLayoutTests.testCollapsedCardMatchesTheCommentCardAtEverySize on phone and pad"
        status: pass
      - kind: grep
        ref: "drawingGroup: 0 in DetailView+Subviews.swift; 2 files left in Sources (LoginView, GalleryDetailCell)"
        status: pass
      - kind: automated_ui
        ref: "testAStripCardOffersReportAndBlockOnALongPress, testABlockedAuthorsCardIsCollapsedAndShowAndUnblockWork on phone and pad"
        status: pass
    human_judgment: false
  - id: T4
    description: "CommentModerationUITests on both devices"
    verification:
      - kind: automated_ui
        ref: "CommentModerationUITests 7/7 on the phone (FFE7E686) and 7/7 on the pad (B470DB46), final code"
        status: pass
      - kind: visual
        ref: "Mockups 05 to 11 compared with kept screenshots from both devices (table below)"
        status: pass
    human_judgment: true

duration: about 1h20m in the final session (2026-11-05 13:13Z to 14:35Z), after two earlier runs that crashed
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 11: Comment moderation UI Summary

**A comment by someone else can now be reported on the site, signed in exactly as in the app, or its author can be
blocked. The list's `…` menu, the context menus on list cells and Detail strip cards, and the VoiceOver actions all
offer the same items. A blocked author's comments collapse into a row or card that never shows the name. A comment
can be shown and hidden again, and the author unblocked. A comment that matches the filter list waits for a second
tap before it is posted.**

## Accomplishments

- **Report (C-4, A-5, T-18-19):**
  - Report raises the `comment.report.confirm_*` alert. Open Report Page presents `ReportPageSheet`.
  - The sheet is a `SessionWebView` on a non-persistent WebKit store. It is seeded only with
    `sessionCookies(for:)` for the report URL's host, and every cookie is awaited before `load`. Nothing is
    written back to `HTTPCookieStorage`.
  - The sheet opens at the large detent with `SheetCloseToolbar`, no title and `.privacyMask()`. Its
    accessibility value is the report URL, with no cookie values.
  - In stubbed UI-test launches the sheet seeds the store but never loads, so no test reaches the live site.
- **Menu (C-4, A-10):**
  - `CommentModerationMenu` builds Report then Block (Unblock when blocked and revealed) from one table.
  - The table feeds three places:
    - the list header's `…` `Menu`: 44pt overhanging hit area, `.body` `ellipsis`, circular hover shape, hidden
      from accessibility;
    - the context menus on cells and strip cards;
    - the accessibility actions after the link actions.
  - A revealed card adds Hide as the third item.
  - The signed-in user's own comment gets none of the three.
- **Block, collapse, Show, Hide, Unblock (C-6 to C-8):**
  - Block asks with `comment.block.confirm_*` (Block is `.destructive`). The alerts are attached to the row or card
    that raised them.
  - Confirming collapses every comment by that author, with the `.default` animation (none under Reduce Motion).
    VoiceOver focus moves to the acted-on row.
  - Collapsed rows and cards take only the comment ID and their actions, so the name cannot reach them. They have no
    swipe actions and no context menu.
  - Show reveals one comment: in the list with the C-7 header line and Hide, on a card with its normal content and
    Hide in the context menu. Unblock expands them all with no confirmation.
- **Detail strip (Research §5.6 a):** `.drawingGroup()` is removed from the strip only. The collapsed card shares the
  normal card's size metric at every Dynamic Type step.
- **Posting warning (C-5, P-8):** Post sends `postTapped`. A matching comment raises the warning over the open editor:
  - Edit keeps the text and refocuses the editor.
  - Post Anyway sends the comment once and the reducer closes the editor.
  - Neither view dismisses the editor itself any more.

## Task Commits

1. **Task 1, report sheet and post intent:** `d169d1620` feat(18-11): report sheet on a private web view and the
   post intent
2. **Task 2, comments list:** `1a2cf5629` feat(18-11): comment menu, accessibility actions and collapsed rows in the
   list
3. **Task 3, Detail strip:** `f88c179ec` feat(18-11): Detail strip moderation on fixed-size cards
4. **Fixes found by the UI tests:**
   - `0a0913180` fix(18-11): exact comment authors and menu-ordered accessibility actions
   - `7201d0ac8` fix(18-11): Show on a strip card and the collapsed row's identifier
5. **Task 4, UI tests:**
   - `fe3731f0e` test(18-11): comment moderation end to end in the list and the Detail strip
   - `710d15da6` test(18-11): reach the strip inside the iPad's Detail sheet

## Verification

All runs below are on the final code, after `710d15da6` (the last commit changed only the UI test file).

- **DetailFeatureTests and ParserFeatureTests** (`-testPlan FeatureTests`): TEST SUCCEEDED with 188/188 passed on the
  phone (FFE7E686), then 188/188 on the pad (B470DB46).
  - `BlockedCommentPresentationTests` has 15 tests: the item table, the collapsed row's content and label, accessibility
    actions in menu order, report-sheet cookies scoped to the host, cookies before load, signed-out load, stubbed no-load,
    and the non-persistent store.
  - `CommentCardLayoutTests` adds `testCollapsedCardMatchesTheCommentCardAtEverySize`.
  - `GalleryCommentParserTests` asserts that authors are exact.
- **`CommentModerationUITests`** (`-testPlan UITests`): 7/7 passed on the phone and 7/7 on the pad:
  - `testTheMenuOffersReportThenBlockAndReportOpensTheSignedInSheet`: Report comes before Block in the `…` menu.
    Report raises the alert, and Open shows the sheet with the fixture gallery's `?report=select` URL.
  - `testBlockCollapsesTheAuthorsCommentsAndShowHideAndUnblockWork`: after Block, no element on screen holds the
    blocked name. Show, Hide and Unblock work.
  - `testTheCellOffersReportAndBlockInItsContextMenu`.
  - `testTheUsersOwnCommentOffersNoModeration`: signed in with the display name set to the comment's author, the comment
    has no `…` and no context menu items.
  - `testAStripCardOffersReportAndBlockOnALongPress`: Report comes above Block.
  - `testABlockedAuthorsCardIsCollapsedAndShowAndUnblockWork`: the collapsed card shows no name. Show reveals the card,
    whose menu holds Hide and Unblock. Hide collapses it again, and Unblock expands it.
  - `testAMatchingCommentWaitsForTheSecondTap`: the term is read from `CommentFilterTerms.json` at test time. Edit keeps
    the exact text and nothing is sent. Post Anyway closes the editor and logs exactly one `POST` to the gallery path.
- **Greps:**
  - `drawingGroup` occurs 0 times in `DetailView+Subviews.swift`, and only `LoginView.swift` and
    `GalleryDetailCell.swift` still contain it in `AppPackage/Sources`.
  - `WebView(url|openURL` has 0 matches in `DetailFeature/Moderation`.
  - `SessionWebView.swift` contains `nonPersistent` and no `HTTPCookieStorage`.
- **Strict lint:** no-cache swiftlint found 0 violations over `AppPackage/Sources/DetailFeature`,
  `AppPackage/Sources/AppComponents`, `AppPackage/Tests/DetailFeatureTests` and `EhPandaUITests`. The lint build plugin
  also passed in every test build.

### Visual check (mockups 05 to 11)

The screenshots are attachments kept by the final UI runs. They were exported to a temporary directory outside the repo
and not committed. The phone is the iPhone Air and the pad is the iPad Pro 11", where Detail and Comments are sheets.
Both ran in light mode, so the dark mockups (07, 09) were compared for layout and content only.

| Mockup | Phone | Pad | Notes |
|--------|-------|-----|-------|
| 05 comment menu | match | match | Report on E-Hentai, then Block 黑锋血色 in red, from the `…` at the header's trailing end. |
| 06 report confirm | match | match | Title, body naming the site and author, Open Report Page, then Cancel. |
| 07 block confirm | match | match | `Block 黑锋血色?` with Cancel and a red Block. |
| 08 collapsed row | match | match | Eye-slash label `Comment from a user you've blocked` with Show and Unblock pills. No name, avatar, score, date or text. |
| 09 revealed row | match | match | C-7 header line with Hide above the normal cell. |
| 10 post warning | match | match | Shown over the open editor, Edit then Post Anyway. |
| 11 Detail preview | match | match | The collapsed card is the same size as its neighbours and shows Show and Unblock. The card's context menu shows Report then Block. |

Finding for the lead: in the list, the `…` glyph renders in the app's green tint rather than gray `.secondary`. The
code asks for `.secondary`, but the menu button's style draws the label in the tint. This was left as built: changing
it needs a design call, and every UI run on both devices would have to be repeated.

## Deviations from Plan

1. **Parser change outside the file list** (Rule 1, bug): `Parser+Comment.swift` trims the author, and
   `GalleryCommentParserTests.swift` gained a case for it. Without this, no moderation action could match a parsed
   author.
2. **Reversed accessibility action declarations:** see the key decision above. A comment with several links also has
   its link actions declared in reverse, so that VoiceOver still reads them in text order.
3. **Unit test reads named accessibility actions through a private symbol:** XCUITest cannot read custom actions, so
   `BlockedCommentPresentationTests` reads them from the rendered accessibility tree. It reaches that tree through a
   `dlsym` lookup.
4. **Identifier moved in `CommentsView`:** `comment_cell_<id>` now sits on the cell, not the row (see above).
5. **UI tests, compared with the plan's list:**
   - **No VoiceOver custom-action assertions in XCUITest**, which cannot read them. The unit test above covers that path.
   - **`…` tapped by coordinate:** inside the cell's combined accessibility element, the button never reads as hittable.
   - **Strip reached by dragging:** the helper drags the strip until the card is wholly inside the Detail scroll view.
     On the pad that view is a sheet, which is why `710d15da6` measures against the scroll view's frame rather than the
     window.
6. **`CommentsSection` takes a scoped store:** see the key decision above. The plan's action already says "takes the
   moderation store scope". The first draft passed a state copy instead, and `7201d0ac8` corrects that.
7. **TDD order:** two earlier executor runs had already written Tasks 1 to 3 without committing them before they
   crashed. This run checked that draft, split it into per-task commits and finished it. A red step could be
   reproduced only for the parser test and the accessibility-order test. The other unit tests were already green
   against the draft when this run began.

## Notes for later plans

- 18-12's closing gate should rerun `CommentModerationUITests` on both devices.
- The `…` tint finding above needs a call from the designer or the lead.
- UGC-18-01 stays Pending: 18-12 and Phase 20 share it.

## Next

Wave 3 is complete. 18-12 (Wave 4) is next.
